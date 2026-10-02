# ADR-012: Prebuilt signed server releases

Status: staging verified; production trust and GitHub cutover remain pending.
Date: 2026-10-01.
Supersedes the source-build installation and independent GHCR rebuild portions of ADR-011-github-delivery.

## Decision

GitHub remains the single delivery authority. Backend, web and contract checks
produce receipts for the full checked-out SHA. A trusted Linux builder packages
only server inputs, produces OCI images with SBOM and provenance, and smokes
those exact image IDs against disposable PostgreSQL 17. The source SHA is the
immutable release ID. Native client distribution has separate signing gates.

The server bundle contains API/web OCI archives, a small runtime archive, the
check receipt, a manifest and its detached RSA/SHA-256 signature. Payload sizes,
checksums, OCI index/manifest digests and compatibility fingerprints are signed.
The RSA private key belongs to the protected release job. The public key is
provisioned separately on the install host. A key inside a received bundle is
never accepted as a trust anchor. Application and client signing secrets are
excluded from server builds and bundles. Key rotation requires provisioning a
new trusted public key before its first signed release is installed.

The installer has Python, OpenSSL, Docker and existing runtime tools provisioned
in advance. It does not build images or download developer tools. It verifies
the bundle before importing images, checks disk reserve and append-only
migrations, preserves maintenance admission and operator commands, then checks
running image IDs and writes an installed receipt. Both the workflow install
queue and host file lock serialize install, recovery and compatible rollback.

## Compatibility and transition

The existing migrations are idempotent SQL without a migration history table.
This change does not introduce a new migration engine. The first upgrade reads
the retained migration inventory of the actual running legacy revision. Later
upgrades compare signed manifests. Removed, reordered or modified historical
migrations fail closed. Compatible rollback requires identical backend tree,
migration inventory, contracts and deployment topology in two signed releases.
No database restoration, reverse migration or volume deletion is introduced.

## Acceptance

Build server retains the signed bundle and checksum in GitHub Actions for 30
days. Deploy production consumes only a successful master build from this
repository and verifies producer provenance. Recovery selects the same retained
artifact by run ID and full revision. Private signing material is available only
to the protected builder job; host trust is provisioned independently at
`/etc/voice-platform/release-signing.pub.pem`.

Build cancellation is isolated from installation. Install, recovery and compatible
rollback share the non-cancellable `v-bootybay-production` queue and host lock.
Delivery rejects reverse source ancestry, and the installer checks that the
running revision has not changed after it acquires the lock. Historical GHCR
images remain available; future mirrors must copy verified images without a
second rebuild. The signed bundle is the authoritative new distribution.

The staging builder, isolated installation and signed rollback results are in
`evidence/reorganization/`. They use a staging-only signer and do not certify
production key provisioning or a trusted GitHub production run.

Unit negatives cover source/receipt drift, archive traversal and expansion,
signature/checksum tampering, migration incompatibility, disk exhaustion and
running digest mismatch. Actual builder and staging installation must pass
before replacing production delivery. Physical media acceptance remains a
separate product gate; artifact smoke does not prove stream quality.
