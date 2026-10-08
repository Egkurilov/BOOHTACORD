package searchmessagespostgres

import (
	"context"
	"testing"
)

func TestRussianSearchQualityReport(t *testing.T) {
	fixture := newSearchFixture(t)
	corpus := readRussianCorpus(t)
	ctx := context.Background()
	_, err := fixture.pool.Exec(ctx, `CREATE TABLE imp17_corpus (
		id text PRIMARY KEY, body text NOT NULL,
		simple_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', body)) STORED,
		russian_vector tsvector GENERATED ALWAYS AS (to_tsvector('russian', body)) STORED)`)
	if err != nil {
		t.Fatal("create synthetic search table:", err)
	}
	seedRussianCorpus(t, fixture, ctx, corpus)
	for _, name := range []string{"simple", "russian"} {
		vector, index := name+"_vector", "imp17_"+name+"_gin"
		if _, err := fixture.pool.Exec(ctx, "CREATE INDEX "+index+" ON imp17_corpus USING GIN ("+vector+")"); err != nil {
			t.Fatal("create comparison index:", err)
		}
	}
	if _, err := fixture.pool.Exec(ctx, "ANALYZE imp17_corpus"); err != nil {
		t.Fatal("analyze synthetic corpus:", err)
	}
	for _, config := range []string{"simple", "russian"} {
		reportSearchConfig(t, fixture, ctx, corpus, config)
	}
}
