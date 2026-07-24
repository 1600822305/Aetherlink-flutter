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
import java.io.BufferedReader
import java.io.InputStreamReader

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
        val useRegex = call.opt("useRegex", false)
        val skipDirs = call.argument<List<String>>("skipDirs").orEmpty().toHashSet()
        val maxMatchesPerFile = call.opt<Number>("maxMatchesPerFile", 5).toInt()

        val needle = query.lowercase()
        // When useRegex is set, compile once (case-insensitive, mirroring the
        // substring path's behaviour). Invalid patterns fail fast.
        val regex: Regex? = if (useRegex) {
            try {
                Regex(query, RegexOption.IGNORE_CASE)
            } catch (e: Exception) {
                throw SafException(
                    SafError.INVALID_ARG,
                    "invalid regular expression: ${e.message}",
                    mapOf("query" to query),
                    e,
                )
            }
        } else {
            null
        }

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
                val name = child["name"] as? String ?: continue
                val isDir = child["type"] == "directory"
                if (isDir) {
                    if (recursive && name !in skipDirs) {
                        stack.addLast(Uri.parse(child["uri"] as String))
                    }
                    continue
                }
                if (fileTypes.isNotEmpty() &&
                    name.substringAfterLast('.', "").lowercase() !in fileTypes
                ) {
                    continue
                }
                val byName = if (regex != null) {
                    regex.containsMatchIn(name)
                } else {
                    name.lowercase().contains(needle)
                }
                when (searchType) {
                    "content", "both" -> {
                        val scan = scanContent(child, needle, regex, maxMatchesPerFile)
                        val byContent = (scan?.matchCount ?: 0) > 0
                        if ((searchType == "both" && byName) || byContent) {
                            matches.add(
                                if (scan == null) child
                                else child + mapOf(
                                    "matchCount" to scan.matchCount,
                                    "matches" to scan.lines,
                                ),
                            )
                        }
                    }
                    else -> if (byName) matches.add(child)
                }
            }
        }
        return mapOf("files" to matches, "totalFound" to matches.size)
    }

    private class ContentScan(val matchCount: Int, val lines: List<Map<String, Any?>>)

    /**
     * Streams the file line-by-line collecting up to [maxLines] matching lines
     * plus the total matching-line count. Null when the file couldn't be
     * scanned as text (oversized / unreadable), so the caller can tell "not
     * scanned" apart from "scanned with zero hits".
     */
    private fun scanContent(
        child: Map<String, Any?>,
        needle: String,
        regex: Regex?,
        maxLines: Int,
    ): ContentScan? {
        val size = (child["size"] as? Number)?.toLong() ?: 0L
        if (size > CONTENT_SEARCH_MAX_BYTES) return null
        val uri = Uri.parse(child["uri"] as String)
        return runCatching {
            BufferedReader(InputStreamReader(repo.openInput(uri), Charsets.UTF_8)).use { reader ->
                var count = 0
                var lineNumber = 0
                val lines = ArrayList<Map<String, Any?>>()
                while (true) {
                    val line = reader.readLine() ?: break
                    lineNumber++
                    val hit = if (regex != null) {
                        regex.containsMatchIn(line)
                    } else {
                        line.lowercase().contains(needle)
                    }
                    if (!hit) continue
                    count++
                    if (lines.size < maxLines) {
                        lines.add(mapOf("lineNumber" to lineNumber, "line" to line))
                    }
                }
                ContentScan(count, lines)
            }
        }.getOrNull()
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
