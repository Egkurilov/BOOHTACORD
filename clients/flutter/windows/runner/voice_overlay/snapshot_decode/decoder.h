#pragma once
#include <flutter/encodable_value.h>
#include <optional>
#include "../../voice_overlay_window.h"

struct DecodedOverlaySnapshot { bool visible; std::vector<VoiceOverlayMember> members; };
std::optional<DecodedOverlaySnapshot> DecodeOverlaySnapshot(const flutter::EncodableValue* value);
