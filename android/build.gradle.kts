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

subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
        }
    }
}

subprojects {
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val targetCompatibility = project.extensions.findByName("android")
            ?.let { it as? com.android.build.gradle.BaseExtension }
            ?.compileOptions
            ?.targetCompatibility

        if (targetCompatibility != null) {
            val targetStr = targetCompatibility.toString()
            val jvmTargetVal = when (targetStr) {
                "1.8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                "21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            }
            compilerOptions {
                jvmTarget.set(jvmTargetVal)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
