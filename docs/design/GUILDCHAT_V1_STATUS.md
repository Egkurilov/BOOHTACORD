# GuildChat v1 — дизайн-система, план и текущий статус

Исторический срез ревью 24.09.2026 зафиксировал **FAIL** frontend tests/build из-за FE-01; подробности в [отчёте](../reviews/2026-09-24-functionality.md). На срезе 25.09.2026 FE-01…21 реализованы, локально прошли 460 frontend-тестов и TypeScript/Vite-сборка; [DES-01 matrix](GUILDCHAT_COMPONENT_MATRIX.md) сопоставляет все 40 компонентов. Актуальная незавершённая работа — в [design TODO](GUILDCHAT_V1_TODO.md), реализованное — в [DONE](../../DONE.md). Исторические production bundle observations ниже не подтверждают visual/browser-приёмку нынешней сборки.

## Назначение

Этот документ — versioned repository snapshot дизайн-системы GuildChat v1 для Voice Platform. Он связывает внешний дизайн-пакет, реализацию Vue/CSS, планы, тесты и evidence в одной точке. Дизайн управляет только визуальной композицией и состояниями интерфейса: он не меняет API, ACL, privacy, media architecture или условия product acceptance.

## Источники дизайна

Проверяемая текстовая копия исходного Markdown-пакета сохранена в репозитории как [GuildChat_Design_System_v1.0.md](GuildChat_Design_System_v1.0.md). HTML preview и ZIP остаются внешними binary-derivatives; SHA-256 исходных вложений фиксирует их происхождение и неизменность:

| Asset | SHA-256 |
| --- | --- |
| `GuildChat_Design_System_v1.0.md` | `60FC0153438E59206364E6622010E1315D9E751C46213157D8EEC807C28D2866` |
| `GuildChat_Design_Preview_v1.0.html` | `D7547F83D285B2438C4411A74FB35D6183AF72578E2E1492F8EB59D48533A140` |
| `GuildChat_Design_System_v1.0.zip` | `E93CC89CC1E925A7585AA46F95E6EEB81E244B3DB9FDA471ACC8F3F7D8614101` |

Этот snapshot фиксирует текущий implementation status, а исходный Markdown — load-bearing visual contract. ZIP не дублируется, потому что Markdown source и реализованные design files подлежат review, diff и автоматической проверке; архив не является runtime dependency.

## Нормативный визуальный контракт

### Палитра и типографика

Темная тема остаётся единственной темой MVP. Указанные в исходном GuildChat v1.0 snapshot палитра и размеры предшествуют текущему Design V2 runtime contract. Текущие значения и Web/Flutter сопоставление зафиксированы в [Design V2 token crosswalk](DESIGN_V2_TOKEN_CROSSWALK.md); актуальные исходники — [`tokens.css`](../../clients/web/src/design/tokens.css) и [`theme.dart`](../../clients/flutter/lib/src/theme.dart). Не переносить старые значения в новый runtime код без проверки применимого ADR.

### Desktop grid

| Ширина окна | Рамка | Навигация | Участники |
| --- | ---: | ---: | ---: |
| ≥1440 CSS px | 0px | 280px | 248px |
| 1280–1439 CSS px | 16px | 264px | 240px |
| 1024–1279 CSS px | 16px | 256px | drawer 320px |
| <1024 CSS px | 0px | drawer | drawer |

Исходный текст дизайн-пакета задавал для ≥1440 CSS px значения 24/312/312. Значения таблицы — визуальное исключение по [ADR-009](../adr/ADR-009-png-shell-geometry.md), основанное на горизонтальной композиции приложенных PNG. Верхняя демонстрационная панель HTML-превью в продукт не переносится.

Для экранов голосовой комнаты и выбранной демонстрации действует визуальное исключение [ADR-008](../adr/ADR-008-voice-stage-layout.md): при ширине ≥1280 CSS px центральная область занимает место постоянной правой колонки, а участники открываются кнопкой в шапке как drawer. Текстовый канал сохраняет сетку из таблицы.

Шапка — 72px, channel row — 42px, connected VoiceDock — не менее 116px, UserFooter — 68px. VoiceDock сохраняется при навигации и не перекрывает composer. В DM/settings/admin постоянная правая колонка скрыта; search использует правую область или drawer, а не четвёртую колонку.

### Обязательные UI-состояния

- Один dark one-guild shell: navigation, основной content и roster участников; server-switcher отсутствует.
- Empty/loading/error/reconnect/permission-denied состояния не заменяются декоративным контентом.
- Screen viewer подписывается только на один выбранный remote stream; невыбранные screen audio/video tracks не attach'ятся.
- Mute и deafen различаются; deafen не останавливает собственную screen share, а recovery не включает микрофон без явного действия пользователя.
- Color не является единственным сигналом: controls имеют labels, focus, keyboard navigation и readable contrast.
- Design не разрешает fake roster, fixture messages, demo media или неподтверждённые measured media values в production UI.

## Связь с реализацией

| Область | Реализация |
| --- | --- |
| Tokens, motion и global foundations | [Design V2 token crosswalk](DESIGN_V2_TOKEN_CROSSWALK.md), [`tokens.css`](../../clients/web/src/design/tokens.css), [`foundation.css`](../../clients/web/src/design/foundation.css) |
| Shell, responsive grid и navigation | [`shell.css`](../../clients/web/src/design/shell.css), [`navigation.css`](../../clients/web/src/design/navigation.css) |
| Chat/DM и composer | [`conversation.css`](../../clients/web/src/design/conversation.css) |
| Voice, participant cards и stream viewer | [`voice.css`](../../clients/web/src/design/voice.css) |
| Центрированные аудио-настройки и управление каналами | [`settings.css`](../../clients/web/src/design/settings.css), [`WorkspaceMain.vue`](../../clients/web/src/workspace/WorkspaceMain.vue) |
| Auth surfaces | [`authentication.css`](../../clients/web/src/design/authentication.css) |
| Regression contract | [`design_system_contract.spec.ts`](../../clients/web/src/design/design_system_contract.spec.ts) |

## Реализационные планы

| План | Статус |
| --- | --- |
| [Foundation](../superpowers/plans/2026-09-19-guildchat-design-foundation.md) | 14/14 шагов завершены |
| [Design completion](../superpowers/plans/2026-09-19-guildchat-design-completion.md) | 11/11 шагов завершены |
| [Reference parity](../superpowers/plans/2026-09-19-guildchat-reference-parity.md) | 14/14 шагов завершены |
| [Reference rebuild](../superpowers/plans/2026-09-19-guildchat-reference-rebuild.md) | 8/9 шагов завершены; runtime deployment подтверждён, authenticated browser screenshot comparison остаётся заблокированным |
| [Wide voice roster parity](../superpowers/plans/2026-09-24-wide-voice-roster-parity.md) | Реализовано локально, затем изменено по [ADR-008](../adr/ADR-008-voice-stage-layout.md): на voice/stream участники доступны через drawer, чтобы центральная область соответствовала PNG; production deploy и connected-state screenshots остаются открыты |
| [PNG shell geometry](../superpowers/plans/2026-09-24-png-shell-geometry.md) | Горизонтальная композиция 1440 CSS px выровнена локально по PNG и ADR-009; браузерная приёмка и production deploy остаются открыты |
| [Connected voice footer](../superpowers/plans/2026-09-24-connected-voice-room-footer.md) | Контекстная нижняя полоса комнаты реализована локально от 1024 CSS px; старый production bundle её ещё не содержит |
| [Workspace panels](../superpowers/plans/2026-09-23-guildchat-workspace-panels.md) | 3/3 задач завершены; навигация сохранена слева, Audio/Admin перенесены в центр |
| [Unified message search](../superpowers/plans/2026-09-24-unified-message-search.md) | Backend/OpenAPI/mobile contract и SearchPanel в существующей правой области/выдвижной панели реализованы локально; deploy, реальные PostgreSQL данные и authenticated visual review не выполнялись |

Актуальный сквозной список требований и оставшихся проверок находится в [GUILDCHAT_V1_TODO.md](GUILDCHAT_V1_TODO.md). TODO в исходном ZIP не обновлялся: это неизменяемый входной артефакт, а не текущая запись статуса репозитория.

## История проверенных пакетов

- CSS tokens, responsive shell, navigation, auth, conversations, DM, VoiceDock, participant cards, audio settings и stream composition реализованы в `clients/web/src`; настройка аудио и управление каналами теперь отображаются в центральной рабочей области, а не замещают навигацию.
- Regression contract проверяет palette, breakpoints, semantic shell regions, persistent dock, data-derived participants и preview hierarchy.
- Последняя зарегистрированная web-only release evidence — `release-guildchat-reference-parity-2026-09-19-003.json` (файл отсутствует в checkout; эту историческую ссылку нельзя использовать как подтверждённый receipt): frontend suite — 53 test files / 131 tests `PASS`; production build, traceability и public health — `PASS`.
- Авторизованная подключённая production-комната просмотрена в Chrome при 1256×1131 CSS px: виден один участник без стрима, отсутствуют вложенный roster и контекстный нижний footer, присутствует лишний desktop-toggle навигации. Production загружал `index-BPuFEA1J.js`, в отличие от локальной сборки. Локально добавлены roster, footer от 1024 CSS px, исправление toggle и сетка без пустого сообщения над одиночной карточкой. Pixel-level приёмка на одинаковых размерах окна и production deploy этих изменений остаются `NOT_RUN`; runtime smoke и health её не заменяют.
- После workspace-panels packet frontend suite — 53 test files / 132 tests `PASS`; `vue-tsc` и production build — `PASS` (Vite сообщает существующее предупреждение о размере LiveKit chunk).
- ProfileSettings, member/channel/audit tabs AdminPanel, MemberPopover, role/block/voice-kick actions, reset-link result и общий SearchPanel реализованы на локальной ветке и подключены к API. Для SearchPanel остаются production/real-data и visual проверки.
- Profile API включает GET/PATCH собственного профиля, смену пароля с отзывом других сессий, приватные PNG-аватары, member list/detail/avatar, admin-only account list и summary audit feed без metadata. GitVerse Actions #1629339 развернул API/web; migration 0030 и публичные runtime smoke checks прошли.
- Local and Actions validation: backend `go test ./...` / `go vet ./...`, frontend 55 files / 142 tests / production build, OpenAPI verifier, release guards и 39-item traceability — PASS. Public home, health и guest-session checks также PASS; эти проверки не доказывают authenticated workflows или pixel parity.
- UI evidence не подтверждает POC game audio, media revocation, capacity или общий product release.
- Unified search ограничивает DM через participant predicate в PostgreSQL и использует существующие GIN search vectors. Unit/contract validation прошла; интеграция на production PostgreSQL и visual acceptance остаются `NOT_RUN`.

## Следующее действие для закрытия design gate

1. Завершить локальные визуальные исправления, затем выкатить web-only сборку и открыть подключённый production-сеанс без публикации аудио для сравнения именно новой версии.
2. Снять authenticated browser screenshots на 1440, 1280 и 1024 CSS px, а также при zoom 125% и 150%.
3. Сверить shell, header, channel rows, dock, composer, voice room и selected stream с этой design system.
4. Проверить нижнюю контекстную кнопку выхода вместе с постоянным VoiceDock на 1440/1280/1024 CSS px. C-19 запрещает повторять четыре голосовые кнопки в UserFooter, а не отдельное действие выхода в открытой комнате.
5. Записать только безопасные screenshots/results в новую evidence record; не включать passwords, cookies, tokens, DM bodies, attachment contents или screen/media payload.
6. После review закрыть последний шаг [reference rebuild plan](../superpowers/plans/2026-09-19-guildchat-reference-rebuild.md).
