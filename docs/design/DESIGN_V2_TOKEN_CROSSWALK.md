# Design V2 token crosswalk: Web and Flutter

Scope: the first documentation slice for GitHub #290, mapped to backlog task `FV2-001`. This records the existing shared contract; it does not introduce a new palette or layout system.

## Sources and precedence

- Web semantic tokens: [`tokens.css`](../../clients/web/src/design/tokens.css).
- Flutter semantic tokens and Material mapping: [`theme.dart`](../../clients/flutter/lib/src/theme.dart).
- Web contrast pairs: [`contrast_contract.spec.ts`](../../clients/web/src/design/contrast_contract.spec.ts).
- Flutter token and admin contrast coverage: [`theme_tokens_test.dart`](../../clients/flutter/test/theme_tokens_test.dart), [`contrast_test.dart`](../../clients/flutter/test/admin_accessibility/contrast_test.dart).
- Responsive behavior: [`responsive_shell.css`](../../clients/web/src/design/responsive_shell.css) and [`width_class.dart`](../../clients/flutter/lib/src/features/admin/layout/width_class.dart).

The current runtime token files define the implemented Design V2 values. The preserved GuildChat v1.0 design snapshot contains earlier palette and geometry values; treat it as historical source material and check the current token files and applicable ADRs before copying a value into runtime code. The product brief and its security, privacy, and media constraints remain authoritative.

## Shared color roles

The CSS variable and Flutter constant in each opaque-color row have the same RGB value. Flutter's `Color(0xAARRGGBB)` representation includes the alpha byte; `FF` means fully opaque. The scrim row also matches alpha (`0.76` / `C2`).

| Role | Web token | Flutter constant | Value |
| --- | --- | --- | --- |
| Canvas | `--gc-canvas` | `GcColors.canvas` | `#0B0D12` |
| Navigation surface | `--gc-sidebar` | `GcColors.sidebar` | `#11131A` |
| Main content surface | `--gc-content` | `GcColors.content` | `#171A22` |
| Member aside | `--gc-aside` | `GcColors.aside` | `#11131A` |
| Surface / input | `--gc-surface`, `--gc-input` | `GcColors.surface`, `GcColors.input` | `#1A1D26` |
| Raised surface | `--gc-surface-raised` | `GcColors.raised` | `#222631` |
| Hover surface | `--gc-surface-hover` | `GcColors.hover` | `#272C39` |
| Selected surface | `--gc-surface-selected` | `GcColors.selected` | `#2B3040` |
| Primary text | `--gc-text-primary` | `GcColors.text` | `#F4F5FA` |
| Secondary text | `--gc-text-secondary` | `GcColors.textSecondary` | `#B6BDCE` |
| Muted text | `--gc-text-muted` | `GcColors.muted` | `#A0A9BE` |
| Disabled text/control | `--gc-text-disabled` | `GcColors.disabled` | `#6F7B8F` |
| Subtle border | `--gc-border-subtle` | `GcColors.borderSubtle`, `GcColors.border` | `#2A2F3A` |
| Control outline | `--gc-border-control` | `GcColors.control` | `#707B91` |
| Accent | `--gc-accent` | `GcColors.accent` | `#5865F2` |
| Accent hover / pressed | `--gc-accent-hover`, `--gc-accent-pressed` | `GcColors.accentHover`, `GcColors.accentPressed` | `#4752C4`, `#484BBF` |
| Accent text | `--gc-accent-text` | `GcColors.accentText` | `#ACAEFF` |
| Brand accent | `--gc-brand-accent` | `GcColors.brandAccent` | `#7C3AED` |
| Text on accent | `--gc-on-accent`, `--gc-on-primary` | `GcColors.onAccent`, `ColorScheme.onPrimary` | `#FFFFFF` |
| Success / background | `--gc-success`, `--gc-success-bg` | `GcColors.success`, `GcColors.successBackground` | `#22C55E`, `#19352F` |
| Warning / background | `--gc-warning`, `--gc-warning-bg` | `GcColors.warning`, `GcColors.warningBackground` | `#F59E0B`, `#3D3020` |
| Danger / background / solid action | `--gc-danger`, `--gc-danger-bg`, `--gc-danger-solid` | `GcColors.danger`, `GcColors.dangerBackground`, `GcColors.dangerSolid` | `#EF4444`, `#2B1116`, `#B91C1C` |
| Text on danger | `--gc-on-danger` | `GcColors.onDanger`, `ColorScheme.onError` | `#FFFFFF` |
| Focus indicator | `--gc-focus` | `GcColors.focus` | `#B4A4FF` |
| Voice / stream accent | `--gc-voice`, `--gc-stream` | `GcColors.voice`, `GcColors.stream` | `#06B6D4`, `#EC4899` |
| Stream canvas | `--gc-stream-canvas` | `GcColors.streamCanvas` | `#090B10` |
| Scrim | `--gc-overlay` | `GcColors.overlay` | `rgba(4, 6, 10, 0.76)` / `#C204060A` |
| Avatar blue / green / violet / orange / gray | `--gc-avatar-blue`, `--gc-avatar-green`, `--gc-avatar-violet`, `--gc-avatar-orange`, `--gc-avatar-gray` | `GcColors.avatarBlue`, `avatarGreen`, `avatarViolet`, `avatarOrange`, `avatarGray` | `#17464A`, `#553521`, `#393059`, `#423657`, `#556176` |

### Color aliases and use

- `input` aliases `surface`; `border` aliases `borderSubtle` in Flutter. Keep the aliases for API readability, but don't create separate values for them.
- CSS `on-primary` and `on-accent` are both white. Flutter represents that role with `GcColors.onAccent` and maps it to Material `ColorScheme.onPrimary`.
- Flutter maps the semantic palette into `ColorScheme` and the shared input/button themes. Component-specific Material styling may still need an explicit semantic role; do not replace a token with a guessed `ColorScheme` field.
- The product currently supports the dark theme only. Do not add a light palette as part of token parity.

## Typography, spacing, and shape

| Contract | Web tokens | Flutter constants | Values |
| --- | --- | --- | --- |
| Sans / monospace family | `--gc-font-family`, `--gc-font-mono` | `GcTypography.fontFamily`, `GcTypography.fontMonoFamily` | `Inter, Arial, sans-serif` / `ui-monospace, SFMono-Regular, Consolas, monospace`; Flutter uses `Inter` / `monospace` |
| Caption | `--gc-text-caption`, `--gc-line-caption` | `GcTypography.caption`, `captionLine` | `12 / 16 px` |
| Small | `--gc-text-small`, `--gc-line-small` | `GcTypography.small`, `smallLine` | `13 / 18 px` |
| Body | `--gc-text-body`, `--gc-line-body` | `GcTypography.body`, `bodyLine` | `14 / 20 px` |
| Message | `--gc-text-message`, `--gc-line-message` | `GcTypography.message`, `messageLine` | `15 / 22 px` |
| Title | `--gc-text-title`, `--gc-line-title` | `GcTypography.title`, `titleLine` | `16 / 24 px` |
| Section | `--gc-text-section`, `--gc-line-section` | `GcTypography.section`, `sectionLine` | `20 / 28 px` |
| Page | `--gc-text-page`, `--gc-line-page` | `GcTypography.page`, `pageLine` | `24 / 32 px` |
| Weights | `--gc-weight-regular`, `medium`, `semibold`, `bold` | `GcTypography.regular`, `medium`, `semibold`, `bold` | `400`, `500`, `600`, `700` |
| Spacing | `--gc-space-1`, `2`, `3`, `4`, `5`, `6`, `8`, `10`, `12`, `16` | `GcSpacing.x1`, `x2`, `x3`, `x4`, `x5`, `x6`, `x8`, `x10`, `x12`, `x16` | `4`, `8`, `12`, `16`, `20`, `24`, `32`, `40`, `48`, `64 px` |
| Radii | `--gc-radius-xs`, `sm`, `md`, `lg`, `shell`, `full` | `GcRadii.xs`, `sm`, `md`, `lg`, `shell`, `full` | `4`, `6`, `8`, `12`, `16`, `999 px` |

`--gc-space-0` has no named Flutter counterpart; use Flutter's zero value rather than adding a redundant constant. Material defaults connect the shared scale to `TextTheme` (caption, small label, body, message, title, section, page); a component may choose a different role when its documented hierarchy calls for it.

## Controls, layout, and interaction

| Contract | Web token | Flutter constant | Current value |
| --- | --- | --- | --- |
| Icon sizes | `--gc-size-icon`, `--gc-size-icon-lg` | `GcLayout.iconSize`, `iconLarge` | `20`, `24 px` |
| Control sizes | `--gc-size-control-sm`, `--gc-size-control`, `--gc-size-control-lg` | `GcLayout.controlSmall`, `control`, `controlLarge` | `32`, `36`, `48 px` |
| Field / touch target | `--gc-size-field`, `--gc-size-touch` | `GcLayout.fieldHeight`, `touchTargetSize` | `44`, `44 px` |
| Navigation columns | `--gc-layout-nav-small`, `nav-medium`, `nav-wide` | `GcLayout.navSmall`, `navMedium`, `navWide` | `280 px` each |
| Member aside | `--gc-layout-aside-medium`, `aside-wide` | `GcLayout.asideMedium`, `asideWide` | `248 px` each |
| Header | `--gc-layout-header`, `header-mobile` | `GcLayout.headerHeight`, `headerMobileHeight` | `64`, `56 px` |
| Composer | `--gc-layout-composer-min`, `composer-max` | `GcLayout.composerMinHeight`, `composerMaxHeight` | `56`, `180 px` |
| Channel / voice member row | `--gc-layout-row-channel`, `row-voice-member` | `GcLayout.channelRowHeight`, `voiceMemberRowHeight` | `36`, `24 px` |
| User footer / voice dock | `--gc-layout-user-footer`, `voice-dock` | `GcLayout.userFooterHeight`, `voiceDockHeight` | `64`, `112 px` |
| Shell frame at medium / wide | `--gc-layout-frame-medium`, `frame-wide` | `GcLayout.frameMedium`, `frameWide` | `0`, `0 px` |
| Popup / shell shadow | `--gc-shadow-popup`, `shadow-shell` | `GcShadows.popup`, `shell` | `0 12px 36px #00000040`; `0 20px 70px #00000024` |
| Motion duration | `--gc-duration-fast`, `base`, `slow` | `GcMotion.fast`, `base`, `slow` | `120`, `180`, `240 ms` |
| Standard easing | `--gc-ease-standard` | `GcMotion.standardCurve` | `cubic-bezier(0.2, 0, 0, 1)` / `Cubic(0.2, 0, 0, 1)` |

### Explicit gaps and local exceptions

- Breakpoints are layout behavior, not spacing tokens. Flutter's `GcLayout` uses `1024 / 1280 / 1440 px`; Web defines responsive rules in `responsive_shell.css`. Admin has its own content-width classes in `width_class.dart` (`600 / 840 / 1200 / 1600 px`). Keep these contracts attached to their layout scope; do not unify breakpoints mechanically.
- Flutter has `GcLayout.frameInset = 16 px` and `authTabHeight = 40 px` without direct Web token equivalents. The Web contract has `layout-dialog = 480 px` and `layout-settings-max = 880 px` without direct Flutter constants. Preserve these as platform/layout-specific until a shared runtime need is confirmed.
- Web owns the `z-index` scale (`base / dock / menu / drawer / modal / tooltip / toast` = `0 / 20 / 40 / 50 / 60 / 70 / 80`). Flutter uses Navigator/Overlay ordering and has no numeric mirror.
- `responsive_shell.css` currently gives the mobile voice dock a local `#10191a` background. No existing palette token has that value or a documented mobile-dock role. Keep it visible as an exception during visual review; do not silently substitute the nearest surface color.
- Values that are unique to a component's geometry may remain local. If the same semantic value exists in this crosswalk, prefer the shared token over another literal.
- The admin-members, authentication, mobile-navigation, member-popover, screen-viewer and voice-room styles now reference semantic variables whenever a literal exactly matches a canonical palette value. Component-specific colors remain local where no token has the same role/value. [`design_token_usage.spec.ts`](../../clients/web/src/design/design_token_usage.spec.ts) prevents these styles from reintroducing exact copies of canonical palette colors; focused presentation tests assert semantic roles rather than implementation literals.

## Opaque color-pair contrast snapshot

Ratios below use WCAG relative luminance on the current token values, rounded to two decimals. Because the Web and Flutter opaque palette values match, these token-pair calculations apply to both client token sets. They are a token audit, not screenshot sampling or proof for every composited runtime state.

| Text pair | Contrast |
| --- | ---: |
| Primary on content / sidebar / surface | `15.98 / 17.04 / 15.46 : 1` |
| Secondary on content / sidebar / surface | `9.24 / 9.86 / 8.94 : 1` |
| Muted on content / sidebar / surface | `7.38 / 7.87 / 7.14 : 1` |
| Accent text on content / sidebar | `8.49 / 9.06 : 1` |
| White on accent | `4.61 : 1` |
| Success / warning / danger on their backgrounds | `5.79 / 5.95 / 4.67 : 1` |

| Non-text pair | Contrast |
| --- | ---: |
| Control outline on surface | `3.95 : 1` |
| Focus on content / surface | `8.03 / 7.77 : 1` |
| Accent on content | `3.78 : 1` |

The sampled normal-text pairs meet `4.5:1`; the listed control/focus pairs meet `3:1`. Disabled text measures `4.06:1` on content and `3.93:1` on surface; it is an inactive-control color and should not be reused for active or essential text. The tests check a focused set of token pairs, not every CSS composition, translucent overlay, or actual component state. Browser/Flutter screenshots, text scaling at `2x`, screen reader checks, and device acceptance remain separate work.
