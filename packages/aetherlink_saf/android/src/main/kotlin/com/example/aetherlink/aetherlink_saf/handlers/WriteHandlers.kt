package com.example.aetherlink.aetherlink_saf.handlers

import android.net.Uri
import android.util.Base64
import com.example.aetherlink.aetherlink_saf.core.SafError
import com.example.aetherlink.aetherlink_saf.core.SafException
import com.example.aetherlink.aetherlink_saf.core.opt
import com.example.aetherlink.aetherlink_saf.core.req
import com.example.aetherlink.aetherlink_saf.io.DocumentRepository
import io.flutter.plugin.common.MethodCall

/** P1 write/structure methods: create, write, delete, rename, move, copy. */
class WriteHandlers(private val repo: DocumentRepository) {

    fun writeFile(call: MethodCall): Any? {
        val path: String = call.req("path")
        val content: String = call.req("content")
        val encoding = call.opt("encoding", "utf8")
        val append = call.opt("append", false)
        repo.writeBytes(Uri.parse(path), decode(content, encoding), append)
        return null
    }

    fun createFile(call: MethodCall): Any {
        val parentPath: String = call.req("parentPath")
        val name: String = call.req("name")
        val content = call.argument<String>("content")
        val encoding = call.opt("encoding", "utf8")
        val mimeType = call.opt("mimeType", "application/octet-stream")
        val uri = repo.createDocument(Uri.parse(parentPath), mimeType, name)
        if (content != null) repo.writeBytes(uri, decode(content, encoding), append = false)
        return mapOf("path" to uri.toString())
    }

    fun createDirectory(call: MethodCall): Any {
        val parentPath: String = call.req("parentPath")
        val name: String = call.req("name")
        val recursive = call.opt("recursive", false)
        val parent = Uri.parse(parentPath)
        // SAF names are single segments. When recursive, reuse an existing dir
        // of the same name rather than letting the provider create "name (1)".
        if (recursive) {
            repo.findChild(parent, name)?.let { existing ->
                if (repo.isDirectory(existing)) return mapOf("path" to existing.toString())
            }
        }
        val uri = repo.createDirectory(parent, name)
        return mapOf("path" to uri.toString())
    }

    fun deleteFile(call: MethodCall): Any? {
        val path: String = call.req("path")
        repo.delete(Uri.parse(path))
        return null
    }

    fun deleteDirectory(call: MethodCall): Any? {
        val path: String = call.req("path")
        val recursive = call.opt("recursive", false)
        val uri = Uri.parse(path)
        if (!recursive) {
            val children = repo.listChildren(uri, showHidden = true, sortBy = "name", sortOrder = "asc")
            if (children.isNotEmpty()) {
                throw SafException(
                    SafError.IO,
                    "directory is not empty; pass recursive=true to delete its contents",
                    mapOf("uri" to path, "childCount" to children.size),
                )
            }
        }
        repo.delete(uri)
        return null
    }

    fun renameFile(call: MethodCall): Any {
        val path: String = call.req("path")
        val newName: String = call.req("newName")
        val uri = repo.rename(Uri.parse(path), newName)
        return mapOf("path" to uri.toString())
    }

    fun moveFile(call: MethodCall): Any {
        val sourcePath: String = call.req("sourcePath")
        val destinationParent: String = call.req("destinationParent")
        val uri = repo.move(Uri.parse(sourcePath), Uri.parse(destinationParent))
        return mapOf("path" to uri.toString())
    }

    fun copyFile(call: MethodCall): Any {
        val sourcePath: String = call.req("sourcePath")
        val destinationParent: String = call.req("destinationParent")
        val newName = call.argument<String>("newName")
        val overwrite = call.opt("overwrite", false)
        val uri = repo.copy(Uri.parse(sourcePath), Uri.parse(destinationParent), newName, overwrite)
        return mapOf("path" to uri.toString())
    }

    private fun decode(content: String, encoding: String): ByteArray = when (encoding) {
        "utf8" -> content.toByteArray(Charsets.UTF_8)
        "base64" -> Base64.decode(content, Base64.DEFAULT)
        else -> throw IllegalArgumentException(
            "encoding must be 'utf8' or 'base64' (got '$encoding')",
        )
    }
}
