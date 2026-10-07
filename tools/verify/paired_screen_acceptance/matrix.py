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
MOTION_60_CASES = {"motion-720p60", "motion-1080p60"}
SWITCH_CASES = {"text-rate-transition", "lifecycle-100-switches"}
STATUSES = {"PASS", "FAIL", "NOT_RUN", "BLOCKED", "UNSUPPORTED"}
TOP_FIELDS = {"schemaVersion", "issue", "candidateSha", "livekitServerImageDigest", "criteriaSha256", "status", "pairings"}
PAIR_FIELDS = {"id", "result", "unsupportedContractRef", "unsupportedCases", "runs"}
RUN_FIELDS = set("""
caseId repeat senderBuild receiverBuild senderOS receiverOS senderDeviceClass receiverDeviceClass
senderGpuDriver receiverGpuDriver senderPowerMode receiverPowerMode senderDisplayRefreshHz
receiverDisplayRefreshHz warmupSeconds measurementSeconds windowSeconds confidenceMethod
profile sourceMode captureMode codec layerTopology measurements
""".split())
METRICS = set("""
sourceFps captureWidth captureHeight encodedFps decodedFps presentedFps presentedFpsP05Lower95
uniqueFrameDelta duplicateFrames skippedFrames freezeCount freezeDurationMs maxPresentationGapMs
firstFrameP95Upper95Ms profileSwitchP95Upper95Ms firstFrameSampleCount profileSwitchSampleCount
profileSwitchAttempts firstFrameTimeoutCount profileSwitchTimeoutCount validForegroundWindows
encodeTimeP95Ms decodeTimeP95Ms packetLossPercent rttP95Ms jitterP95Ms
""".split())
PASS_METRICS = METRICS - {"profileSwitchP95Upper95Ms", "profileSwitchSampleCount", "profileSwitchAttempts", "profileSwitchTimeoutCount"}
DISPLAY_REFRESH_FIELDS = {"senderDisplayRefreshHz", "receiverDisplayRefreshHz"}
DURATION_FIELDS = {"warmupSeconds", "measurementSeconds", "windowSeconds"}
