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
    afterEvaluate {
        if (project.name == "clipboard") {
            // clipboard 3.0.14 pins its Android library compileSdk to 33, but
            // its resolved AndroidX artifacts require API 34. This only raises
            // the library compile SDK; the app targetSdk and runtime behavior
            // remain unchanged.
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 34
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
