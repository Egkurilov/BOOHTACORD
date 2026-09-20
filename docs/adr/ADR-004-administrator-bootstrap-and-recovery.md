# ADR-004: неизменяемый bootstrap и аудит recovery администратора

## Статус

Принято.

## Решение

Первый administrator создаётся только через `cmd/bootstrap_admin`, никогда через public registration. Однострочный `bootstrap_state` claim использует `INSERT … ON CONFLICT DO NOTHING` в том же SQL command, что и создание user и audit-event insertion. Инициализацию может claim'ить ровно один concurrent caller; последующие callers получают `ErrAlreadyInitialized`, а command завершается успехом, не меняя существующий account, role или password.

`cmd/recover_admin` — owner-operated emergency command для deployment без active administrator. Он читает replacement password только из standard input, normalizes существующий login и запускается под transaction-level PostgreSQL advisory lock. После получения lock он использует свежий read-committed statement snapshot, чтобы отказаться от recovery при существующем active administrator. Иначе он atomically повышает и разблокирует выбранный existing account, заменяет его Argon2id hash, отзывает его sessions и создаёт audit event `ADMINISTRATOR_RECOVERED`.

`cmd/recover_last_admin_access` — отдельная owner-operated command при утрате пароля единственным active administrator. Она требует явного acknowledgement `--confirm-sole-active-administrator-access-recovery` и обновляет только существующего, unblocked `ADMINISTRATOR`, когда он действительно единственный active administrator. Она не может повысить `MEMBER` или работать при нуле либо нескольких active administrators. Тот же transaction-level lock защищает семейство recovery; command заменяет Argon2id hash, отзывает sessions и voice leases и создаёт `LAST_ADMINISTRATOR_ACCESS_RECOVERED`. Command output, audit metadata и SQL не содержат raw password или reset/session token.

## Последствия

- Bootstrap sentinel остаётся установленным, даже если все administrators позднее blocked или demoted; явное owner action в этом случае — recovery, а не повторный bootstrap.
- Recovery при нуле active administrators намеренно недоступен, пока существует обычный active administrator: это не позволяет превратить его в routine privilege-escalation path.
- Sole-administrator access recovery ограничен текущим sole active administrator и требует явного owner acknowledgement, поэтому не может повысить другой account или обойти normal multi-administrator password-reset controls.
- `audit_events` хранит только actor/target IDs, event type и non-secret metadata. В него никогда не попадают DM text, message content, passwords, reset URLs, session tokens или attachment data.
- До признания capability complete нужны evidence реальной PostgreSQL concurrency и command flow.
