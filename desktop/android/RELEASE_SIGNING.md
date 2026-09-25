# Android release signing

Release builds require a persistent, private Android upload keystore. The build fails before any release task if signing inputs are incomplete or the keystore file is missing. Debug builds do not require release credentials.

For CI, provision the keystore outside the repository and set all four environment variables:

- `BOOHTACORD_ANDROID_KEYSTORE_FILE`: absolute path to the `.jks` or `.keystore` file;
- `BOOHTACORD_ANDROID_KEYSTORE_PASSWORD`: keystore password;
- `BOOHTACORD_ANDROID_KEY_ALIAS`: alias of the upload key;
- `BOOHTACORD_ANDROID_KEY_PASSWORD`: key password.

If any of these environment variables is set, the build uses only environment inputs. A partial set fails rather than combining CI values with a local file. Configure CI secret masking and keep the keystore outside its checkout and artifacts.

For local release builds, create the ignored `desktop/android/key.properties` with these keys:

```properties
storeFile=C:/private/android/boohtacord-upload.jks
storePassword=<private value>
keyAlias=<private alias>
keyPassword=<private value>
```

`storeFile` may be absolute or relative to `desktop/android/`. The file, `.jks`, and `.keystore` files are ignored by `desktop/android/.gitignore`. Keep the upload key for future updates; a different key cannot update an installed app signed with the original key.

Before distributing an APK, run `flutter analyze`, `flutter test`, and `flutter build apk --release` from `desktop/` on a host with the Flutter and Android SDKs. Inspect the APK signer certificate and verify it is the intended non-debug upload key. Physical-device install/update, secure-cookie authentication, microphone permission, reconnect, voice, and viewer checks are separate QA-13 acceptance evidence.
