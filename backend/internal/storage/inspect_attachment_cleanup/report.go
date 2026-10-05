package inspectattachmentcleanup

import "errors"

var ErrInvalid = errors.New("invalid attachment cleanup inspection")

type Totals struct {
	Count int64 `json:"count"`
	Bytes int64 `json:"bytes"`
}
type Report struct {
	Eligible           Totals            `json:"eligible"`
	OldestRetrySeconds float64           `json:"oldest_retry_seconds"`
	Skipped            map[string]Totals `json:"skipped"`
}

func empty() Report { return Report{Skipped: make(map[string]Totals)} }
