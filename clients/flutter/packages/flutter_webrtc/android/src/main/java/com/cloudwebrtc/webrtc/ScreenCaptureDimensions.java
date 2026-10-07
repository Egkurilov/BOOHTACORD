package com.cloudwebrtc.webrtc;

final class ScreenCaptureDimensions {
    private ScreenCaptureDimensions() {}

    static int[] forOutput(
            int width,
            int height,
            boolean devicePortrait,
            boolean contentSizeAuthoritative) {
        return forOutput(width, height, devicePortrait, contentSizeAuthoritative, 0);
    }

    static int[] forOutput(
            int width,
            int height,
            boolean devicePortrait,
            boolean contentSizeAuthoritative,
            int maximumDimension) {
        final int outputWidth;
        final int outputHeight;
        if (contentSizeAuthoritative) {
            outputWidth = width;
            outputHeight = height;
        } else {
            int max = Math.max(width, height);
            int min = Math.min(width, height);
            outputWidth = devicePortrait ? min : max;
            outputHeight = devicePortrait ? max : min;
        }
        if (maximumDimension <= 0 || Math.max(outputWidth, outputHeight) <= maximumDimension) {
            return new int[] {outputWidth, outputHeight};
        }

        double scale = (double) maximumDimension / Math.max(outputWidth, outputHeight);
        int scaledWidth = evenNearest(outputWidth * scale, maximumDimension);
        int scaledHeight = evenNearest(outputHeight * scale, maximumDimension);
        return new int[] {scaledWidth, scaledHeight};
    }

    private static int evenNearest(double value, int maximumDimension) {
        int rounded = (int) Math.round(value / 2) * 2;
        if (rounded < 2) return Math.max((int) Math.ceil(value), 1);
        return Math.min(rounded, maximumDimension - maximumDimension % 2);
    }
}
