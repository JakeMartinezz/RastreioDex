plugins {
    id("com.android.application")
    id("kotlin-android")
    // O plugin do Flutter deve vir após o Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // REMOVIDO: id("com.google.gms.google-services")
}

android {
    namespace = "com.agiomartinez.rastreiodex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Especifique seu próprio ID único se necessário
        applicationId = "com.agiomartinez.rastreiodex"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Assinando com a chave de debug por enquanto para testes
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
