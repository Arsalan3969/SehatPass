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

fun configureAndroidCompileSdk(proj: Project) {
    val android = proj.extensions.findByName("android") ?: return
    for (method in android.javaClass.methods) {
        if (method.name == "setCompileSdk" && method.parameterCount == 1) {
            method.invoke(android, 36)
            return
        } else if (method.name == "compileSdkVersion" && method.parameterCount == 1 &&
            (method.parameterTypes[0] == Int::class.javaPrimitiveType || method.parameterTypes[0] == java.lang.Integer::class.java)) {
            method.invoke(android, 36)
            return
        }
    }
}

subprojects {
    if (state.executed) {
        configureAndroidCompileSdk(this)
    } else {
        afterEvaluate {
            configureAndroidCompileSdk(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
