plugins {
    id("com.android.application")
    id("kotlin-android")
    // O plugin do Flutter precisa vir depois dos plugins Android e Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.edu.fatec.igorlima.previsao_do_tempo"
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
        applicationId = "br.edu.fatec.igorlima.previsao_do_tempo"
        // Usa as versões de SDK e do aplicativo definidas pelo Flutter.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Assinatura de desenvolvimento para a entrega acadêmica e execução local.
            // Publicação em loja exige uma chave de distribuição própria.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
