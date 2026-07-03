package com.aetherlink.dexeditor;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Structured, binary-level editor for {@code AndroidManifest.xml} (AXML).
 *
 * <p>Unlike a full decode → text → re-encode round trip (which the project's
 * {@code encodeAxml} does not support), this patcher edits the compiled binary
 * directly:
 * <ul>
 *   <li>scalar attribute values (int / bool) are patched <b>in place</b> in the
 *       element's {@code Res_value} record — no chunk resizing, so it is safe;</li>
 *   <li>string attribute values reuse an existing string-pool entry when present,
 *       otherwise a new entry is appended and the pool chunk is rebuilt (element
 *       chunks reference strings by index, so appending never invalidates them).</li>
 * </ul>
 *
 * <p>Only edits of <b>existing</b> attributes on existing elements are supported;
 * inserting/removing elements or attributes (structural AXML surgery) is
 * intentionally out of scope and reported as a failed patch by the caller rather
 * than risking a corrupt manifest.
 *
 * <p>Layout constants mirror the project's working {@link AxmlParser} so the two
 * stay consistent (attributes begin at {@code chunkStart + 36}, each 20 bytes:
 * {@code ns(4) name(4) rawValue(4) size(2) res0(1) dataType(1) data(4)}).
 */
public class AxmlManifestPatcher {

    private static final int AXML_MAGIC = 0x00080003;
    private static final int STRING_POOL_TYPE = 0x0001;
    private static final int XML_START_TAG = 0x0102;

    // Res_value dataType constants.
    private static final int TYPE_STRING = 0x03;
    private static final int TYPE_INT_DEC = 0x10;
    private static final int TYPE_INT_BOOLEAN = 0x12;

    private final byte[] data;
    private boolean valid;

    private static final int SORTED_FLAG = 0x1;

    private int poolStart = -1;
    private int poolEnd = -1;
    private int styleCount;
    private int flags;
    private boolean isUtf8;
    private final List<String> strings = new ArrayList<>();
    private boolean poolDirty;

    // Original string-data region, preserved verbatim on rebuild so that
    // appending a value can never corrupt existing (possibly non-round-trippable)
    // strings.
    private int origStringCount;
    private int origStringsStart = -1;   // absolute offset of first string's bytes
    private int origStringDataEnd = -1;  // absolute end of string data (before styles)
    private int[] origOffsets = new int[0];

    /** One editable attribute located in the binary. */
    private static final class Attr {
        final String element;
        final String name;
        final boolean androidNs;
        final int recordOffset; // absolute offset of the 20-byte attribute record

        Attr(String element, String name, boolean androidNs, int recordOffset) {
            this.element = element;
            this.name = name;
            this.androidNs = androidNs;
            this.recordOffset = recordOffset;
        }
    }

    private final List<Attr> attrs = new ArrayList<>();
    // Pending in-place writes (offset -> byte), applied over a clone at build().
    private final List<int[]> byteWrites = new ArrayList<>();

    public AxmlManifestPatcher(byte[] axmlData) {
        this.data = axmlData;
        try {
            parse();
            this.valid = poolStart >= 0 && poolEnd > poolStart;
        } catch (Exception e) {
            this.valid = false;
        }
    }

    public boolean valid() {
        return valid;
    }

    public boolean hasElement(String element) {
        for (Attr a : attrs) {
            if (a.element.equals(element)) {
                return true;
            }
        }
        return false;
    }

    // ----------------------------------------------------------------- edits

    /** Sets an existing decimal-int attribute in place. Returns false if absent. */
    public boolean setIntAttr(String element, String attrName, boolean androidNs, int value) {
        Attr a = find(element, attrName, androidNs);
        if (a == null) {
            return false;
        }
        writeInt(a.recordOffset + 8, 0xFFFFFFFF); // rawValue = -1 (typed value)
        putShort(a.recordOffset + 12, 8);         // size
        data0(a.recordOffset + 14, 0);            // res0
        data0(a.recordOffset + 15, TYPE_INT_DEC); // dataType
        writeInt(a.recordOffset + 16, value);     // data
        return true;
    }

    /** Sets an existing boolean attribute in place. Returns false if absent. */
    public boolean setBoolAttr(String element, String attrName, boolean androidNs, boolean value) {
        Attr a = find(element, attrName, androidNs);
        if (a == null) {
            return false;
        }
        writeInt(a.recordOffset + 8, 0xFFFFFFFF);
        putShort(a.recordOffset + 12, 8);
        data0(a.recordOffset + 14, 0);
        data0(a.recordOffset + 15, TYPE_INT_BOOLEAN);
        writeInt(a.recordOffset + 16, value ? 0xFFFFFFFF : 0);
        return true;
    }

    /** Sets an existing string attribute, appending to the pool if needed. */
    public boolean setStringAttr(String element, String attrName, boolean androidNs, String value) {
        Attr a = find(element, attrName, androidNs);
        if (a == null) {
            return false;
        }
        int index = internString(value);
        writeInt(a.recordOffset + 8, index);   // rawValue -> string index
        putShort(a.recordOffset + 12, 8);       // size
        data0(a.recordOffset + 14, 0);          // res0
        data0(a.recordOffset + 15, TYPE_STRING); // dataType
        writeInt(a.recordOffset + 16, index);   // data -> string index
        return true;
    }

    /** Rebuilds the AXML bytes with all pending edits applied. */
    public byte[] build() {
        if (!valid) {
            return data;
        }
        byte[] edited = data.clone();
        for (int[] w : byteWrites) {
            edited[w[0]] = (byte) (w[1] & 0xFF);
        }
        byte[] out;
        if (!poolDirty) {
            out = edited;
        } else {
            byte[] newPool = buildStringPool();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            baos.write(edited, 0, poolStart);
            baos.write(newPool, 0, newPool.length);
            baos.write(edited, poolEnd, edited.length - poolEnd);
            out = baos.toByteArray();
        }
        // Patch the total file size in the header.
        int size = out.length;
        out[4] = (byte) (size & 0xFF);
        out[5] = (byte) ((size >> 8) & 0xFF);
        out[6] = (byte) ((size >> 16) & 0xFF);
        out[7] = (byte) ((size >> 24) & 0xFF);
        return out;
    }

    // -------------------------------------------------------------- internals

    private Attr find(String element, String attrName, boolean androidNs) {
        for (Attr a : attrs) {
            if (a.element.equals(element) && a.name.equals(attrName) && a.androidNs == androidNs) {
                return a;
            }
        }
        return null;
    }

    private int internString(String value) {
        for (int i = 0; i < strings.size(); i++) {
            if (value.equals(strings.get(i))) {
                return i;
            }
        }
        strings.add(value);
        poolDirty = true;
        return strings.size() - 1;
    }

    private void writeInt(int offset, int value) {
        byteWrites.add(new int[] {offset, value & 0xFF});
        byteWrites.add(new int[] {offset + 1, (value >> 8) & 0xFF});
        byteWrites.add(new int[] {offset + 2, (value >> 16) & 0xFF});
        byteWrites.add(new int[] {offset + 3, (value >> 24) & 0xFF});
    }

    private void putShort(int offset, int value) {
        byteWrites.add(new int[] {offset, value & 0xFF});
        byteWrites.add(new int[] {offset + 1, (value >> 8) & 0xFF});
    }

    private void data0(int offset, int value) {
        byteWrites.add(new int[] {offset, value & 0xFF});
    }

    private int u16(int pos) {
        return (data[pos] & 0xFF) | ((data[pos + 1] & 0xFF) << 8);
    }

    private int u32(int pos) {
        return (data[pos] & 0xFF)
            | ((data[pos + 1] & 0xFF) << 8)
            | ((data[pos + 2] & 0xFF) << 16)
            | ((data[pos + 3] & 0xFF) << 24);
    }

    private void parse() {
        if (data == null || data.length < 8 || u32(0) != AXML_MAGIC) {
            return;
        }
        int pos = 8;
        while (pos + 8 <= data.length) {
            int chunkStart = pos;
            int chunkType = u16(chunkStart);
            int chunkSize = u32(chunkStart + 4);
            if (chunkSize <= 0 || chunkStart + chunkSize > data.length) {
                break;
            }
            if (chunkType == STRING_POOL_TYPE) {
                parseStringPool(chunkStart, chunkSize);
            } else if (chunkType == XML_START_TAG) {
                parseStartTag(chunkStart);
            }
            pos = chunkStart + chunkSize;
        }
    }

    private void parseStringPool(int chunkStart, int chunkSize) {
        poolStart = chunkStart;
        poolEnd = chunkStart + chunkSize;
        int stringCount = u32(chunkStart + 8);
        styleCount = u32(chunkStart + 12);
        flags = u32(chunkStart + 16);
        int stringsOffset = u32(chunkStart + 20);
        int stylesOffset = u32(chunkStart + 24);
        isUtf8 = (flags & 0x100) != 0;

        int offsetTable = chunkStart + 28;
        int stringsStart = chunkStart + stringsOffset;
        origStringCount = stringCount;
        origStringsStart = stringsStart;
        // String data ends where style data begins (if any), else at chunk end.
        origStringDataEnd = (styleCount > 0 && stylesOffset > 0)
            ? chunkStart + stylesOffset
            : poolEnd;
        origOffsets = new int[stringCount];
        for (int i = 0; i < stringCount; i++) {
            int rel = u32(offsetTable + i * 4);
            origOffsets[i] = rel;
            int at = stringsStart + rel;
            strings.add(at < data.length ? readStringAt(at) : "");
        }
    }

    private String readStringAt(int pos) {
        try {
            if (isUtf8) {
                int p = pos;
                int c = data[p] & 0xFF;
                if ((c & 0x80) != 0) {
                    p += 2;
                } else {
                    p += 1;
                }
                int byteLen = data[p] & 0xFF;
                if ((byteLen & 0x80) != 0) {
                    byteLen = ((byteLen & 0x7F) << 8) | (data[p + 1] & 0xFF);
                    p += 2;
                } else {
                    p += 1;
                }
                if (p + byteLen > data.length) {
                    byteLen = data.length - p;
                }
                if (byteLen <= 0) {
                    return "";
                }
                return new String(data, p, byteLen, StandardCharsets.UTF_8);
            } else {
                int charLen = (data[pos] & 0xFF) | ((data[pos + 1] & 0xFF) << 8);
                int p = pos + 2;
                if ((charLen & 0x8000) != 0) {
                    charLen = ((charLen & 0x7FFF) << 16)
                        | ((data[pos + 2] & 0xFF) | ((data[pos + 3] & 0xFF) << 8));
                    p = pos + 4;
                }
                if (p + charLen * 2 > data.length) {
                    charLen = (data.length - p) / 2;
                }
                if (charLen <= 0) {
                    return "";
                }
                char[] chars = new char[charLen];
                for (int i = 0; i < charLen; i++) {
                    chars[i] = (char) ((data[p + i * 2] & 0xFF) | ((data[p + i * 2 + 1] & 0xFF) << 8));
                }
                return new String(chars);
            }
        } catch (Exception e) {
            return "";
        }
    }

    private void parseStartTag(int chunkStart) {
        int nameIdx = u32(chunkStart + 20);
        int attrCount = u16(chunkStart + 28);
        String element = stringAt(nameIdx);
        int base = chunkStart + 36;
        for (int i = 0; i < attrCount; i++) {
            int rec = base + i * 20;
            if (rec + 20 > data.length) {
                break;
            }
            int nsIdx = u32(rec);
            int attrNameIdx = u32(rec + 4);
            String attrName = stringAt(attrNameIdx);
            boolean androidNs = nsIdx >= 0 && stringAt(nsIdx).contains("android");
            attrs.add(new Attr(element, attrName, androidNs, rec));
        }
    }

    private String stringAt(int index) {
        if (index >= 0 && index < strings.size()) {
            String s = strings.get(index);
            return s != null ? s : "";
        }
        return "";
    }

    private byte[] buildStringPool() {
        try {
            // Preserve the original string-data region verbatim; only encode the
            // strings appended after parsing. This guarantees existing strings are
            // byte-identical and cannot be mangled by a decode/re-encode cycle.
            int origRegionLen = origStringDataEnd - origStringsStart;
            int totalCount = strings.size();

            ByteArrayOutputStream appended = new ByteArrayOutputStream();
            int[] offsets = new int[totalCount];
            for (int i = 0; i < origStringCount && i < origOffsets.length; i++) {
                offsets[i] = origOffsets[i];
            }
            for (int i = origStringCount; i < totalCount; i++) {
                offsets[i] = origRegionLen + appended.size();
                encodeString(appended, strings.get(i));
            }

            byte[] appendedBytes = appended.toByteArray();
            int stringDataLen = origRegionLen + appendedBytes.length;
            int padding = (4 - (stringDataLen % 4)) % 4;

            int headerSize = 28;
            // Styles are dropped on rebuild, so no style offset table is emitted.
            int newStringsOffset = headerSize + totalCount * 4;
            int totalSize = newStringsOffset + stringDataLen + padding;
            int newFlags = flags & ~SORTED_FLAG;

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            writeLE16(out, STRING_POOL_TYPE);
            writeLE16(out, headerSize);
            writeLE32(out, totalSize);
            writeLE32(out, totalCount);
            writeLE32(out, 0);              // styleCount (styles dropped)
            writeLE32(out, newFlags);
            writeLE32(out, newStringsOffset);
            writeLE32(out, 0);              // stylesOffset
            for (int off : offsets) {
                writeLE32(out, off);
            }
            out.write(data, origStringsStart, origRegionLen);
            out.write(appendedBytes, 0, appendedBytes.length);
            for (int i = 0; i < padding; i++) {
                out.write(0);
            }
            return out.toByteArray();
        } catch (Exception e) {
            // Fall back to the original pool bytes on any failure.
            byte[] orig = new byte[poolEnd - poolStart];
            System.arraycopy(data, poolStart, orig, 0, orig.length);
            return orig;
        }
    }

    private void encodeString(ByteArrayOutputStream out, String value) {
        String str = value == null ? "" : value;
        if (isUtf8) {
            byte[] bytes = str.getBytes(StandardCharsets.UTF_8);
            writeUtf8Len(out, str.length());
            writeUtf8Len(out, bytes.length);
            out.write(bytes, 0, bytes.length);
            out.write(0);
        } else {
            int charLen = str.length();
            if (charLen > 0x7FFF) {
                out.write(((charLen >> 16) & 0x7FFF) | 0x80);
                out.write((charLen >> 24) & 0xFF);
            }
            out.write(charLen & 0xFF);
            out.write((charLen >> 8) & 0xFF);
            for (int j = 0; j < str.length(); j++) {
                char ch = str.charAt(j);
                out.write(ch & 0xFF);
                out.write((ch >> 8) & 0xFF);
            }
            out.write(0);
            out.write(0);
        }
    }

    private static void writeUtf8Len(ByteArrayOutputStream out, int len) {
        if (len > 0x7F) {
            out.write(((len >> 8) & 0x7F) | 0x80);
            out.write(len & 0xFF);
        } else {
            out.write(len);
        }
    }

    private static void writeLE16(ByteArrayOutputStream out, int value) {
        out.write(value & 0xFF);
        out.write((value >> 8) & 0xFF);
    }

    private static void writeLE32(ByteArrayOutputStream out, int value) {
        out.write(value & 0xFF);
        out.write((value >> 8) & 0xFF);
        out.write((value >> 16) & 0xFF);
        out.write((value >> 24) & 0xFF);
    }
}
