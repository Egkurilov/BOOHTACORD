package observeincidents

import (
	"github.com/prometheus/client_golang/prometheus"
)

var staleDescription = prometheus.NewDesc("voice_platform_incident_stale", "Latest successful observation older than fixed operation threshold, or no successful attempt.", []string{"operation"}, nil)

func (m *Metrics) collectStale(c chan<- prometheus.Metric) {
	m.export.mu.Lock()
	defer m.export.mu.Unlock()
	for operation, s := range m.export.latest {
		value := 0.
		if s.success == 0 || float64(m.now().Unix())-s.success > staleAfter(operation).Seconds() {
			value = 1
		}
		c <- prometheus.MustNewConstMetric(staleDescription, prometheus.GaugeValue, value, operation)
	}
}
