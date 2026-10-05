# Guild profile and administrator settings — #100

Status: implementation and automated checks PASS; physical platform gates NOT_RUN.
Scope: one deployment, one guild; no directory or federation.

## Implementation

- Web and Flutter load only public name/revision before login, without session
  cookies. Private welcome settings use the existing administrator endpoints.
- Authentication, navigation and application title consume the public profile.
  Revision hints cause a REST refetch; event payloads cannot supply a name.
- Late responses cannot regress the revision or survive a server reset/dispose.
- Administrator editors retain the draft on 409, reread the revision and require
  an explicit retry. Failed reread disables saving until settings reload.
- Names use 1–80 Unicode code points after trim and reject line/control characters.
  Long headers truncate visually while preserving a full tooltip/accessible name.
- Existing Go server ACL, Origin validation, singleton persistence and metadata
  audit remain authoritative. Clients add no mutation permission.

## Automated evidence

Web: 8 public-profile and 4 administrative-state/transport tests; browser tests
mount the actual Vue components with an explicitly mocked API.
Browser acceptance PASS at 390/1024/1440 pixels, including desktop 150% zoom,
name/revision hints, two-administrator conflict, explicit retry and no overflow.
Native widget checks PASS for portrait with 150% text scaling and long names.
Go/PostgreSQL settings tests PASS for revision conflict, VOICE rejection, repeated
migrations, archive cleanup and absence of old/new guild names in audit.

Complete client checks: Web 1080 tests PASS, production build PASS; Flutter 609
application tests PASS. Subsequent integration checks are recorded separately.
No test changes a production guild name.

## Boundaries

Physical Android/Windows interaction and screenshots NOT_RUN in this packet.
Automated widget/browser layout checks are not a physical-device visual gate.
The last public name remains during an outage; initial fallback is BOOHTACORD.
