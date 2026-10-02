# Client update flow

The runtime catalog is `deploy/client-updates/catalog.json`. It is operational
state, separate from downloadable attachments and user data. The API reads at
most 256 KiB and 64 selectors, rejects unknown JSON fields and unsafe URLs, and
reloads every ten seconds. An invalid update leaves the last valid snapshot in
service. A cold start without a valid snapshot returns `503` only from the
update endpoint.

The public response contains no account or deployment secrets and always uses
`Cache-Control: no-store` and `X-Content-Type-Options: nosniff`. Web HTML uses
`no-cache`, hashed assets are immutable, and missing hashed assets return 404.

The clients compare immutable release ID/order rather than display version
text. `published` carries one complete target; `disabled` and `unconfigured`
carry `null`. Android and Windows direct actions open a browser page. Web reload
checks current policy and build info again, warns about active work, records one
attempt in session storage, and then performs one user-confirmed reload.

Operators validate a catalog with:

```text
python -m tools.release.client_updates.catalog validate --path deploy/client-updates/catalog.json
```

Promotion and withdrawal additionally require the expected catalog revision and
the exact four-part selector. The command writes through an atomic replacement.
