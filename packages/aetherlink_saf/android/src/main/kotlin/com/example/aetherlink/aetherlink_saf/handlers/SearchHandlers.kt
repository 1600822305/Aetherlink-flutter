package com.example.aetherlink.aetherlink_saf.handlers

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import com.example.aetherlink.aetherlink_saf.core.opt
import com.example.aetherlink.aetherlink_saf.core.req
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.plugin.common.MethodCall

/**
 * P2 search + "open in system app" methods.
 *
 * SAF has no native search, so [searchFiles] walks the children-URI tree
 * itself (depth-first), honouring the spec §3.4 rule of never using
 * `DocumentFile.listFiles()`.
 */
class SearchHandlers(
    private val appContext: Context,
    private val activityProvider: () -> Activity?,
    private val repo: DocumentRepository,
) {

    fun searchFiles(call: MethodCall): Any {
        val directory: String = call.req("directory")
        val query: String = call.req("query")
        val searchType = call.opt("searchType", "name")
        val fileTypes = call.argument<List<String>>("fileTypes").orEmpty()
            .map { it.removePrefix(".").lowercase() }
        val maxResults = call.opt<Number>("maxResults", 200).toInt()
        val recursive = call.opt("recursive", true)

        val needle = query.lowercase()
        val matches = ArrayList<Map<String, Any?>>()
        val stack = ArrayDeque<Uri>()
        stack.addLast(Uri.parse(directory))

        while (stack.isNotEmpty() && matches.size < maxResults) {
            val dir = stack.removeLast()
            val children = runCatching {
                repo.listChildren(dir, showHidden = false, sortBy = "name", sortOrder = "asc")
            }.getOrNull() ?: continue
            for (child in children) {
                if (matches.size >= maxResults) break
                val isDir = child["type"] == "directory"
                if (isDir) {
                    if (recursive) stack.addLast(Uri.parse(child["uri"] as String))
                    continue
                }
                val name = child["name"] as? String ?: continue
                if (fileTypes.isNotEmpty() &&
                    name.substringAfterLast('.', "").lowercase() !in fileTypes
                ) {
                    continue
                }
                if (matchesEntry(child, name, needle, searchType)) matches.add(child)
            }
        }
        return mapOf("files" to matches, "totalFound" to matches.size)
    }

    private fun matchesEntry(
        child: Map<String, Any?>,
        name: String,
        needle: String,
        searchType: String,
    ): Boolean {
        val byName = name.lowercase().contains(needle)
        return when (searchType) {
            "name" -> byName
            "content" -> contentContains(child, needle)
            "both" -> byName || contentContains(child, needle)
            else -> byName
        }
    }

    private fun contentContains(child: Map<String, Any?>, needle: String): Boolean {
        val size = (child["size"] as? Number)?.toLong() ?: 0L
        if (size > CONTENT_SEARCH_MAX_BYTES) return false
        val uri = Uri.parse(child["uri"] as String)
        val text = runCatching { String(repo.readBytes(uri), Charsets.UTF_8) }.getOrNull() ?: return false
        return text.lowercase().contains(needle)
    }

    fun openSystemFileManager(call: MethodCall): Any? {
        val path = call.argument<String>("path")
        val intent = Intent(Intent.ACTION_VIEW).apply {
            if (path != null) {
                setDataAndType(Uri.parse(path), DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                type = DocumentsContract.Document.MIME_TYPE_DIR
            }
        }
        launch(intent, "no app available to open the file manager")
        return null
    }

    fun openFileWithSystemApp(call: MethodCall): Any? {
        val path: String = call.req("path")
        val uri = Uri.parse(path)
        val mimeType = call.argument<String>("mimeType") ?: repo.queryMime(uri) ?: "*/*"
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        launch(intent, "no app available to open this file")
        return null
    }

    private fun launch(intent: Intent, notFoundMessage: String) {
        val activity = activityProvider()
        try {
            if (activity != null) {
                activity.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                appContext.startActivity(intent)
            }
        } catch (e: ActivityNotFoundException) {
            throw SafException(SafError.NOT_SUPPORTED, notFoundMessage, null, e)
        }
    }

    private companion object {
        const val CONTENT_SEARCH_MAX_BYTES = 2L * 1024L * 1024L
    }
}
