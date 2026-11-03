plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.bilvok.numberslidepro"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {

        applicationId = "com.bilvok.numberslidepro"
        manifestPlaceholders["adMobAppId"] = "ca-app-pub-3940256099942544~3347511713"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            providers.environmentVariable("ADMOB_ANDROID_APP_ID").orNull?.takeIf { it.isNotBlank() }?.let {
                manifestPlaceholders["adMobAppId"] = it
            }
            // Play bundles are signed after assembly with the developer's upload key.
            val preview = providers.environmentVariable("SIGN_PREVIEW_APK_WITH_DEBUG_KEY").orNull == "true"
            val bundle = gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }
            signingConfig = if (preview && !bundle) signingConfigs.getByName("debug") else null
        }
    }
}

flutter {
    source = "../.."
}
