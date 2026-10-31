import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// firma de release: variables de entorno (GitHub Actions) o keystore.properties local (fuera de git)
val signing = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, key: String): String? = System.getenv(env) ?: signing.getProperty(key)

android {
    namespace = "es.david.findemes"
    compileSdk = 37

    defaultConfig {
        applicationId = "es.david.findemes"
        minSdk = 26
        targetSdk = 36
        versionCode = (System.getenv("VERSION_CODE") ?: "1").toInt()
        versionName = "2.3"
        // AdMob: sin las claves de verdad se usan los anuncios de prueba de Google
        manifestPlaceholders["admobAppId"] = System.getenv("FDM_ADMOB_APP_ID")?.takeIf { it.isNotBlank() } ?: "ca-app-pub-3940256099942544~3347511713"
        buildConfigField("String", "ADMOB_REWARDED", "\"" + (System.getenv("FDM_ADMOB_REWARDED")?.takeIf { it.isNotBlank() } ?: "ca-app-pub-3940256099942544/5224354917") + "\"")
    }

    signingConfigs {
        // clave de pruebas (en el repositorio): el APK de prueba siempre lleva la misma firma y se actualiza sin desinstalar
        create("prueba") {
            storeFile = file("prueba.jks")
            storePassword = "findemes"
            keyAlias = "prueba"
            keyPassword = "findemes"
        }
        create("release") {
            val store = signingValue("FDM_KEYSTORE_PATH", "storeFile")
            if (store != null) {
                storeFile = file(store)
                storePassword = signingValue("FDM_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("FDM_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("FDM_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("prueba")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            val cfg = signingConfigs.getByName("release")
            // sin la clave de subida, se firma con la de pruebas (para instalar el APK a mano)
            signingConfig = if (cfg.storeFile != null) cfg else signingConfigs.getByName("prueba")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.fragment)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.play.ads)
    implementation(libs.ump)
    implementation(libs.billing)
    debugImplementation(libs.compose.ui.tooling)
    testImplementation(libs.junit)
}
