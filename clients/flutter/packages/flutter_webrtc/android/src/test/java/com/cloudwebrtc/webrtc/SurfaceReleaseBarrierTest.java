package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.Test;

public class SurfaceReleaseBarrierTest {
    @Test
    public void resizeWaitsUntilEglSurfaceReleaseCompletes() throws Exception {
        CountDownLatch releaseScheduled = new CountDownLatch(1);
        AtomicReference<Runnable> completeRelease = new AtomicReference<>();
        AtomicBoolean resized = new AtomicBoolean();

        Thread resizeThread = new Thread(() -> SurfaceReleaseBarrier.runAfterRelease(
                completion -> {
                    completeRelease.set(completion);
                    releaseScheduled.countDown();
                },
                () -> resized.set(true)));

        resizeThread.start();
        assertTrue("EGL release should be scheduled", releaseScheduled.await(1, TimeUnit.SECONDS));
        assertFalse("surface resize must not race EGL teardown", resized.get());

        completeRelease.get().run();
        resizeThread.join(1000);

        assertFalse("resize thread should finish after release", resizeThread.isAlive());
        assertTrue("surface resize should follow EGL teardown", resized.get());
    }

    @Test
    public void synchronousReleaseDoesNotBlockFollowingResize() {
        AtomicBoolean resized = new AtomicBoolean();

        SurfaceReleaseBarrier.runAfterRelease(Runnable::run, () -> resized.set(true));

        assertTrue(resized.get());
    }

    @Test
    public void restoresInterruptFlagAfterReleaseCompletes() {
        Thread.currentThread().interrupt();
        try {
            SurfaceReleaseBarrier.runAfterRelease(Runnable::run, () -> {});

            assertTrue(Thread.interrupted());
        } finally {
            Thread.interrupted();
        }
    }
}
