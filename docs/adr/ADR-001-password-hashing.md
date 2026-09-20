# ADR-001: базовые параметры hash пароля Argon2id

Статус: принято для первой реализации, ожидается benchmark production host.

Пароли хранятся как self-describing Argon2id hashes с cryptographically random 16-byte salt, 32-byte derived key и параметрами `m=19456 KiB`, `t=2`, `p=1`. Это baseline Argon2id, рекомендуемый OWASP: <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>.

Кодированные параметры строго проверяются, чтобы повреждённое значение БД не заставило login выделять произвольную память или CPU. Rate limiting login и registration обязателен до internet exposure. Benchmark на выбранной production VM может обосновать новую версию параметров; migration должна сохранять проверку существующих hashes и rehash после успешного login. Baseline не изменяет определённую ТЗ validation длины 12–128 Unicode characters и не разрешает trimming пароля.
