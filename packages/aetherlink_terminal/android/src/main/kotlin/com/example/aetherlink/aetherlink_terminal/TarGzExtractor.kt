package com.example.aetherlink.aetherlink_terminal

import android.system.Os
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.zip.GZIPInputStream

/**
 * Minimal tar.gz extractor for Linux rootfs archives (Alpine minirootfs).
 *
 * The Dart `archive` package can't restore symlinks / exec permission bits,
 * which a rootfs is full of (busybox is one binary plus hundreds of links), so
 * extraction happens here with [Os.symlink] / [Os.link] / [Os.chmod].
 * Supports ustar + the GNU 'L' long-name extension and skips pax headers.
 */
object TarGzExtractor {

    fun extract(archivePath: String, destPath: String) {
        val dest = File(destPath)
        if (!dest.exists() && !dest.mkdirs()) {
            throw IOException("无法创建目录 $destPath")
        }
        GZIPInputStream(File(archivePath).inputStream().buffered()).use { input ->
            val header = ByteArray(512)
            var pendingLongName: String? = null
            while (true) {
                if (!readFully(input, header)) break
                if (header.all { it == 0.toByte() }) break // end-of-archive block

                val name = pendingLongName ?: parseName(header)
                pendingLongName = null
                val mode = parseOctal(header, 100, 8).toInt()
                val size = parseOctal(header, 124, 12)
                val type = header[156].toInt().toChar()
                val linkName = parseString(header, 157, 100)

                when (type) {
                    'L' -> pendingLongName = readContentAsString(input, size)
                    'x', 'g' -> skipContent(input, size) // pax headers
                    '5' -> {
                        val dir = resolve(dest, name)
                        if (!dir.exists() && !dir.mkdirs()) {
                            throw IOException("无法创建目录 ${dir.path}")
                        }
                        chmod(dir, mode)
                    }
                    '2' -> {
                        val file = resolve(dest, name)
                        file.parentFile?.mkdirs()
                        file.delete()
                        Os.symlink(linkName, file.path)
                    }
                    '1' -> {
                        val file = resolve(dest, name)
                        file.parentFile?.mkdirs()
                        file.delete()
                        Os.link(resolve(dest, linkName).path, file.path)
                    }
                    '0', '\u0000', '7' -> {
                        val file = resolve(dest, name)
                        file.parentFile?.mkdirs()
                        writeContent(input, file, size)
                        chmod(file, mode)
                    }
                    else -> skipContent(input, size) // char/block devices, fifos
                }
            }
        }
    }

    /** Joins [name] under [dest], refusing entries that escape it (`..`). */
    private fun resolve(dest: File, name: String): File {
        val file = File(dest, name)
        val canonicalDest = dest.canonicalPath
        // canonicalPath resolves existing symlinks; for the escape check the
        // normalized (lexical) path is what matters.
        val normalized = File(canonicalDest, name).normalize()
        if (!normalized.path.startsWith(canonicalDest + File.separator) &&
            normalized.path != canonicalDest
        ) {
            throw IOException("非法的归档条目路径：$name")
        }
        return file
    }

    private fun chmod(file: File, mode: Int) {
        try {
            Os.chmod(file.path, mode)
        } catch (_: Exception) {
            // Best effort — a rootfs entry we can't chmod is still usable.
        }
    }

    private fun writeContent(input: InputStream, file: File, size: Long) {
        file.outputStream().buffered().use { out ->
            var remaining = size
            val buffer = ByteArray(64 * 1024)
            while (remaining > 0) {
                val n = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (n < 0) throw IOException("归档内容不完整")
                out.write(buffer, 0, n)
                remaining -= n
            }
        }
        skipPadding(input, size)
    }

    private fun readContentAsString(input: InputStream, size: Long): String {
        val bytes = ByteArray(size.toInt())
        if (!readFully(input, bytes)) throw IOException("归档内容不完整")
        skipPadding(input, size)
        return String(bytes).trimEnd('\u0000')
    }

    private fun skipContent(input: InputStream, size: Long) =
        rawSkip(input, size + padding(size))

    private fun skipPadding(input: InputStream, size: Long) =
        rawSkip(input, padding(size))

    private fun rawSkip(input: InputStream, count: Long) {
        var remaining = count
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped <= 0) {
                if (input.read() < 0) throw IOException("归档内容不完整")
                remaining -= 1
            } else {
                remaining -= skipped
            }
        }
    }

    private fun padding(size: Long): Long = (512 - size % 512) % 512

    private fun readFully(input: InputStream, buffer: ByteArray): Boolean {
        var offset = 0
        while (offset < buffer.size) {
            val n = input.read(buffer, offset, buffer.size - offset)
            if (n < 0) {
                if (offset == 0) return false
                throw IOException("归档头不完整")
            }
            offset += n
        }
        return true
    }

    private fun parseName(header: ByteArray): String {
        val name = parseString(header, 0, 100)
        val prefix = parseString(header, 345, 155)
        return if (prefix.isEmpty()) name else "$prefix/$name"
    }

    private fun parseString(header: ByteArray, offset: Int, length: Int): String {
        var end = offset
        val max = offset + length
        while (end < max && header[end] != 0.toByte()) end++
        return String(header, offset, end - offset)
    }

    private fun parseOctal(header: ByteArray, offset: Int, length: Int): Long {
        var result = 0L
        for (i in offset until offset + length) {
            val c = header[i].toInt().toChar()
            if (c == ' ' || c == '\u0000') continue
            if (c < '0' || c > '7') break
            result = result * 8 + (c - '0')
        }
        return result
    }
}
