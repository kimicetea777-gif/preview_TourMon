import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store 배포용 release 서명 — key.properties/키스토어는 .gitignore돼 있어 로컬에 없는 게 정상이고,
// 그럴 땐 지금까지처럼 debug 서명으로 자동 폴백한다(로컬 `flutter run --release` 워크플로 유지).
// key.properties 생성 절차는 Document/how_to_build.md 참고.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tourmon.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어 배포 후 영구 변경 불가 — com.tourmon.mobile로 확정(2026-08-27, Document/temp.md
        // "배포 전 커스터마이징 체크리스트" 2번). redirect scheme(com.tourmon.app)과는 무관.
        applicationId = "com.tourmon.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect 최소 요구 버전(API 28)이 Flutter 기본값(API 24)보다 높아서 명시 오버라이드
        // (Document/temp.md "Android (Health Connect)" 절, 2026-08-19 결정. API 24~27 점유율이
        // 낮아 지원 범위 축소 영향 작다고 판단).
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // key.properties가 없는 로컬 개발 환경 — debug 키로 폴백(`flutter run --release`용).
                // 이 경로로 만들어진 산출물은 Play Console에 업로드할 수 없음(서명 불일치로 거부됨).
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
