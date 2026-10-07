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

    @Test
    public void capsPortraitAppCaptureWithoutChangingItsAspectRatio() {
        assertArrayEquals(
                new int[] {720, 1280},
                ScreenCaptureDimensions.forOutput(901, 1601, false, true, 1280));
    }

    @Test
    public void capsLandscapeCaptureAndRoundsScaledBufferToEvenDimensions() {
        assertArrayEquals(
                new int[] {1280, 720},
                ScreenCaptureDimensions.forOutput(2561, 1441, false, true, 1280));
    }

    @Test
    public void keepsSmallOddCaptureAtActualSizeWithoutUpscaling() {
        assertArrayEquals(
                new int[] {541, 919},
                ScreenCaptureDimensions.forOutput(541, 919, true, true, 1280));
    }
}
