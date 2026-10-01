package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertArrayEquals;

import org.junit.Test;

public class ScreenCaptureDimensionsTest {
    @Test
    public void keepsCapturedAppDimensionsIndependentOfDeviceOrientation() {
        assertArrayEquals(
                new int[] {720, 1280},
                ScreenCaptureDimensions.forOutput(720, 1280, false, true));
    }

    @Test
    public void normalizesLegacyFullDisplayCaptureToPortraitOrientation() {
        assertArrayEquals(
                new int[] {1080, 2400},
                ScreenCaptureDimensions.forOutput(2400, 1080, true, false));
    }

    @Test
    public void normalizesLegacyFullDisplayCaptureToLandscapeOrientation() {
        assertArrayEquals(
                new int[] {2400, 1080},
                ScreenCaptureDimensions.forOutput(1080, 2400, false, false));
    }
}
