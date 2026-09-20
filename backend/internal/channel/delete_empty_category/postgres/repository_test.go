package deleteemptycategorypostgres

import (
	"context"
	"strings"
	"testing"
	deleteemptycategory "voice-platform/backend/internal/channel/delete_empty_category"
)

func TestRepositoryLocksTopologyAndRequiresEmptyCategory(t *testing.T) {
	tx := &fakeTx{row: fakeRow{values: []any{"category-1", int64(3)}}}
	result, err := New(&fakeDB{tx}).Delete(context.Background(), deleteemptycategory.Input{ActorID: "admin-1", CategoryID: "category-1", ExpectedRevision: 2})
	if err != nil || !tx.locked || !tx.committed || result.Revision != 3 {
		t.Fatalf("result=%#v err=%v", result, err)
	}
	for _, s := range []string{"DELETE FROM categories", "NOT EXISTS (SELECT 1 FROM channels", "revision = $1", "INSERT INTO audit_events", "EMPTY_CATEGORY_DELETED"} {
		if !strings.Contains(tx.statement, s) {
			t.Fatal(s)
		}
	}
}

type fakeDB struct{ tx *fakeTx }

func (d *fakeDB) Begin(context.Context) (Transaction, error) { return d.tx, nil }

type fakeTx struct {
	locked, committed bool
	statement         string
	row               fakeRow
}

func (t *fakeTx) Lock(context.Context, int64) error                  { t.locked = true; return nil }
func (t *fakeTx) QueryRow(_ context.Context, s string, _ ...any) Row { t.statement = s; return t.row }
func (t *fakeTx) Commit(context.Context) error                       { t.committed = true; return nil }
func (t *fakeTx) Rollback(context.Context) error                     { return nil }

type fakeRow struct{ values []any }

func (r fakeRow) Scan(d ...any) error {
	*(d[0].(*string)) = r.values[0].(string)
	*(d[1].(*int64)) = r.values[1].(int64)
	return nil
}
