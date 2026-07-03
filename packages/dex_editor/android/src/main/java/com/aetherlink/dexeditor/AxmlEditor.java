package com.aetherlink.dexeditor;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * AXML 编辑器 - 支持任意长度的字符串替换
 * 通过重建字符串池实现
 */
public class AxmlEditor {

    private static final int AXML_MAGIC = 0x00080003;
    private static final int STRING_POOL_TYPE = 0x0001;

    private byte[] data;
    private int stringPoolStart;
    private int stringPoolSize;
    private int stringCount;
    private int styleCount;
    private int flags;
    private int stringsOffset;
    private int stylesOffset;
    private List<String> strings;
    private byte[] beforeStringPool;
    private byte[] afterStringPool;
    private boolean isUtf8;

    public AxmlEditor(byte[] axmlData) {
        this.data = axmlData;
        this.strings = new ArrayList<>();
        parse();
    }

    private void parse() {
        if (data.length < 8) return;

        ByteBuffer buffer = ByteBuffer.wrap(data);
        buffer.order(ByteOrder.LITTLE_ENDIAN);

        // 检查魔数
        int magic = buffer.getInt();
        if (magic != AXML_MAGIC) return;

        int fileSize = buffer.getInt();

        // 查找字符串池
        while (buffer.position() < data.length - 8) {
            int chunkStart = buffer.position();
            int chunkType = buffer.getShort() & 0xFFFF;
            int headerSize = buffer.getShort() & 0xFFFF;
            int chunkSize = buffer.getInt();

            if (chunkType == STRING_POOL_TYPE) {
                stringPoolStart = chunkStart;
                stringPoolSize = chunkSize;

                // 保存字符串池之前的数据
                beforeStringPool = new byte[chunkStart];
                System.arraycopy(data, 0, beforeStringPool, 0, chunkStart);

                // 保存字符串池之后的数据
                int afterStart = chunkStart + chunkSize;
                if (afterStart < data.length) {
                    afterStringPool = new byte[data.length - afterStart];
                    System.arraycopy(data, afterStart, afterStringPool, 0, afterStringPool.length);
                } else {
                    afterStringPool = new byte[0];
                }

                // 解析字符串池
                stringCount = buffer.getInt();
                styleCount = buffer.getInt();
                flags = buffer.getInt();
                stringsOffset = buffer.getInt();
                stylesOffset = buffer.getInt();

                isUtf8 = (flags & 0x100) != 0;

                // 读取字符串偏移表
                int[] offsets = new int[stringCount];
                for (int i = 0; i < stringCount; i++) {
                    offsets[i] = buffer.getInt();
                }

                // 读取字符串
                int stringsStart = chunkStart + stringsOffset;
                for (int i = 0; i < stringCount; i++) {
                    int stringStart = stringsStart + offsets[i];
                    if (stringStart < data.length) {
                        strings.add(readStringAt(stringStart));
                    } else {
                        strings.add("");
                    }
                }

                break;
            }

            buffer.position(chunkStart + chunkSize);
        }
    }

    private String readStringAt(int pos) {
        try {
            if (isUtf8) {
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

                return new String(data, dataStart, byteLen, StandardCharsets.UTF_8);
            } else {
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

    /**
     * 替换字符串
     * @return 替换的次数
     */
    public int replaceString(String oldValue, String newValue) {
        int count = 0;
        for (int i = 0; i < strings.size(); i++) {
            String str = strings.get(i);
            if (str != null && str.contains(oldValue)) {
                strings.set(i, str.replace(oldValue, newValue));
                count++;
            }
        }
        return count;
    }

    /**
     * 构建修改后的 AXML 数据
     */
    public byte[] build() {
        if (strings.isEmpty() || beforeStringPool == null) {
            return data;
        }

        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();

            // 写入字符串池之前的数据
            baos.write(beforeStringPool);

            // 构建新的字符串池
            byte[] newStringPool = buildStringPool();
            baos.write(newStringPool);

            // 写入字符串池之后的数据
            baos.write(afterStringPool);

            // 更新文件大小
            byte[] result = baos.toByteArray();
            int newFileSize = result.length;

            // 更新文件头中的大小
            result[4] = (byte) (newFileSize & 0xFF);
            result[5] = (byte) ((newFileSize >> 8) & 0xFF);
            result[6] = (byte) ((newFileSize >> 16) & 0xFF);
            result[7] = (byte) ((newFileSize >> 24) & 0xFF);

            return result;
        } catch (Exception e) {
            return data;
        }
    }

    private byte[] buildStringPool() throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        // 先构建字符串数据
        ByteArrayOutputStream stringData = new ByteArrayOutputStream();
        int[] offsets = new int[strings.size()];

        for (int i = 0; i < strings.size(); i++) {
            offsets[i] = stringData.size();
            String str = strings.get(i);
            if (str == null) str = "";

            if (isUtf8) {
                byte[] bytes = str.getBytes(StandardCharsets.UTF_8);
                int charLen = str.length();
                int byteLen = bytes.length;

                // 写入字符长度
                if (charLen > 127) {
                    stringData.write((charLen >> 8) | 0x80);
                    stringData.write(charLen & 0xFF);
                } else {
                    stringData.write(charLen);
                }

                // 写入字节长度
                if (byteLen > 127) {
                    stringData.write((byteLen >> 8) | 0x80);
                    stringData.write(byteLen & 0xFF);
                } else {
                    stringData.write(byteLen);
                }

                // 写入字符串数据
                stringData.write(bytes);
                stringData.write(0); // null terminator
            } else {
                // UTF-16
                int charLen = str.length();
                if (charLen > 0x7FFF) {
                    stringData.write((charLen & 0xFF) | 0x80);
                    stringData.write((charLen >> 8) | 0x80);
                    stringData.write((charLen >> 16) & 0xFF);
                    stringData.write((charLen >> 24) & 0xFF);
                } else {
                    stringData.write(charLen & 0xFF);
                    stringData.write((charLen >> 8) & 0xFF);
                }

                for (int j = 0; j < str.length(); j++) {
                    char c = str.charAt(j);
                    stringData.write(c & 0xFF);
                    stringData.write((c >> 8) & 0xFF);
                }
                // null terminator
                stringData.write(0);
                stringData.write(0);
            }
        }

        // 计算头部大小
        int headerSize = 28; // 固定头部
        int offsetTableSize = strings.size() * 4;
        int styleOffsetTableSize = styleCount * 4;
        int stringsDataSize = stringData.size();

        // 对齐到 4 字节
        int padding = (4 - (stringsDataSize % 4)) % 4;
        stringsDataSize += padding;

        int newStringsOffset = headerSize + offsetTableSize + styleOffsetTableSize;
        int totalSize = newStringsOffset + stringsDataSize;

        // 写入 chunk 头
        ByteBuffer header = ByteBuffer.allocate(headerSize);
        header.order(ByteOrder.LITTLE_ENDIAN);
        header.putShort((short) STRING_POOL_TYPE); // type
        header.putShort((short) headerSize); // header size
        header.putInt(totalSize); // chunk size
        header.putInt(strings.size()); // string count
        header.putInt(styleCount); // style count
        header.putInt(flags); // flags
        header.putInt(newStringsOffset); // strings offset
        header.putInt(0); // styles offset (暂不支持)

        baos.write(header.array());

        // 写入偏移表
        for (int offset : offsets) {
            baos.write(offset & 0xFF);
            baos.write((offset >> 8) & 0xFF);
            baos.write((offset >> 16) & 0xFF);
            baos.write((offset >> 24) & 0xFF);
        }

        // 写入样式偏移表（空）
        for (int i = 0; i < styleCount; i++) {
            baos.write(0);
            baos.write(0);
            baos.write(0);
            baos.write(0);
        }

        // 写入字符串数据
        baos.write(stringData.toByteArray());

        // 写入对齐填充
        for (int i = 0; i < padding; i++) {
            baos.write(0);
        }

        return baos.toByteArray();
    }
}
