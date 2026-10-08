# Screen setup CI regressions — 2026-10-09

Scope: `features/screen/setup/open_dialog`, source capability notice and quality controls.

Existing quality tests reproduced FAIL: resolution1440 selection missed its hit target at the default viewport, and iOS app-only explanation appeared twice.

The complete capability notice now scrolls with the quality picker. Additional Android app-occlusion guidance follows quality choices. The fixed action footer remains outside scrolling content. iOS uses the existing explicit app-only/video/audio capability notice once.

Verification: Flutter3.47.5/Dart3.13.4; `flutter test --no-pub test/screen_share_quality_test.dart test/screen_setup --reporter expanded`: PASS24 tests. Existing assertions were retained. Physical capture/audio acceptance NOT_RUN.
