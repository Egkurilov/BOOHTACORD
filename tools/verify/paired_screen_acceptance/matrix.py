"""Versioned case, pairing, and field allowlists for acceptance evidence."""

PAIRINGS = set("""
win-chromium-to-win-chromium win-chromium-to-macos-chromium macos-chromium-to-win-chromium
chromium-to-safari flutter-win-to-web flutter-macos-to-web web-to-flutter-win web-to-flutter-macos
android-physical-to-macos android-physical-to-web web-to-android-physical web-to-ios
""".split())
CASE_IDS = set("""
motion-720p30 motion-720p60 motion-1080p30 motion-1080p60 text-15fps text-rate-transition
game-video fine-text-scroll capture-full-display capture-window capture-tab
lifecycle-100-switches voice-screen-audio degraded-network
""".split())
STATUSES = {"PASS", "FAIL", "NOT_RUN", "BLOCKED", "UNSUPPORTED"}
TOP_FIELDS = {"schemaVersion", "issue", "candidateSha", "livekitServerImageDigest", "status", "pairings"}
PAIR_FIELDS = {"id", "result", "unsupportedContractRef", "unsupportedCases", "runs"}
RUN_FIELDS = set("""
caseId repeat senderBuild receiverBuild senderOS receiverOS senderDeviceClass receiverDeviceClass
senderGpuDriver receiverGpuDriver senderPowerMode receiverPowerMode senderDisplayRefreshHz
receiverDisplayRefreshHz profile sourceMode captureMode codec layerTopology measurements
""".split())
METRICS = set("""
sourceFps captureWidth captureHeight encodedFps decodedFps presentedFps uniqueFrameDelta duplicateFrames skippedFrames
freezeCount freezeDurationMs firstFrameP95Ms switchP95Ms encodeTimeP95Ms
decodeTimeP95Ms packetLossPercent rttP95Ms jitterP95Ms
""".split())
PASS_METRICS = METRICS - {"switchP95Ms"}
NUMERIC_ENVIRONMENT = {"senderDisplayRefreshHz", "receiverDisplayRefreshHz"}
