package ratelimit

import (
	"container/heap"
	"time"
)

type expiry struct {
	source string
	reset  time.Time
}

type expirations []expiry

func (items expirations) Len() int           { return len(items) }
func (items expirations) Less(i, j int) bool { return items[i].reset.Before(items[j].reset) }
func (items expirations) Swap(i, j int)      { items[i], items[j] = items[j], items[i] }
func (items *expirations) Push(value any)    { *items = append(*items, value.(expiry)) }
func (items *expirations) Pop() any {
	old := *items
	last := old[len(old)-1]
	*items = old[:len(old)-1]
	return last
}

func (limiter *Limiter) pruneExpired(now time.Time, budget int) {
	for budget > 0 && len(limiter.expires) > 0 && !now.Before(limiter.expires[0].reset) {
		candidate := heap.Pop(&limiter.expires).(expiry)
		if current, found := limiter.entries[candidate.source]; found && current.reset.Equal(candidate.reset) {
			delete(limiter.entries, candidate.source)
		}
		budget--
	}
}

func maxDuration(minimum, actual time.Duration) time.Duration {
	if actual < minimum {
		return minimum
	}
	return actual
}
