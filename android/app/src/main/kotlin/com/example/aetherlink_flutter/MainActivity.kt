package com.example.aetherlink_flutter

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Termux one-tap setup (设计文档 §10.5 / Termux-A): the Dart side
    // (core/platform/impl/termux_impl.dart) asks whether Termux is installed and
    // from where, so it can warn about the deprecated Play build. Requires the
    // <package android:name="com.termux"> <queries> entry in the manifest to be
    // visible on Android 11+.
    private val termuxChannel = "aetherlink/termux"
    private val termuxPackage = "com.termux"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, termuxChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "detect" -> result.success(detectTermux())
                    "runCommand" -> runTermuxCommand(call.argument<String>("script"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun detectTermux(): Map<String, Any?> {
        val pm = packageManager
        val installed = try {
            pm.getPackageInfo(termuxPackage, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
        var installer: String? = null
        if (installed) {
            installer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(termuxPackage).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(termuxPackage)
                }
            } catch (e: Exception) {
                null
            }
        }
        return mapOf(
            "installed" to installed,
            "installer" to installer,
        )
    }

    // Termux-B（设计文档 §10.5 方式 B）：通过 RUN_COMMAND intent 让 Termux 代跑
    // 一段 bash 脚本（前台会话，用户能看到过程并处理授权弹框）。需要 Termux 端已开
    // allow-external-apps=true，否则 Termux 会拒收（回 SecurityException 或静默失败）。
    private fun runTermuxCommand(script: String?, result: MethodChannel.Result) {
        if (script.isNullOrBlank()) {
            result.error("bad-args", "script is required", null)
            return
        }
        val intent = Intent("com.termux.RUN_COMMAND").apply {
            setClassName(termuxPackage, "com.termux.app.RunCommandService")
            putExtra(
                "com.termux.RUN_COMMAND_PATH",
                "/data/data/com.termux/files/usr/bin/bash",
            )
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script))
            putExtra(
                "com.termux.RUN_COMMAND_WORKDIR",
                "/data/data/com.termux/files/home",
            )
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", false)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
        }
        try {
            startService(intent)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("external-apps-disabled", e.message, null)
        } catch (e: Exception) {
            result.error("run-command-failed", e.message, null)
        }
    }
}
