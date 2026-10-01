package com.cloudwebrtc.webrtc.record;

import static org.junit.Assert.assertArrayEquals;

import java.nio.ByteBuffer;

import org.junit.Test;

public class FrameCapturerBufferTest {
    @Test
    public void copiesPixelsFromDirectByteBuffer() {
        ByteBuffer direct = ByteBuffer.allocateDirect(4);
        direct.put(new byte[] {1, 2, 3, 4});

        assertArrayEquals(
            new byte[] {1, 2, 3, 4},
            FrameCapturer.copyBufferBytes(direct, 4)
        );
    }
}
