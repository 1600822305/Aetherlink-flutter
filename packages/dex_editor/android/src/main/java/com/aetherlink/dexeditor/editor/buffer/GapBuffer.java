package com.aetherlink.dexeditor.editor.buffer;

import java.util.LinkedList;
import com.aetherlink.dexeditor.editor.utils.Pair;

/**
 * GapBuffer is a threadsafe EditBuffer that is optimized for editing with a cursor which tends to
 * make a sequence of inserts and deletes at the same place in the buffer
 */
public class GapBuffer implements CharSequence {

    private char[] _contents;
    private int _gapStartIndex;
    private int _gapEndIndex;
    private int _lineCount;
    private BufferCache _cache;
    private UndoStack _undoStack;

    private int _lastUndoSelStart = -1;
    private int _lastUndoSelEnd = -1;
    private boolean _lastUndoSelMode = false;

    private int _lastRedoSelStart = -1;
    private int _lastRedoSelEnd = -1;
    private boolean _lastRedoSelMode = false;

    private final int EOF = '\uFFFF';
    private final int NEWLINE = '\n';

    public GapBuffer() {
        _contents = new char[16];
        _lineCount = 1;
        _gapStartIndex = 0;
        _gapEndIndex = _contents.length;
        _cache = new BufferCache();
        _undoStack = new UndoStack();
    }

    public GapBuffer(String buffer) {
        this();
        insert(0, buffer, false);
    }

    public GapBuffer(char[] buffer) {
        _contents = buffer;
        _lineCount = 1;
        _cache = new BufferCache();
        _undoStack = new UndoStack();
        for (char c : _contents) {
            if (c == NEWLINE) _lineCount++;
        }
    }

    public synchronized String getLine(int lineNumber) {
        int startIndex = getLineOffset(lineNumber);
        int length = getLineLength(lineNumber);
        return substring(startIndex, startIndex + length);
    }

    public synchronized int getLineOffset(int lineNumber) {
        if (lineNumber <= 0 || lineNumber > getLineCount()) {
            throw new IllegalArgumentException("line index is invalid");
        }

        int lineIndex = --lineNumber;
        Pair<Integer, Integer> cacheEntry = _cache.getNearestLine(lineIndex);
        int cacheLine = cacheEntry.first;
        int cacheOffset = cacheEntry.second;

        int offset = 0;
        if (lineIndex > cacheLine) {
            offset = findCharOffset(lineIndex, cacheLine, cacheOffset);
        } else if (lineIndex < cacheLine) {
            offset = findCharOffsetBackward(lineIndex, cacheLine, cacheOffset);
        } else {
            offset = cacheOffset;
        }

        if (offset >= 0) {
            _cache.updateEntry(lineIndex, offset);
        }
        return offset;
    }

    private int findCharOffset(int targetLine, int startLine, int startOffset) {
        int currLine = startLine;
        int offset = getRealIndex(startOffset);

        while ((currLine < targetLine) && (offset < _contents.length)) {
            if (_contents[offset] == NEWLINE) ++currLine;
            ++offset;
            if (offset == _gapStartIndex) offset = _gapEndIndex;
        }

        if (currLine != targetLine) return -1;
        return getLogicalIndex(offset);
    }

    private int findCharOffsetBackward(int targetLine, int startLine, int startOffset) {
        if (targetLine == 0) return 0;

        int currLine = startLine;
        int offset = getRealIndex(startOffset);
        while (currLine > (targetLine - 1) && offset >= 0) {
            if (offset == _gapEndIndex) offset = _gapStartIndex;
            --offset;
            if (_contents[offset] == NEWLINE) --currLine;
        }

        int charOffset;
        if (offset >= 0) {
            charOffset = getLogicalIndex(offset);
            ++charOffset;
        } else {
            charOffset = -1;
        }
        return charOffset;
    }

    public synchronized int findLineNumber(int charOffset) {
        if (charOffset < 0) return 1;
        if (charOffset >= length()) return getLineCount();

        Pair<Integer, Integer> cachedEntry = _cache.getNearestCharOffset(charOffset);
        int line = cachedEntry.first;
        int offset = getRealIndex(cachedEntry.second);
        int targetOffset = getRealIndex(charOffset);
        int lastKnownLine = -1;
        int lastKnownCharOffset = -1;

        if (targetOffset > offset) {
            while ((offset < targetOffset) && (offset < _contents.length)) {
                if (_contents[offset] == NEWLINE) {
                    ++line;
                    lastKnownLine = line;
                    lastKnownCharOffset = getLogicalIndex(offset) + 1;
                }
                ++offset;
                if (offset == _gapStartIndex) offset = _gapEndIndex;
            }
        } else if (targetOffset < offset) {
            while ((offset > targetOffset) && (offset > 0)) {
                if (offset == _gapEndIndex) offset = _gapStartIndex;
                --offset;
                if (_contents[offset] == NEWLINE) {
                    lastKnownLine = line;
                    lastKnownCharOffset = getLogicalIndex(offset) + 1;
                    --line;
                }
            }
        }

        if (offset == targetOffset) {
            if (lastKnownLine != -1) {
                _cache.updateEntry(lastKnownLine, lastKnownCharOffset);
            }
            return line + 1;
        } else {
            return 1;
        }
    }

    public synchronized int getLineLength(int lineNumber) {
        int lineLength = 0;
        int pos = getLineOffset(lineNumber);
        pos = getRealIndex(pos);

        while (pos < _contents.length && _contents[pos] != NEWLINE && _contents[pos] != EOF) {
            ++lineLength;
            ++pos;
            if (pos == _gapStartIndex) pos = _gapEndIndex;
        }
        return lineLength;
    }

    public synchronized char charAt(int charOffset) {
        if (charOffset < 0 || charOffset >= length()) return '\0';
        int realIndex = getRealIndex(charOffset);
        if (realIndex < 0 || realIndex >= _contents.length) return '\0';
        return _contents[realIndex];
    }

    public synchronized CharSequence subSequence(int start, int end) {
        if (start < 0) start = 0;
        if (end > length()) end = length();
        if (start >= end) return "";

        int count = end - start;
        int realIndex = getRealIndex(start);
        char[] chars = new char[count];

        for (int i = 0; i < count; ++i) {
            if (realIndex >= _contents.length) break;
            chars[i] = _contents[realIndex];
            if (++realIndex == _gapStartIndex) realIndex = _gapEndIndex;
        }
        return new String(chars);
    }

    public synchronized String substring(int start, int end) {
        if (start < 0) start = 0;
        if (end > length()) end = length();
        if (start >= end) return "";
        return subSequence(start, end).toString();
    }

    public synchronized GapBuffer insert(int offset, String str, boolean capture) {
        return insert(offset, str, capture, System.nanoTime());
    }

    public synchronized GapBuffer insert(int offset, String str, boolean capture, long timestamp) {
        int length = str.length();
        if (capture && length > 0) {
            _undoStack.captureInsert(offset, offset + length, timestamp);
        }

        int insertIndex = getRealIndex(offset);

        if (insertIndex != _gapEndIndex) {
            if (isBeforeGap(insertIndex)) {
                shiftGapLeft(insertIndex);
            } else {
                shiftGapRight(insertIndex);
            }
        }

        if (length >= gapSize()) {
            expandBuffer(length - gapSize());
        }

        for (int i = 0; i < length; ++i) {
            char c = str.charAt(i);
            if (c == NEWLINE) ++_lineCount;
            _contents[_gapStartIndex] = c;
            ++_gapStartIndex;
        }

        _cache.invalidateCache(offset);
        return this;
    }

    public synchronized GapBuffer append(String str, boolean capture) {
        insert(length(), str, capture);
        return this;
    }

    public synchronized GapBuffer append(String str) {
        insert(length(), str, false);
        return this;
    }

    public synchronized GapBuffer delete(int start, int end, boolean capture) {
        return delete(start, end, capture, System.nanoTime());
    }

    public synchronized GapBuffer delete(int start, int end, boolean capture, long timestamp) {
        if (capture && start < end) {
            _undoStack.captureDelete(start, end, timestamp);
        }

        int newGapStart = end;

        if (newGapStart != _gapStartIndex) {
            if (isBeforeGap(newGapStart)) {
                shiftGapLeft(newGapStart);
            } else {
                shiftGapRight(newGapStart + gapSize());
            }
        }

        int len = end - start;
        for (int i = 0; i < len; ++i) {
            --_gapStartIndex;
            if (_contents[_gapStartIndex] == NEWLINE) --_lineCount;
        }

        _cache.invalidateCache(start);
        return this;
    }

    public synchronized GapBuffer replace(int start, int end, String str, boolean capture) {
        delete(start, end, capture);
        insert(start, str, capture);
        return this;
    }

    private char[] gapSubSequence(int charCount) {
        char[] chars = new char[charCount];
        for (int i = 0; i < charCount; ++i) {
            chars[i] = _contents[_gapStartIndex + i];
        }
        return chars;
    }

    private synchronized void shiftGapStart(int displacement) {
        if (displacement >= 0)
            _lineCount += countNewlines(_gapStartIndex, displacement);
        else
            _lineCount -= countNewlines(_gapStartIndex + displacement, -displacement);

        _gapStartIndex += displacement;
        _cache.invalidateCache(getLogicalIndex(_gapStartIndex - 1) + 1);
    }

    private int countNewlines(int start, int totalChars) {
        int newlines = 0;
        for (int i = start; i < (start + totalChars); ++i) {
            if (_contents[i] == NEWLINE) ++newlines;
        }
        return newlines;
    }

    private void shiftGapLeft(int newGapStart) {
        while (_gapStartIndex > newGapStart) {
            _gapEndIndex--;
            _gapStartIndex--;
            _contents[_gapEndIndex] = _contents[_gapStartIndex];
        }
    }

    private void shiftGapRight(int newGapEnd) {
        while (_gapEndIndex < newGapEnd) {
            _contents[_gapStartIndex] = _contents[_gapEndIndex];
            _gapStartIndex++;
            _gapEndIndex++;
        }
    }

    private void expandBuffer(int minIncrement) {
        int incrSize = Math.max(minIncrement, _contents.length * 2 + 2);
        char[] temp = new char[_contents.length + incrSize];

        int i = 0;
        while (i < _gapStartIndex) {
            temp[i] = _contents[i];
            ++i;
        }

        i = _gapEndIndex;
        while (i < _contents.length) {
            temp[i + incrSize] = _contents[i];
            ++i;
        }

        _gapEndIndex += incrSize;
        _contents = temp;
    }

    private boolean isValid(int charOffset) {
        return (charOffset >= 0 && charOffset <= this.length());
    }

    private int gapSize() {
        return _gapEndIndex - _gapStartIndex;
    }

    private int getRealIndex(int index) {
        if (index < 0) return 0;
        if (index >= length()) return _contents.length - 1;

        if (isBeforeGap(index)) {
            return index;
        } else {
            int realIndex = index + gapSize();
            return Math.min(realIndex, _contents.length - 1);
        }
    }

    private int getLogicalIndex(int index) {
        if (isBeforeGap(index)) return index;
        else return index - gapSize();
    }

    private boolean isBeforeGap(int index) {
        return index < _gapStartIndex;
    }

    public synchronized int getLineCount() {
        return _lineCount;
    }

    @Override
    public synchronized int length() {
        return _contents.length - gapSize();
    }

    @Override
    public synchronized String toString() {
        StringBuffer buf = new StringBuffer();
        int len = this.length();
        for (int i = 0; i < len; i++) {
            buf.append(charAt(i));
        }
        return new String(buf);
    }

    public boolean canUndo() { return _undoStack.canUndo(); }
    public boolean canRedo() { return _undoStack.canRedo(); }

    public int undo() {
        _lastUndoSelStart = _lastUndoSelEnd = -1;
        _lastUndoSelMode = false;
        return _undoStack.undo();
    }

    public int redo() {
        _lastRedoSelStart = _lastRedoSelEnd = -1;
        _lastRedoSelMode = false;
        return _undoStack.redo();
    }

    public void markSelectionBefore(int selStart, int selEnd, boolean selMode) {
        _undoStack.setPendingSelectionBefore(selStart, selEnd, selMode);
    }

    public void markSelectionAfter(int selStart, int selEnd, boolean selMode) {
        _undoStack.setPendingSelectionAfter(selStart, selEnd, selMode);
    }

    public int getLastUndoSelectionStart() { return _lastUndoSelStart; }
    public int getLastUndoSelectionEnd() { return _lastUndoSelEnd; }
    public boolean getLastUndoSelectionMode() { return _lastUndoSelMode; }
    public int getLastRedoSelectionStart() { return _lastRedoSelStart; }
    public int getLastRedoSelectionEnd() { return _lastRedoSelEnd; }
    public boolean getLastRedoSelectionMode() { return _lastRedoSelMode; }

    public void beginBatchEdit() { _undoStack.beginBatchEdit(); }
    public void endBatchEdit() { _undoStack.endBatchEdit(); }
    public boolean isBatchEdit() { return _undoStack.isBatchEdit(); }

    class UndoStack {
        private boolean _isBatchEdit;
        private int _groupId;
        private int _top;
        private long _lastEditTime = -1L;
        private LinkedList<Action> _stack = new LinkedList<>();
        private static final int MAX_UNDO_SIZE = 50000;
        public final long MERGE_TIME = 1000000000;

        private int _pendingSelBeforeStart = -1;
        private int _pendingSelBeforeEnd = -1;
        private boolean _pendingSelBeforeMode = false;
        private int _pendingSelAfterStart = -1;
        private int _pendingSelAfterEnd = -1;
        private boolean _pendingSelAfterMode = false;

        public int undo() {
            if (canUndo()) {
                Action lastUndo = _stack.get(_top - 1);
                int group = lastUndo._group;
                do {
                    Action action = _stack.get(_top - 1);
                    if (action._group != group) break;
                    lastUndo = action;
                    action.undo();
                    _top--;
                } while (canUndo());

                _lastUndoSelStart = lastUndo._selBeforeStart;
                _lastUndoSelEnd = lastUndo._selBeforeEnd;
                _lastUndoSelMode = lastUndo._selBeforeMode;
                return lastUndo.findUndoPosition();
            }
            return -1;
        }

        public int redo() {
            if (canRedo()) {
                Action lastRedo = _stack.get(_top);
                int group = lastRedo._group;
                do {
                    Action action = _stack.get(_top);
                    if (action._group != group) break;
                    lastRedo = action;
                    action.redo();
                    _top++;
                } while (canRedo());

                _lastRedoSelStart = lastRedo._selAfterStart;
                _lastRedoSelEnd = lastRedo._selAfterEnd;
                _lastRedoSelMode = lastRedo._selAfterMode;
                return lastRedo.findRedoPosition();
            }
            return -1;
        }

        public void setPendingSelectionBefore(int s, int e, boolean mode) {
            _pendingSelBeforeStart = s; _pendingSelBeforeEnd = e; _pendingSelBeforeMode = mode;
        }

        public void setPendingSelectionAfter(int s, int e, boolean mode) {
            _pendingSelAfterStart = s; _pendingSelAfterEnd = e; _pendingSelAfterMode = mode;
        }

        public void captureInsert(int start, int end, long time) {
            int len = end - start;
            boolean mergeSuccess = false;

            if (canUndo()) {
                Action action = _stack.get(_top - 1);
                if (action instanceof InsertAction &&
                        (time - _lastEditTime) < MERGE_TIME &&
                        start == action._end &&
                        (action._end - action._start + len <= MAX_UNDO_SIZE)) {
                    action._end += len;
                    mergeSuccess = true;
                } else {
                    action.recordData();
                }
            }

            if (!mergeSuccess && len <= MAX_UNDO_SIZE) {
                InsertAction a = new InsertAction(start, end, _groupId);
                a._selBeforeStart = _pendingSelBeforeStart;
                a._selBeforeEnd = _pendingSelBeforeEnd;
                a._selBeforeMode = _pendingSelBeforeMode;
                a._selAfterStart = _pendingSelAfterStart;
                a._selAfterEnd = _pendingSelAfterEnd;
                a._selAfterMode = _pendingSelAfterMode;
                push(a);
                if (!_isBatchEdit) _groupId++;
            }
            _lastEditTime = time;
        }

        public void captureDelete(int start, int end, long time) {
            int len = end - start;
            boolean mergeSuccess = false;

            if (canUndo()) {
                Action action = _stack.get(_top - 1);
                if (action instanceof DeleteAction &&
                        (time - _lastEditTime) < MERGE_TIME &&
                        end == action._start &&
                        (action._end - start <= MAX_UNDO_SIZE)) {
                    action._start = start;
                    mergeSuccess = true;
                } else {
                    action.recordData();
                }
            }

            if (!mergeSuccess && len <= MAX_UNDO_SIZE) {
                DeleteAction a = new DeleteAction(start, end, _groupId);
                a._selBeforeStart = _pendingSelBeforeStart;
                a._selBeforeEnd = _pendingSelBeforeEnd;
                a._selBeforeMode = _pendingSelBeforeMode;
                a._selAfterStart = _pendingSelAfterStart;
                a._selAfterEnd = _pendingSelAfterEnd;
                a._selAfterMode = _pendingSelAfterMode;
                push(a);
                if (!_isBatchEdit) _groupId++;
            }
            _lastEditTime = time;
        }

        private void push(Action action) {
            trimStack();
            _top++;
            _stack.add(action);
        }

        private void trimStack() {
            while (_stack.size() > _top) _stack.removeLast();
        }

        public final boolean canUndo() { return _top > 0; }
        public final boolean canRedo() { return _top < _stack.size(); }
        public boolean isBatchEdit() { return _isBatchEdit; }
        public void beginBatchEdit() { _isBatchEdit = true; }
        public void endBatchEdit() { _isBatchEdit = false; _groupId++; }

        private abstract class Action {
            public int _start;
            public int _end;
            public String _data;
            public int _group;
            public final long MERGE_TIME = 750000000L;

            public int _selBeforeStart = -1;
            public int _selBeforeEnd = -1;
            public boolean _selBeforeMode = false;
            public int _selAfterStart = -1;
            public int _selAfterEnd = -1;
            public boolean _selAfterMode = false;

            public abstract void undo();
            public abstract void redo();
            public abstract void recordData();
            public abstract int findUndoPosition();
            public abstract int findRedoPosition();
            public abstract boolean merge(int start, int end, long time);
        }

        private class InsertAction extends Action {
            public InsertAction(int start, int end, int group) {
                this._start = start;
                this._end = end;
                this._group = group;
            }

            @Override
            public boolean merge(int start, int end, long time) {
                if (_lastEditTime < 0) return false;
                if ((time - _lastEditTime) < MERGE_TIME && start == _end) {
                    _end += end - start;
                    trimStack();
                    return true;
                }
                return false;
            }

            @Override
            public void recordData() {
                _data = substring(_start, _end);
            }

            @Override
            public void undo() {
                if (_data == null) {
                    recordData();
                    shiftGapStart(-(_end - _start));
                } else {
                    delete(_start, _end, false, 0);
                }
            }

            @Override
            public void redo() {
                insert(_start, _data, false, 0);
            }

            @Override
            public int findRedoPosition() { return _end; }

            @Override
            public int findUndoPosition() { return _start; }
        }

        private class DeleteAction extends Action {
            public DeleteAction(int start, int end, int group) {
                this._start = start;
                this._end = end;
                this._group = group;
            }

            @Override
            public boolean merge(int start, int end, long time) {
                if (_lastEditTime < 0) return false;
                if ((time - _lastEditTime) < MERGE_TIME && end == _start) {
                    _start = start;
                    trimStack();
                    return true;
                }
                return false;
            }

            @Override
            public void recordData() {
                _data = new String(gapSubSequence(_end - _start));
            }

            @Override
            public void undo() {
                if (_data == null) {
                    recordData();
                    shiftGapStart(_end - _start);
                } else {
                    insert(_start, _data, false, 0);
                }
            }

            @Override
            public void redo() {
                delete(_start, _end, false, 0);
            }

            @Override
            public int findRedoPosition() { return _start; }

            @Override
            public int findUndoPosition() { return _end; }
        }
    }
}
