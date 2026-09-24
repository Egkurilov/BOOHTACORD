package httpmetrics

import (
	"context"
	"errors"
	"strings"
	"testing"
)

type fakeVoiceMedia struct {
	snapshot VoiceMediaSnapshot
	err      error
}

func (source fakeVoiceMedia) Snapshot(context.Context) (VoiceMediaSnapshot, error) {
	return source.snapshot, source.err
}

func TestRecorderPublishesAuthoritativeVoiceMediaSnapshot(t *testing.T) {
	recorder := New()
	if err := recorder.RegisterVoiceMedia(fakeVoiceMedia{snapshot: VoiceMediaSnapshot{Participants: 2, Streams: 3, ScreenStreams: 1}}); err != nil {
		t.Fatal(err)
	}
	metrics := scrapeMetrics(recorder)
	for _, line := range []string{
		"voice_platform_voice_media_snapshot_success 1",
		"voice_platform_voice_participants_active 2",
		"voice_platform_voice_streams_active 3",
		"voice_platform_voice_screen_streams_active 1",
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	for _, secret := range []string{"voice:11111111", "voice-lease:", "account_id", "dm_id", "room="} {
		if strings.Contains(metrics, secret) {
			t.Fatalf("metrics leaked %q: %q", secret, metrics)
		}
	}
}

func TestRecorderDistinguishesVoiceMediaFailureFromZero(t *testing.T) {
	zeroRecorder := New()
	if err := zeroRecorder.RegisterVoiceMedia(fakeVoiceMedia{}); err != nil {
		t.Fatal(err)
	}
	zeroMetrics := scrapeMetrics(zeroRecorder)
	for _, line := range []string{
		"voice_platform_voice_media_snapshot_success 1",
		"voice_platform_voice_participants_active 0",
		"voice_platform_voice_streams_active 0",
		"voice_platform_voice_screen_streams_active 0",
	} {
		if !strings.Contains(zeroMetrics, line) {
			t.Fatalf("zero snapshot lacks %q: %q", line, zeroMetrics)
		}
	}

	recorder := New()
	if err := recorder.RegisterVoiceMedia(fakeVoiceMedia{err: errors.New("private room identity")}); err != nil {
		t.Fatal(err)
	}
	metrics := scrapeMetrics(recorder)
	if !strings.Contains(metrics, "voice_platform_voice_media_snapshot_success 0") {
		t.Fatalf("missing failed snapshot gauge: %q", metrics)
	}
	for _, forbidden := range []string{"voice_platform_voice_participants_active ", "voice_platform_voice_streams_active ", "voice_platform_voice_screen_streams_active ", "private room identity"} {
		if strings.Contains(metrics, forbidden) {
			t.Fatalf("failed scrape disclosed/staled %q: %q", forbidden, metrics)
		}
	}
}

func TestRecorderRejectsInvalidOrDuplicateVoiceMediaSource(t *testing.T) {
	recorder := New()
	if err := recorder.RegisterVoiceMedia(nil); !errors.Is(err, ErrInvalidVoiceMediaSource) {
		t.Fatalf("nil source error = %v", err)
	}
	if err := recorder.RegisterVoiceMedia(fakeVoiceMedia{}); err != nil {
		t.Fatal(err)
	}
	if err := recorder.RegisterVoiceMedia(fakeVoiceMedia{}); !errors.Is(err, ErrVoiceMediaAlreadyRegistered) {
		t.Fatalf("duplicate source error = %v", err)
	}
}
