allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ← Force Kotlin version across ALL subprojects
    configurations.all {
        resolutionStrategy {
            force("org.jetbrains.kotlin:kotlin-stdlib:2.3.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.3.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.3.0")
        }
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

gradle.afterProject {
    if (plugins.hasPlugin("com.android.library")) {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}