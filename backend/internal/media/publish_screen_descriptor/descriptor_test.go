package publish_screen_descriptor

import "testing"

func TestValidateAcceptsSupportedProfileAndRejectsInvalidRevision(t *testing.T) {
	value := validDescriptor()
	if !Validate(value) {
		t.Fatal("valid descriptor rejected")
	}
	value.Scope.OperationRevision = 0
	if Validate(value) {
		t.Fatal("zero operation revision accepted")
	}
}

func validDescriptor() Descriptor {
	return Descriptor{SchemaVersion: 1, Scope: Scope{MediaSessionID: "media-session", PublicationGeneration: 1, OperationRevision: 1},
		Mode: "text", PublisherState: "sharing", ViewerState: "idle", RequestedProfileID: "P1080_30",
		EffectiveProfile: EffectiveProfile{Capture: Capture{MaxWidth: 1920, MaxHeight: 1080, MaxFPS: 30}, Encoding: Encoding{Layers: []Layer{{Width: 1920, Height: 1080, MaxFPS: 30, MaxBitrateBPS: 2_000_000, ScaleDownBy: 1, Active: true}}}},
		LayerTopology:    "single-layer", ProfileRevision: 1, ReasonCodes: []string{"user-request"}}
}
