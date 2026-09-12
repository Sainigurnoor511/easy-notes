import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept out of version control. The keystore itself
// lives outside the repo entirely, so it can never be committed by accident.
//
// When this file is absent — a fresh clone, or CI without the secret — release
// builds fall back to the debug key rather than failing, so the project still
// builds. `flutter build apk --release` will say which key it used.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile")?.let {
    file(it).exists()
} ?: false

android {
    namespace = "dev.gurnoorsaini.easynotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // flutter_local_notifications schedules reminders with java.time, which
        // needs the desugared JDK libs to run on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Permanent identity: Play treats a change here as a different app, and
        // the Google OAuth client is registered against this exact string paired
        // with the signing certificate's SHA-1.
        applicationId = "dev.gurnoorsaini.easynotes"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Keeps `--release` working on a clone without the keystore. Such
                // a build is not shippable: Play rejects debug-signed uploads,
                // and Google sign-in would need the debug SHA-1 registered too.
                logger.warn(
                    "easy-notes: android/key.properties missing — signing the " +
                    "release build with the DEBUG key. Not shippable."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
