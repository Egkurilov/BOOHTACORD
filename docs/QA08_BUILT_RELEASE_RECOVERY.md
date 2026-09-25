# QA-08: возобновление уже собранного релиза

Trusted [run #1648803](https://gitverse.ru/egkurilov/BOOHTACORD/cicd/1648803) собрал образы commit `9201f219f9c1311a3b58f3bacf040cda00b4029c`, но второй guard остановил выкладку до maintenance и переключения контейнеров. Повторный запуск `install-received-release.sh` с этим SHA не подходит: каталог релиза уже существует. Ниже описан отдельный путь для оператора после восстановления запаса места.

1. На production-хосте измерить именно `voice-platform_attachments-data`: `sudo -n docker volume inspect --format '{{.Mountpoint}}' voice-platform_attachments-data`, затем `sudo -n df -B1 --output=avail,size -- <полученный mountpoint>` и `sudo -n docker system df -v`. Сопоставить reclaimable build cache с дефицитом; если подтверждённого безопасного источника места недостаточно, расширить filesystem. Не удалять attachment history, volume или backup. При любых неизвестных показателях остановиться.
2. Убедиться, что другой rollout не выполняется. Из корня актуального репозитория передать `scripts/resume_built_release/resume.sh` по доверенному SSH-сеансу и запустить от root с точным SHA:

   ```sh
   ssh -o BatchMode=yes <production-host> 'sudo -n bash -s -- 9201f219f9c1311a3b58f3bacf040cda00b4029c' < scripts/resume_built_release/resume.sh
   ```

   Скрипт требует каталог и оба локальных образа именно этого SHA, повторно проверяет headroom до любого изменения работающего стека, затем вызывает проверенный `deploy-images.sh` из сохранённого релиза и `audit-attachment-volume.sh` для нового работающего SHA. При отказе guard или отсутствии образа deploy не начинается. Если завершающий audit не прошёл, результат нельзя считать успешным даже при переключённых контейнерах: выяснить фактическое состояние прежде следующей попытки.
3. Сохранить stdout guard и post-rollout audit вместе с revision, временем, ссылкой на запуск и статусом двух авторизованных browser-сессий. QA-08 закрывается только после свежего PASS на точном volume с достаточным запасом; QA-12/14 имеют отдельные критерии.

Локальные fake-Docker проверки сценария запуска входят в `scripts/verify-release-guards.sh`. Они подтверждают порядок и fail-closed поведение скрипта, но не измеряют production capacity и не заменяют post-rollout audit.

Этот путь развернёт только SHA `9201f21…`. Если `master` уже содержит более поздние изменения, для выполнения требования «развернуть все изменения» после восстановления устойчивого запаса необходимо выполнить trusted build/deploy текущего SHA и его post-rollout audit. Промежуточный resume не закрывает этот критерий.
