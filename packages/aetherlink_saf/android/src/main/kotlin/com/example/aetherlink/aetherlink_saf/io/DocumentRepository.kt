package com.example.aetherlink.aetherlink_saf.io

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException

/**
 * The single SAF gateway: every `ContentResolver` / `DocumentsContract` call
 * lives here. Handlers stay free of Android storage details and only deal in
 * URIs, bytes and wire maps. Failures surface as [SafException] with the right
 * spec error code.
 */
class DocumentRepository(private val resolver: ContentResolver) {

    // ===== queries =====

    /** Single-document metadata as a wire `FileInfo`; null if gone/inaccessible. */
    fun queryFileInfo(uri: Uri): Map<String, Any?>? {
        val cursor = resolver.query(uri, FileInfoMapper.PROJECTION, null, null, null) ?: return null
        cursor.use { c ->
            if (!c.moveToFirst()) return null
            val nameIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val mtimeIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val name = c.getString(nameIdx) ?: lastPathName(uri)
            val mime = if (mimeIdx < 0 || c.isNull(mimeIdx)) null else c.getString(mimeIdx)
            val size = if (sizeIdx < 0 || c.isNull(sizeIdx)) 0L else c.getLong(sizeIdx)
            val mtime = if (mtimeIdx < 0 || c.isNull(mtimeIdx)) 0L else c.getLong(mtimeIdx)
            return FileInfoMapper.build(name, uri.toString(), mime, size, mtime)
        }
    }

    /** [queryFileInfo] plus the display-only `displayPath` (spec §2.2). */
    fun querySelectedFileInfo(uri: Uri): Map<String, Any?>? {
        val base = queryFileInfo(uri) ?: return null
        val displayPath = FileInfoMapper.friendlyPath(
            runCatching { DocumentsContract.getDocumentId(uri) }.getOrNull(),
        )
        return if (displayPath == null) base else base + ("displayPath" to displayPath)
    }

    fun queryLong(uri: Uri, column: String): Long? {
        val cursor = resolver.query(uri, arrayOf(column), null, null, null) ?: return null
        cursor.use { c ->
            if (!c.moveToFirst() || c.isNull(0)) return null
            return c.getLong(0)
        }
    }

    fun queryMime(uri: Uri): String? =
        queryFileInfo(uri)?.get("mimeType") as? String

    fun exists(uri: Uri): Boolean =
        runCatching { queryFileInfo(uri) != null }.getOrDefault(false)

    fun isDirectory(uri: Uri): Boolean =
        queryFileInfo(uri)?.get("type") == "directory"

    /** Children of a directory, built via the children-URI (spec §3.4: never `listFiles()`). */
    fun listChildren(
        parentUri: Uri,
        showHidden: Boolean,
        sortBy: String,
        sortOrder: String,
    ): List<Map<String, Any?>> {
        val childrenUri = childrenUriOf(parentUri)
        val items = ArrayList<Map<String, Any?>>()
        val cursor = resolver.query(childrenUri, FileInfoMapper.PROJECTION, null, null, null)
            ?: throw SafException(
                SafError.URI_STALE,
                "directory query returned null",
                mapOf("uri" to parentUri.toString()),
            )
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
                    FileInfoMapper.build(
                        name = name,
                        uriString = childUri.toString(),
                        mime = if (c.isNull(mimeIdx)) null else c.getString(mimeIdx),
                        size = if (c.isNull(sizeIdx)) 0L else c.getLong(sizeIdx),
                        mtime = if (c.isNull(mtimeIdx)) 0L else c.getLong(mtimeIdx),
                    ),
                )
            }
        }
        FileInfoMapper.sort(items, sortBy, sortOrder)
        return items
    }

    /** First child of [parentUri] whose display name equals [name]; null if none. */
    fun findChild(parentUri: Uri, name: String): Uri? {
        val childrenUri = childrenUriOf(parentUri)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )
        val cursor = resolver.query(childrenUri, projection, null, null, null) ?: return null
        cursor.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) {
                    return DocumentsContract.buildDocumentUriUsingTree(parentUri, c.getString(0))
                }
            }
        }
        return null
    }

    // ===== reads =====

    fun readBytes(uri: Uri): ByteArray =
        resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw SafException(SafError.NOT_FOUND, "cannot open input stream", mapOf("uri" to uri.toString()))

    /** Bytes `[offset, offset+length)`; `length=null` reads to EOF. */
    fun readBytesRange(uri: Uri, offset: Long, length: Long?): ByteArray {
        val stream = resolver.openInputStream(uri)
            ?: throw SafException(SafError.NOT_FOUND, "cannot open input stream", mapOf("uri" to uri.toString()))
        stream.use { input ->
            var toSkip = offset
            while (toSkip > 0) {
                val skipped = input.skip(toSkip)
                if (skipped <= 0) break
                toSkip -= skipped
            }
            if (length == null) return input.readBytes()
            val out = ByteArrayOutputStream()
            val buf = ByteArray(64 * 1024)
            var remaining = length
            while (remaining > 0) {
                val want = if (remaining < buf.size) remaining.toInt() else buf.size
                val read = input.read(buf, 0, want)
                if (read < 0) break
                out.write(buf, 0, read)
                remaining -= read
            }
            return out.toByteArray()
        }
    }

    /** Whole-file text for line operations; capped at [MAX_TEXT_BYTES]. */
    fun readText(uri: Uri): String {
        val declared = queryLong(uri, DocumentsContract.Document.COLUMN_SIZE)
        if (declared != null && declared > MAX_TEXT_BYTES) {
            throw SafException(
                SafError.TOO_LARGE,
                "file is ${declared}B, over the ${MAX_TEXT_BYTES}B text-edit limit",
                mapOf("uri" to uri.toString(), "size" to declared),
            )
        }
        val bytes = readBytes(uri)
        if (bytes.size > MAX_TEXT_BYTES) {
            throw SafException(
                SafError.TOO_LARGE,
                "file is ${bytes.size}B, over the ${MAX_TEXT_BYTES}B text-edit limit",
                mapOf("uri" to uri.toString(), "size" to bytes.size),
            )
        }
        return String(bytes, Charsets.UTF_8)
    }

    // ===== writes =====

    fun writeBytes(uri: Uri, bytes: ByteArray, append: Boolean) {
        val mode = if (append) "wa" else "rwt"
        val stream = resolver.openOutputStream(uri, mode)
            ?: throw SafException(SafError.NOT_FOUND, "cannot open output stream", mapOf("uri" to uri.toString()))
        stream.use { it.write(bytes) }
    }

    fun createDocument(parentUri: Uri, mimeType: String, name: String): Uri =
        DocumentsContract.createDocument(resolver, parentUri, mimeType, name)
            ?: throw SafException(
                SafError.IO,
                "createDocument returned null",
                mapOf("parent" to parentUri.toString(), "name" to name),
            )

    fun createDirectory(parentUri: Uri, name: String): Uri =
        createDocument(parentUri, DocumentsContract.Document.MIME_TYPE_DIR, name)

    fun delete(uri: Uri) {
        val ok = DocumentsContract.deleteDocument(resolver, uri)
        if (!ok) throw SafException(SafError.IO, "deleteDocument failed", mapOf("uri" to uri.toString()))
    }

    fun rename(uri: Uri, newName: String): Uri =
        DocumentsContract.renameDocument(resolver, uri, newName)
            ?: throw SafException(SafError.IO, "renameDocument failed", mapOf("uri" to uri.toString()))

    /** Copy [sourceUri] under [destParentUri] (recursively for directories). */
    fun copy(sourceUri: Uri, destParentUri: Uri, newName: String?, overwrite: Boolean): Uri {
        val info = queryFileInfo(sourceUri)
            ?: throw SafException(SafError.NOT_FOUND, "source not found", mapOf("uri" to sourceUri.toString()))
        val name = newName ?: (info["name"] as? String ?: lastPathName(sourceUri))
        val isDir = info["type"] == "directory"

        findChild(destParentUri, name)?.let { existing ->
            if (overwrite) delete(existing)
            else throw SafException(
                SafError.IO,
                "destination already has an entry named '$name'",
                mapOf("parent" to destParentUri.toString(), "name" to name),
            )
        }

        if (isDir) {
            val newDir = createDirectory(destParentUri, name)
            for (child in listChildren(sourceUri, showHidden = true, sortBy = "name", sortOrder = "asc")) {
                val childUri = Uri.parse(child["uri"] as String)
                copy(childUri, newDir, newName = null, overwrite = false)
            }
            return newDir
        }
        val mime = info["mimeType"] as? String ?: "application/octet-stream"
        val newFile = createDocument(destParentUri, mime, name)
        writeBytes(newFile, readBytes(sourceUri), append = false)
        return newFile
    }

    /**
     * Move = copy then delete. Works within and across trees, sidestepping the
     * cross-tree `moveDocument` limitation (spec §3.4).
     */
    fun move(sourceUri: Uri, destParentUri: Uri): Uri {
        val copied = copy(sourceUri, destParentUri, newName = null, overwrite = false)
        try {
            delete(sourceUri)
        } catch (e: Exception) {
            runCatching { delete(copied) }
            throw SafException(
                SafError.IO,
                "moved copy created but source delete failed; rolled back",
                mapOf("uri" to sourceUri.toString()),
                e,
            )
        }
        return copied
    }

    // ===== helpers =====

    fun childrenUriOf(parentUri: Uri): Uri {
        val parentDocId = try {
            DocumentsContract.getDocumentId(parentUri)
        } catch (e: IllegalArgumentException) {
            throw SafException(
                SafError.INVALID_ARG,
                "path is not a document-in-tree URI: $parentUri",
                mapOf("uri" to parentUri.toString()),
                e,
            )
        }
        return DocumentsContract.buildChildDocumentsUriUsingTree(parentUri, parentDocId)
    }

    /**
     * Best-effort immediate parent of [uri], derived from its document id
     * (`primary:a/b/c` → `primary:a/b`). SAF has no generic "parent of"
     * operation, so this relies on the path-shaped doc ids that
     * ExternalStorageProvider uses; returns null when it can't be derived.
     */
    fun parentOf(uri: Uri): Uri? {
        val docId = runCatching { DocumentsContract.getDocumentId(uri) }.getOrNull() ?: return null
        val colon = docId.indexOf(':')
        if (colon < 0) return null
        val volume = docId.substring(0, colon)
        val rel = docId.substring(colon + 1)
        val slash = rel.lastIndexOf('/')
        if (slash < 0) return null
        val parentDocId = "$volume:${rel.substring(0, slash)}"
        return runCatching {
            DocumentsContract.buildDocumentUriUsingTree(uri, parentDocId)
        }.getOrNull()
    }

    fun requireExists(uri: Uri): Uri {
        if (!exists(uri)) {
            throw FileNotFoundException("no document at uri: $uri")
        }
        return uri
    }

    private fun lastPathName(uri: Uri): String =
        uri.lastPathSegment?.substringAfterLast('/')?.substringAfterLast(':') ?: ""

    companion object {
        /** Whole-file read cap for text/line operations. */
        const val MAX_TEXT_BYTES = 50L * 1024L * 1024L
    }
}
