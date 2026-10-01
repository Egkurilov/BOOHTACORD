package com.cloudwebrtc.webrtc;

/** Dimension checks shared by the Android encoder wrapper and its unit tests. */
final class VideoFrameDimensions {
    private VideoFrameDimensions() {}

    static boolean matchesEncoderSettings(
            int frameWidth,
            int frameHeight,
            int encoderWidth,
            int encoderHeight) {
        return frameWidth == encoderWidth && frameHeight == encoderHeight;
    }
}
