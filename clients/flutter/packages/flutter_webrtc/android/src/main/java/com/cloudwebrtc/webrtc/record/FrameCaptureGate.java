package com.cloudwebrtc.webrtc.record;

import java.util.concurrent.atomic.AtomicBoolean;

/** Ensures a frame capture is completed by at most one frame or timeout. */
final class FrameCaptureGate {
    private final AtomicBoolean completed = new AtomicBoolean(false);

    boolean tryComplete() {
        return completed.compareAndSet(false, true);
    }
}
