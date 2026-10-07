package observeincidents

func (m *Metrics) SetEnabled(operation string, enabled bool) {
	switch operation {
	case "trace_export", "metric_export", "relay_export":
	default:
		return
	}
	value := 0.
	if enabled {
		value = 1
	}
	m.enabled.WithLabelValues(operation).Set(value)
	m.export.mu.Lock()
	defer m.export.mu.Unlock()
	m.export.enabled[operation] = value
}
