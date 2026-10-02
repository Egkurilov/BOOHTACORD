package com.cloudwebrtc.webrtc;

/** Tracks whether a SurfaceProducer surface may currently be used for EGL rendering. */
final class SurfaceProducerAvailability {
    private boolean available = true;

    boolean isAvailable() {
        return available;
    }

    void onSurfaceCleanup() {
        available = false;
    }

    void onSurfaceAvailable() {
        available = true;
    }
}
