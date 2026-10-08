# Actual search submit layout regression

Date: 2026-10-09. Base: 1168ed8a5decaa29b7bbcb0e36c77a700510b4fe.
Route: small_direct; search/filters + actual search presentation CSS.
Reported CI witness: run37851529946, job113565329117; normal Find click timed
out because the timezone hint intercepted the clipped submit target.

## Reproduction and fix

The source `design_v2_search_presentation.css` explicitly made `.search-submit`
an absolutely positioned, clipped 1x1px control. Existing date tests used Enter,
which exercised search submission without exercising its pointer target.
New tests mount the existing real SearchPanel/SearchFilters with production
style.css, without modifying their fixture or injecting CSS. Four cases
(1440x900 and390x844, each UTC/NewYork) failed before source changes because
the actual button height was1px rather than the required44px.

The source button now occupies its normal grid row with44px minimum height.
The wrapping filter fieldset has min-width0; its timezone note owns a full flex
row. All author/attachment/date fields and every existing handler remain intact.
No force click, pointer-events bypass, absolute overlay, field removal, or search
API/business logic change is used. The spring date test now clicks Find normally;
the autumn test retains Enter to cover the keyboard path too.

## Observed checks

- `npm run test:search-dates`: 8 actual Chromium tests PASS. Four verify enabled
  button >=44x44, below the complete fieldset, center hit-testing reaches the
  button, no horizontal viewport overflow, ordinary click creates one search
  request with the existing query and date-bound parameters.
- Existing UTC/NewYork spring/fall/DST day bounds, pagination, reopen and logout
  behavior PASS, including25-hour autumn day and23-hour spring day.
- `npm test -- src/search`: 14 files /36 typed tests PASS.
- `VITE_PUBLIC_ORIGIN=https://app.example.test npm run build`: typing + production
  Vite build PASS. Existing chunk/dynamic import warnings remain nonfatal.
- `git diff --check` PASS. Edited source/test files <=120lines.

Hosted full lifecycle workflow rerun is pending integration by the parent agent;
these component-browser passes do not claim that pending workflow has passed.
