plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zaznamity"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.zaznamity"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

tasks.withType<com.android.build.gradle.internal.tasks.CheckAarMetadataTask>().configureEach {
    enabled = false
}

afterEvaluate {
    tasks.findByName("assembleDebug")?.finalizedBy("copyApkToRoot")
    tasks.findByName("assembleRelease")?.finalizedBy("copyApkToRoot")
}

tasks.register("copyApkToRoot") {
    doLast {
        val outputDir = File(rootProject.projectDir, "../build/app/outputs/flutter-apk")
        outputDir.mkdirs()
        
        val debugApk = File(projectDir, "build/outputs/flutter-apk/app-debug.apk")
        if (debugApk.exists()) {
            debugApk.copyTo(File(outputDir, "app-debug.apk"), overwrite = true)
        }
        
        val releaseApk = File(projectDir, "build/outputs/flutter-apk/app-release.apk")
        if (releaseApk.exists()) {
            releaseApk.copyTo(File(outputDir, "app-release.apk"), overwrite = true)
        }
    }
}