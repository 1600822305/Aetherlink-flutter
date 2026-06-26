package com.example.aetherlink.aetherlink_saf.core

/**
 * Pure diff engine for `applyDiff` (spec P2). Two formats are supported:
 *
 *  - `search-replace` (**primary**, what the original Aetherlink agent emits):
 *    one or more blocks of the shape
 *    ```
 *    <<<<<<< SEARCH
 *    old text
 *    =======
 *    new text
 *    >>>>>>> REPLACE
 *    ```
 *    Each block's SEARCH text must occur in the (progressively edited) document;
 *    the first occurrence is replaced.
 *
 *  - `unified`: standard `@@ -a,b +c,d @@` hunks with ` ` / `-` / `+` lines.
 *
 * No Android imports — unit-tested on the JVM.
 */
object DiffApplier {

    fun apply(text: String, diff: String, format: String): DiffOutcome = when (format) {
        "search-replace" -> applySearchReplace(text, diff)
        "unified" -> applyUnified(text, diff)
        else -> throw DiffException(
            DiffFailure.INVALID_FORMAT,
            "unknown diff format '$format' (expected 'search-replace' or 'unified')",
        )
    }

    // ===== search-replace =====

    private const val MARK_SEARCH = "<<<<<<< SEARCH"
    private const val MARK_SEP = "======="
    private const val MARK_REPLACE = ">>>>>>> REPLACE"

    fun applySearchReplace(text: String, diff: String): DiffOutcome {
        val blocks = parseSearchReplace(diff)
        if (blocks.isEmpty()) {
            throw DiffException(DiffFailure.INVALID_FORMAT, "no SEARCH/REPLACE blocks found")
        }
        var current = text
        var added = 0
        var deleted = 0
        var changed = 0
        for ((index, block) in blocks.withIndex()) {
            val at = current.indexOf(block.search)
            if (at >= 0) {
                current = current.substring(0, at) + block.replace +
                    current.substring(at + block.search.length)
            } else {
                // Whitespace-tolerant fallback: match on line-trimmed equality
                // before giving up, so a SEARCH block that only differs in
                // leading/trailing whitespace still applies.
                current = applyFuzzy(current, block.search, block.replace)
                    ?: throw DiffException(
                        DiffFailure.SEARCH_NOT_FOUND,
                        searchNotFoundMessage(current, block.search, index),
                    )
            }
            val searchLines = countLines(block.search)
            val replaceLines = countLines(block.replace)
            deleted += searchLines
            added += replaceLines
            changed += maxOf(searchLines, replaceLines)
        }
        return DiffOutcome(
            text = current,
            linesChanged = changed,
            linesAdded = added,
            linesDeleted = deleted,
        )
    }

    private fun parseSearchReplace(diff: String): List<SearchReplaceBlock> {
        val lines = diff.split("\n")
        val blocks = ArrayList<SearchReplaceBlock>()
        var i = 0
        while (i < lines.size) {
            if (lines[i].trimEnd() != MARK_SEARCH) {
                i++
                continue
            }
            i++
            val search = StringBuilder()
            var sawSep = false
            while (i < lines.size) {
                if (lines[i].trimEnd() == MARK_SEP) {
                    sawSep = true
                    i++
                    break
                }
                search.append(lines[i]).append('\n')
                i++
            }
            if (!sawSep) {
                throw DiffException(DiffFailure.INVALID_FORMAT, "SEARCH block missing '=======' separator")
            }
            val replace = StringBuilder()
            var sawEnd = false
            while (i < lines.size) {
                if (lines[i].trimEnd() == MARK_REPLACE) {
                    sawEnd = true
                    i++
                    break
                }
                replace.append(lines[i]).append('\n')
                i++
            }
            if (!sawEnd) {
                throw DiffException(DiffFailure.INVALID_FORMAT, "block missing '>>>>>>> REPLACE' terminator")
            }
            blocks.add(
                SearchReplaceBlock(
                    search = stripTrailingNewline(search.toString()),
                    replace = stripTrailingNewline(replace.toString()),
                ),
            )
        }
        return blocks
    }

    // ===== unified =====

    private val HUNK_HEADER = Regex("""^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@""")

    fun applyUnified(text: String, diff: String): DiffOutcome {
        val src = if (text.isEmpty()) emptyList() else text.split("\n")
        val out = ArrayList<String>()
        var srcPos = 0 // 0-based index into src
        var added = 0
        var deleted = 0

        val diffLines = diff.split("\n")
        var i = 0
        while (i < diffLines.size) {
            val line = diffLines[i]
            val header = HUNK_HEADER.find(line)
            if (header == null) {
                i++
                continue
            }
            val oldStart = header.groupValues[1].toInt() // 1-based
            // copy untouched lines before the hunk
            val copyUntil = oldStart - 1
            while (srcPos < copyUntil && srcPos < src.size) {
                out.add(src[srcPos])
                srcPos++
            }
            i++
            while (i < diffLines.size && HUNK_HEADER.find(diffLines[i]) == null) {
                val h = diffLines[i]
                when {
                    h.startsWith("+") -> {
                        out.add(h.substring(1))
                        added++
                    }
                    h.startsWith("-") -> {
                        verifyContext(src, srcPos, h.substring(1))
                        srcPos++
                        deleted++
                    }
                    h.startsWith(" ") -> {
                        verifyContext(src, srcPos, h.substring(1))
                        out.add(src[srcPos])
                        srcPos++
                    }
                    h.isEmpty() -> {
                        // tolerate a blank trailing line in the diff payload
                    }
                    h == "\\ No newline at end of file" -> {
                        // ignore the no-trailing-newline marker
                    }
                    else -> throw DiffException(
                        DiffFailure.INVALID_FORMAT,
                        "unexpected hunk line: '$h'",
                    )
                }
                i++
            }
        }
        while (srcPos < src.size) {
            out.add(src[srcPos])
            srcPos++
        }
        return DiffOutcome(
            text = out.joinToString("\n"),
            linesChanged = maxOf(added, deleted),
            linesAdded = added,
            linesDeleted = deleted,
        )
    }

    private fun verifyContext(src: List<String>, pos: Int, expected: String) {
        if (pos >= src.size || src[pos] != expected) {
            throw DiffException(
                DiffFailure.CONTEXT_MISMATCH,
                "diff context does not match the file at source line ${pos + 1}",
            )
        }
    }

    /**
     * Line-level, whitespace-tolerant fallback for [applySearchReplace]. Finds
     * the first window of document lines whose `trim()`med text equals the
     * trimmed SEARCH lines, then swaps in [replace]. Returns the new document,
     * or null when there's no confident match. Skips all-blank SEARCH blocks to
     * avoid matching arbitrary empty regions.
     */
    private fun applyFuzzy(text: String, search: String, replace: String): String? {
        val searchLines = search.split("\n")
        if (searchLines.all { it.isBlank() }) return null
        val docLines = text.split("\n")
        val trimmedSearch = searchLines.map { it.trim() }
        val n = trimmedSearch.size
        if (n == 0 || n > docLines.size) return null

        var matchStart = -1
        for (start in 0..(docLines.size - n)) {
            var ok = true
            for (k in 0 until n) {
                if (docLines[start + k].trim() != trimmedSearch[k]) {
                    ok = false
                    break
                }
            }
            if (ok) {
                matchStart = start
                break
            }
        }
        if (matchStart < 0) return null

        val out = ArrayList<String>(docLines.size)
        out.addAll(docLines.subList(0, matchStart))
        out.addAll(replace.split("\n"))
        out.addAll(docLines.subList(matchStart + n, docLines.size))
        return out.joinToString("\n")
    }

    /** A precise, model-actionable error when a SEARCH block can't be located. */
    private fun searchNotFoundMessage(text: String, search: String, blockIndex: Int): String {
        val firstLine = search.split("\n").firstOrNull { it.isNotBlank() }?.trim() ?: ""
        val preview = if (firstLine.length > 60) firstLine.substring(0, 60) + "…" else firstLine

        val docLines = text.split("\n")
        var nearLine = -1
        if (preview.isNotEmpty()) {
            for (i in docLines.indices) {
                val t = docLines[i].trim()
                if (t == firstLine || t.contains(preview)) {
                    nearLine = i + 1
                    break
                }
            }
        }
        val where = if (nearLine > 0) " (closest similar line is around line $nearLine)" else ""
        return "SEARCH block #${blockIndex + 1} did not match the file$where. " +
            "First line: \"$preview\". Re-read the file with read_file and make the " +
            "SEARCH text match exactly (including indentation and blank lines)."
    }

    private fun countLines(s: String): Int = if (s.isEmpty()) 0 else s.split("\n").size

    private fun stripTrailingNewline(s: String): String =
        if (s.endsWith("\n")) s.substring(0, s.length - 1) else s

    private data class SearchReplaceBlock(val search: String, val replace: String)
}

/** Why a diff could not be applied. */
enum class DiffFailure { INVALID_FORMAT, SEARCH_NOT_FOUND, CONTEXT_MISMATCH }

class DiffException(val failure: DiffFailure, message: String) : Exception(message)

/** Result of a successful [DiffApplier.apply]. */
data class DiffOutcome(
    val text: String,
    val linesChanged: Int,
    val linesAdded: Int,
    val linesDeleted: Int,
)
