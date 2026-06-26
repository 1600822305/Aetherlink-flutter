package com.example.aetherlink.aetherlink_saf.handlers

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * SAF permission management and the system picker. These are the only methods
 * that drive an `Activity` (`startActivityForResult`), so the asynchronous
 * pending-result bookkeeping is isolated here; the plugin just forwards
 * `onActivityResult`.
 */
class PermissionPickerHandler(
    private val resolver: ContentResolver,
    private val repo: DocumentRepository,
    private val activityProvider: () -> Activity?,
) {

    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int = 0
    private var pendingKind: Int = KIND_NONE
    private var pendingPickerType: String? = null

    // ===== async methods =====

    fun requestPermissions(result: MethodChannel.Result) {
        val act = activityProvider()
            ?: return result.error(SafError.NOT_SUPPORTED, "no foreground activity", null)
        if (pendingResult != null) {
            return result.error(SafError.IO, "another picker/permission request is in progress", null)
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply { addFlags(PERSISTABLE_FLAGS) }
        beginPending(result, REQ_REQUEST_PERMS, KIND_REQUEST_PERMS, null)
        act.startActivityForResult(intent, REQ_REQUEST_PERMS)
    }

    fun openSystemFilePicker(call: MethodCall, result: MethodChannel.Result) {
        val act = activityProvider()
            ?: return result.error(SafError.NOT_SUPPORTED, "no foreground activity", null)
        if (pendingResult != null) {
            return result.error(SafError.IO, "another picker/permission request is in progress", null)
        }
        val type = call.argument<String>("type")
            ?: return result.error(SafError.INVALID_ARG, "missing arg: type", null)
        val multiple = call.argument<Boolean>("multiple") ?: false
        val accept = call.argument<List<String>>("accept")
        val startDirectory = call.argument<String>("startDirectory")

        val intent = when (type) {
            "directory" -> Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply { addFlags(PERSISTABLE_FLAGS) }
            "file" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                this.type = "*/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
                if (!accept.isNullOrEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, accept.toTypedArray())
                addFlags(PERSISTABLE_FLAGS)
            }
            else -> return result.error(
                SafError.INVALID_ARG,
                "type must be 'file' or 'directory' (got '$type'); 'both' is unsupported",
                null,
            )
        }
        if (startDirectory != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(startDirectory))
        }
        beginPending(result, REQ_PICKER, KIND_PICKER, type)
        act.startActivityForResult(intent, REQ_PICKER)
    }

    /** Forwarded from the plugin's `ActivityResultListener`. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val pending = pendingResult ?: return false
        if (requestCode != pendingRequestCode) return false
        val kind = pendingKind
        val pickerType = pendingPickerType
        clearPending()
        return try {
            when (kind) {
                KIND_PICKER -> handlePickerResult(pending, resultCode, data, pickerType)
                KIND_REQUEST_PERMS -> handleRequestPermsResult(pending, resultCode, data)
                else -> pending.error(SafError.IO, "unexpected activity result kind", null)
            }
            true
        } catch (t: Throwable) {
            pending.error(SafError.IO, t.message ?: t::class.java.simpleName, null)
            true
        }
    }

    // ===== sync methods =====

    fun checkPermissions(call: MethodCall): Any {
        val uri = call.argument<String>("uri")
        val perms = resolver.persistedUriPermissions
        val granted = if (uri == null) {
            perms.any { it.isReadPermission }
        } else {
            val target = Uri.parse(uri)
            perms.any { it.isReadPermission && uriCoversTree(it.uri, target) }
        }
        return mapOf(
            "granted" to granted,
            "message" to if (granted) "已授权" else "未找到持久化授权",
        )
    }

    fun listPersistedPermissions(): Any {
        val list = resolver.persistedUriPermissions.mapNotNull { perm ->
            val rootUri = runCatching {
                DocumentsContract.buildDocumentUriUsingTree(
                    perm.uri,
                    DocumentsContract.getTreeDocumentId(perm.uri),
                )
            }.getOrNull() ?: return@mapNotNull null
            repo.querySelectedFileInfo(rootUri)
        }
        return mapOf("uris" to list)
    }

    fun releasePersistableUriPermission(call: MethodCall): Any? {
        val uri = call.argument<String>("uri")
            ?: throw IllegalArgumentException("missing arg: uri")
        runCatching {
            resolver.releasePersistableUriPermission(Uri.parse(uri), PERSISTABLE_TAKE_FLAGS)
        }
        return null
    }

    // ===== activity result branches =====

    private fun handlePickerResult(
        result: MethodChannel.Result,
        resultCode: Int,
        data: Intent?,
        pickerType: String?,
    ) {
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyPickerResult(cancelled = true))
            return
        }
        val takeFlags = data.flags and PERSISTABLE_TAKE_FLAGS
        val effectiveFlags = if (takeFlags != 0) takeFlags else PERSISTABLE_TAKE_FLAGS

        if (pickerType == "directory") {
            val treeUri = data.data ?: return result.success(emptyPickerResult(cancelled = true))
            resolver.takePersistableUriPermission(treeUri, effectiveFlags)
            val rootUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )
            result.success(
                mapOf(
                    "files" to emptyList<Any?>(),
                    "directories" to listOfNotNull(repo.querySelectedFileInfo(rootUri)),
                    "cancelled" to false,
                ),
            )
            return
        }

        val uris = collectPickedUris(data)
        if (uris.isEmpty()) {
            result.success(emptyPickerResult(cancelled = true))
            return
        }
        val files = uris.mapNotNull { uri ->
            runCatching { resolver.takePersistableUriPermission(uri, effectiveFlags) }
            repo.querySelectedFileInfo(uri)
        }
        result.success(
            mapOf(
                "files" to files,
                "directories" to emptyList<Any?>(),
                "cancelled" to false,
            ),
        )
    }

    private fun handleRequestPermsResult(
        result: MethodChannel.Result,
        resultCode: Int,
        data: Intent?,
    ) {
        val treeUri = data?.data
        if (resultCode != Activity.RESULT_OK || treeUri == null) {
            result.success(mapOf("granted" to false, "message" to "用户取消"))
            return
        }
        val takeFlags = data.flags and PERSISTABLE_TAKE_FLAGS
        resolver.takePersistableUriPermission(
            treeUri,
            if (takeFlags != 0) takeFlags else PERSISTABLE_TAKE_FLAGS,
        )
        result.success(mapOf("granted" to true, "message" to "已授权"))
    }

    // ===== helpers =====

    private fun beginPending(result: MethodChannel.Result, code: Int, kind: Int, pickerType: String?) {
        pendingResult = result
        pendingRequestCode = code
        pendingKind = kind
        pendingPickerType = pickerType
    }

    private fun clearPending() {
        pendingResult = null
        pendingRequestCode = 0
        pendingKind = KIND_NONE
        pendingPickerType = null
    }

    private fun collectPickedUris(data: Intent): List<Uri> {
        val clip = data.clipData
        if (clip != null) {
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        }
        return listOfNotNull(data.data)
    }

    private fun uriCoversTree(treeUri: Uri, target: Uri): Boolean {
        if (treeUri == target) return true
        return runCatching {
            DocumentsContract.getTreeDocumentId(treeUri) ==
                runCatching { DocumentsContract.getTreeDocumentId(target) }.getOrNull()
        }.getOrDefault(false)
    }

    private fun emptyPickerResult(cancelled: Boolean): Map<String, Any?> = mapOf(
        "files" to emptyList<Any?>(),
        "directories" to emptyList<Any?>(),
        "cancelled" to cancelled,
    )

    private companion object {
        const val KIND_NONE = 0
        const val KIND_PICKER = 1
        const val KIND_REQUEST_PERMS = 2

        const val REQ_PICKER = 42001
        const val REQ_REQUEST_PERMS = 42002

        const val PERSISTABLE_TAKE_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        const val PERSISTABLE_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
    }
}
