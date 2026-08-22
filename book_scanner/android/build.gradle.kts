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
// afterProject 等价于安全的 afterEvaluate：项目已被 evaluate 时也会立即回调，不会抛
// "Cannot run Project.afterEvaluate" 错误。设置方法用 setCompileSdkVersion(36)。
gradle.afterProject { proj, _ ->
    if (proj == rootProject) return@afterProject
    val androidExt = proj.extensions.findByName("android") ?: return@afterProject
    try {
        val setter = androidExt.javaClass.methods.firstOrNull {
            it.name == "setCompileSdkVersion" && it.parameterCount == 1
        }
        if (setter == null) {
            println("compileSdk-fix: ${proj.path} 未找到 setCompileSdkVersion，可用方法: " +
                androidExt.javaClass.methods.map { it.name }.filter { it.contains("ompileSdk") })
            return@afterProject
        }
        setter.invoke(androidExt, 36)
        val now = androidExt.javaClass.methods.firstOrNull {
            it.name == "getCompileSdkVersion" && it.parameterCount == 0
        }?.invoke(androidExt)
        println("compileSdk-fix: ${proj.path} compileSdk=$now")
    } catch (e: Exception) {
        println("compileSdk-fix: ${proj.path} 设置失败: ${e.message}")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
