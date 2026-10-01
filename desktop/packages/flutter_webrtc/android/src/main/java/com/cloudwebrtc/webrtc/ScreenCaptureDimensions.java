package com.cloudwebrtc.webrtc;

final class ScreenCaptureDimensions {
    private ScreenCaptureDimensions() {}

    static int[] forOutput(
            int width,
            int height,
            boolean devicePortrait,
            boolean contentSizeAuthoritative) {
        if (contentSizeAuthoritative) {
            return new int[] {width, height};
        }
        int max = Math.max(width, height);
        int min = Math.min(width, height);
        return devicePortrait ? new int[] {min, max} : new int[] {max, min};
    }
}
