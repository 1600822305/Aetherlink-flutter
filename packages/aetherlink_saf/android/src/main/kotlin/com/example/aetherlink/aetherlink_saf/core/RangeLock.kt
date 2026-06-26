package com.example.aetherlink.aetherlink_saf.core

/**
 * Optimistic-lock token helper for `applyDiff` (spec §3.2 `E_RANGE_CONFLICT`,
 * §3.3 `rangeHash`).
 *
 * The contract: a caller reads a slice with `readFileRange(startLine, endLine)`,
 * keeps the returned `rangeHash` (sha256 of *only that range's* bytes), and later
 * passes it back to `applyDiff` as `expectedRangeHash` together with the same
 * line range. `applyDiff` must recompute the hash **over the same range** of the
 * current file and compare — hashing the whole file instead would only ever
 * match when the range happened to be the entire file, which is the bug this
 * helper exists to prevent.
 *
 * Kept Android-free so it can be unit-tested on the JVM.
 */
object RangeLock {

    /**
     * Recomputes the optimistic-lock hash of [text] for the 1-based, inclusive
     * line range [[startLine], [endLine]]. When both bounds are null the hash
     * covers the whole file (equivalent to `getFileHash`). Returns `null` when
     * the range no longer exists (e.g. the file shrank past [startLine]) — the
     * caller should treat that as a conflict.
     */
    fun currentHash(text: String, startLine: Int?, endLine: Int?): String? {
        if (startLine == null || endLine == null) {
            return LineText.sha256Hex(text.toByteArray(Charsets.UTF_8))
        }
        return try {
            val slice = LineText.sliceLines(text, startLine, endLine)
            LineText.sha256Hex(slice.content.toByteArray(Charsets.UTF_8))
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    /**
     * Whether [text] still matches [expectedHash] over the given range. A null
     * [expectedHash] means "no lock requested" → always true.
     */
    fun matches(
        text: String,
        expectedHash: String?,
        startLine: Int?,
        endLine: Int?,
    ): Boolean {
        if (expectedHash == null) return true
        val actual = currentHash(text, startLine, endLine) ?: return false
        return actual.equals(expectedHash, ignoreCase = true)
    }
}
