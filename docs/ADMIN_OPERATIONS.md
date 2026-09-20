# Bootstrap и recovery администратора

Запускайте migrations до любой recovery command. Ни одна command не принимает password как command-line flag. Выполняйте эти one-shot commands в terminal владельца сервера; передавайте password через standard input, чтобы process arguments, application logs и Compose files не содержали secret.

Выполните bootstrap первого администратора до открытия регистрации:

```bash
read -rsp 'Initial administrator password: ' BOOTSTRAP_PASSWORD; echo
printf '%s\n' "$BOOTSTRAP_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T bootstrap-admin --login owner --password-stdin
unset BOOTSTRAP_PASSWORD
```

Первый успешный bootstrap создаёт `ADMINISTRATOR` и audit event. Любой последующий bootstrap успешно завершается с сообщением «already initialized» и не меняет ни role, ни password.

Если command сообщает о неполном bootstrap state, не повторяйте её, не используйте administrator recovery и не создавайте account напрямую в PostgreSQL. Сначала deploy current repair migration: она связывает только singleton state без administrator с ровно одним существующим active administrator и записывает отсутствующий initial-bootstrap audit event. State, не соответствующий этим точным условиям, остаётся неизменным для investigation владельцем.

Emergency recovery доступен только при отсутствии active administrator. Он восстанавливает существующий account как unblocked `ADMINISTRATOR`, заменяет его password, отзывает прежние sessions и создаёт audit event `ADMINISTRATOR_RECOVERED`:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T recover-admin --login owner --password-stdin
unset RECOVERY_PASSWORD
```

Если единственный active administrator утратил password, используйте отдельную command ниже с явным acknowledgement. Она работает только когда `owner` — единственный active, unblocked `ADMINISTRATOR`; она не повышает другой account и не меняет role. Command заменяет password, отзывает active sessions и voice leases account и создаёт `LAST_ADMINISTRATOR_ACCESS_RECOVERED`:

```bash
read -rsp 'Replacement administrator password: ' RECOVERY_PASSWORD; echo
printf '%s\n' "$RECOVERY_PASSWORD" | sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm -T recover-last-admin-access --login owner --password-stdin --confirm-sole-active-administrator-access-recovery
unset RECOVERY_PASSWORD
```

Владелец сервера обязан передавать password через controlled channel. Эти owner-operated commands не предоставляют backup, account discovery или обычный administration workflow.

## Входные параметры GitVerse Actions

Workflow [`.gitverse/workflows/deploy-production.yaml`](../.gitverse/workflows/deploy-production.yaml) запускается только после успешных Go и Vue checks на trusted `push` в `master` или вручную из `master`. Для запуска требуется один repository secret: `DEPLOY_SSH_PRIVATE_KEY`. Он должен соответствовать публичному ключу, уже установленному в `authorized_keys` пользователя `shaneque` на утверждённом production-хосте `176.108.242.211`. Адрес, пользователь и host key зафиксированы в workflow для этого единственного окружения; PostgreSQL, LiveKit и файл `.env` не передаются в CI.

Workflow закрепляет проверенный ED25519 host key deployment-сервера в `known_hosts`; он не использует `ssh-keyscan`, `StrictHostKeyChecking=accept-new` или интерактивный SSH. Изменение host key намеренно останавливает поставку до отдельной owner-проверки и обновления workflow.

Сервер не обязан быть Git-клоном и не получает registry credential. Pipeline тестирует точный checkout, передаёт `.env`-free source archive, проверяет его SHA-256, распаковывает его в новый `/opt/voice-platform-releases/<commit-sha>` и копирует туда только существующий server-local `/opt/voice-platform/.env` с правами `0600`. Затем он строит `voice-platform-api:<commit-sha>` и `voice-platform-web:<тот же commit-sha>` на сервере. Это не `latest`, не смешивает API/web разных revisions и не заменяет канонический каталог `/opt/voice-platform`.

После build workflow вызывает guard script с `VOICE_PLATFORM_DIR` нового release directory. Guard включает maintenance, запускает migration, перезапускает только API/web/proxy и проверяет Caddy, сети и public health; volumes PostgreSQL, attachments, LiveKit и Caddy не удаляются. Каталоги прошлых releases не удаляются автоматически: их очистка требует отдельного owner-approved maintenance решения.

## Maintenance admission во время trusted release

Release script включает maintenance admission, ждёт 15 секунд, чтобы public warning дошло до browsers, проверяет локальные commit-addressed images или получает registry-digest images, запускает migrations, перезапускает API/web/proxy, проверяет Caddy и public health. Он отключает admission только после успешного health check. Неудачный release намеренно оставляет admission active; исследуйте и восстановите deployment до его отключения.

Первый release, добавляющий эту capability, требует одноразовой schema preparation, потому что его admission row ещё не существует. Подтвердите, что candidate migration — единственная ожидающая compatible migration, выполните её отдельным проверенным шагом, затем запустите normal release script. Не утверждайте, что эта одноразовая preparation была защищена maintenance; каждый дальнейший release использует normal sequence enable-before-pull.

Для controlled verification используйте второй browser как observer. Во время warning подтвердите, что новая registration, login и voice lease получают maintenance refusal, тогда как существующая session продолжает читать protected data, а существующее media connection не отключается намеренно до restart. После успешного health и отключения admission обновите оба browser и подтвердите, что banner исчез, а новые admissions снова доступны. Фиксируйте только image digests, UTC times и pass/fail outcomes — никогда не cookies, passwords, media credentials, private keys или host fingerprints.

## Очистка устаревшего staging

Следующая явная owner-operated command удаляет только прямые regular files `staging/upload-*.part`, строго старше одного часа:

```bash
sudo docker compose --project-directory /opt/voice-platform -f /opt/voice-platform/compose.yaml --profile operator run --rm cleanup-stale-staging
```

Она сохраняет symlinks, directories, unexpected names, данные ровно на one-hour cutoff, опубликованные attachments, unattached objects и все database rows. Она намеренно не scheduled и запускается только после решения владельца о допустимости удаления. Её output сообщает только aggregate count; имена и contents attachments не раскрываются.
