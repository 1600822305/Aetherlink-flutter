package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSObject;
import com.aetherlink.dexeditor.utils.FileUtils;

import com.android.tools.smali.dexlib2.iface.ClassDef;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * SmaliOps - Smali 反汇编/汇编与 Smali↔Java 转换（均基于 C++ 实现）。
 *
 * 从 {@link DexManager} 的「Smali 操作」「Smali 转 Java」段抽出：
 *  - {@link #classToSmali}：把类转成 Smali；
 *  - {@link #smaliToClass}：编译 Smali 并加入会话；
 *  - {@link #disassemble}：整包反汇编到目录；
 *  - {@link #assemble}：汇编 Smali 目录为 DEX；
 *  - {@link #smaliToJava}：Smali 转 Java 伪代码（多 DEX 会话）。
 *
 * 会话查找、Smali 编译、类型转换等能力仍由 DexManager 提供，通过 dex 引用回调；
 * 仅被 assemble/disassemble 使用的文件读写 helper 一并迁入本类（委托 FileUtils）。
 */
class SmaliOps {

    private static final String TAG = "SmaliOps";

    private final DexManager dex;

    SmaliOps(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 将类转换为 Smali 代码（优先使用 C++ 实现）
     */
    JSObject classToSmali(String sessionId, String className) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        
        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.getClassSmali(session.dexBytes, className);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    String smali = cppResult.optString("smali", "");
                    if (!smali.isEmpty()) {
                        JSObject result = new JSObject();
                        result.put("className", className);
                        result.put("smali", smali);
                        result.put("engine", "cpp");
                        return result;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ classToSmali failed", e);
                throw new Exception("C++ classToSmali failed: " + e.getMessage());
            }
        }
        
        throw new UnsupportedOperationException("C++ library not available for classToSmali");
    }

    /**
     * 将 Smali 代码编译为类并添加到 DEX
     */
    void smaliToClass(String sessionId, String smaliCode) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef newClass = dex.compileSmaliToClass(smaliCode, session.originalDexFile.getOpcodes());
        session.modifiedClasses.add(newClass);
        session.modified = true;
    }

    /**
     * 反汇编整个 DEX 到目录（优先使用 C++ 实现）
     */
    void disassemble(String sessionId, String outputDir) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        File outDir = new File(outputDir);
        outDir.mkdirs();

        // 优先使用 C++ 实现 - 逐个类反汇编
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                // 获取所有类
                String classesJson = CppDex.listClasses(session.dexBytes, "", 0, 10000);
                if (classesJson != null && !classesJson.contains("\"error\"")) {
                    org.json.JSONObject result = new org.json.JSONObject(classesJson);
                    org.json.JSONArray classes = result.optJSONArray("classes");
                    if (classes != null) {
                        for (int i = 0; i < classes.length(); i++) {
                            String className = classes.getJSONObject(i).optString("className");
                            try {
                                String smaliJson = CppDex.getClassSmali(session.dexBytes, className);
                                if (smaliJson != null && !smaliJson.contains("\"error\"")) {
                                    org.json.JSONObject smaliResult = new org.json.JSONObject(smaliJson);
                                    String smali = smaliResult.optString("smali", "");
                                    if (!smali.isEmpty()) {
                                        // 保存到文件
                                        String filePath = className.substring(1, className.length() - 1) + ".smali";
                                        File smaliFile = new File(outDir, filePath);
                                        smaliFile.getParentFile().mkdirs();
                                        writeFileContent(smaliFile, smali);
                                    }
                                }
                            } catch (Exception e) {
                                Log.w(TAG, "Failed to disassemble class: " + className, e);
                            }
                        }
                        Log.d(TAG, "Disassembled to (C++): " + outputDir);
                        return;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ disassemble failed", e);
                throw new Exception("C++ disassemble failed: " + e.getMessage());
            }
        }

        throw new UnsupportedOperationException("C++ library not available for disassemble");
    }

    /**
     * 汇编 Smali 目录为 DEX（优先使用 C++ 实现）
     */
    JSObject assemble(String smaliDir, String outputPath) throws Exception {
        File inputDir = new File(smaliDir);
        File outputFile = new File(outputPath);

        if (!inputDir.exists() || !inputDir.isDirectory()) {
            throw new IllegalArgumentException("Invalid smali directory: " + smaliDir);
        }

        outputFile.getParentFile().mkdirs();
        
        // 优先使用 C++ 实现
        if (CppDex.isAvailable()) {
            try {
                // 读取所有 smali 文件并合并
                List<File> smaliFiles = collectSmaliFiles(inputDir);
                StringBuilder allSmali = new StringBuilder();
                for (File f : smaliFiles) {
                    allSmali.append(readFileContent(f));
                    allSmali.append("\n\n");
                }
                
                byte[] dexBytes = CppDex.smaliToDex(allSmali.toString());
                if (dexBytes != null && dexBytes.length > 0) {
                    try (java.io.FileOutputStream fos = new java.io.FileOutputStream(outputFile)) {
                        fos.write(dexBytes);
                    }
                    JSObject result = new JSObject();
                    result.put("success", true);
                    result.put("outputPath", outputPath);
                    result.put("engine", "cpp");
                    return result;
                }
            } catch (Exception e) {
                Log.e(TAG, "C++ smaliToDex failed", e);
                throw new Exception("C++ smaliToDex failed: " + e.getMessage());
            }
        }

        throw new UnsupportedOperationException("C++ library not available for smaliToDex");
    }

    /**
     * 将 Smali 代码转换为 Java 伪代码
     */
    JSObject smaliToJava(String sessionId, String className) throws Exception {
        // dex_open 创建的是多 DEX 会话，查不到时按 apkPath 落盘元数据惰性重建。
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        if (!CppDex.isAvailable()) {
            throw new UnsupportedOperationException("C++ library not available for smali to java conversion");
        }

        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换后再查询。
        String targetType = dex.convertClassNameToType(className);
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String jsonResult = CppDex.smaliToJava(entry.getValue(), targetType);
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                JSObject result = new JSObject();
                result.put("className", className);
                result.put("dexFile", entry.getKey());
                result.put("java", cppResult.optString("java", ""));
                return result;
            }
        }

        throw new IllegalArgumentException("Class not found: " + className);
    }

    // ==================== 工具方法委托到 FileUtils ====================

    private List<File> collectSmaliFiles(File dir) {
        return FileUtils.collectSmaliFiles(dir);
    }

    private String readFileContent(File file) throws IOException {
        return FileUtils.readFileContent(file);
    }

    private void writeFileContent(File file, String content) throws IOException {
        FileUtils.writeFileContent(file, content);
    }
}
