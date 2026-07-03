group = "com.aetherlink.dexeditor"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.aetherlink.dexeditor"

    compileSdk = 36
    ndkVersion = "25.2.9519653"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/java", "src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17 -O2"
                // 静态链接 C++ 标准库，避免 libc++_shared.so 的 16KB 对齐问题
                arguments += "-DANDROID_STL=c++_static"
            }
        }

        // 仅保留 ARM 架构（x86 走电脑端 C++ MCP）
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }

    lint {
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")

    // dexlib2 - DEX 文件编辑核心库
    api("com.android.tools.smali:smali-dexlib2:3.0.3")
    // Guava - dexlib2 依赖
    api("com.google.guava:guava:32.1.3-android")
    // Gson - JSON 序列化
    api("com.google.code.gson:gson:2.10.1")
    // APK Signer - V1/V2/V3/V4 签名支持
    api("com.android.tools.build:apksig:8.7.2")
}
