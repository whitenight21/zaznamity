// Clear conflicting ANDROID_PREFS_ROOT environment variable to prevent AndroidLocationsException
try {
    val processEnvironment = Class.forName("java.lang.ProcessEnvironment")
    val theEnvironmentField = processEnvironment.getDeclaredField("theEnvironment")
    theEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val env = theEnvironmentField.get(null) as MutableMap<String, String>
    env.remove("ANDROID_PREFS_ROOT")

    val theCaseInsensitiveEnvironmentField = processEnvironment.getDeclaredField("theCaseInsensitiveEnvironment")
    theCaseInsensitiveEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val cienv = theCaseInsensitiveEnvironmentField.get(null) as MutableMap<String, String>
    cienv.remove("ANDROID_PREFS_ROOT")
} catch (e: Exception) {
    // Ignore
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.4.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

include(":app")
