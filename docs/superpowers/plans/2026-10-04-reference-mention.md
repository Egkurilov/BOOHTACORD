# Reference mention capture correction

Route: `review_gate`; T-050; leaf: synthetic chat reference fixture.
Boundary: fixture payload → existing `MessageBody` inline mention renderer.

- [x] Compare native fixture with earlier verified R01–R03 fixture: visible `@Daria` lacked server mention recipient metadata in the native capture.
- [x] Add the fixture member's existing ID to `mention_user_ids`; no product or reference changes.
- [x] Require visible inline mention before chat screenshots.
- [x] Run the native real chat capture with composer/image interaction checks.

The fixture now models a confirmed mention, matching the supplied screenshot. New full metrics are not a controlled product-only comparison with prior captures.
