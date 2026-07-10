plugins {
    id("com.android.application")
    // NOTE(Phase B): the FlutterFire google-services plugin was removed while
    // app IDs moved off com.example — Firebase currently initializes from
    // explicit Dart FirebaseOptions (lib/firebase_options_stage.dart). Phase B
    // re-adds the plugin with per-flavor google-services.json files matching
    // the new application IDs.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drivedrivio.drivio_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time — needs desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.drivedrivio.drivio_driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "flavor"
    productFlavors {
        create("prod") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_driver"
            resValue("string", "app_name", "Drivio Driver")
        }
        create("staging") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_driver.beta"
            resValue("string", "app_name", "Drivio Driver Beta")
        }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
