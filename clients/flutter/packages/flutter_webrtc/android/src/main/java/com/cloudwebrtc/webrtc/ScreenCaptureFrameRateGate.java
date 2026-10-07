package com.cloudwebrtc.webrtc;

final class ScreenCaptureFrameRateGate {
    private static final long NANOS_PER_SECOND = 1_000_000_000L;
    private final int maximumFramesPerSecond;
    private long lastForwardedAt = Long.MIN_VALUE;

    ScreenCaptureFrameRateGate(int maximumFramesPerSecond) {
        this.maximumFramesPerSecond = maximumFramesPerSecond;
    }

    boolean shouldForward(long nowNanos) {
        if (maximumFramesPerSecond <= 0) return true;
        long interval = NANOS_PER_SECOND / maximumFramesPerSecond;
        if (lastForwardedAt != Long.MIN_VALUE && nowNanos >= lastForwardedAt
                && nowNanos - lastForwardedAt < interval) {
            return false;
        }
        lastForwardedAt = nowNanos;
        return true;
    }

    void reset() {
        lastForwardedAt = Long.MIN_VALUE;
    }
}
