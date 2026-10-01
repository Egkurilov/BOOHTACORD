package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class VideoFrameDimensionsTest {
    @Test
    public void matchesWhenBothPortraitDimensionsMatch() {
        assertTrue(VideoFrameDimensions.matchesEncoderSettings(540, 1170, 540, 1170));
    }

    @Test
    public void detectsHeightOnlyChangeAfterOrientationOrResize() {
        assertFalse(VideoFrameDimensions.matchesEncoderSettings(540, 2340, 540, 1170));
    }

    @Test
    public void detectsWidthOnlyChange() {
        assertFalse(VideoFrameDimensions.matchesEncoderSettings(1080, 1170, 540, 1170));
    }
}
