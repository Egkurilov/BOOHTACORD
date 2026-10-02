# Noise suppression verification

Unit, real-browser, native synthetic PCM, release artifacts and physical
acceptance are separate gates. Current implementation uses the stock model
from pinned RNNoise v0.1. Records must identify implementation SHA, model and
WASM hashes, platform/toolchain and measured scope. Never record private PCM,
voice recordings, device labels, accounts or media credentials. Hardware,
listening and capacity checks remain NOT_RUN unless real evidence exists.

## Reproduce automated gates

Use the locked toolchains in `tools/toolchains.json`, Docker and the locked
Chromium installed by `npx playwright install chromium` in `clients/web`.
`python -m tools.ci.native.web` rebuilds source-bound WASM using the digest-pinned
Emscripten container, runs unit and synthetic signal checks, starts a disposable
loopback-only LiveKit SFU for the real browser gate, and stops it on exit.

The implemented scripts are `npm run test:audio:browser` and
`npm run test:audio:quality` in `clients/web`. Direct browser execution requires
the disposable SFU on port 17880. These scripts prove their recorded synthetic
scope; they do not close physical or listening gates.

`VITE_RNNOISE_ENABLED=false` disables the Web offer at build time. For the
production image use `--build-arg VITE_RNNOISE_ENABLED=false`; rebuilding and
deploying that signed image is required. Saved preferences then explicitly
fallback to the standard engine. This is not a runtime kill switch. Assets
from an older open tab can disappear after version replacement; a load failure
follows the same explicit bounded fallback.
