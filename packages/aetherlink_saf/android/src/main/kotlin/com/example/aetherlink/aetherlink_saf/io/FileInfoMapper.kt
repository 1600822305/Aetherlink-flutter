package com.example.aetherlink.aetherlink_saf.io

import android.provider.DocumentsContract

/**
 * Builds and sorts the wire `FileInfo` maps (spec §2.1). The keys here are
 * load-bearing: the Dart `FileInfo.fromMap` decoder reads them verbatim, so
 * don't rename them.
 */
object FileInfoMapper {

    /** Columns every metadata query needs. */
    val PROJECTION = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
    )

    fun build(
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

    fun sort(items: MutableList<Map<String, Any?>>, sortBy: String, sortOrder: String) {
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
    fun friendlyPath(docId: String?): String? {
        if (docId.isNullOrEmpty()) return null
        val parts = docId.split(":", limit = 2)
        if (parts.size != 2) return null
        val (volume, rel) = parts
        return if (volume == "primary") "/storage/emulated/0/$rel" else "/storage/$volume/$rel"
    }
}
