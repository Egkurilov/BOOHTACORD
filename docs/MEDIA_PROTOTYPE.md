# Протокол media prototype

## POC-01 — реальный game audio и capture

Выполните отдельные прогоны на Windows и Apple-Silicon macOS со второй физической observer machine. Зафиксируйте hardware, OS build, версию Chrome Stable, input/output devices, LiveKit image digest, игру и capture source. Presenter входит в voice, запускает реальную игру, выбирает предлагаемый браузером source, передаёт его с audio и говорит. Observer выбирает этот stream, одновременно слыша room voice.

Воспроизводимая operator procedure, controlled topology preflight и классификация evidence находятся в [POC_01_OPERATOR_RUNBOOK.md](runbooks/game-capture.md). Он добавляет только детали выполнения; этот протокол остаётся источником правила приёмки POC-01.

`PASS` допустим только когда observer видит движущийся game content, слышит game audio и речь presenter, а presenter не получает собственное воспроизведение observer как устойчивую цифровую петлю. Зафиксируйте timestamps и artifacts. Наличия track или tab-only audio недостаточно. Если OS не позволяет передать game audio, зафиксируйте `BLOCKED` с наблюдаемым ограничением browser/source; не заменяйте сценарий молча desktop software, driver или virtual cable.

## POC-02 — измерения profile

Для 720p/30, 720p/60, 1080p/30 и 1080p/60 используйте движущийся game content и фиксируйте selected target, measured dimensions, decoded FPS, bitrate, RTT, loss и adaptation/recovery behaviour. Повторите при ухудшенной сети observer. Claim о поддерживаемом profile появляется только из записи `PASS`; UI всегда отделяет target от measured values.

[Операторский протокол POC-02](runbooks/media-profiles.md) задаёт отдельные измерения capture/encoded, decoded/presented FPS и transport RTT, чтобы проверить жалобу 60→15 FPS на физических клиентах. Шаблон записи — [poc-02-evidence.json](../templates/poc-02-evidence.json).

## POC-03 — отзыв доступа

С подключёнными publisher и observer проверьте kick, ban, logout, session revocation и voice-channel deletion. После каждого действия попробуйте reconnect и replay ранее выданных API media token и LiveKit SDK token. `PASS` допустим только когда отозванный actor не может publish, subscribe или re-enter, а unaffected caller получает правдивый outcome. Зафиксируйте закреплённую версию/digest LiveKit.

## Evidence

Сохраняйте одну JSON-запись в `evidence/` для каждого прогона, используя `templates/evidence.json`. Для `PASS` нужны artifact paths и observer. `FAIL` описывает неисполненный expected result. `BLOCKED` описывает внешнюю prerequisite. `NOT_RUN` никогда не удовлетворяет release gate.
