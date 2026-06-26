package com.example.aetherlink.aetherlink_saf

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Aetherlink local SAF workspace plugin (Android side).
 *
 * Implements the contract in `docs/本地SAF工作区插件-方法规格.md`.
 *
 * In this revision only `echo` is wired end-to-end; the rest of the P0
 * surface returns `notImplemented` so the channel route map and Dart-side
 * signatures can be exercised before the SAF logic lands. Subsequent passes
 * fill in `openSystemFilePicker` -> `listDirectory` -> `readFile` etc.
 *
 * Error contract (spec §3.2): every handler should translate failures into a
 * `result.error(<E_*>, message, details)` pair instead of leaking exceptions.
 */
class AetherlinkSafPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    // ---- pending picker state (populated when openSystemFilePicker runs) ----
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingPickerRequestCode: Int = 0

    // ===== FlutterPlugin lifecycle =====

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "aetherlink_saf")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ===== ActivityAware lifecycle =====

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // ===== ActivityResultListener =====

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == pendingPickerRequestCode && pendingPickerResult != null) {
            val pending = pendingPickerResult ?: return false
            pendingPickerResult = null
            // Real picker handling is implemented alongside openSystemFilePicker.
            // For now, fail loudly so we notice if we ever forget to swap this out.
            pending.error(
                ERR_NOT_SUPPORTED,
                "openSystemFilePicker result handler not implemented yet",
                null
            )
            return true
        }
        return false
    }

    // ===== Method dispatch =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                // ----- P0: connectivity self-test -----
                "echo" -> handleEcho(call, result)

                // ----- P0: permission management (not yet implemented) -----
                "requestPermissions",
                "checkPermissions",
                "listPersistedPermissions",
                "releasePersistableUriPermission" -> result.notImplemented()

                // ----- P0: system picker (not yet implemented) -----
                "openSystemFilePicker" -> result.notImplemented()

                // ----- P0: directory & file reads (not yet implemented) -----
                "listDirectory",
                "readFile",
                "getFileInfo",
                "exists" -> result.notImplemented()

                else -> result.notImplemented()
            }
        } catch (e: IllegalArgumentException) {
            result.error(ERR_INVALID_ARG, e.message, null)
        } catch (e: SecurityException) {
            result.error(ERR_NO_PERMISSION, e.message, null)
        } catch (t: Throwable) {
            result.error(ERR_IO, t.message ?: t::class.java.simpleName, null)
        }
    }

    // ===== Handlers =====

    private fun handleEcho(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("value")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: value", null)
        result.success(mapOf("value" to value))
    }

    // ===== Error codes (spec §3.2) =====

    @Suppress("unused", "MemberVisibilityCanBePrivate")
    private companion object {
        const val ERR_NO_PERMISSION = "E_NO_PERMISSION"
        const val ERR_URI_STALE = "E_URI_STALE"
        const val ERR_NOT_FOUND = "E_NOT_FOUND"
        const val ERR_INVALID_ARG = "E_INVALID_ARG"
        const val ERR_IO = "E_IO"
        const val ERR_OUT_OF_SPACE = "E_OUT_OF_SPACE"
        const val ERR_TOO_LARGE = "E_TOO_LARGE"
        const val ERR_RANGE_CONFLICT = "E_RANGE_CONFLICT"
        const val ERR_NOT_SUPPORTED = "E_NOT_SUPPORTED"
        const val ERR_USER_CANCELLED = "E_USER_CANCELLED"
    }
}
