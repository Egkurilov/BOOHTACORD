package inspectattachmentcleanup

import (
	"os"
	"path/filepath"
	"strings"
	"time"
)

func Staging(directory string, now time.Time) (Report, error) {
	if !filepath.IsAbs(directory) || now.IsZero() {
		return Report{}, ErrInvalid
	}
	entries, err := os.ReadDir(directory)
	if err != nil {
		return Report{}, err
	}
	report := empty()
	for _, entry := range entries {
		info, err := entry.Info()
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return Report{}, err
		}
		reason := "eligible"
		switch {
		case !info.Mode().IsRegular():
			reason = "non_regular"
		case !strings.HasPrefix(entry.Name(), "upload-") || !strings.HasSuffix(entry.Name(), ".part"):
			reason = "unexpected"
		case !info.ModTime().Before(now.Add(-time.Hour)):
			reason = "fresh"
		}
		if reason == "eligible" {
			report.Eligible.Count++
			report.Eligible.Bytes += info.Size()
		} else {
			totals := report.Skipped[reason]
			totals.Count++
			totals.Bytes += info.Size()
			report.Skipped[reason] = totals
		}
	}
	return report, nil
}
