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
    private val termuxRunCommandPermission = "com.termux.permission.RUN_COMMAND"
    private val runCommandPermissionRequestCode = 41043

    // The script waiting for the RUN_COMMAND permission grant: the permission is
    // "dangerous", so it needs a runtime request; the send is resumed (or failed)
    // in onRequestPermissionsResult.
    private var pendingRunCommand: Pair<String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, termuxChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "detect" -> result.success(detectTermux())
                    "runCommand" -> runTermuxCommand(call.argument<String>("script"), result)
                    "openTermux" -> openTermux(result)
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

    // 跳到 Termux 前台（快速启动入口，也方便代跑后切过去看执行过程）。
    private fun openTermux(result: MethodChannel.Result) {
        val intent = packageManager.getLaunchIntentForPackage(termuxPackage)
        if (intent == null) {
            result.error("not-installed", "Termux is not installed", null)
            return
        }
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("open-failed", e.message, null)
        }
    }

    // Termux-B（设计文档 §10.5 方式 B）：通过 RUN_COMMAND intent 让 Termux 代跑
    // 一段 bash 脚本（前台会话，用户能看到过程并处理授权弹框）。两个前提：
    // ① Termux 端已开 allow-external-apps=true，否则 Termux 拒收；
    // ② com.termux.permission.RUN_COMMAND 是运行时（dangerous）权限，manifest
    //    声明之外还必须在这里向系统申请，用户同意后才发得出去。
    private fun runTermuxCommand(script: String?, result: MethodChannel.Result) {
        if (script.isNullOrBlank()) {
            result.error("bad-args", "script is required", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(termuxRunCommandPermission) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingRunCommand != null) {
                result.error("busy", "another runCommand is awaiting permission", null)
                return
            }
            pendingRunCommand = script to result
            requestPermissions(
                arrayOf(termuxRunCommandPermission),
                runCommandPermissionRequestCode,
            )
            return
        }
        sendRunCommand(script, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != runCommandPermissionRequestCode) return
        val pending = pendingRunCommand ?: return
        pendingRunCommand = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            sendRunCommand(pending.first, pending.second)
        } else {
            pending.second.error(
                "permission-denied",
                "RUN_COMMAND permission was denied",
                null,
            )
        }
    }

    private fun sendRunCommand(script: String, result: MethodChannel.Result) {
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
            // Termux 的 RunCommandService 自己会转前台服务；当 Termux 进程还在后台时
            // 普通 startService 会被系统的后台启动限制拦下（IllegalStateException），
            // 所以 O+ 用 startForegroundService。
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(true)
        } catch (e: SecurityException) {
            result.error("external-apps-disabled", e.message, null)
        } catch (e: Exception) {
            result.error("run-command-failed", e.message, null)
        }
    }
}
