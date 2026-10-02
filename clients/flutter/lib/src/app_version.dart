const appVersionName = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.24');
const appBuildNumber = String.fromEnvironment('APP_NATIVE_BUILD', defaultValue: '38');
const appReleaseId = String.fromEnvironment('APP_RELEASE_ID', defaultValue: 'boohtacord-1.0.24-38');
const appReleaseOrder = int.fromEnvironment('APP_RELEASE_ORDER', defaultValue: 38);
const appVersionLabel = 'Версия $appVersionName ($appBuildNumber)';
