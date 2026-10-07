package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertEquals;

import com.cloudwebrtc.webrtc.utils.ConstraintsMap;
import java.util.HashMap;
import java.util.Map;
import org.junit.Test;

public class ScreenCaptureConstraintsTest {
    @Test
    public void readsLiveKitNestedNumericProfileConstraints() {
        Map<String, Object> video = new HashMap<>();
        video.put("width", 1280);
        video.put("height", 720);
        video.put("frameRate", 15);
        Map<String, Object> constraints = new HashMap<>();
        constraints.put("audio", false);
        constraints.put("video", video);

        ScreenCaptureConstraints.Limits limits = ScreenCaptureConstraints.from(
                new ConstraintsMap(constraints));

        assertEquals(1280, limits.maximumDimension);
        assertEquals(15, limits.maximumFrameRate);
    }

    @Test
    public void usesMaximumBeforeExactAndIdealForConstraintMaps() {
        Map<String, Object> width = new HashMap<>();
        width.put("ideal", 1920);
        width.put("max", 1280);
        Map<String, Object> height = new HashMap<>();
        height.put("exact", 720);
        Map<String, Object> frameRate = new HashMap<>();
        frameRate.put("max", "15");
        Map<String, Object> video = new HashMap<>();
        video.put("width", width);
        video.put("height", height);
        video.put("frameRate", frameRate);
        Map<String, Object> constraints = new HashMap<>();
        constraints.put("video", video);

        ScreenCaptureConstraints.Limits limits = ScreenCaptureConstraints.from(
                new ConstraintsMap(constraints));

        assertEquals(1280, limits.maximumDimension);
        assertEquals(15, limits.maximumFrameRate);
    }

    @Test
    public void ignoresMalformedOrNonPositiveValues() {
        Map<String, Object> video = new HashMap<>();
        video.put("width", -1);
        video.put("height", "not-a-number");
        video.put("frameRate", 0);
        Map<String, Object> constraints = new HashMap<>();
        constraints.put("video", video);

        ScreenCaptureConstraints.Limits limits = ScreenCaptureConstraints.from(
                new ConstraintsMap(constraints));

        assertEquals(0, limits.maximumDimension);
        assertEquals(0, limits.maximumFrameRate);
    }
}
