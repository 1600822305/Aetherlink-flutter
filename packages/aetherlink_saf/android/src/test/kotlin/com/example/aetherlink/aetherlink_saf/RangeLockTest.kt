package com.example.aetherlink.aetherlink_saf

import com.example.aetherlink.aetherlink_saf.core.LineText
import com.example.aetherlink.aetherlink_saf.core.RangeLock
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Round-trip coverage for the `readFileRange` → `applyDiff` optimistic lock.
 *
 * This is the regression guard for the historic bug where `applyDiff` hashed
 * the *whole file* and compared it against `readFileRange`'s *range* hash, so
 * any partial-range read falsely tripped `E_RANGE_CONFLICT`.
 */
internal class RangeLockTest {

    private val file = buildString {
        for (i in 1..20) append("line $i\n")
    }

    /** Mimics what `ReadHandlers.readFileRange` returns as `rangeHash`. */
    private fun readFileRangeHash(text: String, start: Int, end: Int): String {
        val slice = LineText.sliceLines(text, start, end)
        return LineText.sha256Hex(slice.content.toByteArray(Charsets.UTF_8))
    }

    @Test
    fun rangeHash_fromRead_matches_recompute_overSameRange() {
        val rangeHash = readFileRangeHash(file, 5, 10)
        // applyDiff recomputes over the same range of the unchanged file.
        assertTrue(RangeLock.matches(file, rangeHash, 5, 10))
        assertEquals(rangeHash, RangeLock.currentHash(file, 5, 10))
    }

    @Test
    fun partialRangeHash_doesNotEqual_wholeFileHash() {
        val rangeHash = readFileRangeHash(file, 5, 10)
        val wholeFileHash = LineText.sha256Hex(file.toByteArray(Charsets.UTF_8))
        // The exact symptom of the old bug: these must differ for a partial range.
        assertFalse(rangeHash.equals(wholeFileHash, ignoreCase = true))
        // And whole-file verification of a range token must therefore fail.
        assertFalse(RangeLock.matches(file, rangeHash, null, null))
    }

    @Test
    fun matches_failsWhenRangeChanged() {
        val rangeHash = readFileRangeHash(file, 5, 10)
        val edited = file.replace("line 7\n", "LINE SEVEN CHANGED\n")
        assertFalse(RangeLock.matches(edited, rangeHash, 5, 10))
    }

    @Test
    fun matches_ignoresEditsOutsideTheLockedRange() {
        val rangeHash = readFileRangeHash(file, 5, 10)
        // Editing a line outside [5,10] keeps the locked slice byte-identical.
        val edited = file.replace("line 18\n", "line 18 edited\n")
        assertTrue(RangeLock.matches(edited, rangeHash, 5, 10))
    }

    @Test
    fun currentHash_isNull_whenFileShrankPastRange() {
        val rangeHash = readFileRangeHash(file, 15, 18)
        val shrunk = "line 1\nline 2\nline 3\n"
        assertNull(RangeLock.currentHash(shrunk, 15, 18))
        // A vanished range counts as a conflict, not a match.
        assertFalse(RangeLock.matches(shrunk, rangeHash, 15, 18))
    }

    @Test
    fun nullExpectedHash_meansNoLock() {
        assertTrue(RangeLock.matches(file, null, 5, 10))
    }

    @Test
    fun wholeFileLock_matches_whenRangeOmitted() {
        val wholeFileHash = LineText.sha256Hex(file.toByteArray(Charsets.UTF_8))
        assertTrue(RangeLock.matches(file, wholeFileHash, null, null))
    }
}
