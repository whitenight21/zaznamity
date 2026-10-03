allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rootBuildDir: File = rootProject.layout.buildDirectory.get().asFile
tasks.register<Delete>("clean") {
    delete(rootBuildDir)
}