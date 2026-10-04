# Optional registration password generation

Web and Flutter (Android, iOS and Windows) offer **Сгенерировать пароль** in registration. Login has no generator. Manual passwords and password managers remain supported.

The client generates a 24-character ASCII password locally. It contains uppercase and lowercase letters, digits and symbols from `!@#$%^&*_-+=`. Web uses `crypto.getRandomValues`; Flutter uses `Random.secure()`. Rejection sampling avoids modulo bias, including during the Fisher–Yates shuffle. No server call is needed to generate a password.

Generation reveals the new password and focuses its field so the user can save it in a password manager. The user can hide, edit or regenerate it. A nonempty field requires confirmation: **Заменить введённый пароль сгенерированным?** Choosing **Оставить** preserves the current value. The live announcement is only **Надёжный пароль сгенерирован**.

Generation never copies to the clipboard or stores the password in browser storage, application preferences, logs, traces, screenshots or evidence. The password is sent only by the existing authentication submission. Switching modes, successful authentication and screen disposal clear the transient field and visibility state. Generation failures preserve entered text and show a neutral error. Flutter disables autocorrection, suggestions and personalized IME learning, and uses `AutofillHints.newPassword` during registration.

The server policy remains **12–128 Unicode characters**, counted without trimming or normalization. ADR-001 and OpenAPI are unchanged. The stricter composition of generated passwords is a client convenience, not a new server requirement.

## Checks

- Web: `npm test`, `npm run test:password-generation`, `npm run build`.
- Flutter: `flutter test --no-pub`, `flutter analyze --no-pub --no-fatal-infos`, Android debug and Windows builds.
- Visual evidence: set `PASSWORD_GENERATION_SCREENSHOTS=1` for the browser checks and `flutter test --no-pub test/password_generation/visual_test.dart`. Captures are taken only after hiding the password. Browser traces, videos and automatic failure screenshots are disabled for these secret-bearing scenarios.

See `evidence/qa/issue-104-password-generation/REVIEW.md` for observed results and limitations.
