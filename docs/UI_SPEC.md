# UI specification

The desktop-first Russian UI has one dark-theme guild shell. The left navigation contains guild identity, categories and channels; the persistent voice dock is below it. The centre surface is exactly one selected text channel, DM, voice room or stream viewer. There is no server-switcher column.

| Component | Required state and action |
| --- | --- |
| Shell/navigation | loading, empty category list, selected unread/mention, channel archive and reorder conflict |
| Voice dock | disconnected, permission denied, joining, connected, reconnecting, muted, deafened, transferred elsewhere, kicked |
| Participant card | speaking indicator, local volume 0–200%, mute/deafen status expressed with text/icon as well as colour |
| Stream viewer | picker cancelled, no audio track, metadata-only cards, one selected stream, stopped stream placeholder, switch in progress, overload; unselected stream audio/video must not be attached |
| Audio settings | input/output choice, VAD/PTT, processing toggles, inaccessible device and validation feedback |
| Chat compositor | empty history, pagination, reply/deleted origin, edit conflict, send retry and attachment progress/error |
| Search/DM/admin | no result, unauthorized action, loading, confirmation for destructive action, recoverable error |

Desktop acceptance is 1024 CSS px minimum and 1440 CSS px primary at 125% and 150% browser zoom. All controls are keyboard reachable, have accessible Russian labels, visible focus and readable contrast. Colour is never the sole signal. Capture permissions are requested only when the user starts the relevant action. The design follows the documented layout and states, not visual identity with Discord.
