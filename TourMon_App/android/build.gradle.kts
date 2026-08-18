allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 1단계 배경 지도: objectbox_flutter_libs(4.3.1, flutter_map_tile_caching가 강제하는 버전)가
// 자체 compileSdk=31로 퍼블리시되어 있어 다른 androidx 트랜지티브 의존성(compileSdk 34+ 요구)과
// 충돌함(CheckAarMetadataWorkAction 실패). 플러그인 자체를 고칠 수 없으니 모든 서브프로젝트의
// compileSdk를 앱과 동일하게 강제 통일.
subprojects {
    // :app은 evaluationDependsOn(":app")으로 인해 이 시점에 이미 평가가 끝나 있어서
    // afterEvaluate를 걸면 "already evaluated" 오류가 남 — :app은 flutter.compileSdkVersion을
    // 이미 정상적으로 쓰고 있어 애초에 이 오버라이드가 필요 없으므로 제외
    if (project.name != "app") {
        afterEvaluate {
            plugins.withId("com.android.library") {
                extensions.configure<com.android.build.gradle.LibraryExtension> {
                    compileSdk = 36
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
