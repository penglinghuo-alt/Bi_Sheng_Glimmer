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

// 统一所有模块（含第三方插件）compileSdk=36，避免插件自身 compileSdk 过低导致 AAR 检查失败
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val method = androidExt.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" && it.parameterCount == 1
            }
            method?.invoke(androidExt, 36)
        } catch (_: Exception) {
            // 非 Android 模块跳过
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
