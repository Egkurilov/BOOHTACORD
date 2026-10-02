# RNNoise reproducible assets

The official Xiph RNNoise v0.1 commit `cdf196b1e9de2f8ff1003328ebf9a4316477429d`
and its embedded stock `src/rnn_data.c` model are vendored under
`clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream`. Source/model
hashes are fixed in `rnnoise_build_lock.json` and `rnnoise_upstream_checksums.json`.
The vendored `src/pitch.c` and `src/celt_lpc.c` contain a minimal, behavior-
preserving portability edit: runtime-sized scratch arrays route through
`rnnoise_platform_compat.h`, which uses `_alloca` on MSVC and standard C VLAs on
other compilers. This retains bounded per-call stack storage and avoids heap
allocation in the audio callback. The checksum manifest binds these adapted
files; all other RNNoise sources remain byte-identical to the pinned upstream
commit.
Version v0.1 is chosen to share a small proven scalar C API between the native
capture callback and synchronous AudioWorklet. It does not imply any measured
quality advantage over newer upstream models. No Jitsi adapter code is reused.

Install and activate the official Emscripten **4.0.20** SDK, then from the root:

```sh
python3 tools/audio/build_rnnoise.py
node tools/audio/verify_rnnoise_wasm.mjs
```

`EMCC` can name an absolute compiler path. The script verifies exact compiler
version and every vendored source/model hash before compiling. Flags use O3,
scalar single-thread standalone WASM, fixed 16 MiB memory, a 1 MiB stack, emmalloc for one-time FFT-table preparation,
no filesystem, no SIMD or SharedArrayBuffer requirement. All state/frame storage and lazy upstream FFT tables
are prepared before rendering; the callback adds no heap/GC/MethodChannel
allocation. Running twice with the same compiler/source must
produce the same WASM SHA256. Generated assets stay ignored under
`clients/web/public/audio/rnnoise/v0.1-cdf196b` and enter the web release before Vite
build; no third party asset fetch occurs at runtime.

The generated versioned manifest binds model/source/WASM hashes, sample rate,
frame size and PCM scale. The loader verifies same-origin URLs, MIME types, pinned
source/model identity, SHA256 and an empty WASM import list before compilation.
`RNNOISE-NOTICES.txt` reproduces the upstream BSD-3-Clause notice. Generated
`rnnoise-sbom.cdx.json` is a CycloneDX component record to include with the signed
release SBOM. Preserve prior versioned asset directories for older tabs/rollbacks.

The Float32↔16-bit float conversion occurs exactly once in the worklet's ring
buffer adapter. The fixed scheduling buffer adds 480 samples (10 ms at 48 kHz)
in addition to the RNNoise algorithm delay; end-to-end latency and quality gates
remain separate hardware/browser evidence, never inferred from this build.
