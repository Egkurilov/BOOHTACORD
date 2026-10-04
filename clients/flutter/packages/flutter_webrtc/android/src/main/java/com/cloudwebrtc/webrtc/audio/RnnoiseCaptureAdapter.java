package com.cloudwebrtc.webrtc.audio;

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

/** Persistent capture-only native processor; PCM never crosses the Dart channel. */
public final class RnnoiseCaptureAdapter implements AudioProcessingAdapter.ExternalAudioFrameProcessing {
    private static final String[] ENGINES = {"off", "browser", "rnnoise", "unknown"};
    private static final boolean AVAILABLE;
    static {
        boolean loaded;
        try { System.loadLibrary("boohta_rnnoise_android"); loaded = true; }
        catch (LinkageError error) { loaded = false; }
        AVAILABLE = loaded;
    }
    private long handle;
    private final boolean hardwareNoiseSuppression;
    private int channels;
    private int requested = 1;
    public RnnoiseCaptureAdapter() { this(false); }
    public RnnoiseCaptureAdapter(boolean hardwareNoiseSuppression) {
        this.hardwareNoiseSuppression = hardwareNoiseSuppression;
        if (AVAILABLE) handle = nativeCreate();
    }
    @Override public void initialize(int rate, int channelCount) {
        channels = channelCount;
        if (handle != 0) nativeInitialize(handle, rate, channelCount);
    }
    @Override public void reset(int rate) { initialize(rate, channels); }
    @Override public void process(int bands, int frames, ByteBuffer buffer) {
        if (handle == 0) return;
        if (hardwareNoiseSuppression) nativeProcessControls(handle, frames, buffer);
        else nativeProcess(handle, frames, buffer);
    }
    public void setControls(Map<String, Object> settings) {
        if (handle == 0) return;
        Number threshold = (Number) settings.get("vadThresholdDb");
        Number gain = (Number) settings.get("microphoneGainPercent");
        nativeSetControls(handle, threshold == null ? -50 : threshold.doubleValue(),
            gain == null ? 100 : gain.doubleValue(), Boolean.TRUE.equals(settings.get("vad")),
            Boolean.TRUE.equals(settings.get("agc")), Boolean.TRUE.equals(settings.get("enabled")));
    }
    public Map<String, Object> controlsState() {
        double[] v = handle == 0 ? null : nativeControlsState(handle);
        Map<String, Object> result = new HashMap<>();
        result.put("status", v == null ? "unsupported" : v[5] == 0 ? "initializing" :
            v[0] == 0 ? "unsupported" : v[1] != 0 ? "active" : "initializing");
        result.put("levelDb", v == null ? -90. : v[2]);
        result.put("clipping", v != null && v[3] != 0);
        result.put("gateOpen", v != null && v[4] != 0);
        return result;
    }
    private static native void nativeSetControls(long handle, double threshold, double gain, boolean vad, boolean agc, boolean enabled);
    private static native double[] nativeControlsState(long handle);
    private static native void nativeProcessControls(long handle, int frames, ByteBuffer buffer);
    public void resetState() { if (handle != 0) nativeReset(handle); }
    public boolean setEngine(String name) {
        for (int i = 0; i < 3; i++) {
            if (ENGINES[i].equals(name)) {
                requested = i;
                if (handle != 0) nativeSetEngine(handle, i);
                return true;
            }
        }
        return false;
    }
    public Map<String, Object> state() {
        long[] values = handle == 0 ? null : nativeState(handle);
        Map<String, Object> result = new HashMap<>();
        result.put("requestedEngine", ENGINES[requested]);
        result.put("effectiveEngine", values == null ? (requested == 0 ? "off" : requested == 1 ? "browser" : "unknown") : ENGINES[(int) values[1]]);
        result.put("supported", values != null && values[2] != 0 && !hardwareNoiseSuppression);
        result.put("failureReason", values == null ? "processor-unavailable" : nativeFailureReason(handle));
        if (requested == 2 && hardwareNoiseSuppression) {
            result.put("effectiveEngine", "unknown");
            result.put("failureReason", "hardware-noise-suppression-active");
        }
        result.put("processedFrames", values == null ? 0L : values[3]);
        result.put("fallbackFrames", values == null ? 0L : values[4]);
        result.put("sampleRate", values == null ? 0 : (int) values[5]);
        result.put("channels", values == null ? 0 : (int) values[6]);
        return result;
    }
    // Remove from AudioProcessingAdapter first; its lock joins any active callback.
    public void close() {
        if (handle != 0) { nativeDestroy(handle); handle = 0; }
    }
    private static native long nativeCreate();
    private static native void nativeDestroy(long handle);
    private static native void nativeInitialize(long handle, int rate, int channels);
    private static native void nativeReset(long handle);
    private static native void nativeSetEngine(long handle, int engine);
    private static native void nativeProcess(long handle, int frames, ByteBuffer buffer);
    private static native long[] nativeState(long handle);
    private static native String nativeFailureReason(long handle);
}
