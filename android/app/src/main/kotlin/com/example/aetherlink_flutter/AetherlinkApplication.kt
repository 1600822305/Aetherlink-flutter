package com.example.aetherlink_flutter

import android.app.Application
import com.example.aetherlink_flutter.background.BackgroundRuntime
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * 一个进程只有一个 Dart isolate，归 Application 而不是 Activity（对齐 kelivo
 * `KelivoApplication`）：用户划掉最近任务、系统回收 Activity 时，引擎和其中
 * 运行的聊天生成 / 智能体任务都继续活着，前台服务 + WakeLock 才有意义。
 * 进程被杀时引擎随之结束，新进程再建一个。
 */
class AetherlinkApplication : Application() {
    val backgroundRuntime by lazy { BackgroundRuntime(this) }

    private val engineHolder = lazy {
        // 构造时自动注册 GeneratedPluginRegistrant 里的全部插件。
        FlutterEngine(this).also { engine ->
            // 后台通道跟引擎同生命周期：只配置一次，Activity 重建不再重配。
            backgroundRuntime.configure(engine.dartExecutor.binaryMessenger)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
        }
    }

    val hasEngine get() = engineHolder.isInitialized()
    val engine: FlutterEngine get() = engineHolder.value
}
