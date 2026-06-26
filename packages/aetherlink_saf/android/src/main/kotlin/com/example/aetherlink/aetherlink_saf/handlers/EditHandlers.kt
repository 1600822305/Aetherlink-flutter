package com.example.aetherlink.aetherlink_saf.handlers

import android.net.Uri
import com.example.aetherlink.aetherlink_saf.core.DiffApplier
import com.example.aetherlink.aetherlink_saf.core.DiffException
import com.example.aetherlink.aetherlink_saf.core.DiffFailure
import com.example.aetherlink.aetherlink_saf.core.LineText
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import com.example.aetherlink.aetherlink_saf.core.opt
import com.example.aetherlink.aetherlink_saf.core.req
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.plugin.common.MethodCall

/**
 * P2 in-place editing: line insert, find/replace, and diff application. All the
 * actual transformation lives in the pure [LineText] / [DiffApplier] cores; this
 * layer only does read → transform → write and result mapping.
 */
class EditHandlers(private val repo: DocumentRepository) {

    fun insertContent(call: MethodCall): Any? {
        val path: String = call.req("path")
        val line = (call.req<Number>("line")).toInt()
        val content: String = call.req("content")
        val uri = Uri.parse(path)
        val updated = LineText.insertBefore(repo.readText(uri), line, content)
        repo.writeBytes(uri, updated.toByteArray(Charsets.UTF_8), append = false)
        return null
    }

    fun replaceInFile(call: MethodCall): Any {
        val path: String = call.req("path")
        val search: String = call.req("search")
        val replace: String = call.req("replace")
        val isRegex = call.opt("isRegex", false)
        val replaceAll = call.opt("replaceAll", true)
        val caseSensitive = call.opt("caseSensitive", true)
        val uri = Uri.parse(path)
        val outcome = LineText.replace(
            text = repo.readText(uri),
            search = search,
            replace = replace,
            isRegex = isRegex,
            replaceAll = replaceAll,
            caseSensitive = caseSensitive,
        )
        if (outcome.modified) {
            repo.writeBytes(uri, outcome.text.toByteArray(Charsets.UTF_8), append = false)
        }
        return mapOf("replacements" to outcome.replacements, "modified" to outcome.modified)
    }

    fun applyDiff(call: MethodCall): Any {
        val path: String = call.req("path")
        val diff: String = call.req("diff")
        val format = call.opt("format", "search-replace")
        val createBackup = call.opt("createBackup", false)
        val expectedRangeHash = call.argument<String>("expectedRangeHash")
        val uri = Uri.parse(path)

        val original = repo.readText(uri)
        if (expectedRangeHash != null) {
            val actual = LineText.sha256Hex(original.toByteArray(Charsets.UTF_8))
            if (!actual.equals(expectedRangeHash, ignoreCase = true)) {
                throw SafException(
                    SafError.RANGE_CONFLICT,
                    "file changed since it was read (expectedRangeHash mismatch)",
                    mapOf("uri" to path, "expected" to expectedRangeHash, "actual" to actual),
                )
            }
        }

        val outcome = try {
            DiffApplier.apply(original, diff, format)
        } catch (e: DiffException) {
            throw when (e.failure) {
                DiffFailure.SEARCH_NOT_FOUND, DiffFailure.CONTEXT_MISMATCH ->
                    SafException(SafError.RANGE_CONFLICT, e.message ?: "diff did not apply", mapOf("uri" to path), e)
                DiffFailure.INVALID_FORMAT ->
                    SafException(SafError.INVALID_ARG, e.message ?: "invalid diff", mapOf("uri" to path), e)
            }
        }

        var backupPath: String? = null
        if (createBackup) backupPath = writeBackup(uri, original)

        repo.writeBytes(uri, outcome.text.toByteArray(Charsets.UTF_8), append = false)
        return buildMap {
            put("success", true)
            put("linesChanged", outcome.linesChanged)
            put("linesAdded", outcome.linesAdded)
            put("linesDeleted", outcome.linesDeleted)
            if (backupPath != null) put("backupPath", backupPath)
        }
    }

    private fun writeBackup(uri: Uri, original: String): String {
        val parent = repo.parentOf(uri)
            ?: throw SafException(
                SafError.NOT_SUPPORTED,
                "cannot derive parent directory for backup on this provider",
                mapOf("uri" to uri.toString()),
            )
        val name = repo.queryFileInfo(uri)?.get("name") as? String ?: "file"
        val backupName = "$name.bak.${System.currentTimeMillis()}"
        val backup = repo.createDocument(parent, "application/octet-stream", backupName)
        repo.writeBytes(backup, original.toByteArray(Charsets.UTF_8), append = false)
        return backup.toString()
    }
}
