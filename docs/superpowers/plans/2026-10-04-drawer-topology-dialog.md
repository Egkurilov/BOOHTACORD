# Mobile drawer topology dialog repair plan

`small_direct`, T-050; leaf: create topology dialog from the mobile navigation drawer.

**Baseline:** The real mobile Cancel button cannot be clicked: `.user-footer` at z-index 62 intercepts the topology modal at token z-index 60. The drawer's window keydown trap also receives the modal's Tab/Escape events.

**Architecture:** Keep modal token 60. Place drawer header/dock/footer at drawer token 50 + 1/2. Stop modal keydown propagation while preserving its existing Tab loop, Escape close, Enter submit and focus restoration.

**Files:** `design/design_v2_mobile_navigation.css`, `channel/member_topology/ChannelTopologyActions.vue`. No request or permission changes.

- [x] Preserve the failing ordinary-click observation in the channel-tree browser evidence.
- [x] Replace mobile navigation chrome z-index 60/61/62 with `calc(var(--gc-z-drawer) + 1/2)`.
- [x] Add `.stop` to the existing dialog keydown handlers so the outer drawer cannot trap its keyboard events.
- [x] Browser-check first/last Tab wrap, Escape closes only the dialog, opener focus returns, and ordinary Cancel clicks work for global and category creation. Keep drawer visible until explicitly closed.
- [x] Run nearest dialog/disclosure/drawer tests and build, record actual modal screenshot, commit separately from tree styling.

Stop after this concrete interaction passes on desktop and mobile. Existing API mutations, retry IDs and ACL resolution stay unchanged.
