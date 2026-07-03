package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;
import com.android.tools.smali.dexlib2.iface.MethodImplementation;
import com.android.tools.smali.dexlib2.iface.instruction.Instruction;

import java.io.IOException;
import java.util.HashSet;
import java.util.Set;

/**
 * ApkDexReader - 直接从 APK 里读取/解析 DEX 的只读操作（无需编辑会话）。
 *
 * 从 {@link DexManager} 抽出（原「APK 内 DEX 操作（无需会话）」一段）：
 *  - {@link #listDexClassesFromApk}：列出某 DEX 的所有类；
 *  - {@link #getDexStringsFromApk}：抽取字符串常量池；
 *  - {@link #searchInDexFromApk}：在某 DEX 内搜索类/方法/指令。
 *
 * 均自行从 zip 读取 DEX 字节并用 dexlib2 解析，不触碰会话状态；
 * 类型描述符转换仍复用 DexManager 的 convertTypeToClassName。
 */
class ApkDexReader {

    private static final String TAG = "ApkDexReader";

    private final DexManager dex;

    ApkDexReader(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 从 APK 中的 DEX 文件列出所有类
     * @param apkPath APK 文件路径
     * @param dexPath DEX 文件在 APK 中的路径（如 "classes.dex"）
     */
    JSObject listDexClassesFromApk(String apkPath, String dexPath) throws Exception {
        JSObject result = new JSObject();
        JSArray classes = new JSArray();

        java.util.zip.ZipFile zipFile = null;
        java.io.InputStream dexInputStream = null;

        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.zip.ZipEntry dexEntry = zipFile.getEntry(dexPath);

            if (dexEntry == null) {
                throw new IOException("DEX file not found in APK: " + dexPath);
            }

            dexInputStream = zipFile.getInputStream(dexEntry);

            // 读取 DEX 文件到内存
            java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = dexInputStream.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            byte[] dexBytes = baos.toByteArray();

            // 解析 DEX 文件
            DexBackedDexFile dexFile = new DexBackedDexFile(Opcodes.getDefault(), dexBytes);

            // 收集所有类名
            for (ClassDef classDef : dexFile.getClasses()) {
                String type = classDef.getType();
                // 转换 Lcom/example/Class; 格式为 com.example.Class
                String className = dex.convertTypeToClassName(type);
                classes.put(className);
            }

            result.put("classes", classes);
            result.put("count", classes.length());

        } finally {
            if (dexInputStream != null) {
                try { dexInputStream.close(); } catch (Exception ignored) {}
            }
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }

        return result;
    }

    /**
     * 从 APK 中的 DEX 文件获取字符串常量池
     */
    JSObject getDexStringsFromApk(String apkPath, String dexPath) throws Exception {
        JSObject result = new JSObject();
        JSArray strings = new JSArray();

        java.util.zip.ZipFile zipFile = null;
        java.io.InputStream dexInputStream = null;

        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.zip.ZipEntry dexEntry = zipFile.getEntry(dexPath);

            if (dexEntry == null) {
                throw new IOException("DEX file not found in APK: " + dexPath);
            }

            dexInputStream = zipFile.getInputStream(dexEntry);

            // 读取 DEX 文件到内存
            java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = dexInputStream.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            byte[] dexBytes = baos.toByteArray();

            // 解析 DEX 文件
            DexBackedDexFile dexFile = new DexBackedDexFile(Opcodes.getDefault(), dexBytes);

            // 从类和方法中提取所有字符串引用
            Set<String> uniqueStrings = new HashSet<>();
            int index = 0;

            for (ClassDef classDef : dexFile.getClasses()) {
                // 添加类名
                String className = classDef.getType();
                if (className != null && !uniqueStrings.contains(className)) {
                    uniqueStrings.add(className);
                }

                // 从字段中提取
                for (Field field : classDef.getFields()) {
                    String fieldName = field.getName();
                    String fieldType = field.getType();
                    if (fieldName != null && !uniqueStrings.contains(fieldName)) {
                        uniqueStrings.add(fieldName);
                    }
                    if (fieldType != null && !uniqueStrings.contains(fieldType)) {
                        uniqueStrings.add(fieldType);
                    }
                }

                // 从方法中提取
                for (Method method : classDef.getMethods()) {
                    String methodName = method.getName();
                    if (methodName != null && !uniqueStrings.contains(methodName)) {
                        uniqueStrings.add(methodName);
                    }

                    // 从方法实现中提取字符串常量
                    MethodImplementation impl = method.getImplementation();
                    if (impl != null) {
                        for (Instruction instruction : impl.getInstructions()) {
                            // 检查是否是字符串引用指令
                            if (instruction instanceof com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction) {
                                com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction refInstr =
                                    (com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction) instruction;
                                com.android.tools.smali.dexlib2.iface.reference.Reference ref = refInstr.getReference();
                                if (ref instanceof com.android.tools.smali.dexlib2.iface.reference.StringReference) {
                                    String str = ((com.android.tools.smali.dexlib2.iface.reference.StringReference) ref).getString();
                                    if (str != null && !uniqueStrings.contains(str)) {
                                        uniqueStrings.add(str);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 转换为数组
            for (String str : uniqueStrings) {
                JSObject item = new JSObject();
                item.put("index", index++);
                item.put("value", str);
                strings.put(item);
            }

            result.put("strings", strings);
            result.put("count", strings.length());

        } finally {
            if (dexInputStream != null) {
                try { dexInputStream.close(); } catch (Exception ignored) {}
            }
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }

        return result;
    }

    /**
     * 在 APK 中的 DEX 文件中搜索
     */
    JSObject searchInDexFromApk(String apkPath, String dexPath, String query) throws Exception {
        JSObject result = new JSObject();
        JSArray results = new JSArray();

        Log.d(TAG, "searchInDexFromApk: apkPath=" + apkPath + ", dexPath=" + dexPath + ", query=" + query);

        if (query == null || query.isEmpty()) {
            result.put("results", results);
            result.put("count", 0);
            return result;
        }

        String queryLower = query.toLowerCase();

        java.util.zip.ZipFile zipFile = null;
        java.io.InputStream dexInputStream = null;

        try {
            zipFile = new java.util.zip.ZipFile(apkPath);

            // 尝试多种可能的 dexPath 格式
            java.util.zip.ZipEntry dexEntry = zipFile.getEntry(dexPath);
            if (dexEntry == null && !dexPath.startsWith("/")) {
                // 如果没有找到，尝试去掉开头的斜杠
                dexEntry = zipFile.getEntry(dexPath.replaceFirst("^/+", ""));
            }
            if (dexEntry == null) {
                // 如果还是没找到，尝试只用文件名
                String fileName = dexPath;
                if (dexPath.contains("/")) {
                    fileName = dexPath.substring(dexPath.lastIndexOf("/") + 1);
                }
                dexEntry = zipFile.getEntry(fileName);
            }

            if (dexEntry == null) {
                Log.e(TAG, "DEX file not found in APK: " + dexPath);
                throw new IOException("DEX file not found in APK: " + dexPath);
            }

            Log.d(TAG, "Found DEX entry: " + dexEntry.getName());

            dexInputStream = zipFile.getInputStream(dexEntry);

            // 读取 DEX 文件到内存
            java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = dexInputStream.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            byte[] dexBytes = baos.toByteArray();

            // 解析 DEX 文件
            DexBackedDexFile dexFile = new DexBackedDexFile(Opcodes.getDefault(), dexBytes);

            // 搜索类名和方法名
            for (ClassDef classDef : dexFile.getClasses()) {
                String className = dex.convertTypeToClassName(classDef.getType());

                // 搜索类名
                if (className.toLowerCase().contains(queryLower)) {
                    JSObject item = new JSObject();
                    item.put("className", className);
                    item.put("type", "class");
                    item.put("content", className);
                    results.put(item);
                }

                // 搜索方法名
                for (Method method : classDef.getMethods()) {
                    String methodName = method.getName();
                    if (methodName.toLowerCase().contains(queryLower)) {
                        JSObject item = new JSObject();
                        item.put("className", className);
                        item.put("methodName", methodName);
                        item.put("type", "method");
                        item.put("content", methodName + " in " + className);
                        results.put(item);
                    }

                    // 搜索方法内的字符串
                    MethodImplementation impl = method.getImplementation();
                    if (impl != null) {
                        for (Instruction instruction : impl.getInstructions()) {
                            String instrStr = instruction.toString();
                            if (instrStr.toLowerCase().contains(queryLower)) {
                                JSObject item = new JSObject();
                                item.put("className", className);
                                item.put("methodName", methodName);
                                item.put("type", "instruction");
                                item.put("content", instrStr);
                                results.put(item);
                                break; // 每个方法只记录一次
                            }
                        }
                    }
                }
            }

            result.put("results", results);
            result.put("count", results.length());

        } finally {
            if (dexInputStream != null) {
                try { dexInputStream.close(); } catch (Exception ignored) {}
            }
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }

        return result;
    }
}
