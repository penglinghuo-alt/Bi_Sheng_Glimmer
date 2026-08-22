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
// 使用 projectsEvaluated 而不是 afterEvaluate：模板的 evaluationDependsOn 已提前 evaluate 部分子项目
gradle.projectsEvaluated {
    rootProject.subprojects.forEach { proj ->
        proj.extensions.findByName("android")?.let { ext ->
            try {
                val method = ext.javaClass.methods.firstOrNull {
                    it.name == "compileSdkVersion" && it.parameterCount == 1
                }
                method?.invoke(ext, 36)
            } catch (_: Exception) {
                // 非 Android 模块跳过
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
