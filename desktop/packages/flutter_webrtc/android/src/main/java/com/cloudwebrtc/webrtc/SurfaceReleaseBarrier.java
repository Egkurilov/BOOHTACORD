package com.cloudwebrtc.webrtc;

import java.util.concurrent.CountDownLatch;
import java.util.function.Consumer;

/** Waits for an asynchronous EGL surface release before mutating its backing surface. */
final class SurfaceReleaseBarrier {
    private SurfaceReleaseBarrier() {}

    static void runAfterRelease(Consumer<Runnable> scheduleRelease, Runnable afterRelease) {
        CountDownLatch released = new CountDownLatch(1);
        scheduleRelease.accept(released::countDown);

        boolean interrupted = false;
        while (true) {
            try {
                released.await();
                break;
            } catch (InterruptedException ignored) {
                interrupted = true;
            }
        }

        if (interrupted) {
            Thread.currentThread().interrupt();
        }
        afterRelease.run();
    }
}
