import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps key for the admin dashboard's map. Resolution order:
//   1. MAPS_API_KEY env var (CI)
//   2. maps.apiKey in android/local.properties (developer machines, gitignored)
//   3. empty string — the app still builds and runs; the map falls back to a list.
val mapsApiKey: String = run {
    val fromEnv = System.getenv("MAPS_API_KEY")
    if (!fromEnv.isNullOrBlank()) return@run fromEnv
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        Properties().apply { localProps.inputStream().use { load(it) } }
            .getProperty("maps.apiKey") ?: ""
    } else {
        ""
    }
}

android {
    namespace = "com.sublimetransfers.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.sublimetransfers.app"
        // minSdk 23 is the floor for geolocator + google_maps_flutter.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
