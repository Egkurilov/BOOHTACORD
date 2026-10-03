# BOOHTACORD Design V2 — план переноса во Flutter

Дата анализа: 2026-10-03
Область: Flutter-клиенты Android, macOS и Windows.

## Цель и границы

Перенести в Flutter визуальную систему и состояния Design V2, уже принятые в web, сохранив текущие сценарии и владельцев состояния. Эталон поведения — production web (`clients/web/src`), карта экранов R01–R30 — [web-план Design V2](2026-10-03-design-v2-chat.md), актуальное состояние паритета — [Flutter ↔ web parity](../../flutter-web-parity.md).

Это presentation-перенос, а не повторная реализация приложения. Не менять API, серверные ACL, модель одного guild, secure-cookie/session, realtime, загрузку/хранение файлов и владельцев LiveKit/медиа. Не переносить демонстрационные данные, синтетические действия и брендовые пиксели из дизайн-пакета. Платформенные рамки окна и системные диалоги разрешений не обязаны копировать web; видимые продуктовые экраны и состояния обязаны.

## Что обнаружено

- Web-план сообщает о покрытии всех R01–R30 для production Vue и о геометрическом сравнении его DOM с HTML-эталоном. Это даёт Flutter источник правды; web-план сам по себе не доказывает визуальный паритет Flutter.
- В Flutter уже есть большая часть функциональных вертикалей и много регрессионных тестов: shell/chat, профиль, администрирование, поиск, voice dock, viewer, диагностика, audio settings, attachments и DM. Переносить нужно существующие экраны, не создавать второй набор экранов.
- `clients/flutter/lib/src/theme.dart` расходится с V2-токенами `clients/web/src/design/tokens.css`: например, canvas Flutter `#0E1117` против web `#0B0D12`, accent `#5C5FE8` против `#5865F2`, поверхность `#1D2430` против `#1A1D26`; Flutter использует радиусы md/lg/shell `10/14/20`, web — `8/12/16`; высота header `72` против `64`, строки канала `42` против `36`, обычного control `40` против `36`. Типографическая шкала, интервалы и часть токенов уже близки или совпадают. Значит, визуальная разница заметна ещё до покомпонентного сравнения.
- Главные области Flutter сейчас собраны в больших файлах, особенно `screens/workspace_screen.dart`. Нужно локально отделять/переиспользовать презентационные виджеты только там, где это уменьшает риск; не проводить попутный рефакторинг контроллеров и media lifecycle.
- Widget tests проверяют поведение, размеры и семантику отдельных состояний; в `clients/flutter/test` не найден существующий набор golden-тестов, который покрывает R01–R30. Для первого этапа следует добавить явные тесты токенов и геометрии, затем расширять их по мере реализации.
- На начало анализа уже были пользовательские изменения `clients/flutter/pubspec.lock` и untracked `clients/flutter/packages/flutter_webrtc/android/.cxx/`. Они не относятся к этому плану и должны быть сохранены.

## Карта R01–R30 на Flutter

| Эталон | Flutter-владелец представления | Пакет |
|---|---|---|
| R01–R03 | `WorkspaceScreen`, `_Sidebar`, `_MainSurface`, `_Header`, `_Conversation`, `_DirectConversation` | Shell и переписка |
| R04–R05, R27 | `_VoiceRoom`, `_VoiceParticipantRoom`, `_VoiceParticipantCard`, `_VoiceDock`, `VoiceViewerLayout`, `VoiceScreenSelectionRail` | Voice и viewer |
| R06–R07, R21–R22 | `AdminScreen`, секции участников и ролей | Администрирование |
| R08–R09, R24, R29 | `AdminScreen`, topology actions, существующие confirmation/dialog widgets | Каналы и диалоги |
| R10–R11 | `_AudioSettingsScreen`, `AudioDeviceCheck`, `NoiseSuppressionSettings` | Настройки звука |
| R12 | `ProfileScreen`, профильная панель в `WorkspaceScreen` | Профиль |
| R13 | `_WorkspaceSearchPanel` | Поиск |
| R14, R18 | `_DrawerSurface`, `_MembersPanel`, `_MemberProfilePopover`, `SlidingDrawerLayer` | Навигация и участники |
| R15 | `theme.dart` и общие Flutter controls | Только каталог компонентов/токенов; отдельный экран не создавать |
| R16–R17 | `AuthScreen`, `PasswordResetScreen` | Вход, регистрация, восстановление |
| R19–R20, R30 | `_VoiceScreenViewer`, `ScreenReceiverDiagnostics`, `ScreenShareSetupDialog`, `ScreenFullScreenOverlay` | Viewer, статистика и выбор источника |
| R23 | Flutter update banner/status widgets | Обновление клиента |
| R25 | `_ReplyTargetBanner`, `_MentionPicker`, `MessageAttachmentComposer` | Ответ и composer |
| R26 | `MessageAttachmentList`, protected image preview/viewer | Просмотр вложения |
| R28 | `_DirectConversation` и его message/composer widgets | Личные сообщения |

Привязки сверять с production-компонентами из web-плана перед каждым пакетом; эта таблица не означает, что исходная разметка web должна буквально повторяться во Flutter.

## Порядок работ и критерии закрытия

### Пакет 0 — зафиксировать baseline и backlog

1. Внести отдельные leaf-задачи Design V2 Flutter в `backlog/tasks.yaml` и короткий трекер в `backlog/FRONTEND_TODO.md`, с зависимостями и тестами; выбирать и закрывать по одной leaf-задаче.
2. Снять baseline: `git status --short`, текущие `flutter test`, `flutter analyze`, доступные Android/macOS/Windows debug builds; сохранить команды и результаты. Существующие dirty файлы не включать.
3. Зафиксировать для R01–R30 соответствующий production web route/component, Flutter widget, размер окна/viewport, ключевые состояния и nearest Flutter test. `R15` остаётся каталогом общих компонентов.

Закрытие: backlog содержит трассируемые небольшие задачи, baseline воспроизводим, известные предупреждения и платформенные ограничения отделены от регрессий.

### Пакет 1 — Flutter tokens и общие controls

Обновить `theme.dart` по текущим web-токенам: semantic colors, accent/voice/stream, radii, header/rows/footer/dock, control/field/touch sizes, typography, motion, focus, overlay и elevations. Уточнить Material defaults, чтобы компоненты не подменяли заданные токены неявными Material-размерами. Начать с `theme_tokens_test.dart`: тестировать точные значения и соответствия web token names → `Gc*`, затем адаптировать UI.

Границы: токены не меняют доступность кнопок, бизнес-состояния, валидацию, ACL или тексты продукта; сохранить touch targets минимум 44 dp там, где этого требует handoff/мобильная доступность, даже если desktop control визуально 36 px.

Закрытие: focused token tests, `flutter analyze`, полный Flutter unit/widget suite; не осталось непреднамеренных старых значений в Material defaults.

### Пакет 2 — shell и переписка (R01–R03, R25, R28)

Перенести три зоны desktop, tablet/compact navigation, headers, размеры и прокрутку колонок, сообщения/группировку, reply state, composer, вложения и DM. Проверить канонические размеры из web-плана: R01 `1440×900`, R02 `390×844`, R03 `1024×768`; дополнительно проверить Android 320/360 dp и доступную ширину macOS/Windows окна. Длинные имена, пустые/loading/error-состояния, клавиатура/IME, несброшенный draft и scroll/read cursor — обязательные проверки. Первые отдельные leaves выровняли responsive shell/message rhythm (FV2-007) и TEXT/DM reply band (FV2-008); история, attachment states и runtime scroll/read/IME ещё остаются.

Владельцы отправки, пагинации, reply, draft, upload, mention, прочтения и DM-доступа остаются текущими; исправления состояния включать только если parity test выявит уже существующее расхождение, отдельной задачей.

Закрытие: widget/layout regressions для desktop, tablet и compact; текущие tests conversation, attachments, composer, DM и scroll проходят; измеренные границы основных зон и controls задокументированы.

### Пакет 3 — голос и демонстрация экрана (R04–R05, R19–R20, R27, R30)

Сверить disconnected/prejoin, roster loading/error/empty/populated, joining/connected/reconnecting, participant cards, dock, viewer rail/stage, local/remote preview, качество источника и popover диагностики. Отдельно пройти no publication, connecting, first frame, ended, no audio, mute/gain и fullscreen. Это следующий приоритет после shell из-за текущего продуктового фокуса на Flutter voice/screen-share.

Использовать существующие `ScreenReceiverDiagnostics`, `ScreenShareSetupDialog`, `VoiceViewerLayout`, `VoiceScreenSelectionRail` и voice controllers. Внешний вид статистики не должен обещать данные, которых receiver/sender API не дал; настройки качества не меняют capture contract. Не менять LiveKit lifecycle только ради раскладки и не заявлять FPS/качество без соответствующего источника/evidence.

Закрытие: focused tests для каждой ветви отображения плюс весь voice/screen test subset; затем Android emulator и macOS/Windows runtime acceptance для доступных реальных состояний. Сетевые/media ошибки и уже открытые FE-52/59/61/69 остаются самостоятельными verification задачами, не объявляются закрытыми дизайн-переносом.

### Пакет 4 — навигация, участники, настройки и администрирование

Перенести R06–R14, R18, R21–R24, R29: admin секции/таблицы, channel/category dialogs, profile/audio settings, поиск, drawer/member panel/popover, update banner. Сохранять ограничения ширины/ellipsis длинных логинов, семантику tabs, клавиатурную навигацию, modal focus loop/возврат фокуса, touch back и текущие role/permission guards.

Закрытие: targeted layout+semantics tests для широкого, среднего и компактного режима; admin/API/controller regressions проходят; обновлён parity tracker.

### Пакет 5 — auth и оставшиеся overlay состояния (R16–R17, R26)

Перенести auth/reset layout, protected image preview/fullscreen, loading/error/403/deleted states. Сохранять бесплатную регистрацию, актуальную серверную проверку, защищённую загрузку только после ACL, отдельное действие download, текущие password/IME/focus контракты.

Закрытие: auth/profile/attachment-focused tests, keyboard/focus/semantics regression; проверить реальные 401/403 ветви через существующие тестовые API fixtures, не добавляя демо-данные в продукт.

### Пакет 6 — сводный responsive и платформенный gate

Пройти все R01–R30 и предусмотренные responsive/derived states. Flutter widget tests фиксируют bounds/constraints/semantics на канонических размерах, а ручная проверка приложения подтверждает визуальную и интерактивную пригодность на Android, macOS и Windows; системная рамка окна и системные permission dialogs исключены. Проверить TalkBack/VoiceOver/NVDA по доступным хостам, клавиатуру на desktop, system Back/edge-swipe на Android и при увеличении текста отсутствие потери контролов.

Не считать layout-only widget test доказательством media, ACL или hardware behavior. Для POC/integration/release-gate evidence записывать platform/device, app revision, viewport, сценарий, commands, PASS/NOT_RUN/BLOCKED и ограничения; не закрывать gate по `NOT_RUN`.

Закрытие: все measurable R-states имеют Flutter parity result, все focused/native tests pass, analyzer без новых diagnostics, три платформы собраны доступными локально средствами, outstanding manual/device results явно остаются открытыми.

## Общие правила для каждого пакета

1. Перед кодом выбрать один leaf из backlog, проверить его зависимости и добавить/обновить focused tests.
2. Использовать актуальный web presentation и web tests как сверяемый источник; HTML handoff — reference, не источник product data/behavior.
3. Не менять API, ACL, storage, auth/session или LiveKit владельцев внутри чисто визуальной задачи.
4. После закрытия обновить `docs/flutter-web-parity.md`, соответствующий evidence record и backlog status; запустить ближайший Flutter test, `flutter analyze`, затем нужные platform builds.
5. Если меняются requirements/backlog, запустить spec traceability verifier; если затронут contract — contract verifier. Перед staging проверить статус и размеры файлов, не захватывая pre-existing пользовательские изменения.

## Решение для старта

Первой реализационной задачей сделать Пакет 0 + один leaf из Пакета 1 — точные V2 semantic/theme tokens и их widget/unit assertions. После зелёной проверки перейти к R01–R03. Не начинать массовый перерисованный rewrite и не закрывать весь R01–R30 одним коммитом: каждый пакет должен оставаться отдельным проверяемым вертикальным срезом.
