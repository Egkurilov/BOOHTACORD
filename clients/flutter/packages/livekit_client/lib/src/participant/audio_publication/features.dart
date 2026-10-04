import '../../options.dart';
/// The SFU request field is negative; AudioPublishOptions.red is positive.
/// Encryption cannot use RED; preserve the existing encrypted transport rule.
bool disableAudioRed(AudioPublishOptions options, {required bool encrypted}) =>
    encrypted || !(options.red ?? true);
