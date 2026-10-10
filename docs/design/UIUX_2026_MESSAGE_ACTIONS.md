# TEXT and DM message actions (#293)

This contract keeps message actions usable without hover while preserving the existing message, reaction, pin and ACL behavior.

## Shared action policy

| State | Actions and behavior |
| --- | --- |
| Normal TEXT or DM message | An explicit, named `Действия с сообщением` control opens the same ordered actions: Reply, Edit, Delete. Edit and Delete appear only when the caller grants the corresponding capability. Reactions and channel pinning remain separate controls. |
| Mobile Web | The disclosure, six reaction buttons and channel pin button have at least 44×44 CSS px targets. A stationary 500 ms touch/pen press on the message body is an alternate entry; movement over 10 px cancels it so scrolling and reply swipe do not open the menu. Pressing an interactive child does not start the long-press timer. |
| Flutter on iOS/Android | A visible `PopupMenuButton` exposes the same action order with a 48×48 logical-pixel target and `Действия с сообщением` semantics. In a DM, Edit and Delete follow message ownership. |
| Delete | Selecting Delete opens a confirmation dialog. Dismissing or cancelling it does not call the deletion callback; confirming it requires a second, explicit action. |
| Grouped message | The action control remains available even when sender metadata is visually compact. |
| System welcome | Only the separately authorized delete action appears; it uses an explicit confirmation. |
| Deleted or unsent message | The normal toolbar is absent. Failed sends retain their contextual Retry/Discard controls and delivery status. |

## Verification evidence

- Web touch browser coverage mounts the production `MessageItem.vue`: it checks touch disclosure, all six reaction buttons and channel pin targets at 44×44 px, stationary long-press, movement cancellation, one open menu at a time, Reply focus restoration, grouped/system/deleted/failed states, WCAG axe, and that cancelling native confirmation does not emit removal.
- Flutter widget coverage exercises TEXT and DM action menus with both iOS and Android target-platform themes, checks 48 px touch targets and semantics, asserts action order and ownership-based visibility, and verifies Delete is not called when confirmation is cancelled. Separate workspace scenarios cover horizontal reply swipe and history scrolling in TEXT and DM.
- `message_toolbar.spec.ts` verifies the Web accessible name/expanded relationship, caller-supplied action permissions, 44 px touch target and long-press cancellation threshold.
- Automated browser and widget tests do not replace physical touch, keyboard/screen-reader, or real attachment-device acceptance. Those outcomes remain `NOT_RUN` under #301/#303.
