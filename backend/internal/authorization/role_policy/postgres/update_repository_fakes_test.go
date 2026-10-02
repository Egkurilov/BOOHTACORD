package rolepolicypostgres

import (
	"context"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
)

type updateDatabase struct{ transaction *updateTransaction }

func (database *updateDatabase) QueryRow(context.Context, string, ...any) Row { return fakeRow{} }
func (database *updateDatabase) Begin(context.Context) (Transaction, error) {
	return database.transaction, nil
}

type updateTransaction struct {
	selectRow   Row
	updateRow   Row
	updateCalls int
	auditCalls  int
	committed   bool
	rolledBack  bool
}

func newUpdateTransaction(policy permissionregistry.Policy) *updateTransaction {
	return &updateTransaction{selectRow: policyRow(policy)}
}

func (transaction *updateTransaction) QueryRow(_ context.Context, statement string, _ ...any) Row {
	if statement == selectMemberForUpdate {
		return transaction.selectRow
	}
	transaction.updateCalls++
	return transaction.updateRow
}
func (transaction *updateTransaction) Exec(context.Context, string, ...any) error {
	transaction.auditCalls++
	return nil
}
func (transaction *updateTransaction) Commit(context.Context) error {
	transaction.committed = true
	return nil
}
func (transaction *updateTransaction) Rollback(context.Context) error {
	transaction.rolledBack = true
	return nil
}

func policyRow(policy permissionregistry.Policy) fakeRow {
	return fakeRow{values: []any{policy.TextCreate, policy.TextDelete, policy.VoiceCreate, policy.VoiceDelete, policy.CategoryCreate, policy.CategoryDelete, policy.Revision}}
}
