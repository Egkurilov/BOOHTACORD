#include "support.h"
#include <iostream>

int main() {
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  try {
    CheckWindowLifecycle();
    CheckHotkeyBehavior();
    CheckDecoders();
    std::cout << "Native overlay: lifecycle, click-through, focus, editor, opacity, display restore and hotkey checks PASS\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "Native overlay FAIL: " << error.what() << '\n';
    return 1;
  }
}
