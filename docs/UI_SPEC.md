# Спецификация UI

Desktop-first русский UI содержит один shell гильдии в тёмной теме. Левая navigation содержит identity гильдии, categories и channels; ниже находится постоянный voice dock. Центральная поверхность — ровно один выбранный text channel, DM, voice room или stream viewer. Колонки переключения серверов нет.

| Компонент | Обязательное состояние и действие |
| --- | --- |
| Shell/navigation | loading, пустой список categories, выбранный unread/mention, channel archive и reorder conflict |
| Voice dock | disconnected, permission denied, joining, connected, reconnecting, muted, deafened, transferred elsewhere, kicked; when screen capture is unsupported, disable only its control and explain the Android-app/desktop route |
| Participant card | speaking indicator, local volume 0–200%, состояние mute/deafen текстом/icon, а не только colour |
| Stream viewer | picker cancelled, unsupported browser capture before picker, нет audio track, metadata-only cards, один selected stream, placeholder остановленного stream, switch in progress, overload; audio/video невыбранного stream нельзя attach'ить |
| Audio settings | выбор input/output, VAD/PTT, processing toggles, недоступное device и validation feedback |
| Chat compositor | пустая history, pagination, reply/deleted origin, edit conflict, send retry и attachment progress/error |
| Search/DM/admin | нет результата, unauthorized action, loading, confirmation destructive action, recoverable error |

Desktop acceptance: минимум 1024 CSS px и основная ширина 1440 CSS px при browser zoom 125% и 150%. Все controls доступны с keyboard, имеют доступные русские labels, видимый focus и читаемый contrast. Colour не является единственным сигналом. Capture permissions запрашиваются только когда пользователь запускает соответствующее действие. Design следует документированным layout и states, а не visual identity с Discord.
