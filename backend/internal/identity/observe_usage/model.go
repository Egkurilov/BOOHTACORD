package observeusage

import (
	"context"
	"time"
)

// All account dates in this deployment use Moscow's UTC+3 calendar.
var moscow = time.FixedZone("Europe/Moscow", 3*60*60)

func Day(at time.Time) time.Time {
	at = at.In(moscow)
	return time.Date(at.Year(), at.Month(), at.Day(), 0, 0, 0, 0, moscow)
}

type Snapshot struct {
	Users, RegistrationsToday, RegistrationsYesterday int64
	ActiveToday, ActiveYesterday                      int64
	StartedAt                                         time.Time
}

type Store interface {
	Record(context.Context, string, time.Time) error
	Snapshot(context.Context, time.Time) (Snapshot, error)
}
