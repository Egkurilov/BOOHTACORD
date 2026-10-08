#include "support.h"
#include "../snapshot_decode/decoder.h"
#include "../configuration_decode/decoder.h"
#include <limits>

void CheckDecoders() {
  using flutter::EncodableValue;
  using flutter::EncodableMap;
  EncodableMap values{
    {EncodableValue("scale"), EncodableValue(1.5)},
    {EncodableValue("opacity"), EncodableValue(.7)},
    {EncodableValue("x"), EncodableValue(.4)}, {EncodableValue("y"), EncodableValue(.6)},
    {EncodableValue("hotkey"), EncodableValue(119)},
    {EncodableValue("modifiers"), EncodableValue(6)},
    {EncodableValue("revision"), EncodableValue(1)},
    {EncodableValue("editing"), EncodableValue(false)},
    {EncodableValue("monitor"), EncodableValue("DISPLAY1")},
  };
  EncodableValue arguments(values);
  Check(DecodeOverlayConfiguration(&arguments).has_value(), "typed native settings decode");
  values[EncodableValue("scale")] = EncodableValue(std::numeric_limits<double>::infinity());
  arguments = EncodableValue(values);
  Check(!DecodeOverlayConfiguration(&arguments), "nonfinite scale fails closed");
  values[EncodableValue("scale")] = EncodableValue(1.0);
  values[EncodableValue("hotkey")] = EncodableValue(119.5);
  arguments = EncodableValue(values);
  Check(!DecodeOverlayConfiguration(&arguments), "fractional hotkey fails closed");
  EncodableValue hidden(EncodableMap{{EncodableValue("visible"), EncodableValue(false)}});
  const auto snapshot = DecodeOverlaySnapshot(&hidden);
  Check(snapshot && !snapshot->visible && snapshot->members.empty(), "cleared snapshot decode");
  EncodableValue malformed(EncodableMap{{EncodableValue("visible"), EncodableValue(true)}});
  Check(!DecodeOverlaySnapshot(&malformed), "malformed current snapshot fails closed");
}
