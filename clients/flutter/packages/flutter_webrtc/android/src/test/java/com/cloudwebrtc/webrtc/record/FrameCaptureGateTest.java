package com.cloudwebrtc.webrtc.record;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Test;

public class FrameCaptureGateTest {
    @Test
    public void onlyOneCaptureTerminalEventWins() {
        FrameCaptureGate timeoutFirst = new FrameCaptureGate();
        assertTrue(timeoutFirst.tryComplete());
        assertFalse(timeoutFirst.tryComplete()); // A late first frame is ignored.

        FrameCaptureGate frameFirst = new FrameCaptureGate();
        assertTrue(frameFirst.tryComplete());
        assertFalse(frameFirst.tryComplete()); // The timeout is ignored.
    }

    @Test
    public void concurrentFrameAndTimeoutStillCompleteOnlyOnce() throws Exception {
        FrameCaptureGate gate = new FrameCaptureGate();
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        AtomicInteger winners = new AtomicInteger();

        Runnable terminalEvent = () -> {
            ready.countDown();
            try {
                start.await();
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            }
            if (gate.tryComplete()) winners.incrementAndGet();
        };
        Thread frame = new Thread(terminalEvent, "frame-capture-test-frame");
        Thread timeout = new Thread(terminalEvent, "frame-capture-test-timeout");
        frame.start();
        timeout.start();
        ready.await();
        start.countDown();
        frame.join();
        timeout.join();

        assertEquals(1, winners.get());
    }
}
