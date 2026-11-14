import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.team_attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.team_attendance"
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when android/key.properties exists;
            // otherwise fall back to debug signing so other machines can build.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        resources {
            // datastore 1.2.1 ships the same LICENSE.txt in both
            // datastore-core-okio and datastore-core-okio-jvm; the
            // classes do not clash, only this resource file does.
            excludes += "META-INF/androidx/datastore/datastore-core-okio/LICENSE.txt"
            // Multiplatform jars (collection 1.4.2, okio 3.9.1, ...)
            // all embed the same Kotlin multiplatform metadata files
            // under their shared source-set dirs. They are compiler
            // metadata, unused at Android runtime. (Literal leading
            // segments only: AGP does not match a leading * here.)
            excludes += "commonMain/**"
            excludes += "linuxMain/**"
            excludes += "nativeMain/**"
            // Same file in every Kotlin multiplatform jar; compiler
            // metadata about project structure, unused at runtime.
            excludes += "META-INF/kotlin-project-structure-metadata.json"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// v1.1.0 dependency fix: shared_preferences_android pulls
// androidx.collection:collection-ktx:1.1.0 (via fragment-ktx) while
// android_file_picker pulls androidx.collection:collection:1.4.2
// (via core 1.18.0). Both ship the same ArrayMapKt / ArraySetKt /
// LruCacheKt classes, so the release build fails
// checkReleaseDuplicateClasses. collection-jvm 1.4.2 already provides
// those classes, so excluding the old ktx artifact is safe.
configurations.all {
    exclude(group = "androidx.collection", module = "collection-ktx")
    // Same multiplatform split problem in datastore 1.2.1 (pulled in by
    // shared_preferences_android): the -android AARs and the -jvm JARs
    // ship identical classes, failing checkReleaseDuplicateClasses.
    // The -android artifacts are the ones used on Android.
    exclude(group = "androidx.datastore", module = "datastore-core-jvm")
    exclude(group = "androidx.datastore", module = "datastore-preferences-core-jvm")
}

flutter {
    source = "../.."
}
