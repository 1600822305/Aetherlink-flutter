package com.example.aetherlink_flutter

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * 内置浏览器下载落到系统公共「下载/AetherLink」目录，其它应用和文件管理器
 * 都能看到。Android 10+ 走 MediaStore.Downloads（无需存储权限）；
 * Android 9 及以下写公共目录（需 WRITE_EXTERNAL_STORAGE，Dart 侧申请）。
 */
class PublicDownloads(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "aetherlink/downloads"
        private const val SUB_DIR = "AetherLink"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "save" -> save(
                call.argument<String>("source"),
                call.argument<String>("name"),
                call.argument<String>("mime"),
                result,
            )
            "open" -> open(call.argument<String>("uri"), call.argument<String>("mime"), result)
            "delete" -> delete(call.argument<String>("uri"), result)
            else -> result.notImplemented()
        }
    }

    private fun mimeOf(name: String, mime: String?): String {
        if (!mime.isNullOrBlank() && mime != "application/octet-stream") return mime
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }

    private fun save(source: String?, name: String?, mime: String?, result: MethodChannel.Result) {
        if (source.isNullOrBlank() || name.isNullOrBlank()) {
            result.error("bad-args", "source and name are required", null)
            return
        }
        val src = File(source)
        if (!src.exists()) {
            result.error("missing-source", "downloaded file not found", null)
            return
        }
        val type = mimeOf(name, mime)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("permission-required", "WRITE_EXTERNAL_STORAGE not granted", null)
            return
        }
        Thread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val saved = saveWithMediaStore(src, name, type)
                    activity.runOnUiThread { result.success(saved) }
                } else {
                    saveLegacy(src, name, type, result)
                }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("save-failed", e.message, null) }
            }
        }.start()
    }

    private fun saveWithMediaStore(src: File, name: String, type: String): Map<String, Any?> {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, type)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$SUB_DIR")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore insert failed")
        try {
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { it.copyTo(out) }
            } ?: throw IllegalStateException("cannot open output stream")
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // 同名时系统会自动改名（如 a (1).pdf），回读实际文件名。
        var finalName = name
        resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) finalName = c.getString(0) ?: name }
        return mapOf(
            "uri" to uri.toString(),
            "name" to finalName,
            "path" to "${Environment.DIRECTORY_DOWNLOADS}/$SUB_DIR/$finalName",
            "mime" to type,
        )
    }

    private fun saveLegacy(src: File, name: String, type: String, result: MethodChannel.Result) {
        @Suppress("DEPRECATION")
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            SUB_DIR,
        )
        dir.mkdirs()
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var target = File(dir, name)
        var n = 1
        while (target.exists()) {
            target = File(dir, "$stem ($n)$ext")
            n++
        }
        src.copyTo(target)
        MediaScannerConnection.scanFile(
            activity,
            arrayOf(target.absolutePath),
            arrayOf(type),
        ) { _, uri ->
            activity.runOnUiThread {
                result.success(
                    mapOf(
                        "uri" to (uri ?: Uri.fromFile(target)).toString(),
                        "name" to target.name,
                        "path" to target.absolutePath,
                        "mime" to type,
                    ),
                )
            }
        }
    }

    private fun open(uri: String?, mime: String?, result: MethodChannel.Result) {
        if (uri.isNullOrBlank()) {
            result.error("bad-args", "uri is required", null)
            return
        }
        val parsed = Uri.parse(uri)
        val type = mime ?: activity.contentResolver.getType(parsed) ?: "*/*"
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(parsed, type)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            activity.startActivity(Intent.createChooser(view, null))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("no-app", "没有能打开该文件的应用", null)
        } catch (e: Exception) {
            result.error("open-failed", e.message, null)
        }
    }

    private fun delete(uri: String?, result: MethodChannel.Result) {
        if (uri.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val parsed = Uri.parse(uri)
            val ok = if (parsed.scheme == "file") {
                File(parsed.path ?: "").delete()
            } else {
                activity.contentResolver.delete(parsed, null, null) > 0
            }
            result.success(ok)
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
