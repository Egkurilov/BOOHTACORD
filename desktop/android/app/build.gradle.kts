import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertyFile = rootProject.file("key.properties")
val signingInputs = mapOf(
    "storeFile" to "BOOHTACORD_ANDROID_KEYSTORE_FILE",
    "storePassword" to "BOOHTACORD_ANDROID_KEYSTORE_PASSWORD",
    "keyAlias" to "BOOHTACORD_ANDROID_KEY_ALIAS",
    "keyPassword" to "BOOHTACORD_ANDROID_KEY_PASSWORD",
)
val useSigningEnvironment = signingInputs.values.any { System.getenv(it) != null }
val localSigning = Properties().apply {
    if (!useSigningEnvironment && signingPropertyFile.isFile) {
        FileInputStream(signingPropertyFile).use { load(it) }
    }
}
val releaseSigning = signingInputs.mapValues { (property, variable) ->
    if (useSigningEnvironment) System.getenv(variable) else localSigning.getProperty(property)
}
val signingStoreFile = releaseSigning["storeFile"]?.let { rootProject.file(it) }
val releaseSigningReady = releaseSigning.values.all { !it.isNullOrBlank() } &&
    signingStoreFile?.isFile == true

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release", ignoreCase = true) } &&
        !releaseSigningReady
    ) {
        throw GradleException(
            "Android release signing requires all four BOOHTACORD_ANDROID_* values " +
                "or ignored android/key.properties, plus an existing keystore file."
        )
    }
}

android {
    namespace = "ru.boohtacord.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "ru.boohtacord.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningReady) {
        signingConfigs {
            create("release") {
                storeFile = signingStoreFile
                storePassword = releaseSigning["storePassword"]
                keyAlias = releaseSigning["keyAlias"]
                keyPassword = releaseSigning["keyPassword"]
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
