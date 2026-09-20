package httpmetrics

func (recorder *Recorder) ObserveVoiceSFURevocation(confirmed, pending int, failed bool) {
	if confirmed > 0 {
		recorder.voiceSFURevocations.WithLabelValues("confirmed").Add(float64(confirmed))
	}
	if pending > 0 {
		recorder.voiceSFURevocations.WithLabelValues("pending").Add(float64(pending))
	}
	if failed {
		recorder.voiceSFURevocations.WithLabelValues("failed").Inc()
	}
}
