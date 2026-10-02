package com.cloudwebrtc.webrtc;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class SurfaceProducerAvailabilityTest {
    @Test
    public void rendererMustWaitForSurfaceAfterCleanupUntilAvailableCallback() {
        SurfaceProducerAvailability availability = new SurfaceProducerAvailability();

        assertTrue("new producer starts available", availability.isAvailable());

        availability.onSurfaceCleanup();
        assertFalse("cleanup must stop rendering to the invalid surface", availability.isAvailable());

        availability.onSurfaceAvailable();
        assertTrue("resume callback must allow rendering to a new surface", availability.isAvailable());
    }
}
