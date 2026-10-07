package com.cloudwebrtc.webrtc;

import com.cloudwebrtc.webrtc.utils.ConstraintsMap;
import com.cloudwebrtc.webrtc.utils.ObjectType;

final class ScreenCaptureConstraints {
    private ScreenCaptureConstraints() {}

    static Limits from(ConstraintsMap constraints) {
        ConstraintsMap video = constraints != null
                && constraints.getType("video") == ObjectType.Map
                ? constraints.getMap("video") : null;
        int width = positive(readInteger(video, "width"));
        int height = positive(readInteger(video, "height"));
        int frameRate = positive(readInteger(video, "frameRate"));
        return new Limits(Math.max(width, height), frameRate);
    }

    private static Integer readInteger(ConstraintsMap constraints, String key) {
        if (constraints == null) return null;
        ObjectType type = constraints.getType(key);
        if (type == ObjectType.Number) return (int) Math.round(constraints.getDouble(key));
        if (type == ObjectType.String) return parseInteger(constraints.getString(key));
        if (type != ObjectType.Map) return null;

        ConstraintsMap values = constraints.getMap(key);
        for (String preference : new String[] {"max", "exact", "ideal"}) {
            ObjectType valueType = values.getType(preference);
            if (valueType == ObjectType.Number) {
                return (int) Math.round(values.getDouble(preference));
            }
            if (valueType == ObjectType.String) {
                Integer parsed = parseInteger(values.getString(preference));
                if (parsed != null) return parsed;
            }
        }
        return null;
    }

    private static Integer parseInteger(String value) {
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException ignored) {
            try {
                return (int) Math.round(Double.parseDouble(value));
            } catch (NumberFormatException invalid) {
                return null;
            }
        }
    }

    private static int positive(Integer value) {
        return value == null || value <= 0 ? 0 : value;
    }

    static final class Limits {
        final int maximumDimension;
        final int maximumFrameRate;

        Limits(int maximumDimension, int maximumFrameRate) {
            this.maximumDimension = maximumDimension;
            this.maximumFrameRate = maximumFrameRate;
        }
    }
}
