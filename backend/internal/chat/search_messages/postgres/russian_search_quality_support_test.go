package searchmessagespostgres

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

type russianCorpus struct {
	Documents []struct{ ID, Body string } `json:"documents"`
	Queries   []struct {
		Query      string   `json:"query"`
		ExpectedID []string `json:"expected_ids"`
	} `json:"queries"`
}

func readRussianCorpus(t *testing.T) russianCorpus {
	t.Helper()
	file, err := os.ReadFile(filepath.Join("testdata", "russian_search_corpus.json"))
	if err != nil {
		t.Fatal("read synthetic corpus:", err)
	}
	var corpus russianCorpus
	if err := json.Unmarshal(file, &corpus); err != nil {
		t.Fatal("decode synthetic corpus:", err)
	}
	return corpus
}

func seedRussianCorpus(t *testing.T, fixture searchFixture, ctx context.Context, corpus russianCorpus) {
	t.Helper()
	insert := func(id, body string) {
		t.Helper()
		if _, err := fixture.pool.Exec(ctx, "INSERT INTO imp17_corpus (id, body) VALUES ($1, $2)", id, body); err != nil {
			t.Fatal("seed synthetic document:", err)
		}
	}
	for _, document := range corpus.Documents {
		insert(document.ID, document.Body)
	}
	for index := 0; index < 5000; index++ {
		insert(fmt.Sprintf("noise-%05d", index), fmt.Sprintf("техническая запись индекса номер %d без целевых терминов", index))
	}
}

func reportSearchConfig(t *testing.T, fixture searchFixture, ctx context.Context, corpus russianCorpus, config string) {
	t.Helper()
	truePositive, falsePositive, falseNegative := 0, 0, 0
	for _, query := range corpus.Queries {
		actual := runCorpusQuery(t, fixture, ctx, config, query.Query)
		want := makeSet(query.ExpectedID)
		got := makeSet(actual)
		for id := range want {
			if got[id] {
				truePositive++
			} else {
				falseNegative++
			}
		}
		for id := range got {
			if !want[id] {
				falsePositive++
			}
		}
		plan := explainCorpusQuery(t, fixture, ctx, config, query.Query)
		t.Logf("IMP-17 config=%s query=%q expected=%v actual=%v plan=%s", config, query.Query, query.ExpectedID, actual, plan)
	}
	var indexBytes int64
	if err := fixture.pool.QueryRow(ctx, "SELECT pg_relation_size($1::regclass)", "imp17_"+config+"_gin").Scan(&indexBytes); err != nil {
		t.Fatal("read synthetic index size:", err)
	}
	t.Logf("IMP-17 summary config=%s corpus_rows=%d recall=%s precision=%s gin_index_bytes=%d", config, len(corpus.Documents)+5000, ratio(truePositive, truePositive+falseNegative), ratio(truePositive, truePositive+falsePositive), indexBytes)
}

func makeSet(values []string) map[string]bool {
	set := make(map[string]bool, len(values))
	for _, value := range values {
		set[value] = true
	}
	return set
}
func ratio(numerator, denominator int) string {
	if denominator == 0 {
		return "n/a"
	}
	return fmt.Sprintf("%.3f", float64(numerator)/float64(denominator))
}
