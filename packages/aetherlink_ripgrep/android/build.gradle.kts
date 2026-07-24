group = "com.example.aetherlink.aetherlink_ripgrep"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.aetherlink.aetherlink_ripgrep"

    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    // libaether_rg.so ships prebuilt in src/main/jniLibs — no NDK/CMake step
    // at build time. Rebuild with native/build_android.sh after editing
    // native/src/lib.rs.
}
