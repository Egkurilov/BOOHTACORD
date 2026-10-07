package measurement

// Report has bounded values only. Publication/RID/SSRC stay in local diagnostics.
type Report struct {
	TotalBitrateKbps         *float64 `json:"total_bitrate_kbps,omitempty"`
	SelectedLayerBitrateKbps *float64 `json:"selected_layer_bitrate_kbps,omitempty"`
	RetransmittedBitrateKbps *float64 `json:"retransmitted_bitrate_kbps,omitempty"`
	EncodeMsPerFrame         *float64 `json:"encode_ms_per_frame,omitempty"`
	DecodeMsPerFrame         *float64 `json:"decode_ms_per_frame,omitempty"`
	JitterBufferMsPerFrame   *float64 `json:"jitter_buffer_ms_per_frame,omitempty"`
	NackPerSecond            *float64 `json:"nack_per_second,omitempty"`
	PliPerSecond             *float64 `json:"pli_per_second,omitempty"`
	FirPerSecond             *float64 `json:"fir_per_second,omitempty"`
	FirstFrameMs             *float64 `json:"first_frame_ms,omitempty"`
	FreezeDurationMs         *float64 `json:"freeze_duration_ms,omitempty"`
	FreezeCount              *int64   `json:"freeze_count,omitempty"`
	StatsWindowMs            *float64 `json:"stats_window_ms,omitempty"`
	CollectionState          string   `json:"collection_state,omitempty"`
	PresentationSource       string   `json:"presentation_source,omitempty"`
	StatsSource              string   `json:"stats_source,omitempty"`
}

func (r Report) Numbers() map[string]*float64 {
	return map[string]*float64{
		"total_bitrate_kbps": r.TotalBitrateKbps, "selected_layer_bitrate_kbps": r.SelectedLayerBitrateKbps,
		"retransmitted_bitrate_kbps": r.RetransmittedBitrateKbps, "encode_ms_per_frame": r.EncodeMsPerFrame,
		"decode_ms_per_frame": r.DecodeMsPerFrame, "jitter_buffer_ms_per_frame": r.JitterBufferMsPerFrame,
		"nack_per_second": r.NackPerSecond, "pli_per_second": r.PliPerSecond, "fir_per_second": r.FirPerSecond,
		"first_frame_ms": r.FirstFrameMs, "freeze_duration_ms": r.FreezeDurationMs, "stats_window_ms": r.StatsWindowMs,
	}
}

func (r Report) Enums() map[string]string {
	return map[string]string{"collection_state": r.CollectionState, "presentation_source": r.PresentationSource, "stats_source": r.StatsSource}
}
