# ADR-002: непрозрачные server-side session tokens

Статус: принято.

Сервер выдаёт cryptographically random 32-byte opaque token, закодированный как base64url. Сохраняется только SHA-256 digest token; raw value отправляется один раз в secure, HTTP-only, same-site cookie и никогда не логируется и не хранится в browser storage.

Это поддерживает отзыв отдельных sessions при logout, password reset, ban и media revocation без раскрытия bearer tokens JavaScript. Cookie attributes, CSRF/Origin enforcement, session lifetime и database persistence — отдельные implementation leaves. Решение соответствует запрету browser storage из OWASP session guidance: <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>.
