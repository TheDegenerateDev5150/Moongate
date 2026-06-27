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

// v0.5.0: Force every Android plugin subproject (e.g. bonsoir_android) to
// build against compileSdk 36. Setting compileSdk in app/build.gradle.kts
// alone doesn't propagate - Flutter plugin modules pick up Flutter's
// default (33 in the current stable channel), and bonsoir's transitive
// androidx.fragment:1.7.1 / androidx.window:1.2.0 deps need 34+.
//
// Targeting BaseExtension covers both com.android.library plugins (most
// Flutter plugins) and com.android.application (:app). MUST register
// before the evaluationDependsOn(":app") block below - that block forces
// evaluation of subprojects, after which afterEvaluate would throw
// "Cannot run Project.afterEvaluate when the project is already evaluated".
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileSdkVersion(36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
