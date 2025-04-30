plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin siempre va después
}

android {
    namespace = "com.example.pos_app" // Asegúrate de que coincide con AndroidManifest.xml
    compileSdk = 34 // ⚠️ SDK más alto requerido por algunos plugins
    ndkVersion = "27.0.12077973" // Tu NDK correcto para blue_thermal_printer

    defaultConfig {
        applicationId = "com.example.pos_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // reemplaza esto si tienes una config release propia
        }
    }
}

flutter {
    source = "../.."
}
