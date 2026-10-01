package com.cloudwebrtc.webrtc.record;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.os.Handler;
import android.os.Looper;

import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;
import org.webrtc.VideoTrack;
import org.webrtc.YuvHelper;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.concurrent.TimeUnit;

import io.flutter.plugin.common.MethodChannel;

public class FrameCapturer implements VideoSink {
    private static final long FRAME_TIMEOUT_MILLIS = TimeUnit.SECONDS.toMillis(5);
    private final VideoTrack videoTrack;
    private File file;
    private final MethodChannel.Result callback;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final FrameCaptureGate completionGate = new FrameCaptureGate();
    private final Runnable timeout = () -> finishWithError(
        "TimeoutException",
        "Timed out waiting for a video frame."
    );

    public FrameCapturer(VideoTrack track, File file, MethodChannel.Result callback) {
        videoTrack = track;
        this.file = file;
        this.callback = callback;
        track.addSink(this);
        mainHandler.postDelayed(timeout, FRAME_TIMEOUT_MILLIS);
    }

    @Override
    public void onFrame(VideoFrame videoFrame) {
        if (!completionGate.tryComplete()) return;
        mainHandler.removeCallbacks(timeout);
        videoFrame.retain();
        final int frameRotation = videoFrame.getRotation();
        final YuvImage yuvImage;
        final int width;
        final int height;
        try {
            VideoFrame.I420Buffer i420Buffer = videoFrame.getBuffer().toI420();
            try {
                ByteBuffer y = i420Buffer.getDataY();
                ByteBuffer u = i420Buffer.getDataU();
                ByteBuffer v = i420Buffer.getDataV();
                width = i420Buffer.getWidth();
                height = i420Buffer.getHeight();
                int[] strides = new int[] {
                    i420Buffer.getStrideY(),
                    i420Buffer.getStrideU(),
                    i420Buffer.getStrideV()
                };
                final int chromaWidth = (width + 1) / 2;
                final int chromaHeight = (height + 1) / 2;
                final int minSize = width * height + chromaWidth * chromaHeight * 2;

                ByteBuffer yuvBuffer = ByteBuffer.allocateDirect(minSize);
                // NV21 is NV12 with the U and V bytes reversed. Reuse the NV12
                // helper with swapped chroma planes.
                YuvHelper.I420ToNV12(y, strides[0], v, strides[2], u, strides[1], yuvBuffer, width, height);

                byte[] cleanedArray = copyBufferBytes(yuvBuffer, minSize);
                yuvImage = new YuvImage(
                    cleanedArray,
                    ImageFormat.NV21,
                    width,
                    height,
                    null);
            } finally {
                i420Buffer.release();
            }
        } catch (RuntimeException runtime) {
            mainHandler.post(() -> videoTrack.removeSink(this));
            file = null;
            videoFrame.release();
            callback.error("FrameCaptureError", runtime.getLocalizedMessage(), runtime);
            return;
        }
        videoFrame.release();
        mainHandler.post(() -> {
            videoTrack.removeSink(this);
        });
        try {
            if (!file.exists()) {
                //noinspection ResultOfMethodCallIgnored
                file.getParentFile().mkdirs();
                //noinspection ResultOfMethodCallIgnored
                file.createNewFile();
            }
        } catch (IOException io) {
            file = null;
            callback.error("IOException", io.getLocalizedMessage(), io);
            return;
        }
        try (FileOutputStream outputStream = new FileOutputStream(file)) {
            yuvImage.compressToJpeg(
                new Rect(0, 0, width, height),
                100,
                outputStream
            );
            switch (frameRotation) {
                case 0:
                    break;
                case 90:
                case 180:
                case 270:
                    Bitmap original = BitmapFactory.decodeFile(file.toString());
                    Matrix matrix = new Matrix();
                    matrix.postRotate(videoFrame.getRotation());
                    Bitmap rotated = Bitmap.createBitmap(original, 0, 0, original.getWidth(), original.getHeight(), matrix, true);
                    FileOutputStream rotatedOutputStream = new FileOutputStream(file);
                    rotated.compress(Bitmap.CompressFormat.JPEG, 100, rotatedOutputStream);
                    break;
                default:
                    // Rotation is checked to always be 0, 90, 180 or 270 by VideoFrame
                    throw new RuntimeException("Invalid rotation");
            }
            callback.success(null);
        } catch (IOException io) {
            callback.error("IOException", io.getLocalizedMessage(), io);
        } catch (IllegalArgumentException iae) {
            callback.error("IllegalArgumentException", iae.getLocalizedMessage(), iae);
        } catch (RuntimeException runtime) {
            callback.error("FrameCaptureError", runtime.getLocalizedMessage(), runtime);
        } finally {
            file = null;
        }
    }

    private void finishWithError(String code, String message) {
        if (!completionGate.tryComplete()) return;
        try {
            videoTrack.removeSink(this);
        } finally {
            callback.error(code, message, null);
        }
    }

    static byte[] copyBufferBytes(ByteBuffer buffer, int length) {
        ByteBuffer readable = buffer.duplicate();
        readable.clear();
        if (length < 0 || length > readable.remaining()) {
            throw new IllegalArgumentException("Invalid frame buffer length");
        }
        byte[] bytes = new byte[length];
        readable.get(bytes);
        return bytes;
    }
}
