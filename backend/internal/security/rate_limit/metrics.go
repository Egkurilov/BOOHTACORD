package ratelimit

import "github.com/prometheus/client_golang/prometheus"

type Stats struct {
	ActiveSources int
	MaxSources    int
	Saturated     uint64
}

func (limiter *Limiter) Stats() Stats {
	limiter.mutex.Lock()
	defer limiter.mutex.Unlock()
	return Stats{ActiveSources: len(limiter.entries), MaxSources: limiter.maxSources, Saturated: limiter.saturated}
}

type Collector struct {
	active, capacity, saturated *prometheus.Desc
	limiters                    map[string]*Limiter
}

func NewCollector(limiters map[string]*Limiter) *Collector {
	return &Collector{
		active:    prometheus.NewDesc("voice_platform_rate_limit_sources_active", "Active source budgets held by rate limiters.", []string{"operation"}, nil),
		capacity:  prometheus.NewDesc("voice_platform_rate_limit_sources_capacity", "Maximum active source budgets held by rate limiters.", []string{"operation"}, nil),
		saturated: prometheus.NewDesc("voice_platform_rate_limit_saturation_total", "New source requests rejected because the bounded limiter is full.", []string{"operation"}, nil),
		limiters:  limiters,
	}
}

func (collector *Collector) Describe(channel chan<- *prometheus.Desc) {
	channel <- collector.active
	channel <- collector.capacity
	channel <- collector.saturated
}

func (collector *Collector) Collect(channel chan<- prometheus.Metric) {
	for operation, limiter := range collector.limiters {
		stats := limiter.Stats()
		channel <- prometheus.MustNewConstMetric(collector.active, prometheus.GaugeValue, float64(stats.ActiveSources), operation)
		channel <- prometheus.MustNewConstMetric(collector.capacity, prometheus.GaugeValue, float64(stats.MaxSources), operation)
		channel <- prometheus.MustNewConstMetric(collector.saturated, prometheus.CounterValue, float64(stats.Saturated), operation)
	}
}
