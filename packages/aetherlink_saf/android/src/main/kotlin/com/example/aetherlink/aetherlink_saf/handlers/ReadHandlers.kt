package com.example.aetherlink.aetherlink_saf.handlers

import android.net.Uri
import android.provider.DocumentsContract
import android.util.Base64
import com.example.aetherlink.aetherlink_saf.core.LineText
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import com.example.aetherlink.aetherlink_saf.core.opt
import com.example.aetherlink.aetherlink_saf.core.req
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.plugin.common.MethodCall
import java.io.FileNotFoundException
import java.nio.ByteBuffer

/**
 * Read-side methods (P0 reads + P1 advanced reads). Each handler returns the
 * wire map/value; the dispatcher calls `result.success(...)` and maps thrown
 * exceptions to spec error codes.
 */
class ReadHandlers(private val repo: DocumentRepository) {

    fun listDirectory(call: MethodCall): Any {
        val path: String = call.req("path")
        val showHidden = call.opt("showHidden", false)
        val sortBy = call.opt("sortBy", "name")
        val sortOrder = call.opt("sortOrder", "asc")
        val items = repo.listChildren(Uri.parse(path), showHidden, sortBy, sortOrder)
        return mapOf("files" to items, "totalCount" to items.size)
    }

    /**
     * One-call recursive listing (depth-first pre-order, directories first
     * within each level), so the Dart side doesn't pay one channel round-trip
     * per directory level. Directories named in `skipDirs` are listed but not
     * descended into; the walk stops once `maxEntries` entries are collected.
     */
    fun listRecursive(call: MethodCall): Any {
        val directory: String = call.req("directory")
        val maxDepth = call.opt<Number>("maxDepth", 3).toInt()
        val skipDirs = call.argument<List<String>>("skipDirs").orEmpty().toHashSet()
        val maxEntries = call.opt<Number>("maxEntries", 2000).toInt()

        val out = ArrayList<Map<String, Any?>>()
        var truncated = false

        fun walk(dir: Uri, depth: Int) {
            if (truncated) return
            // Root errors (revoked grant, not a directory) must surface;
            // unreadable subdirectories are skipped like the search walk.
            val children = if (depth == 1) {
                repo.listChildren(dir, showHidden = false, sortBy = "name", sortOrder = "asc")
            } else {
                runCatching {
                    repo.listChildren(dir, showHidden = false, sortBy = "name", sortOrder = "asc")
                }.getOrNull() ?: return
            }
            val ordered = children.sortedBy { if (it["type"] == "directory") 0 else 1 }
            for (child in ordered) {
                if (out.size >= maxEntries) {
                    truncated = true
                    return
                }
                out.add(child)
                val name = child["name"] as? String ?: continue
                if (child["type"] == "directory" && depth < maxDepth && name !in skipDirs) {
                    walk(Uri.parse(child["uri"] as String), depth + 1)
                }
            }
        }

        walk(Uri.parse(directory), 1)
        return mapOf("files" to out, "truncated" to truncated)
    }

    fun readFile(call: MethodCall): Any {
        val path: String = call.req("path")
        val encoding = call.opt("encoding", "utf8")
        val uri = Uri.parse(path)

        val declaredSize = repo.queryLong(uri, DocumentsContract.Document.COLUMN_SIZE)
        if (declaredSize != null && declaredSize > MAX_READ_BYTES) {
            throw tooLarge(path, declaredSize)
        }
        val bytes = repo.readBytes(uri)
        if (bytes.size > MAX_READ_BYTES) throw tooLarge(path, bytes.size.toLong())

        val content = when (encoding) {
            "base64" -> Base64.encodeToString(bytes, Base64.NO_WRAP)
            "utf8" -> String(bytes, Charsets.UTF_8)
            else -> throw IllegalArgumentException(
                "encoding must be 'utf8' or 'base64' (got '$encoding')",
            )
        }
        return mapOf("content" to content, "encoding" to encoding, "size" to bytes.size)
    }

    fun getFileInfo(call: MethodCall): Any {
        val path: String = call.req("path")
        return repo.queryFileInfo(Uri.parse(path))
            ?: throw FileNotFoundException("no document at uri: $path")
    }

    fun exists(call: MethodCall): Any {
        val path: String = call.req("path")
        return mapOf("exists" to repo.exists(Uri.parse(path)))
    }

    // ===== P1 advanced reads =====

    fun readFileRange(call: MethodCall): Any {
        val path: String = call.req("path")
        val startLine: Int = (call.req<Number>("startLine")).toInt()
        val endLine: Int = (call.req<Number>("endLine")).toInt()
        val text = repo.readText(Uri.parse(path))
        val slice = LineText.sliceLines(text, startLine, endLine)
        return mapOf(
            "content" to slice.content,
            "totalLines" to slice.totalLines,
            "startLine" to slice.startLine,
            "endLine" to slice.endLine,
            "rangeHash" to LineText.sha256Hex(slice.content.toByteArray(Charsets.UTF_8)),
        )
    }

    fun readFileBytes(call: MethodCall): Any {
        val path: String = call.req("path")
        val offset = (call.argument<Number>("offset")?.toLong()) ?: 0L
        val length = call.argument<Number>("length")?.toLong()
        require(offset >= 0) { "offset must be >= 0" }
        require(length == null || length >= 0) { "length must be >= 0" }
        val bytes = repo.readBytesRange(Uri.parse(path), offset, length)
        // Flutter decodes a Kotlin ByteArray as Uint8List / ByteData on the Dart side.
        return mapOf("bytes" to ByteBuffer.wrap(bytes).array())
    }

    fun getLineCount(call: MethodCall): Any {
        val path: String = call.req("path")
        val text = repo.readText(Uri.parse(path))
        return mapOf("lines" to LineText.lineCount(text))
    }

    fun getFileHash(call: MethodCall): Any {
        val path: String = call.req("path")
        val algorithm = call.opt("algorithm", "sha256")
        val jca = when (algorithm) {
            "md5" -> "MD5"
            "sha256" -> "SHA-256"
            else -> throw IllegalArgumentException(
                "algorithm must be 'md5' or 'sha256' (got '$algorithm')",
            )
        }
        val hash = LineText.digestHex(repo.readBytes(Uri.parse(path)), jca)
        return mapOf("hash" to hash, "algorithm" to algorithm)
    }

    private fun tooLarge(path: String, size: Long) = SafException(
        SafError.TOO_LARGE,
        "file is ${size}B, over the ${MAX_READ_BYTES}B whole-read limit",
        mapOf("uri" to path, "size" to size),
    )

    private companion object {
        // Spec §3.3: whole-file read cap is 10 MB.
        const val MAX_READ_BYTES = 10L * 1024L * 1024L
    }
}
