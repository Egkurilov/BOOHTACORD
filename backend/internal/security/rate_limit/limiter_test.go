package ratelimit

import (
	"fmt"
	"testing"
	"time"
)

func BenchmarkLimiterLookupAndAdmission(b *testing.B) {
	for _, size := range []int{100, 1_000, 10_000} {
		b.Run(fmt.Sprintf("existing/%d", size), func(b *testing.B) {
			limiter, _ := New(Config{Limit: b.N + size + 1, Window: time.Hour, MaxSources: size + b.N + 1})
			for index := 0; index < size; index++ {
				limiter.Allow(fmt.Sprintf("seed-%d", index))
			}
			b.ResetTimer()
			for index := 0; index < b.N; index++ {
				limiter.Allow("seed-0")
			}
		})
		b.Run(fmt.Sprintf("new/%d", size), func(b *testing.B) {
			limiter, _ := New(Config{Limit: 1, Window: time.Hour, MaxSources: size + b.N + 1})
			for index := 0; index < size; index++ {
				limiter.Allow(fmt.Sprintf("seed-%d", index))
			}
			keys := make([]string, b.N)
			for index := range keys {
				keys[index] = fmt.Sprintf("new-%d", index)
			}
			b.ResetTimer()
			for _, key := range keys {
				limiter.Allow(key)
			}
		})
	}
}
