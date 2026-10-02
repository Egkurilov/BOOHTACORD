const appVersionName = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.25');
const appBuildNumber = String.fromEnvironment('APP_NATIVE_BUILD', defaultValue: '39');
const appReleaseId = String.fromEnvironment('APP_RELEASE_ID', defaultValue: 'boohtacord-1.0.25-39');
const appReleaseOrder = int.fromEnvironment('APP_RELEASE_ORDER', defaultValue: 39);
const appVersionLabel = 'Версия $appVersionName ($appBuildNumber)';
