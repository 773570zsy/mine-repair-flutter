import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.julong.mine_repair_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.julong.mine_repair_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["JPUSH_PKGNAME"] = applicationId ?: "com.julong.mine_repair_flutter"
        manifestPlaceholders["JPUSH_APPKEY"] = "113e14960cc6c1614b818614"
        manifestPlaceholders["JPUSH_CHANNEL"] = "developer-default"
        // 厂商通道（暂无密钥，留空占位）
        manifestPlaceholders["MEIZU_APPKEY"] = ""
        manifestPlaceholders["MEIZU_APPID"] = ""
        manifestPlaceholders["XIAOMI_APPID"] = ""
        manifestPlaceholders["XIAOMI_APPKEY"] = ""
        manifestPlaceholders["OPPO_APPKEY"] = ""
        manifestPlaceholders["OPPO_APPID"] = ""
        manifestPlaceholders["OPPO_APPSECRET"] = ""
        manifestPlaceholders["VIVO_APPKEY"] = ""
        manifestPlaceholders["VIVO_APPID"] = ""
        manifestPlaceholders["HONOR_APPID"] = ""
        manifestPlaceholders["NIO_APPID"] = ""
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 极光推送 SDK 5.6.0（5.0.0+ 自动包含 JCore，无需单独引入）
    implementation("cn.jiguang.sdk:jpush:5.6.0")

    // === 厂商通道（暂无密钥，注释备用） ===
    // 华为: implementation("com.huawei.hms:push:6.13.0.300") + plugin
    // implementation("cn.jiguang.sdk.plugin:huawei:5.6.0")
    // FCM: implementation("com.google.firebase:firebase-messaging:24.1.0") + plugin
    // implementation("cn.jiguang.sdk.plugin:fcm:5.6.0")
    // 魅族: implementation("cn.jiguang.sdk.plugin:meizu:5.6.0")
    // VIVO: implementation("cn.jiguang.sdk.plugin:vivo:5.6.0")
    // 小米: implementation("cn.jiguang.sdk.plugin:xiaomi:5.6.0")
    // OPPO: implementation("cn.jiguang.sdk.plugin:oppo:5.6.0")
    // 荣耀: implementation("cn.jiguang.sdk.plugin:honor:5.6.0")
    // 蔚来: implementation("cn.jiguang.sdk.plugin:nio:5.6.0")
}

// FCM + 华为 Gradle 插件（启用厂商通道时取消注释）
// apply(plugin = "com.google.gms.google-services")
// apply(plugin = "com.huawei.agconnect")

flutter {
    source = "../.."
}
