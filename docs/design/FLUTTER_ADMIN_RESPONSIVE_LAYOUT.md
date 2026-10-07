# Flutter admin responsive layout

The Flutter administrator workspace uses the same width classes for every
admin feature. The class is resolved from the local layout constraint rather
than from the operating system or a global device breakpoint:

| Class | Available width |
| --- | ---: |
| `compact` | `< 600` |
| `medium` | `600–839` |
| `expanded` | `840–1199` |
| `large` | `1200–1599` |
| `extraLarge` | `>= 1600` |

Use `AdminWidthBuilder` or a local `LayoutBuilder` when a feature needs to
adapt to the width of its panel. Do not use `MediaQuery` in a leaf admin
widget: a desktop window can be narrower than the available tablet viewport.

The workspace shell owns navigation, the title header and the horizontal tab
strip. Feature panels own their data and draft state. The admin content remains
centered with a maximum width of 880 px, and the tab strip keeps 44 px minimum
targets plus horizontal scrolling for compact viewports.

Geometry coverage is maintained in
`clients/flutter/test/admin_panel_geometry_test.dart` for 360, 390, 600, 768,
840, 900, 1024, 1440 and 1920 px viewports. Resizing must not recreate the
screen state or clear the selected section, drafts, or panel scroll positions.
