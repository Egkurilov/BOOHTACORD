package coalescepresencesnapshot

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
)

// Synthetic observation cost, not a hardware/media capacity measurement.
func BenchmarkEquivalentScopeFanout(b *testing.B) {
	for _, watchers := range []int{1, 10, 25, 50, 100} {
		for _, rooms := range []int{0, 1, 5, 20} {
			for _, coalesced := range []bool{false, true} {
				b.Run(fmt.Sprintf("watchers=%d/rooms=%d/coalesced=%t", watchers, rooms, coalesced), func(b *testing.B) {
					var calls atomic.Int64
					ids := make([]string, rooms)
					for index := range ids {
						ids[index] = fmt.Sprint(index)
					}
					source := sourceFunc(func(context.Context, []string) (Snapshot, error) { calls.Add(1); return Snapshot{}, nil })
					gate := New(source)
					for range b.N {
						gate.Invalidate()
						var group sync.WaitGroup
						for range watchers {
							group.Add(1)
							go func() {
								defer group.Done()
								if coalesced {
									_, _ = gate.SnapshotRooms(context.Background(), ids)
								} else {
									_, _ = source.SnapshotRooms(context.Background(), ids)
								}
							}()
						}
						group.Wait()
					}
					b.ReportMetric(float64(calls.Load())/float64(b.N), "source-calls/burst")
				})
			}
		}
	}
}
