# ADR-002: Opaque server-side session tokens

Status: accepted.

The server issues a cryptographically random 32-byte opaque token encoded as base64url. Only a SHA-256 digest of the token is persisted; the raw value is sent once in a secure, HTTP-only, same-site cookie and is never logged or stored in browser storage.

This supports per-session revocation on logout, password reset, ban and media revocation without exposing bearer tokens to JavaScript. Cookie attributes, CSRF/Origin enforcement, session lifetime and database persistence are separate implementation leaves. The design follows the browser-storage prohibition in the OWASP session guidance: <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>.
