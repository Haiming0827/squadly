plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mipushAars = fileTree("libs") { include("MiPush_SDK_Client*.aar") }.files
require(mipushAars.size <= 1) {
    "Place exactly one Xiaomi Mi Push AAR (MiPush_SDK_Client*.aar) in android/app/libs."
}
val mipushAppId = providers.gradleProperty("MIPUSH_APP_ID").orNull
val mipushAppKey = providers.gradleProperty("MIPUSH_APP_KEY").orNull
val mipushConfigured = mipushAppId != null || mipushAppKey != null || mipushAars.isNotEmpty()
require(!mipushConfigured || (mipushAppId?.isNotBlank() == true && mipushAppKey?.isNotBlank() == true && mipushAars.size == 1)) {
    "Mi Push requires one official AAR in android/app/libs plus both -P MIPUSH_APP_ID and -P MIPUSH_APP_KEY."
}

android {
    namespace = "com.squadly.squadly"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.squadly.squadly"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "MIPUSH_ENABLED", mipushConfigured.toString())
        buildConfigField("String", "MIPUSH_APP_ID", "\"${mipushAppId.orEmpty()}\"")
        buildConfigField("String", "MIPUSH_APP_KEY", "\"${mipushAppKey.orEmpty()}\"")
        manifestPlaceholders["mipushReceiver"] = if (mipushConfigured) {
            "com.squadly.squadly.MiPushMessageReceiver"
        } else {
            "com.squadly.squadly.UnconfiguredMiPushReceiver"
        }
        manifestPlaceholders["mipushReceiverExported"] = mipushConfigured.toString()
    }

    buildFeatures { buildConfig = true }

    if (mipushConfigured) {
        sourceSets.getByName("main").java.srcDir("src/withMiPush/kotlin")
    } else {
        sourceSets.getByName("main").java.srcDir("src/noMiPush/kotlin")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

if (mipushConfigured) {
    dependencies { implementation(files(mipushAars.single())) }
}

flutter {
    source = "../.."
}
