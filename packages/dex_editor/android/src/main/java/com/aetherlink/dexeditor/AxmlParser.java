package com.aetherlink.dexeditor;

import android.util.Log;

/**
 * 简单的 AXML (Android Binary XML) 解析器
 * 用于解码 APK 中的二进制 XML 文件
 */
public class AxmlParser {

    private static final String TAG = "AxmlParser";

    // AXML 文件头魔数
    private static final int AXML_MAGIC = 0x00080003;
    private static final int STRING_POOL_TYPE = 0x0001;
    private static final int XML_START_TAG = 0x0102;
    private static final int XML_END_TAG = 0x0103;
    private static final int XML_START_NAMESPACE = 0x0100;
    private static final int XML_END_NAMESPACE = 0x0101;

    private byte[] data;
    private int position;
    private String[] stringPool;
    private StringBuilder xml;
    private int indent = 0;

    /**
     * 解码 AXML 数据为可读 XML 字符串
     */
    public static String decode(byte[] data) {
        try {
            AxmlParser parser = new AxmlParser();
            return parser.parse(data);
        } catch (Exception e) {
            Log.e(TAG, "AXML parse error", e);
            return "<!-- AXML Parse Error: " + e.getMessage() + " -->";
        }
    }

    private String parse(byte[] data) throws Exception {
        this.data = data;
        this.position = 0;
        this.xml = new StringBuilder();
        this.xml.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");

        // 读取文件头
        int magic = readInt();
        if (magic != AXML_MAGIC) {
            throw new Exception("Invalid AXML magic: 0x" + Integer.toHexString(magic));
        }

        int fileSize = readInt();

        // 解析 chunks
        while (position < data.length - 8) {
            int chunkStart = position;
            int chunkType = readShort();
            int headerSize = readShort();
            int chunkSize = readInt();

            if (chunkSize <= 0 || chunkStart + chunkSize > data.length) {
                break;
            }

            switch (chunkType) {
                case STRING_POOL_TYPE:
                    parseStringPool(chunkStart, chunkSize);
                    break;
                case XML_START_NAMESPACE:
                case XML_END_NAMESPACE:
                    // 跳过命名空间
                    break;
                case XML_START_TAG:
                    parseStartTag();
                    break;
                case XML_END_TAG:
                    parseEndTag();
                    break;
                default:
                    // 跳过未知 chunk
                    break;
            }

            // 移动到下一个 chunk
            position = chunkStart + chunkSize;
        }

        return xml.toString();
    }

    private void parseStringPool(int chunkStart, int chunkSize) {
        int stringCount = readInt();
        int styleCount = readInt();
        int flags = readInt();
        int stringsOffset = readInt();
        int stylesOffset = readInt();

        boolean isUtf8 = (flags & 0x100) != 0;

        // 读取字符串偏移表
        int[] offsets = new int[stringCount];
        for (int i = 0; i < stringCount; i++) {
            offsets[i] = readInt();
        }

        // 字符串数据开始位置
        int stringsStart = chunkStart + stringsOffset;
        stringPool = new String[stringCount];

        for (int i = 0; i < stringCount; i++) {
            int stringStart = stringsStart + offsets[i];
            if (stringStart >= data.length) {
                stringPool[i] = "";
                continue;
            }
            stringPool[i] = readStringAt(stringStart, isUtf8);
        }
    }

    private String readStringAt(int pos, boolean isUtf8) {
        try {
            if (isUtf8) {
                // UTF-8: 先读长度
                int charLen = data[pos] & 0xFF;
                int byteLen;
                int dataStart;

                if ((charLen & 0x80) != 0) {
                    charLen = ((charLen & 0x7F) << 8) | (data[pos + 1] & 0xFF);
                    byteLen = data[pos + 2] & 0xFF;
                    if ((byteLen & 0x80) != 0) {
                        byteLen = ((byteLen & 0x7F) << 8) | (data[pos + 3] & 0xFF);
                        dataStart = pos + 4;
                    } else {
                        dataStart = pos + 3;
                    }
                } else {
                    byteLen = data[pos + 1] & 0xFF;
                    if ((byteLen & 0x80) != 0) {
                        byteLen = ((byteLen & 0x7F) << 8) | (data[pos + 2] & 0xFF);
                        dataStart = pos + 3;
                    } else {
                        dataStart = pos + 2;
                    }
                }

                if (dataStart + byteLen > data.length) {
                    byteLen = data.length - dataStart;
                }
                if (byteLen <= 0) return "";

                return new String(data, dataStart, byteLen, java.nio.charset.StandardCharsets.UTF_8);
            } else {
                // UTF-16
                int charLen = (data[pos] & 0xFF) | ((data[pos + 1] & 0xFF) << 8);
                if ((charLen & 0x8000) != 0) {
                    int high = (data[pos + 2] & 0xFF) | ((data[pos + 3] & 0xFF) << 8);
                    charLen = ((charLen & 0x7FFF) << 16) | high;
                    pos += 4;
                } else {
                    pos += 2;
                }

                if (pos + charLen * 2 > data.length) {
                    charLen = (data.length - pos) / 2;
                }
                if (charLen <= 0) return "";

                char[] chars = new char[charLen];
                for (int i = 0; i < charLen; i++) {
                    chars[i] = (char) ((data[pos + i * 2] & 0xFF) | ((data[pos + i * 2 + 1] & 0xFF) << 8));
                }
                return new String(chars);
            }
        } catch (Exception e) {
            return "";
        }
    }

    private void parseStartTag() {
        int lineNumber = readInt();
        int comment = readInt();
        int ns = readInt();
        int name = readInt();
        int attrStart = readShort();
        int attrSize = readShort();
        int attrCount = readShort();
        int idIndex = readShort();
        int classIndex = readShort();
        int styleIndex = readShort();

        // 缩进
        for (int i = 0; i < indent; i++) {
            xml.append("  ");
        }

        xml.append("<").append(getString(name));

        // 解析属性
        for (int i = 0; i < attrCount; i++) {
            int attrNs = readInt();
            int attrName = readInt();
            int attrRawValue = readInt();
            int attrTypeAndSize = readInt();
            int attrData = readInt();

            int attrType = (attrTypeAndSize >> 24) & 0xFF;

            xml.append("\n");
            for (int j = 0; j <= indent; j++) {
                xml.append("  ");
            }

            // 命名空间前缀
            String nsStr = getString(attrNs);
            if (nsStr.contains("android")) {
                xml.append("android:");
            }

            xml.append(getString(attrName)).append("=\"");
            xml.append(escapeXml(getAttrValue(attrRawValue, attrType, attrData)));
            xml.append("\"");
        }

        xml.append(">\n");
        indent++;
    }

    private void parseEndTag() {
        int lineNumber = readInt();
        int comment = readInt();
        int ns = readInt();
        int name = readInt();

        indent--;
        for (int i = 0; i < indent; i++) {
            xml.append("  ");
        }
        xml.append("</").append(getString(name)).append(">\n");
    }

    private String getString(int index) {
        if (stringPool != null && index >= 0 && index < stringPool.length) {
            return stringPool[index] != null ? stringPool[index] : "";
        }
        return "";
    }

    private String getAttrValue(int rawValue, int type, int data) {
        // 优先使用原始字符串
        if (rawValue >= 0 && stringPool != null && rawValue < stringPool.length && stringPool[rawValue] != null) {
            return stringPool[rawValue];
        }

        switch (type) {
            case 0x01: return "@0x" + Integer.toHexString(data);
            case 0x02: return "?0x" + Integer.toHexString(data);
            case 0x03:
                if (data >= 0 && stringPool != null && data < stringPool.length) {
                    return stringPool[data] != null ? stringPool[data] : "";
                }
                return "";
            case 0x10: return String.valueOf(data);
            case 0x11: return "0x" + Integer.toHexString(data);
            case 0x12: return data != 0 ? "true" : "false";
            case 0x1C: return String.format("#%08X", data);
            case 0x1D: return String.format("#%06X", data & 0xFFFFFF);
            case 0x05: return String.format("%.1fdip", Float.intBitsToFloat(data));
            case 0x06: return String.format("%.1fsp", Float.intBitsToFloat(data));
            default: return "0x" + Integer.toHexString(data);
        }
    }

    private int readInt() {
        if (position + 4 > data.length) return 0;
        int result = (data[position] & 0xFF) |
                ((data[position + 1] & 0xFF) << 8) |
                ((data[position + 2] & 0xFF) << 16) |
                ((data[position + 3] & 0xFF) << 24);
        position += 4;
        return result;
    }

    private int readShort() {
        if (position + 2 > data.length) return 0;
        int result = (data[position] & 0xFF) | ((data[position + 1] & 0xFF) << 8);
        position += 2;
        return result;
    }

    private String escapeXml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
