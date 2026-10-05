package com.cloudwebrtc.webrtc.utils;

import static org.junit.Assert.assertEquals;

import java.util.Collections;
import org.junit.Test;

public class ConstraintsMapTest {
    @Test
    public void getDoubleAcceptsIntegerAndFloatingPointNumbers() {
        ConstraintsMap integer = new ConstraintsMap(Collections.singletonMap("sampleRate", 48000));
        ConstraintsMap decimal = new ConstraintsMap(Collections.singletonMap("sampleRate", 48000.5d));

        assertEquals(48000d, integer.getDouble("sampleRate"), 0d);
        assertEquals(48000.5d, decimal.getDouble("sampleRate"), 0d);
    }
}
