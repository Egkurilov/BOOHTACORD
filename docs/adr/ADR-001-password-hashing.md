# ADR-001: Argon2id password hash baseline

Status: accepted for the first implementation, pending a production-host benchmark.

Passwords are stored as self-describing Argon2id hashes using a cryptographically random 16-byte salt, 32-byte derived key and parameters `m=19456 KiB`, `t=2`, `p=1`. This is an OWASP-recommended Argon2id baseline: <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>.

The encoded parameters are verified strictly so a corrupted database value cannot make login allocate arbitrary memory or CPU. Login and registration rate limiting are mandatory before internet exposure. A benchmark on the selected production VM may justify a new parameter version; the migration must retain verification for existing hashes and rehash after successful login. This baseline does not alter the specification’s 12–128 Unicode-character validation or permit password trimming.
