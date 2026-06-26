package com.example.aetherlink.aetherlink_saf

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import com.example.aetherlink.aetherlink_saf.handlers.EditHandlers
import com.example.aetherlink.aetherlink_saf.handlers.PermissionPickerHandler
import com.example.aetherlink.aetherlink_saf.handlers.ReadHandlers
import com.example.aetherlink.aetherlink_saf.handlers.SearchHandlers
import com.example.aetherlink.aetherlink_saf.handlers.WriteHandlers
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.FileNotFoundException

/**
 * Aetherlink local SAF workspace plugin (Android side).
 *
 * Implements the contract in `docs/本地SAF工作区插件-方法规格.md`. This class is a
 * thin lifecycle + dispatch layer: business logic lives in `core/` (pure
 * helpers), `io/` (the SAF gateway) and `handlers/` (per-domain method groups),
 * each kept small and focused.
 *
 * Wire contract notes (load-bearing; the Dart `*.fromMap` decoders read these
 * exact keys):
 *  - channel name is `aetherlink_saf`.
 *  - every node `path`/`uri` is a **document-in-tree** URI
 *    (`content://auth/tree/<treeId>/document/<docId>`).
 *  - `FileInfo` keys: name, path, uri, size, type, mtime, isHidden (+ optional
 *    ctime, mimeType, permissions). `SelectedFileInfo` adds `displayPath`.
 *
 * Error contract (spec §3.2): handlers raise [SafException] (or a stock
 * `IllegalArgumentException` / `FileNotFoundException` / `SecurityException`),
 * and [onMethodCall] maps them to a stable `result.error(<E_*>, ...)`.
 */
class AetherlinkSafPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    private lateinit var repo: DocumentRepository
    private lateinit var read: ReadHandlers
    private lateinit var write: WriteHandlers
    private lateinit var edit: EditHandlers
    private lateinit var search: SearchHandlers
    private lateinit var permissionPicker: PermissionPickerHandler

    // ===== FlutterPlugin lifecycle =====

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        repo = DocumentRepository(applicationContext.contentResolver)
        read = ReadHandlers(repo)
        write = WriteHandlers(repo)
        edit = EditHandlers(repo)
        search = SearchHandlers(applicationContext, { activity }, repo)
        permissionPicker = PermissionPickerHandler(
            applicationContext.contentResolver,
            repo,
        ) { activity }
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

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        permissionPicker.onActivityResult(requestCode, resultCode, data)

    // ===== Method dispatch =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                // connectivity
                "echo" -> result.success(mapOf("value" to call.argument<String>("value")
                    ?: throw IllegalArgumentException("missing arg: value")))

                // permissions & picker (async / activity-driven)
                "requestPermissions" -> permissionPicker.requestPermissions(result)
                "openSystemFilePicker" -> permissionPicker.openSystemFilePicker(call, result)
                "checkPermissions" -> result.success(permissionPicker.checkPermissions(call))
                "listPersistedPermissions" -> result.success(permissionPicker.listPersistedPermissions())
                "releasePersistableUriPermission" ->
                    result.success(permissionPicker.releasePersistableUriPermission(call))

                // P0 reads
                "listDirectory" -> result.success(read.listDirectory(call))
                "readFile" -> result.success(read.readFile(call))
                "getFileInfo" -> result.success(read.getFileInfo(call))
                "exists" -> result.success(read.exists(call))

                // P1 advanced reads
                "readFileRange" -> result.success(read.readFileRange(call))
                "readFileBytes" -> result.success(read.readFileBytes(call))
                "getLineCount" -> result.success(read.getLineCount(call))
                "getFileHash" -> result.success(read.getFileHash(call))

                // P1 writes
                "writeFile" -> result.success(write.writeFile(call))
                "createFile" -> result.success(write.createFile(call))
                "createDirectory" -> result.success(write.createDirectory(call))
                "deleteFile" -> result.success(write.deleteFile(call))
                "deleteDirectory" -> result.success(write.deleteDirectory(call))
                "renameFile" -> result.success(write.renameFile(call))
                "moveFile" -> result.success(write.moveFile(call))
                "copyFile" -> result.success(write.copyFile(call))

                // P2 edits
                "insertContent" -> result.success(edit.insertContent(call))
                "replaceInFile" -> result.success(edit.replaceInFile(call))
                "applyDiff" -> result.success(edit.applyDiff(call))

                // P2 search & system apps
                "searchFiles" -> result.success(search.searchFiles(call))
                "openSystemFileManager" -> result.success(search.openSystemFileManager(call))
                "openFileWithSystemApp" -> result.success(search.openFileWithSystemApp(call))

                else -> result.notImplemented()
            }
        } catch (e: SafException) {
            result.error(e.code, e.message, e.details)
        } catch (e: IllegalArgumentException) {
            result.error(SafError.INVALID_ARG, e.message, null)
        } catch (e: FileNotFoundException) {
            result.error(SafError.NOT_FOUND, e.message, null)
        } catch (e: SecurityException) {
            result.error(SafError.NO_PERMISSION, e.message, null)
        } catch (t: Throwable) {
            result.error(SafError.IO, t.message ?: t::class.java.simpleName, null)
        }
    }
}
