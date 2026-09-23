# GuildChat v1 — дизайн-система, план и текущий статус

## Назначение

Этот документ — versioned repository snapshot дизайн-системы GuildChat v1 для Voice Platform. Он связывает внешний дизайн-пакет, реализацию Vue/CSS, планы, тесты и evidence в одной точке. Дизайн управляет только визуальной композицией и состояниями интерфейса: он не меняет API, ACL, privacy, media architecture или условия product acceptance.

## Источники дизайна

Проверяемая текстовая копия исходного Markdown-пакета сохранена в репозитории как [GuildChat_Design_System_v1.0.md](GuildChat_Design_System_v1.0.md). HTML preview и ZIP остаются внешними binary-derivatives; SHA-256 исходных вложений фиксирует их происхождение и неизменность:

| Asset | SHA-256 |
| --- | --- |
| `GuildChat_Design_System_v1.0.md` | `CE8E43A8BC3D4D8143DC084AFEDAEDF3E5E25CE43763C4F6A514C1AEE5638FE8` |
| `GuildChat_Design_Preview_v1.0.html` | `D7547F83D285B2438C4411A74FB35D6183AF72578E2E1492F8EB59D48533A140` |
| `GuildChat_Design_System_v1.0.zip` | `E93CC89CC1E925A7585AA46F95E6EEB81E244B3DB9FDA471ACC8F3F7D8614101` |

Этот snapshot фиксирует текущий implementation status, а исходный Markdown — load-bearing visual contract. ZIP не дублируется, потому что Markdown source и реализованные design files подлежат review, diff и автоматической проверке; архив не является runtime dependency.

## Нормативный визуальный контракт

### Палитра и типографика

Темная тема остаётся единственной темой MVP. Ключевые tokens: canvas `#0E1117`, sidebar/aside `#141922`, content `#151A23`, surface `#1D2430`, raised surface `#242D3B`, selected surface `#293345`, основной текст `#F1F4F9`, вторичный текст `#B7C0D0`, muted text `#929EB2`, accent `#5C5FE8`, focus `#ADB8FF`, success `#58D5A2`, warning `#F4BD62`, danger `#FF9199`.

Используется стек `Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif`, с системным fallback. Базовая сетка отступов: 4/8/12/16/20/24/32/40/48/64px. Основной control — 40px; compact — 32px; large — 48px. Radius: 4/6/10/14/20px и 999px. Все актуальные CSS custom properties находятся в [`frontend/src/design/tokens.css`](../../frontend/src/design/tokens.css).

### Desktop grid

| Ширина окна | Рамка | Навигация | Участники |
| --- | ---: | ---: | ---: |
| ≥1440 CSS px | 24px | 312px | 312px |
| 1280–1439 CSS px | 16px | 264px | 240px |
| 1024–1279 CSS px | 16px | 256px | drawer 320px |
| <1024 CSS px | 0px | drawer | drawer |

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
| Tokens, motion и global foundations | [`tokens.css`](../../frontend/src/design/tokens.css), [`foundation.css`](../../frontend/src/design/foundation.css) |
| Shell, responsive grid и navigation | [`shell.css`](../../frontend/src/design/shell.css), [`navigation.css`](../../frontend/src/design/navigation.css) |
| Chat/DM и composer | [`conversation.css`](../../frontend/src/design/conversation.css) |
| Voice, participant cards и stream viewer | [`voice.css`](../../frontend/src/design/voice.css) |
| Центрированные аудио-настройки и управление каналами | [`settings.css`](../../frontend/src/design/settings.css), [`WorkspaceMain.vue`](../../frontend/src/workspace/WorkspaceMain.vue) |
| Auth surfaces | [`authentication.css`](../../frontend/src/design/authentication.css) |
| Regression contract | [`design_system_contract.spec.ts`](../../frontend/src/design/design_system_contract.spec.ts) |

## Реализационные планы

| План | Статус |
| --- | --- |
| [Foundation](../superpowers/plans/2026-09-19-guildchat-design-foundation.md) | 14/14 шагов завершены |
| [Design completion](../superpowers/plans/2026-09-19-guildchat-design-completion.md) | 11/11 шагов завершены |
| [Reference parity](../superpowers/plans/2026-09-19-guildchat-reference-parity.md) | 14/14 шагов завершены |
| [Reference rebuild](../superpowers/plans/2026-09-19-guildchat-reference-rebuild.md) | 8/9 шагов завершены; runtime deployment подтверждён, authenticated browser screenshot comparison остаётся заблокированным |
| [Workspace panels](../superpowers/plans/2026-09-23-guildchat-workspace-panels.md) | 3/3 задач завершены; навигация сохранена слева, Audio/Admin перенесены в центр |

Актуальный сквозной список требований и оставшихся проверок находится в [GUILDCHAT_V1_TODO.md](GUILDCHAT_V1_TODO.md). TODO в исходном ZIP не обновлялся: это неизменяемый входной артефакт, а не текущая запись статуса репозитория.

## Текущий проверенный статус

- CSS tokens, responsive shell, navigation, auth, conversations, DM, VoiceDock, participant cards, audio settings и stream composition реализованы в `frontend/src`; настройка аудио и управление каналами теперь отображаются в центральной рабочей области, а не замещают навигацию.
- Regression contract проверяет palette, breakpoints, semantic shell regions, persistent dock, data-derived participants и preview hierarchy.
- Последняя зарегистрированная web-only release evidence — [`release-guildchat-reference-parity-2026-09-19-003.json`](../../evidence/release-guildchat-reference-parity-2026-09-19-003.json): frontend suite — 53 test files / 131 tests `PASS`; production build, traceability и public health — `PASS`.
- Pixel-level authenticated browser acceptance в этой записи — `BLOCKED`: не был записан signed-in browser capture. Runtime smoke и health не заменяют visual acceptance.
- После workspace-panels packet frontend suite — 53 test files / 132 tests `PASS`; `vue-tsc` и production build — `PASS` (Vite сообщает существующее предупреждение о размере LiveKit chunk).
- ProfileSettings, member/channel/audit tabs AdminPanel, MemberPopover, role/block/voice-kick actions и reset-link result реализованы на локальной ветке и подключены к API. Global SearchPanel остаётся открытым.
- Profile API включает GET/PATCH собственного профиля, смену пароля с отзывом других сессий, приватные PNG-аватары, member list/detail/avatar, admin-only account list и summary audit feed без metadata. GitVerse Actions #1629339 развернул API/web; migration 0030 и публичные runtime smoke checks прошли.
- Local and Actions validation: backend `go test ./...` / `go vet ./...`, frontend 55 files / 142 tests / production build, OpenAPI verifier, release guards и 39-item traceability — PASS. Public home, health и guest-session checks также PASS; эти проверки не доказывают authenticated workflows или pixel parity.
- UI evidence не подтверждает POC game audio, media revocation, capacity или общий product release.

## Следующее действие для закрытия design gate

1. Войти в production под тестовым account без private user content.
2. Снять authenticated browser screenshots на 1440, 1280 и 1024 CSS px, а также при zoom 125% и 150%.
3. Сверить shell, header, channel rows, dock, composer, voice room и selected stream с этой design system.
4. Записать только безопасные screenshots/results в новую evidence record; не включать passwords, cookies, tokens, DM bodies, attachment contents или screen/media payload.
5. После review закрыть последний шаг [reference rebuild plan](../superpowers/plans/2026-09-19-guildchat-reference-rebuild.md).
