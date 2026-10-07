package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ScreenCaptureFrameRateGateTest {
    @Test
    public void forwardsNoMoreThanTheRequestedCadence() {
        ScreenCaptureFrameRateGate gate = new ScreenCaptureFrameRateGate(15);
        assertTrue(gate.shouldForward(1_000_000_000L));
        assertFalse(gate.shouldForward(1_020_000_000L));
        assertTrue(gate.shouldForward(1_070_000_000L));
    }

    @Test
    public void resetAllowsFirstFrameOfNewCaptureGenerationImmediately() {
        ScreenCaptureFrameRateGate gate = new ScreenCaptureFrameRateGate(30);
        assertTrue(gate.shouldForward(1_000_000_000L));
        gate.reset();
        assertTrue(gate.shouldForward(1_000_000_001L));
    }

    @Test
    public void nonPositiveRateLeavesTheFrameCadenceUnchanged() {
        ScreenCaptureFrameRateGate gate = new ScreenCaptureFrameRateGate(0);
        assertTrue(gate.shouldForward(1_000_000_000L));
        assertTrue(gate.shouldForward(1_000_000_001L));
    }
}
