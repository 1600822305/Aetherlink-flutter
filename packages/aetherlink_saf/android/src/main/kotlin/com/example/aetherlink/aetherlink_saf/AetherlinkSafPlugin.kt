package com.example.aetherlink.aetherlink_saf

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Base64
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
 * Implements the contract in `docs/本地SAF工作区插件-方法规格.md`.
 *
 * Wire contract notes (these are load-bearing; the Dart `*.fromMap` decoders
 * read these exact keys, so don't rename them):
 *  - channel name is `aetherlink_saf`.
 *  - every node `path`/`uri` is a **document-in-tree** URI
 *    (`content://auth/tree/<treeId>/document/<docId>`). The root of a picked
 *    tree is `buildDocumentUriUsingTree(treeUri, getTreeDocumentId(treeUri))`.
 *    Keeping `path` in this form means `getDocumentId` /
 *    `buildChildDocumentsUriUsingTree` work uniformly for root and children.
 *  - `FileInfo` map keys: name, path, uri, size, type, mtime, isHidden (+
 *    optional ctime, mimeType, permissions). `SelectedFileInfo` adds the
 *    display-only `displayPath`.
 *
 * Error contract (spec §3.2): handlers translate failures into a
 * `result.error(<E_*>, message, details)` pair instead of leaking exceptions.
 */
class AetherlinkSafPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    private val resolver: ContentResolver get() = applicationContext.contentResolver

    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity

    // ---- pending activity-result state ----
    // Only one picker / permission request can be in flight at a time.
    private var pendingResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int = 0
    private var pendingKind: Int = KIND_NONE
    private var pendingPickerType: String? = null

    // ===== FlutterPlugin lifecycle =====

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
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
        val pending = pendingResult ?: return false
        if (requestCode != pendingRequestCode) return false

        pendingResult = null
        pendingRequestCode = 0
        val kind = pendingKind
        val pickerType = pendingPickerType
        pendingKind = KIND_NONE
        pendingPickerType = null

        return try {
            when (kind) {
                KIND_PICKER -> handlePickerResult(pending, resultCode, data, pickerType)
                KIND_REQUEST_PERMS -> handleRequestPermsResult(pending, resultCode, data)
                else -> pending.error(ERR_IO, "unexpected activity result kind", null)
            }
            true
        } catch (t: Throwable) {
            pending.error(ERR_IO, t.message ?: t::class.java.simpleName, null)
            true
        }
    }

    // ===== Method dispatch =====

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "echo" -> handleEcho(call, result)
                "requestPermissions" -> handleRequestPermissions(result)
                "checkPermissions" -> handleCheckPermissions(call, result)
                "listPersistedPermissions" -> handleListPersistedPermissions(result)
                "releasePersistableUriPermission" ->
                    handleReleasePersistableUriPermission(call, result)
                "openSystemFilePicker" -> handleOpenSystemFilePicker(call, result)
                "listDirectory" -> handleListDirectory(call, result)
                "readFile" -> handleReadFile(call, result)
                "getFileInfo" -> handleGetFileInfo(call, result)
                "exists" -> handleExists(call, result)
                else -> result.notImplemented()
            }
        } catch (e: IllegalArgumentException) {
            result.error(ERR_INVALID_ARG, e.message, null)
        } catch (e: FileNotFoundException) {
            result.error(ERR_NOT_FOUND, e.message, null)
        } catch (e: SecurityException) {
            result.error(ERR_NO_PERMISSION, e.message, null)
        } catch (t: Throwable) {
            result.error(ERR_IO, t.message ?: t::class.java.simpleName, null)
        }
    }

    // ===== Handlers: connectivity =====

    private fun handleEcho(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("value")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: value", null)
        result.success(mapOf("value" to value))
    }

    // ===== Handlers: permission management =====

    private fun handleRequestPermissions(result: MethodChannel.Result) {
        val act = activity
            ?: return result.error(ERR_NOT_SUPPORTED, "no foreground activity", null)
        if (pendingResult != null) {
            return result.error(ERR_IO, "another picker/permission request is in progress", null)
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(PERSISTABLE_FLAGS)
        }
        pendingResult = result
        pendingRequestCode = REQ_REQUEST_PERMS
        pendingKind = KIND_REQUEST_PERMS
        act.startActivityForResult(intent, REQ_REQUEST_PERMS)
    }

    private fun handleCheckPermissions(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        val perms = resolver.persistedUriPermissions
        val granted = if (uri == null) {
            perms.any { it.isReadPermission }
        } else {
            val target = Uri.parse(uri)
            perms.any { it.isReadPermission && uriCoversTree(it.uri, target) }
        }
        result.success(
            mapOf(
                "granted" to granted,
                "message" to if (granted) "已授权" else "未找到持久化授权",
            )
        )
    }

    private fun handleListPersistedPermissions(result: MethodChannel.Result) {
        val list = resolver.persistedUriPermissions.mapNotNull { perm ->
            val treeUri = perm.uri
            // Persisted entries are bare tree URIs; project them to the root
            // document-in-tree URI so the result is usable as a `path`.
            val rootUri = runCatching {
                DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri),
                )
            }.getOrNull() ?: return@mapNotNull null
            val info = querySelectedFileInfo(rootUri) ?: return@mapNotNull null
            info
        }
        result.success(list)
    }

    private fun handleReleasePersistableUriPermission(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val uri = call.argument<String>("uri")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: uri", null)
        runCatching {
            resolver.releasePersistableUriPermission(Uri.parse(uri), PERSISTABLE_TAKE_FLAGS)
        }
        result.success(null)
    }

    // ===== Handlers: system picker =====

    private fun handleOpenSystemFilePicker(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
            ?: return result.error(ERR_NOT_SUPPORTED, "no foreground activity", null)
        if (pendingResult != null) {
            return result.error(ERR_IO, "another picker/permission request is in progress", null)
        }
        val type = call.argument<String>("type")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: type", null)
        val multiple = call.argument<Boolean>("multiple") ?: false
        val accept = call.argument<List<String>>("accept")
        val startDirectory = call.argument<String>("startDirectory")

        val intent = when (type) {
            "directory" -> Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(PERSISTABLE_FLAGS)
            }
            "file" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                this.type = "*/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
                if (!accept.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_MIME_TYPES, accept.toTypedArray())
                }
                addFlags(PERSISTABLE_FLAGS)
            }
            else -> return result.error(
                ERR_INVALID_ARG,
                "type must be 'file' or 'directory' (got '$type'); 'both' is unsupported",
                null,
            )
        }
        if (startDirectory != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(startDirectory))
        }

        pendingResult = result
        pendingRequestCode = REQ_PICKER
        pendingKind = KIND_PICKER
        pendingPickerType = type
        act.startActivityForResult(intent, REQ_PICKER)
    }

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

        if (pickerType == "directory") {
            val treeUri = data.data
                ?: return result.success(emptyPickerResult(cancelled = true))
            resolver.takePersistableUriPermission(
                treeUri,
                if (takeFlags != 0) takeFlags else PERSISTABLE_TAKE_FLAGS,
            )
            val rootUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )
            val info = querySelectedFileInfo(rootUri)
            result.success(
                mapOf(
                    "files" to emptyList<Any?>(),
                    "directories" to listOfNotNull(info),
                    "cancelled" to false,
                )
            )
            return
        }

        // file picker
        val uris = collectPickedUris(data)
        if (uris.isEmpty()) {
            result.success(emptyPickerResult(cancelled = true))
            return
        }
        val files = uris.mapNotNull { uri ->
            runCatching {
                resolver.takePersistableUriPermission(
                    uri,
                    if (takeFlags != 0) takeFlags else PERSISTABLE_TAKE_FLAGS,
                )
            }
            querySelectedFileInfo(uri)
        }
        result.success(
            mapOf(
                "files" to files,
                "directories" to emptyList<Any?>(),
                "cancelled" to false,
            )
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

    // ===== Handlers: directory & file reads =====

    private fun handleListDirectory(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: path", null)
        val showHidden = call.argument<Boolean>("showHidden") ?: false
        val sortBy = call.argument<String>("sortBy") ?: "name"
        val sortOrder = call.argument<String>("sortOrder") ?: "asc"

        val parentUri = Uri.parse(path)
        val parentDocId = DocumentsContract.getDocumentId(parentUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(parentUri, parentDocId)

        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )

        val items = ArrayList<Map<String, Any?>>()
        val cursor = resolver.query(childrenUri, projection, null, null, null)
            ?: return result.error(ERR_URI_STALE, "directory query returned null", mapOf("uri" to path))
        cursor.use { c ->
            val idIdx = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIdx = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIdx = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeIdx = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
            val mtimeIdx = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            while (c.moveToNext()) {
                val childDocId = c.getString(idIdx) ?: continue
                val childUri = DocumentsContract.buildDocumentUriUsingTree(parentUri, childDocId)
                val name = c.getString(nameIdx) ?: ""
                if (!showHidden && name.startsWith(".")) continue
                items.add(
                    buildFileInfo(
                        name = name,
                        uriString = childUri.toString(),
                        mime = if (c.isNull(mimeIdx)) null else c.getString(mimeIdx),
                        size = if (c.isNull(sizeIdx)) 0L else c.getLong(sizeIdx),
                        mtime = if (c.isNull(mtimeIdx)) 0L else c.getLong(mtimeIdx),
                    )
                )
            }
        }

        sortFileInfo(items, sortBy, sortOrder)
        result.success(mapOf("files" to items, "totalCount" to items.size))
    }

    private fun handleReadFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: path", null)
        val encoding = call.argument<String>("encoding") ?: "utf8"
        val uri = Uri.parse(path)

        val declaredSize = queryLong(uri, DocumentsContract.Document.COLUMN_SIZE)
        if (declaredSize != null && declaredSize > MAX_READ_BYTES) {
            return result.error(
                ERR_TOO_LARGE,
                "file is ${declaredSize}B, over the ${MAX_READ_BYTES}B whole-read limit",
                mapOf("uri" to path, "size" to declaredSize),
            )
        }

        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return result.error(ERR_NOT_FOUND, "cannot open input stream", mapOf("uri" to path))
        if (bytes.size > MAX_READ_BYTES) {
            return result.error(
                ERR_TOO_LARGE,
                "file is ${bytes.size}B, over the ${MAX_READ_BYTES}B whole-read limit",
                mapOf("uri" to path, "size" to bytes.size),
            )
        }

        val content = when (encoding) {
            "base64" -> Base64.encodeToString(bytes, Base64.NO_WRAP)
            "utf8" -> String(bytes, Charsets.UTF_8)
            else -> return result.error(
                ERR_INVALID_ARG,
                "encoding must be 'utf8' or 'base64' (got '$encoding')",
                null,
            )
        }
        result.success(
            mapOf("content" to content, "encoding" to encoding, "size" to bytes.size)
        )
    }

    private fun handleGetFileInfo(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: path", null)
        val info = queryFileInfo(Uri.parse(path))
            ?: return result.error(ERR_NOT_FOUND, "no document at uri", mapOf("uri" to path))
        result.success(info)
    }

    private fun handleExists(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error(ERR_INVALID_ARG, "missing arg: path", null)
        val exists = runCatching { queryFileInfo(Uri.parse(path)) != null }.getOrDefault(false)
        result.success(mapOf("exists" to exists))
    }

    // ===== Query helpers =====

    /** Single-document metadata query; null if the doc is gone / inaccessible. */
    private fun queryFileInfo(uri: Uri): Map<String, Any?>? {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val cursor = resolver.query(uri, projection, null, null, null) ?: return null
        cursor.use { c ->
            if (!c.moveToFirst()) return null
            val name = c.getString(0) ?: lastPathName(uri)
            val mime = if (c.isNull(1)) null else c.getString(1)
            val size = if (c.isNull(2)) 0L else c.getLong(2)
            val mtime = if (c.isNull(3)) 0L else c.getLong(3)
            return buildFileInfo(name, uri.toString(), mime, size, mtime)
        }
    }

    private fun querySelectedFileInfo(uri: Uri): Map<String, Any?>? {
        val base = queryFileInfo(uri) ?: return null
        val displayPath = friendlyPath(runCatching { DocumentsContract.getDocumentId(uri) }.getOrNull())
        return if (displayPath == null) base else base + ("displayPath" to displayPath)
    }

    private fun queryLong(uri: Uri, column: String): Long? {
        val cursor = resolver.query(uri, arrayOf(column), null, null, null) ?: return null
        cursor.use { c ->
            if (!c.moveToFirst() || c.isNull(0)) return null
            return c.getLong(0)
        }
    }

    private fun collectPickedUris(data: Intent): List<Uri> {
        val clip = data.clipData
        if (clip != null) {
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        }
        return listOfNotNull(data.data)
    }

    private fun buildFileInfo(
        name: String,
        uriString: String,
        mime: String?,
        size: Long,
        mtime: Long,
    ): Map<String, Any?> {
        val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR
        val map = HashMap<String, Any?>()
        map["name"] = name
        map["path"] = uriString
        map["uri"] = uriString
        map["size"] = if (isDir) 0L else size
        map["type"] = if (isDir) "directory" else "file"
        map["mtime"] = mtime
        map["isHidden"] = name.startsWith(".")
        if (mime != null) map["mimeType"] = mime
        return map
    }

    private fun sortFileInfo(items: MutableList<Map<String, Any?>>, sortBy: String, sortOrder: String) {
        val base: Comparator<Map<String, Any?>> = when (sortBy) {
            "size" -> compareBy { (it["size"] as? Number)?.toLong() ?: 0L }
            "mtime" -> compareBy { (it["mtime"] as? Number)?.toLong() ?: 0L }
            "type" -> compareBy<Map<String, Any?>> { if (it["type"] == "directory") 0 else 1 }
                .thenBy { (it["name"] as? String)?.lowercase() ?: "" }
            else -> compareBy { (it["name"] as? String)?.lowercase() ?: "" }
        }
        val cmp = if (sortOrder == "desc") base.reversed() else base
        items.sortWith(cmp)
    }

    /** Best-effort friendly path for display only (spec §2.2). Never an API input. */
    private fun friendlyPath(docId: String?): String? {
        if (docId.isNullOrEmpty()) return null
        val parts = docId.split(":", limit = 2)
        if (parts.size != 2) return null
        val (volume, rel) = parts
        return if (volume == "primary") "/storage/emulated/0/$rel" else "/storage/$volume/$rel"
    }

    private fun lastPathName(uri: Uri): String =
        uri.lastPathSegment?.substringAfterLast('/')?.substringAfterLast(':') ?: ""

    /** Whether persisted [treeUri] grants access to [target] (same tree). */
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

    // ===== Constants =====

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

        // Spec §3.3: whole-file read cap is 10 MB.
        const val MAX_READ_BYTES = 10L * 1024L * 1024L
    }
}
