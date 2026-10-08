# Search submit layout

Classification: small_direct. Leaf: search/filters + design search presentation.
Base1168ed8a. Preserve search queries, date bounds/DST, scopes, pagination,
session reset and all controls. Native edges: SearchPanel -> SearchFilters;
style.css -> search.css -> design_v2_search_presentation.css.
Checks: failing real-browser pointer/geometry at1440x900 and390x844; existing
UTC/NewYork spring/autumn date matrix; scoped source tests and production build.
No force click, Enter substitute, mock layout, removed fields or search logic.
Hard120 lines per edited source/test. Stop: pointer reachability, nonoverlap and
native checks pass; record evidence and local commit, root owns integration.
