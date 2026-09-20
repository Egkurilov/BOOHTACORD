# Research notes — not product decisions

This file separates facts to verify from approved requirements. It must not be used to overwrite the source brief without an ADR.

| Unknown | Evidence required | Gate affected |
| --- | --- | --- |
| Game-audio capture and playout-loop avoidance on Windows/macOS | POC-01 on physical devices | media and release |
| Supported Chrome/OS combinations and actual video profile | POC-01/02 measurements | compatibility claims |
| Reliable post-revocation media admission | POC-03 on pinned LiveKit | security |
| VM throughput, traffic limit and CPU scheduling | preflight and load run | production capacity |
| Domain, DNS/TLS, registry, SSH and network access | owner deployment-input record | actual deployment |
| Encoding parameters and resource sufficiency | ADR based on measurements | 1080p/60 and 100-user claims |

The starting VM description (4 vCPU, 8 GiB RAM, 30 GiB SSD) is context only, not a proven capacity promise. The application itself must not create or depend upon backups or provider snapshots.
