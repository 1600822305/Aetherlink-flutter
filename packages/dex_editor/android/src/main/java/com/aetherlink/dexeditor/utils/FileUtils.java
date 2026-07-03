package com.aetherlink.dexeditor.utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * FileUtils - 文件操作工具类
 */
public class FileUtils {

    /**
     * 递归收集目录下的所有 Smali 文件
     * @param dir 目录
     * @return Smali 文件列表
     */
    public static List<File> collectSmaliFiles(File dir) {
        List<File> files = new ArrayList<>();
        File[] children = dir.listFiles();
        if (children != null) {
            for (File child : children) {
                if (child.isDirectory()) {
                    files.addAll(collectSmaliFiles(child));
                } else if (child.getName().endsWith(".smali")) {
                    files.add(child);
                }
            }
        }
        return files;
    }

    /**
     * 读取文件内容为字符串
     * @param file 文件
     * @return 文件内容
     */
    public static String readFileContent(File file) throws IOException {
        StringBuilder content = new StringBuilder();
        try (java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.FileReader(file))) {
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
        }
        return content.toString();
    }

    /**
     * 将字符串写入文件
     * @param file 文件
     * @param content 内容
     */
    public static void writeFileContent(File file, String content) throws IOException {
        try (java.io.BufferedWriter writer = new java.io.BufferedWriter(new java.io.FileWriter(file))) {
            writer.write(content);
        }
    }

    /**
     * 读取文件内容为字节数组
     * @param file 文件
     * @return 文件字节
     */
    public static byte[] readFileBytes(File file) throws IOException {
        byte[] bytes = new byte[(int) file.length()];
        try (FileInputStream fis = new FileInputStream(file)) {
            fis.read(bytes);
        }
        return bytes;
    }

    /**
     * 递归删除文件或目录
     * @param file 文件或目录
     */
    public static void deleteRecursive(File file) {
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursive(child);
                }
            }
        }
        file.delete();
    }
}
