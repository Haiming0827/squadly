plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
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
val releaseStorePath = providers.environmentVariable("SQUADLY_ANDROID_KEYSTORE_PATH").orNull
val releaseStorePassword = providers.environmentVariable("SQUADLY_ANDROID_KEYSTORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("SQUADLY_ANDROID_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("SQUADLY_ANDROID_KEY_PASSWORD").orNull
val releaseSigningValues = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
)
val hasReleaseSigningValues = releaseSigningValues.all { !it.isNullOrBlank() }
require(releaseSigningValues.all { it.isNullOrBlank() } || hasReleaseSigningValues) {
    "Android release signing requires SQUADLY_ANDROID_KEYSTORE_PATH, SQUADLY_ANDROID_KEYSTORE_PASSWORD, SQUADLY_ANDROID_KEY_ALIAS, and SQUADLY_ANDROID_KEY_PASSWORD."
}
if (hasReleaseSigningValues) {
    require(file(releaseStorePath!!).isFile) {
        "SQUADLY_ANDROID_KEYSTORE_PATH must point to an existing keystore file."
    }
}

android {
    namespace = "com.squadly.squadly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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

    signingConfigs {
        if (hasReleaseSigningValues) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    if (mipushConfigured) {
        sourceSets.getByName("main").java.srcDir("src/withMiPush/kotlin")
    } else {
        sourceSets.getByName("main").java.srcDir("src/noMiPush/kotlin")
    }

    buildTypes {
        release {
            // Never ship a release artifact signed with the debug certificate.
            // Local/CI builds without secrets remain unsigned for compile checks.
            signingConfig = if (hasReleaseSigningValues) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

if (mipushConfigured) {
    dependencies { implementation(files(mipushAars.single())) }
}

flutter {
    source = "../.."
}
