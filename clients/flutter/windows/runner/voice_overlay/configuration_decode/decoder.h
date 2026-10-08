#pragma once
#include <flutter/encodable_value.h>
#include <optional>
#include "../configuration/model.h"

std::optional<VoiceOverlayConfiguration> DecodeOverlayConfiguration(const flutter::EncodableValue* value);
