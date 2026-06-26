package com.example.aetherlink.aetherlink_saf.core

import java.security.MessageDigest

/**
 * Pure, platform-free text/line utilities shared by the read- and edit-range
 * handlers. Kept free of Android imports so it can be unit-tested on the JVM.
 *
 * Line model (spec §3.3): line numbers are **1-based, closed range**. A "line"
 * keeps its own terminator (`\n` / `\r\n`); the last line may have none. This
 * lets `readFileRange` return the exact bytes of a range — including its
 * newline style — so a `rangeHash` round-trips.
 */
object LineText {

    /**
     * Splits [text] into lines, **keeping each line's trailing `\n`**. A
     * trailing newline does not produce an extra empty line; the empty string
     * has zero lines.
     */
    fun splitKeepEnds(text: String): List<String> {
        if (text.isEmpty()) return emptyList()
        val out = ArrayList<String>()
        var start = 0
        var i = 0
        while (i < text.length) {
            if (text[i] == '\n') {
                out.add(text.substring(start, i + 1))
                start = i + 1
            }
            i++
        }
        if (start < text.length) out.add(text.substring(start))
        return out
    }

    /** Number of lines in [text] under [splitKeepEnds]'s model. */
    fun lineCount(text: String): Int = splitKeepEnds(text).size

    /**
     * Concatenated content of lines [startLine]..[endLine] (1-based, inclusive),
     * with terminators preserved. [endLine] is clamped to the last line; an
     * out-of-range or inverted [startLine]/[endLine] throws [IllegalArgumentException].
     */
    fun sliceLines(text: String, startLine: Int, endLine: Int): RangeSlice {
        val lines = splitKeepEnds(text)
        val total = lines.size
        require(startLine >= 1) { "startLine must be >= 1 (got $startLine)" }
        require(endLine >= startLine) {
            "endLine ($endLine) must be >= startLine ($startLine)"
        }
        if (total == 0) {
            return RangeSlice(content = "", totalLines = 0, startLine = startLine, endLine = startLine - 1)
        }
        require(startLine <= total) {
            "startLine ($startLine) is past the last line ($total)"
        }
        val clampedEnd = if (endLine > total) total else endLine
        val sb = StringBuilder()
        for (idx in (startLine - 1) until clampedEnd) sb.append(lines[idx])
        return RangeSlice(
            content = sb.toString(),
            totalLines = total,
            startLine = startLine,
            endLine = clampedEnd,
        )
    }

    /**
     * Inserts [content] *before* 1-based [line]. [line] may equal
     * `lineCount + 1` to append at the end. The inserted block is normalised to
     * end with a `\n` so it doesn't fuse with the following line.
     */
    fun insertBefore(text: String, line: Int, content: String): String {
        val lines = splitKeepEnds(text).toMutableList()
        require(line >= 1) { "line must be >= 1 (got $line)" }
        require(line <= lines.size + 1) {
            "line ($line) is past end+1 (${lines.size + 1})"
        }
        val block = if (content.endsWith("\n")) content else "$content\n"
        lines.add(line - 1, block)
        return lines.joinToString(separator = "")
    }

    /**
     * Literal or regex find/replace. Returns the new text and how many matches
     * were replaced.
     */
    fun replace(
        text: String,
        search: String,
        replace: String,
        isRegex: Boolean,
        replaceAll: Boolean,
        caseSensitive: Boolean,
    ): ReplaceOutcome {
        require(search.isNotEmpty()) { "search must not be empty" }
        val options = if (caseSensitive) emptySet() else setOf(RegexOption.IGNORE_CASE)
        val regex = if (isRegex) {
            Regex(search, options)
        } else {
            Regex(Regex.escape(search), options)
        }
        var count = 0
        // `replace` is treated as literal text (no `$1` group expansion) so the
        // behaviour is identical for literal and regex searches.
        val result = if (replaceAll) {
            regex.replace(text) {
                count++
                replace
            }
        } else {
            val match = regex.find(text)
            if (match == null) {
                text
            } else {
                count = 1
                text.substring(0, match.range.first) + replace +
                    text.substring(match.range.last + 1)
            }
        }
        return ReplaceOutcome(text = result, replacements = count)
    }

    /** Lowercase hex SHA-256 of [bytes] (spec §3.3 rangeHash / getFileHash). */
    fun sha256Hex(bytes: ByteArray): String = digestHex(bytes, "SHA-256")

    /** Lowercase hex digest of [bytes] under [algorithm] (`MD5` / `SHA-256`). */
    fun digestHex(bytes: ByteArray, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm).digest(bytes)
        val sb = StringBuilder(digest.size * 2)
        for (b in digest) {
            val v = b.toInt() and 0xFF
            sb.append(HEX[v ushr 4])
            sb.append(HEX[v and 0x0F])
        }
        return sb.toString()
    }

    private val HEX = "0123456789abcdef".toCharArray()
}

/** Output of [LineText.sliceLines]. */
data class RangeSlice(
    val content: String,
    val totalLines: Int,
    val startLine: Int,
    val endLine: Int,
)

/** Output of [LineText.replace]. */
data class ReplaceOutcome(val text: String, val replacements: Int) {
    val modified: Boolean get() = replacements > 0
}
