package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.DexFileFactory;
import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.rewriter.DexRewriter;
import com.android.tools.smali.dexlib2.rewriter.Rewriter;
import com.android.tools.smali.dexlib2.rewriter.RewriterModule;
import com.android.tools.smali.dexlib2.rewriter.Rewriters;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedClassDef;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedField;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedMethod;
import com.android.tools.smali.dexlib2.iface.Annotation;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.DexFile;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;
import com.android.tools.smali.dexlib2.iface.MethodImplementation;
import com.android.tools.smali.dexlib2.iface.instruction.Instruction;
import com.android.tools.smali.dexlib2.immutable.ImmutableClassDef;
import com.android.tools.smali.dexlib2.immutable.ImmutableDexFile;
import com.android.tools.smali.dexlib2.immutable.ImmutableField;
import com.android.tools.smali.dexlib2.immutable.ImmutableMethod;
import com.android.tools.smali.dexlib2.writer.io.FileDataStore;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;
// smali 依赖已移除 - 使用 C++ 实现

import org.json.JSONArray;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

import com.aetherlink.dexeditor.utils.SmaliUtils;
import com.aetherlink.dexeditor.utils.FileUtils;
import com.aetherlink.dexeditor.ops.ApkResourceOperations;

/**
 * DexManager - 封装 dexlib2 全部功能
 * 管理多个 DEX 会话，支持加载、编辑、保存 DEX 文件
 */
public class DexManager {

    private static final String TAG = "DexManager";
    
    /**
     * 编译进度回调接口
     */
    public interface CompileProgress {
        void onProgress(int current, int total);
        void onMessage(String message);
        void onTitle(String title);
    }
    
    // 当前进度回调
    private CompileProgress progressCallback;
    
    public void setProgressCallback(CompileProgress callback) {
        this.progressCallback = callback;
    }
    
    private void reportProgress(int current, int total) {
        if (progressCallback != null) {
            progressCallback.onProgress(current, total);
        }
    }
    
    private void reportMessage(String message) {
        if (progressCallback != null) {
            progressCallback.onMessage(message);
        }
    }
    
    private void reportTitle(String title) {
        if (progressCallback != null) {
            progressCallback.onTitle(title);
        }
    }
    
    // 会话存储与生命周期（已抽出到 DexSessionManager，持有单/多 DEX 两套会话表）
    private final DexSessionManager sessionManager = new DexSessionManager();

    // 交叉引用分析（已抽出到独立类，本类仅负责会话查找 + 委派）
    private final DexXrefAnalyzer xrefAnalyzer = new DexXrefAnalyzer();

    // 搜索服务（单 DEX 会话内的字符串/代码/方法/字段搜索）
    private final DexSearchService searchService = new DexSearchService(this);

    // 类/方法/字段 CRUD（单 DEX 会话）
    private final DexEditOps editOps = new DexEditOps(this);

    // APK 内 DEX 只读操作（无需会话）
    private final ApkDexReader apkDexReader = new ApkDexReader(this);
    
    // APK DEX 缓存 - 用于加速编译（key: apkPath + ":" + dexPath）
    private final Map<String, ApkDexCache> apkDexCaches = new HashMap<>();
    
    /**
     * APK DEX 缓存 - 缓存从 APK 读取的 DEX 数据和 ClassDef
     */
    private static class ApkDexCache {
        String apkPath;
        String dexPath;
        long lastModified;
        Map<String, ClassDef> classDefMap; // type -> ClassDef
        int dexVersion;
        byte[] dexBytes; // DEX 原始字节用于 C++ 操作
        
        ApkDexCache(String apkPath, String dexPath) {
            this.apkPath = apkPath;
            this.dexPath = dexPath;
            this.classDefMap = new HashMap<>();
        }
        
        String getCacheKey() {
            return apkPath + ":" + dexPath;
        }
    }

    /**
     * DEX 会话 - 存储加载的 DEX 文件及其修改状态
     */
    static class DexSession {
        String sessionId;
        String filePath;
        DexBackedDexFile originalDexFile;
        byte[] dexBytes;  // DEX 字节数据，用于 C++ 解析
        List<ClassDef> modifiedClasses;
        Set<String> removedClasses;
        boolean modified = false;

        DexSession(String sessionId, String filePath, DexBackedDexFile dexFile, byte[] bytes) {
            this.sessionId = sessionId;
            this.filePath = filePath;
            this.originalDexFile = dexFile;
            this.dexBytes = bytes;
            this.modifiedClasses = new ArrayList<>();
            this.removedClasses = new HashSet<>();
        }
    }

    /**
     * 多 DEX 会话 - 用于 MCP 工作流，支持同时编辑多个 DEX 文件
     */
    static class MultiDexSession {
        String sessionId;
        String apkPath;
        Map<String, DexBackedDexFile> dexFiles;
        Map<String, byte[]> dexBytes;  // DEX 字节数据，用于 Rust 搜索
        Map<String, ClassDef> modifiedClasses;
        boolean modified = false;
        Map<String, DexXrefAnalyzer.ChaNode> chaGraph;  // 会话级缓存的 CHA 类型图（懒构建）

        MultiDexSession(String sessionId, String apkPath) {
            this.sessionId = sessionId;
            this.apkPath = apkPath;
            this.dexFiles = new HashMap<>();
            this.dexBytes = new HashMap<>();
            this.modifiedClasses = new HashMap<>();
        }

        void addDex(String dexName, DexBackedDexFile dexFile, byte[] bytes) {
            this.dexFiles.put(dexName, dexFile);
            if (bytes != null) {
                this.dexBytes.put(dexName, bytes);
            }
        }
    }

    // ==================== DEX 文件操作 ====================

    /**
     * 加载 DEX 文件
     */
    public JSObject loadDex(String path, String sessionId) throws Exception {
        if (path == null || path.isEmpty()) {
            throw new IllegalArgumentException("Path is required");
        }

        File file = new File(path);
        if (!file.exists()) {
            throw new IOException("File not found: " + path);
        }

        // 生成或使用提供的 sessionId
        String sid = (sessionId != null && !sessionId.isEmpty()) ? sessionId : UUID.randomUUID().toString();

        // 读取 DEX 字节数据（用于 C++ 解析）
        byte[] dexBytes = readFileBytes(file);

        // 加载 DEX 文件 (使用官方推荐的 DexFileFactory)
        DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
            file, 
            Opcodes.getDefault()
        );

        // 创建会话
        DexSession session = new DexSession(sid, path, dexFile, dexBytes);
        sessionManager.sessions.put(sid, session);

        Log.d(TAG, "Loaded DEX: " + path + " with session: " + sid);

        JSObject result = new JSObject();
        result.put("sessionId", sid);
        result.put("classCount", dexFile.getClasses().size());
        result.put("dexVersion", dexFile.getOpcodes().api);
        return result;
    }

    /**
     * 保存 DEX 文件（优先使用 C++ 修改的字节数据）
     */
    public void saveDex(String sessionId, String outputPath) throws Exception {
        DexSession session = getSession(sessionId);
        
        File outputFile = new File(outputPath);
        if (outputFile.getParentFile() != null) {
            outputFile.getParentFile().mkdirs();
        }

        // 如果使用 C++ 修改了 dexBytes，直接保存
        if (session.dexBytes != null && session.modified && 
            session.modifiedClasses.isEmpty() && session.removedClasses.isEmpty()) {
            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(outputFile)) {
                fos.write(session.dexBytes);
            }
            Log.d(TAG, "Saved DEX (C++ modified) to: " + outputPath);
            return;
        }

        // Java 回退实现
        DexPool dexPool = new DexPool(session.originalDexFile.getOpcodes());

        Set<String> modifiedClassTypes = new HashSet<>();
        for (ClassDef modifiedClass : session.modifiedClasses) {
            modifiedClassTypes.add(modifiedClass.getType());
            dexPool.internClass(modifiedClass);
        }

        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            String type = classDef.getType();
            if (!session.removedClasses.contains(type) && !modifiedClassTypes.contains(type)) {
                dexPool.internClass(classDef);
            }
        }

        List<ClassDef> allClasses = new ArrayList<>();
        for (ClassDef c : session.modifiedClasses) {
            allClasses.add(c);
        }
        for (ClassDef c : session.originalDexFile.getClasses()) {
            if (!session.removedClasses.contains(c.getType()) && !modifiedClassTypes.contains(c.getType())) {
                allClasses.add(c);
            }
        }
        
        ImmutableDexFile newDexFile = new ImmutableDexFile(session.originalDexFile.getOpcodes(), allClasses);
        DexFileFactory.writeDexFile(outputPath, newDexFile);

        Log.d(TAG, "Saved DEX to: " + outputPath);
    }

    /**
     * 关闭 DEX 会话
     */
    public void closeDex(String sessionId) {
        sessionManager.closeSession(sessionId);
        Log.d(TAG, "Closed session: " + sessionId);
    }

    /**
     * 获取会话的 DEX 字节数据（用于 C++ 操作）
     */
    public byte[] getSessionDexBytes(String sessionId) {
        DexSession session = sessionManager.sessions.get(sessionId);
        return session != null ? session.dexBytes : null;
    }

    /**
     * 获取 DEX 文件信息（优先使用 C++ 实现）
     */
    public JSObject getDexInfo(String sessionId) throws Exception {
        DexSession session = getSession(sessionId);
        
        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.getDexInfo(session.dexBytes);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    JSObject info = new JSObject();
                    info.put("sessionId", sessionId);
                    info.put("filePath", session.filePath);
                    info.put("classCount", cppResult.optInt("classCount", 0));
                    info.put("methodCount", cppResult.optInt("methodCount", 0));
                    info.put("fieldCount", cppResult.optInt("fieldCount", 0));
                    info.put("stringCount", cppResult.optInt("stringCount", 0));
                    info.put("dexVersion", cppResult.optInt("version", 35));
                    info.put("modified", session.modified);
                    info.put("engine", "cpp");
                    return info;
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ getDexInfo failed, fallback to Java", e);
            }
        }
        
        // Java 回退实现
        DexBackedDexFile dexFile = session.originalDexFile;
        JSObject info = new JSObject();
        info.put("sessionId", sessionId);
        info.put("filePath", session.filePath);
        info.put("classCount", dexFile.getClasses().size());
        
        int methodCount = 0;
        int fieldCount = 0;
        for (ClassDef classDef : dexFile.getClasses()) {
            for (Method ignored : classDef.getMethods()) methodCount++;
            for (Field ignored : classDef.getFields()) fieldCount++;
        }
        info.put("methodCount", methodCount);
        info.put("fieldCount", fieldCount);
        info.put("dexVersion", dexFile.getOpcodes().api);
        info.put("modified", session.modified);
        info.put("engine", "java");
        return info;
    }

    // ==================== 类/方法/字段 CRUD（委派到 DexEditOps）====================

    public JSArray getClasses(String sessionId) throws Exception {
        return editOps.getClasses(sessionId);
    }

    public JSObject getClassInfo(String sessionId, String className) throws Exception {
        return editOps.getClassInfo(sessionId, className);
    }

    public void addClass(String sessionId, String smaliCode) throws Exception {
        editOps.addClass(sessionId, smaliCode);
    }

    public void removeClass(String sessionId, String className) throws Exception {
        editOps.removeClass(sessionId, className);
    }

    public void renameClass(String sessionId, String oldName, String newName) throws Exception {
        editOps.renameClass(sessionId, oldName, newName);
    }

    public JSArray getMethods(String sessionId, String className) throws Exception {
        return editOps.getMethods(sessionId, className);
    }

    public JSObject getMethodInfo(String sessionId, String className,
                                  String methodName, String methodSignature) throws Exception {
        return editOps.getMethodInfo(sessionId, className, methodName, methodSignature);
    }

    public JSObject getMethodSmali(String sessionId, String className,
                                   String methodName, String methodSignature) throws Exception {
        return editOps.getMethodSmali(sessionId, className, methodName, methodSignature);
    }

    public void setMethodSmali(String sessionId, String className,
                               String methodName, String methodSignature,
                               String smaliCode) throws Exception {
        editOps.setMethodSmali(sessionId, className, methodName, methodSignature, smaliCode);
    }

    public void addMethod(String sessionId, String className, String smaliCode) throws Exception {
        editOps.addMethod(sessionId, className, smaliCode);
    }

    public void removeMethod(String sessionId, String className,
                             String methodName, String methodSignature) throws Exception {
        editOps.removeMethod(sessionId, className, methodName, methodSignature);
    }

    public JSArray getFields(String sessionId, String className) throws Exception {
        return editOps.getFields(sessionId, className);
    }

    public JSObject getFieldInfo(String sessionId, String className, String fieldName) throws Exception {
        return editOps.getFieldInfo(sessionId, className, fieldName);
    }

    public void addField(String sessionId, String className, String fieldDef) throws Exception {
        editOps.addField(sessionId, className, fieldDef);
    }

    public void removeField(String sessionId, String className, String fieldName) throws Exception {
        editOps.removeField(sessionId, className, fieldName);
    }

    // ==================== Smali 操作 ====================

    /**
     * 将类转换为 Smali 代码（优先使用 C++ 实现）
     */
    public JSObject classToSmali(String sessionId, String className) throws Exception {
        DexSession session = getSession(sessionId);
        
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
    public void smaliToClass(String sessionId, String smaliCode) throws Exception {
        DexSession session = getSession(sessionId);
        ClassDef newClass = compileSmaliToClass(smaliCode, session.originalDexFile.getOpcodes());
        session.modifiedClasses.add(newClass);
        session.modified = true;
    }

    /**
     * 反汇编整个 DEX 到目录（优先使用 C++ 实现）
     */
    public void disassemble(String sessionId, String outputDir) throws Exception {
        DexSession session = getSession(sessionId);
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
                            String className = classes.getString(i);
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
    public JSObject assemble(String smaliDir, String outputPath) throws Exception {
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

    // ==================== 搜索操作 ====================

    /** 搜索字符串（委派到 DexSearchService）。 */
    public JSArray searchString(String sessionId, String query,
                                boolean regex, boolean caseSensitive) throws Exception {
        return searchService.searchString(sessionId, query, regex, caseSensitive);
    }

    /** 搜索代码（委派到 DexSearchService）。 */
    public JSArray searchCode(String sessionId, String query, boolean regex) throws Exception {
        return searchService.searchCode(sessionId, query, regex);
    }

    /** 搜索方法（委派到 DexSearchService）。 */
    public JSArray searchMethod(String sessionId, String query) throws Exception {
        return searchService.searchMethod(sessionId, query);
    }

    /** 搜索字段（委派到 DexSearchService）。 */
    public JSArray searchField(String sessionId, String query) throws Exception {
        return searchService.searchField(sessionId, query);
    }

    // ==================== 交叉引用分析（委派到 DexXrefAnalyzer）====================

    /** 方法交叉引用（C++ 实现，单 DEX 会话）。 */
    public JSObject findMethodXrefs(String sessionId, String className, String methodName) throws Exception {
        return xrefAnalyzer.findMethodXrefs(getSession(sessionId), className, methodName);
    }

    /** 字段交叉引用（C++ 实现，单 DEX 会话）。 */
    public JSObject findFieldXrefs(String sessionId, String className, String fieldName) throws Exception {
        return xrefAnalyzer.findFieldXrefs(getSession(sessionId), className, fieldName);
    }

    /** 方法交叉引用（dexlib2 CHA，多 DEX 会话）。 */
    public JSObject findMethodXrefsCHA(String sessionId, String className, String methodName,
                                       String methodSignature, String resolution, int limit)
            throws Exception {
        return xrefAnalyzer.findMethodXrefsCHA(requireMultiDexSession(sessionId),
                className, methodName, methodSignature, resolution, limit);
    }

    /** 字段交叉引用（dexlib2，多 DEX 会话）。 */
    public JSObject findFieldXrefsCHA(String sessionId, String className, String fieldName,
                                      String fieldType, String access, int limit)
            throws Exception {
        return xrefAnalyzer.findFieldXrefsCHA(requireMultiDexSession(sessionId),
                className, fieldName, fieldType, access, limit);
    }

    /** 类级交叉引用（dexlib2，多 DEX 会话）。 */
    public JSObject findClassXrefsCHA(String sessionId, String className, int limit)
            throws Exception {
        return xrefAnalyzer.findClassXrefsCHA(requireMultiDexSession(sessionId), className, limit);
    }

    private MultiDexSession requireMultiDexSession(String sessionId) {
        return sessionManager.requireMultiDexSession(sessionId);
    }

    // ==================== Smali 转 Java（C++ 实现）====================

    /**
     * 将 Smali 代码转换为 Java 伪代码
     */
    public JSObject smaliToJava(String sessionId, String className) throws Exception {
        // dex_open 创建的是多 DEX 会话，需在 multiDexSessions 中查找并逐个 DEX 定位类。
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        if (!CppDex.isAvailable()) {
            throw new UnsupportedOperationException("C++ library not available for smali to java conversion");
        }

        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换后再查询。
        String targetType = convertClassNameToType(className);
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

    // ==================== 工具操作 ====================

    /**
     * 修复 DEX 文件
     */
    public void fixDex(String inputPath, String outputPath) throws Exception {
        // 读取并重新写入 DEX 来修复格式问题
        File inputFile = new File(inputPath);
        DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
            inputFile,
            Opcodes.getDefault()
        );

        DexPool dexPool = new DexPool(dexFile.getOpcodes());
        for (ClassDef classDef : dexFile.getClasses()) {
            dexPool.internClass(classDef);
        }

        File outputFile = new File(outputPath);
        outputFile.getParentFile().mkdirs();
        dexPool.writeTo(new FileDataStore(outputFile));
        
        Log.d(TAG, "Fixed DEX: " + inputPath + " -> " + outputPath);
    }

    /**
     * 合并多个 DEX 文件
     */
    public void mergeDex(JSONArray inputPaths, String outputPath) throws Exception {
        DexPool dexPool = new DexPool(Opcodes.getDefault());

        for (int i = 0; i < inputPaths.length(); i++) {
            String path = inputPaths.getString(i);
            DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
                new File(path),
                Opcodes.getDefault()
            );

            for (ClassDef classDef : dexFile.getClasses()) {
                dexPool.internClass(classDef);
            }
        }

        File outputFile = new File(outputPath);
        outputFile.getParentFile().mkdirs();
        dexPool.writeTo(new FileDataStore(outputFile));
        
        Log.d(TAG, "Merged " + inputPaths.length() + " DEX files to: " + outputPath);
    }

    /**
     * 拆分 DEX 文件
     */
    public JSArray splitDex(String sessionId, int maxClasses) throws Exception {
        DexSession session = getSession(sessionId);
        JSArray outputFiles = new JSArray();

        List<ClassDef> allClasses = new ArrayList<>();
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (!session.removedClasses.contains(classDef.getType())) {
                allClasses.add(classDef);
            }
        }

        int dexIndex = 0;
        for (int i = 0; i < allClasses.size(); i += maxClasses) {
            DexPool dexPool = new DexPool(session.originalDexFile.getOpcodes());
            
            int end = Math.min(i + maxClasses, allClasses.size());
            for (int j = i; j < end; j++) {
                dexPool.internClass(allClasses.get(j));
            }

            String outputPath = session.filePath.replace(".dex", "_" + dexIndex + ".dex");
            dexPool.writeTo(new FileDataStore(new File(outputPath)));
            outputFiles.put(outputPath);
            dexIndex++;
        }

        return outputFiles;
    }

    /**
     * 获取字符串常量池
     */
    public JSArray getStrings(String sessionId) throws Exception {
        DexSession session = getSession(sessionId);
        JSArray strings = new JSArray();

        // 收集所有类中的字符串
        Set<String> collectedStrings = new HashSet<>();
        int index = 0;
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (!collectedStrings.contains(classDef.getType())) {
                collectedStrings.add(classDef.getType());
                JSObject item = new JSObject();
                item.put("index", index++);
                item.put("value", classDef.getType());
                strings.put(item);
            }
        }

        return strings;
    }

    /**
     * 修改字符串
     */
    public void modifyString(String sessionId, String oldString, String newString) throws Exception {
        DexSession session = getSession(sessionId);

        // 需要遍历所有类，替换字符串引用
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (session.removedClasses.contains(classDef.getType())) continue;

            try {
                String smali = classToSmali(sessionId, classDef.getType()).getString("smali");
                if (smali.contains(oldString)) {
                    String modifiedSmali = smali.replace(oldString, newString);
                    ClassDef modifiedClass = compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());
                    
                    session.removedClasses.add(classDef.getType());
                    session.modifiedClasses.add(modifiedClass);
                }
            } catch (Exception e) {
                Log.w(TAG, "Failed to modify string in class: " + classDef.getType(), e);
            }
        }

        session.modified = true;
    }

    // ==================== 辅助方法 ====================

    DexSession getSession(String sessionId) throws Exception {
        return sessionManager.getSession(sessionId);
    }

    ClassDef findClass(DexSession session, String className) {
        // 先检查修改后的类
        for (ClassDef classDef : session.modifiedClasses) {
            if (classDef.getType().equals(className)) {
                return classDef;
            }
        }
        
        // 再检查原始类
        if (!session.removedClasses.contains(className)) {
            for (ClassDef classDef : session.originalDexFile.getClasses()) {
                if (classDef.getType().equals(className)) {
                    return classDef;
                }
            }
        }
        
        return null;
    }

    Method findMethod(DexSession session, String className, 
                              String methodName, String methodSignature) {
        ClassDef classDef = findClass(session, className);
        if (classDef == null) return null;

        for (Method method : classDef.getMethods()) {
            if (method.getName().equals(methodName)) {
                StringBuilder sig = new StringBuilder("(");
                for (CharSequence param : method.getParameterTypes()) {
                    sig.append(param);
                }
                sig.append(")").append(method.getReturnType());
                
                if (sig.toString().equals(methodSignature)) {
                    return method;
                }
            }
        }
        
        return null;
    }

    ClassDef compileSmaliToClass(String smaliCode, Opcodes opcodes) throws Exception {
        // 使用 C++ 实现编译 smali
        if (CppDex.isAvailable()) {
            byte[] dexBytes = CppDex.smaliToDex(smaliCode);
            if (dexBytes != null && dexBytes.length > 0) {
                DexBackedDexFile compiledDex = new DexBackedDexFile(opcodes, dexBytes);
                for (ClassDef classDef : compiledDex.getClasses()) {
                    return classDef;
                }
            }
            throw new Exception("C++ smaliToDex returned no classes");
        }
        throw new UnsupportedOperationException("C++ library not available for smaliToDex");
    }

    // ==================== 工具方法委托到 SmaliUtils 和 FileUtils ====================

    private List<File> collectSmaliFiles(File dir) {
        return FileUtils.collectSmaliFiles(dir);
    }

    private String readFileContent(File file) throws IOException {
        return FileUtils.readFileContent(file);
    }

    private void writeFileContent(File file, String content) throws IOException {
        FileUtils.writeFileContent(file, content);
    }

    private byte[] readFileBytes(File file) throws IOException {
        return FileUtils.readFileBytes(file);
    }

    private void deleteRecursive(File file) {
        FileUtils.deleteRecursive(file);
    }

    // ==================== APK 内 DEX 操作（无需会话，委派到 ApkDexReader）====================

    public JSObject listDexClassesFromApk(String apkPath, String dexPath) throws Exception {
        return apkDexReader.listDexClassesFromApk(apkPath, dexPath);
    }

    public JSObject getDexStringsFromApk(String apkPath, String dexPath) throws Exception {
        return apkDexReader.getDexStringsFromApk(apkPath, dexPath);
    }

    public JSObject searchInDexFromApk(String apkPath, String dexPath, String query) throws Exception {
        return apkDexReader.searchInDexFromApk(apkPath, dexPath, query);
    }

    // ==================== MCP 工作流支持方法 ====================

    /**
     * 列出 APK 中的所有 DEX 文件
     */
    public JSObject listDexFilesInApk(String apkPath) throws Exception {
        JSObject result = new JSObject();
        JSArray dexFiles = new JSArray();
        
        java.util.zip.ZipFile zipFile = null;
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.Enumeration<? extends java.util.zip.ZipEntry> entries = zipFile.entries();
            
            while (entries.hasMoreElements()) {
                java.util.zip.ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.endsWith(".dex") && !name.contains("/")) {
                    JSObject dexInfo = new JSObject();
                    dexInfo.put("name", name);
                    dexInfo.put("size", entry.getSize());
                    dexFiles.put(dexInfo);
                }
            }
            
            result.put("apkPath", apkPath);
            result.put("dexFiles", dexFiles);
            result.put("count", dexFiles.length());
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 打开多个 DEX 文件创建会话（MCP 工作流）
     */
    public JSObject openMultipleDex(String apkPath, JSONArray dexFiles) throws Exception {
        JSObject result = new JSObject();
        String sessionId = UUID.randomUUID().toString();
        
        // 创建复合会话
        MultiDexSession multiSession = new MultiDexSession(sessionId, apkPath);
        
        java.util.zip.ZipFile zipFile = null;
        int totalClasses = 0;
        
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            
            for (int i = 0; i < dexFiles.length(); i++) {
                String dexName = dexFiles.getString(i);
                java.util.zip.ZipEntry dexEntry = zipFile.getEntry(dexName);
                
                if (dexEntry == null) {
                    Log.w(TAG, "DEX not found: " + dexName);
                    continue;
                }
                
                // 读取 DEX 到内存
                java.io.InputStream is = zipFile.getInputStream(dexEntry);
                java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int len;
                while ((len = is.read(buffer)) != -1) {
                    baos.write(buffer, 0, len);
                }
                is.close();
                byte[] dexData = baos.toByteArray();
                
                // 解析 DEX
                DexBackedDexFile dexFile = new DexBackedDexFile(Opcodes.getDefault(), dexData);
                multiSession.addDex(dexName, dexFile, dexData);
                totalClasses += dexFile.getClasses().size();
                
                Log.d(TAG, "Loaded DEX: " + dexName + " with " + dexFile.getClasses().size() + " classes");
            }
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        sessionManager.multiDexSessions.put(sessionId, multiSession);
        
        result.put("sessionId", sessionId);
        result.put("apkPath", apkPath);
        result.put("dexCount", multiSession.dexFiles.size());
        result.put("classCount", totalClasses);
        
        return result;
    }

    /**
     * 列出所有打开的会话
     */
    public JSArray listAllSessions() {
        return sessionManager.listAllSessions();
    }

    /**
     * 关闭多 DEX 会话
     */
    public void closeMultiDexSession(String sessionId) {
        sessionManager.closeMultiDexSession(sessionId);
    }

    /**
     * 获取多 DEX 会话中的类列表（Rust 实现）
     */
    public JSObject getClassesFromMultiSession(String sessionId, String packageFilter, int offset, int limit) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!CppDex.isAvailable() || session.dexBytes.isEmpty()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        JSObject result = new JSObject();
        JSArray classes = new JSArray();
        List<String> allClasses = new ArrayList<>();
        String filter = packageFilter != null ? packageFilter : "";
        
        // 使用 Rust 获取每个 DEX 的类列表
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String dexName = entry.getKey();
            byte[] dexData = entry.getValue();
            
            String jsonResult = CppDex.listClasses(dexData, filter, 0, 100000);
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                org.json.JSONObject rustResult = new org.json.JSONObject(jsonResult);
                org.json.JSONArray rustClasses = rustResult.optJSONArray("classes");
                if (rustClasses != null) {
                    for (int i = 0; i < rustClasses.length(); i++) {
                        allClasses.add(rustClasses.getString(i) + "|" + dexName);
                    }
                }
            }
        }
        
        // 排序
        java.util.Collections.sort(allClasses);
        
        // 分页
        int total = allClasses.size();
        int end = Math.min(offset + limit, total);
        
        for (int i = offset; i < end; i++) {
            String[] parts = allClasses.get(i).split("\\|");
            JSObject classInfo = new JSObject();
            classInfo.put("className", parts[0]);
            classInfo.put("dexFile", parts[1]);
            classes.put(classInfo);
        }
        
        result.put("total", total);
        result.put("offset", offset);
        result.put("limit", limit);
        result.put("classes", classes);
        result.put("hasMore", end < total);
        result.put("engine", "rust");
        
        return result;
    }

    /**
     * 在多 DEX 会话中搜索（Rust 实现）
     */
    public JSObject searchInMultiSession(String sessionId, String query, String searchType, 
                                          boolean caseSensitive, int maxResults) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }

        // 结构性搜索（父类/接口/注解）由 dexlib2 在 Java 层完成，C++ 引擎不支持这些类型
        if ("superclass".equals(searchType) || "interface".equals(searchType)
                || "annotation".equals(searchType)) {
            return searchStructuralInSession(session, query, searchType, caseSensitive, maxResults);
        }

        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        if (session.dexBytes.isEmpty()) {
            throw new RuntimeException("No DEX data loaded");
        }
        
        JSObject result = new JSObject();
        JSArray allResults = new JSArray();
        
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String dexName = entry.getKey();
            byte[] dexData = entry.getValue();
            
            String jsonResult = CppDex.searchInDex(dexData, query, searchType, caseSensitive, maxResults);
            
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                org.json.JSONObject rustResult = new org.json.JSONObject(jsonResult);
                org.json.JSONArray rustResults = rustResult.optJSONArray("results");
                
                if (rustResults != null) {
                    for (int i = 0; i < rustResults.length() && allResults.length() < maxResults; i++) {
                        org.json.JSONObject item = rustResults.getJSONObject(i);
                        JSObject jsItem = new JSObject();
                        jsItem.put("type", item.optString("type", searchType));
                        jsItem.put("className", item.optString("className", ""));
                        jsItem.put("dexFile", dexName);
                        if (item.has("methodName")) {
                            jsItem.put("methodName", item.getString("methodName"));
                        }
                        if (item.has("fieldName")) {
                            jsItem.put("fieldName", item.getString("fieldName"));
                        }
                        allResults.put(jsItem);
                    }
                }
            }
            
            if (allResults.length() >= maxResults) break;
        }
        
        result.put("query", query);
        result.put("searchType", searchType);
        result.put("total", allResults.length());
        result.put("results", allResults);
        result.put("engine", "rust");
        
        return result;
    }

    /**
     * 结构性搜索：按父类(superclass)、接口(interface)、注解(annotation) 匹配。
     * 由 dexlib2 在 Java 层遍历完成，C++ 搜索引擎不覆盖这些类型。
     */
    private JSObject searchStructuralInSession(MultiDexSession session, String query,
                                               String searchType, boolean caseSensitive,
                                               int maxResults) {
        JSObject result = new JSObject();
        JSArray allResults = new JSArray();
        String needle = caseSensitive ? query : query.toLowerCase();

        outer:
        for (Map.Entry<String, DexBackedDexFile> entry : session.dexFiles.entrySet()) {
            String dexName = entry.getKey();
            DexBackedDexFile dexFile = entry.getValue();
            if (dexFile == null) {
                continue;
            }
            for (ClassDef classDef : dexFile.getClasses()) {
                if ("superclass".equals(searchType)) {
                    String sup = classDef.getSuperclass();
                    if (sup != null && matches(sup, needle, caseSensitive)) {
                        JSObject item = new JSObject();
                        item.put("type", "superclass");
                        item.put("className", classDef.getType());
                        item.put("superclass", sup);
                        item.put("dexFile", dexName);
                        allResults.put(item);
                    }
                } else if ("interface".equals(searchType)) {
                    for (String iface : classDef.getInterfaces()) {
                        if (matches(iface, needle, caseSensitive)) {
                            JSObject item = new JSObject();
                            item.put("type", "interface");
                            item.put("className", classDef.getType());
                            item.put("interface", iface);
                            item.put("dexFile", dexName);
                            allResults.put(item);
                            break;
                        }
                    }
                } else { // annotation
                    for (Annotation ann : classDef.getAnnotations()) {
                        if (matches(ann.getType(), needle, caseSensitive)) {
                            JSObject item = new JSObject();
                            item.put("type", "annotation");
                            item.put("className", classDef.getType());
                            item.put("annotation", ann.getType());
                            item.put("target", "class");
                            item.put("dexFile", dexName);
                            allResults.put(item);
                            if (allResults.length() >= maxResults) break outer;
                        }
                    }
                    for (Method m : classDef.getMethods()) {
                        for (Annotation ann : m.getAnnotations()) {
                            if (matches(ann.getType(), needle, caseSensitive)) {
                                JSObject item = new JSObject();
                                item.put("type", "annotation");
                                item.put("className", classDef.getType());
                                item.put("methodName", m.getName());
                                item.put("annotation", ann.getType());
                                item.put("target", "method");
                                item.put("dexFile", dexName);
                                allResults.put(item);
                                if (allResults.length() >= maxResults) break outer;
                            }
                        }
                    }
                    for (Field f : classDef.getFields()) {
                        for (Annotation ann : f.getAnnotations()) {
                            if (matches(ann.getType(), needle, caseSensitive)) {
                                JSObject item = new JSObject();
                                item.put("type", "annotation");
                                item.put("className", classDef.getType());
                                item.put("fieldName", f.getName());
                                item.put("annotation", ann.getType());
                                item.put("target", "field");
                                item.put("dexFile", dexName);
                                allResults.put(item);
                                if (allResults.length() >= maxResults) break outer;
                            }
                        }
                    }
                }
                if (allResults.length() >= maxResults) break outer;
            }
        }

        result.put("query", query);
        result.put("searchType", searchType);
        result.put("total", allResults.length());
        result.put("results", allResults);
        result.put("engine", "java-dexlib2");
        return result;
    }

    private static boolean matches(String value, String needle, boolean caseSensitive) {
        if (value == null) {
            return false;
        }
        return caseSensitive ? value.contains(needle) : value.toLowerCase().contains(needle);
    }

    /**
     * 获取类的 Smali 代码（内部方法）- 使用 C++ 实现
     */
    private String getSmaliForClass(DexBackedDexFile dexFile, ClassDef classDef) {
        // 此方法已弃用，使用 C++ 实现
        return "";
    }


    /**
     * 从多 DEX 会话获取类的 Smali 代码（Rust 实现）
     */
    public JSObject getClassSmaliFromSession(String sessionId, String className) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换后再查询。
        String targetType = convertClassNameToType(className);
        // 使用 Rust 获取 Smali
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String dexName = entry.getKey();
            byte[] dexData = entry.getValue();
            
            String jsonResult = CppDex.getClassSmali(dexData, targetType);
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                org.json.JSONObject rustResult = new org.json.JSONObject(jsonResult);
                JSObject result = new JSObject();
                result.put("className", className);
                result.put("dexFile", dexName);
                result.put("smaliContent", rustResult.optString("smaliContent", ""));
                result.put("engine", "rust");
                return result;
            }
        }
        
        throw new IllegalArgumentException("Class not found: " + className);
    }

    /**
     * 修改类并保存到多 DEX 会话（Rust 实现）
     */
    public void modifyClassInSession(String sessionId, String className, String smaliContent) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换。
        String targetType = convertClassNameToType(className);
        // 找到类所在的 DEX
        String targetDex = null;
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String jsonResult = CppDex.getClassSmali(entry.getValue(), targetType);
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                targetDex = entry.getKey();
                break;
            }
        }
        
        if (targetDex == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }
        
        // 使用 Rust 修改类
        byte[] originalDex = session.dexBytes.get(targetDex);
        byte[] modifiedDex = CppDex.modifyClass(originalDex, targetType, smaliContent);
        
        if (modifiedDex == null) {
            throw new RuntimeException("Failed to modify class: " + className);
        }
        
        // 更新 DEX 字节数据
        session.dexBytes.put(targetDex, modifiedDex);
        session.modified = true;
        
        Log.d(TAG, "Modified class in session (Rust): " + className);
    }

    /**
     * 添加新类到会话（Rust 实现）
     */
    public void addClassToSession(String sessionId, String className, String smaliContent) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // 添加到第一个 DEX（默认 classes.dex）
        String targetDex = "classes.dex";
        if (!session.dexBytes.containsKey(targetDex) && !session.dexBytes.isEmpty()) {
            targetDex = session.dexBytes.keySet().iterator().next();
        }
        
        // 使用 Rust 添加类
        byte[] originalDex = session.dexBytes.get(targetDex);
        byte[] modifiedDex = CppDex.addClass(originalDex, smaliContent);
        
        if (modifiedDex == null) {
            throw new RuntimeException("Failed to add class: " + className);
        }
        
        // 更新 DEX 字节数据
        session.dexBytes.put(targetDex, modifiedDex);
        session.modified = true;
        
        Log.d(TAG, "Added class to session (Rust): " + className);
    }

    /**
     * 从会话中删除类（Rust 实现）
     */
    public void deleteClassFromSession(String sessionId, String className) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换。
        String targetType = convertClassNameToType(className);
        // 找到类所在的 DEX
        String targetDex = null;
        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            String jsonResult = CppDex.getClassSmali(entry.getValue(), targetType);
            if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                targetDex = entry.getKey();
                break;
            }
        }
        
        if (targetDex == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }
        
        // 使用 Rust 删除类
        byte[] originalDex = session.dexBytes.get(targetDex);
        byte[] modifiedDex = CppDex.deleteClass(originalDex, targetType);
        
        if (modifiedDex == null) {
            throw new RuntimeException("Failed to delete class: " + className);
        }
        
        // 更新 DEX 字节数据
        session.dexBytes.put(targetDex, modifiedDex);
        session.modified = true;
        
        Log.d(TAG, "Deleted class from session (Rust): " + className);
    }

    /**
     * 从会话中获取单个方法的 Smali 代码
     */
    public JSObject getMethodFromSession(String sessionId, String className, String methodName, String methodSignature) throws Exception {
        JSObject result = new JSObject();
        
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        // 先获取整个类的 Smali
        JSObject classResult = getClassSmaliFromSession(sessionId, className);
        String smaliContent = classResult.optString("smaliContent", "");
        
        if (smaliContent.isEmpty()) {
            result.put("methodCode", "# 类未找到: " + className);
            return result;
        }
        
        // 解析并提取方法
        String methodCode = extractMethodFromSmali(smaliContent, methodName, methodSignature);
        result.put("methodCode", methodCode);
        result.put("className", className);
        result.put("methodName", methodName);
        
        return result;
    }

    /**
     * 修改会话中的单个方法
     */
    public void modifyMethodInSession(String sessionId, String className, String methodName, String methodSignature, String newMethodCode) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        // 获取整个类的 Smali
        JSObject classResult = getClassSmaliFromSession(sessionId, className);
        String smaliContent = classResult.optString("smaliContent", "");
        
        if (smaliContent.isEmpty()) {
            throw new IllegalArgumentException("Class not found: " + className);
        }
        
        // 替换方法
        String newSmaliContent = replaceMethodInSmali(smaliContent, methodName, methodSignature, newMethodCode);
        
        // 保存修改后的类
        modifyClassInSession(sessionId, className, newSmaliContent);
        
        Log.d(TAG, "Modified method in session: " + className + "." + methodName);
    }

    /**
     * 从 Smali 代码中提取指定方法
     */
    private String extractMethodFromSmali(String smaliContent, String methodName, String methodSignature) {
        return SmaliUtils.extractMethodFromSmali(smaliContent, methodName, methodSignature);
    }

    private String replaceMethodInSmali(String smaliContent, String methodName, String methodSignature, String newMethodCode) {
        return SmaliUtils.replaceMethodInSmali(smaliContent, methodName, methodSignature, newMethodCode);
    }

    /**
     * 列出会话中类的所有方法
     */
    public JSObject listMethodsFromSession(String sessionId, String className) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        String targetType = convertClassNameToType(className);
        JSObject result = new JSObject();
        JSArray methods = new JSArray();
        
        for (DexBackedDexFile dexFile : session.dexFiles.values()) {
            for (ClassDef classDef : dexFile.getClasses()) {
                if (classDef.getType().equals(targetType)) {
                    for (com.android.tools.smali.dexlib2.iface.Method method : classDef.getMethods()) {
                        JSObject methodInfo = new JSObject();
                        methodInfo.put("name", method.getName());
                        methodInfo.put("returnType", method.getReturnType());
                        methodInfo.put("accessFlags", method.getAccessFlags());
                        
                        // 参数类型
                        StringBuilder params = new StringBuilder("(");
                        for (CharSequence param : method.getParameterTypes()) {
                            params.append(param);
                        }
                        params.append(")").append(method.getReturnType());
                        methodInfo.put("signature", params.toString());
                        
                        methods.put(methodInfo);
                    }
                    break;
                }
            }
        }
        
        result.put("className", className);
        result.put("methods", methods);
        result.put("count", methods.length());
        return result;
    }

    /**
     * 列出会话中类的所有字段
     */
    public JSObject listFieldsFromSession(String sessionId, String className) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        String targetType = convertClassNameToType(className);
        JSObject result = new JSObject();
        JSArray fields = new JSArray();
        
        for (DexBackedDexFile dexFile : session.dexFiles.values()) {
            for (ClassDef classDef : dexFile.getClasses()) {
                if (classDef.getType().equals(targetType)) {
                    for (com.android.tools.smali.dexlib2.iface.Field field : classDef.getFields()) {
                        JSObject fieldInfo = new JSObject();
                        fieldInfo.put("name", field.getName());
                        fieldInfo.put("type", field.getType());
                        fieldInfo.put("accessFlags", field.getAccessFlags());
                        fields.put(fieldInfo);
                    }
                    break;
                }
            }
        }
        
        result.put("className", className);
        result.put("fields", fields);
        result.put("count", fields.length());
        return result;
    }

    /**
     * 类轮廓：一次遍历返回类的父类、接口、字段与方法列表，
     * 便于在读取全量 Smali 前先了解类结构。
     */
    public JSObject outlineClassFromSession(String sessionId, String className) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }

        String targetType = convertClassNameToType(className);
        JSObject result = new JSObject();
        JSArray fields = new JSArray();
        JSArray methods = new JSArray();
        boolean found = false;

        for (DexBackedDexFile dexFile : session.dexFiles.values()) {
            for (ClassDef classDef : dexFile.getClasses()) {
                if (!classDef.getType().equals(targetType)) {
                    continue;
                }
                found = true;
                result.put("accessFlags", classDef.getAccessFlags());
                if (classDef.getSuperclass() != null) {
                    result.put("superclass", convertTypeToClassName(classDef.getSuperclass()));
                }
                JSArray interfaces = new JSArray();
                for (String iface : classDef.getInterfaces()) {
                    interfaces.put(convertTypeToClassName(iface));
                }
                result.put("interfaces", interfaces);

                for (com.android.tools.smali.dexlib2.iface.Field field : classDef.getFields()) {
                    JSObject fieldInfo = new JSObject();
                    fieldInfo.put("name", field.getName());
                    fieldInfo.put("type", field.getType());
                    fieldInfo.put("accessFlags", field.getAccessFlags());
                    fields.put(fieldInfo);
                }

                for (com.android.tools.smali.dexlib2.iface.Method method : classDef.getMethods()) {
                    JSObject methodInfo = new JSObject();
                    methodInfo.put("name", method.getName());
                    methodInfo.put("returnType", method.getReturnType());
                    methodInfo.put("accessFlags", method.getAccessFlags());
                    StringBuilder params = new StringBuilder("(");
                    for (CharSequence param : method.getParameterTypes()) {
                        params.append(param);
                    }
                    params.append(")").append(method.getReturnType());
                    methodInfo.put("signature", params.toString());
                    methods.put(methodInfo);
                }
                break;
            }
            if (found) {
                break;
            }
        }

        if (!found) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        result.put("className", className);
        result.put("fields", fields);
        result.put("fieldCount", fields.length());
        result.put("methods", methods);
        result.put("methodCount", methods.length());
        return result;
    }

    /**
     * 重命名会话中的类
     */
    public void renameClassInSession(String sessionId, String oldClassName, String newClassName) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        // 获取原类的 Smali
        JSObject classResult = getClassSmaliFromSession(sessionId, oldClassName);
        String smaliContent = classResult.optString("smaliContent", "");
        
        if (smaliContent.isEmpty()) {
            throw new IllegalArgumentException("Class not found: " + oldClassName);
        }
        
        String oldType = convertClassNameToType(oldClassName);
        String newType = convertClassNameToType(newClassName);
        
        // 替换类名
        String newSmaliContent = smaliContent.replace(oldType, newType);
        
        // 删除旧类，添加新类
        deleteClassFromSession(sessionId, oldClassName);
        addClassToSession(sessionId, newClassName, newSmaliContent);
        
        Log.d(TAG, "Renamed class: " + oldClassName + " -> " + newClassName);
    }

    /**
     * 修改 APK 中的资源文件
     */
    public JSObject modifyResourceInApk(String apkPath, String resourcePath, String newContent) throws Exception {
        return ApkResourceOperations.modifyResourceInApk(apkPath, resourcePath, newContent, false);
    }

    /**
     * 从 APK 中删除指定文件
     */
    public JSObject deleteFileFromApk(String apkPath, String filePath) throws Exception {
        JSObject result = new JSObject();
        
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");
        
        java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));
        
        java.util.zip.ZipEntry entry;
        boolean found = false;
        String normalizedPath = filePath.replaceFirst("^/+", "");
        
        while ((entry = zis.getNextEntry()) != null) {
            String entryName = entry.getName();
            
            if (entryName.equals(filePath) || entryName.equals(normalizedPath)) {
                // 跳过要删除的文件
                found = true;
                continue;
            }
            
            // 复制其他文件
            java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                newEntry.setSize(entry.getSize());
                newEntry.setCrc(entry.getCrc());
            }
            zos.putNextEntry(newEntry);
            
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }
        
        zis.close();
        zos.close();
        
        if (!found) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "文件未找到: " + filePath);
            return result;
        }
        
        // 替换原文件
        if (!apkFile.delete()) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "无法删除原 APK");
            return result;
        }
        
        if (!tempApkFile.renameTo(apkFile)) {
            copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
        
        result.put("success", true);
        result.put("message", "文件已删除: " + filePath);
        result.put("needSign", true);
        return result;
    }

    /**
     * 向 APK 中添加或替换文件
     */
    public JSObject addFileToApk(String apkPath, String filePath, String content, boolean isBase64) throws Exception {
        JSObject result = new JSObject();
        
        // 解码内容
        byte[] contentBytes;
        if (isBase64) {
            contentBytes = android.util.Base64.decode(content, android.util.Base64.DEFAULT);
        } else {
            contentBytes = content.getBytes("UTF-8");
        }
        
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");
        
        java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));
        
        java.util.zip.ZipEntry entry;
        String normalizedPath = filePath.replaceFirst("^/+", "");
        boolean replaced = false;
        
        while ((entry = zis.getNextEntry()) != null) {
            String entryName = entry.getName();
            
            if (entryName.equals(filePath) || entryName.equals(normalizedPath)) {
                // 跳过要替换的文件，稍后添加新版本
                replaced = true;
                continue;
            }
            
            // 复制其他文件
            java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                newEntry.setSize(entry.getSize());
                newEntry.setCrc(entry.getCrc());
            }
            zos.putNextEntry(newEntry);
            
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }
        
        // 添加新文件
        java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(normalizedPath);
        newEntry.setSize(contentBytes.length);
        zos.putNextEntry(newEntry);
        zos.write(contentBytes);
        zos.closeEntry();
        
        zis.close();
        zos.close();
        
        // 替换原文件
        if (!apkFile.delete()) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "无法删除原 APK");
            return result;
        }
        
        if (!tempApkFile.renameTo(apkFile)) {
            copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
        
        result.put("success", true);
        result.put("message", replaced ? "文件已替换: " + filePath : "文件已添加: " + filePath);
        result.put("needSign", true);
        return result;
    }

    /**
     * 用原始字节替换 APK 中的某个条目（保持其余条目不变）。
     * resources.arsc 以 STORED（不压缩）写入，以满足 Android 11+ 的安装要求。
     */
    private void replaceApkEntryBytes(String apkPath, String entryName, byte[] newBytes) throws Exception {
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");

        boolean storeUncompressed = "resources.arsc".equals(entryName);
        java.util.zip.ZipInputStream zis =
            new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos =
            new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));

        java.util.zip.ZipEntry entry;
        while ((entry = zis.getNextEntry()) != null) {
            String name = entry.getName();
            if (name.equals(entryName)) {
                continue; // 稍后写入新版本
            }
            java.util.zip.ZipEntry copy = new java.util.zip.ZipEntry(name);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                copy.setMethod(java.util.zip.ZipEntry.STORED);
                copy.setSize(entry.getSize());
                copy.setCrc(entry.getCrc());
            }
            zos.putNextEntry(copy);
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }

        java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
        if (storeUncompressed) {
            java.util.zip.CRC32 crc = new java.util.zip.CRC32();
            crc.update(newBytes);
            newEntry.setMethod(java.util.zip.ZipEntry.STORED);
            newEntry.setSize(newBytes.length);
            newEntry.setCompressedSize(newBytes.length);
            newEntry.setCrc(crc.getValue());
        }
        zos.putNextEntry(newEntry);
        zos.write(newBytes);
        zos.closeEntry();

        zis.close();
        zos.close();

        if (!apkFile.delete()) {
            tempApkFile.delete();
            throw new Exception("无法删除原 APK");
        }
        if (!tempApkFile.renameTo(apkFile)) {
            copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
    }

    /**
     * 按资源 ID 读取 resources.arsc 里的值（逐 config）。
     */
    public JSObject getResourceValueInApk(String apkPath, long resId) throws Exception {
        byte[] arscBytes = CppApkHelper.readFileFromApk(apkPath, "resources.arsc");
        String json = CppDex.getArscResourceValue(arscBytes, resId);
        return new JSObject(json);
    }

    /**
     * 按资源 ID 修改 resources.arsc 里的值并写回 APK。
     */
    public JSObject setResourceValueInApk(String apkPath, long resId, String config,
                                          String valueType, String newValue) throws Exception {
        byte[] arscBytes = CppApkHelper.readFileFromApk(apkPath, "resources.arsc");
        byte[] newArsc = CppDex.setArscResourceValue(arscBytes, resId, config, valueType, newValue);
        replaceApkEntryBytes(apkPath, "resources.arsc", newArsc);

        JSObject result = new JSObject();
        result.put("success", true);
        result.put("message", "资源值已修改并写回 resources.arsc");
        result.put("needSign", true);
        return result;
    }

    /**
     * 保存多 DEX 会话的修改到 APK
     */
    public JSObject saveMultiDexSessionToApk(String sessionId) throws Exception {
        MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        
        if (!session.modified || session.modifiedClasses.isEmpty()) {
            JSObject result = new JSObject();
            result.put("success", true);
            result.put("message", "没有需要保存的修改");
            return result;
        }
        
        // 按 DEX 文件分组修改
        Map<String, List<ClassDef>> modifiedByDex = new HashMap<>();
        for (Map.Entry<String, ClassDef> entry : session.modifiedClasses.entrySet()) {
            String[] parts = entry.getKey().split("\\|");
            String dexName = parts[0];
            modifiedByDex.computeIfAbsent(dexName, k -> new ArrayList<>()).add(entry.getValue());
        }
        
        // 为每个修改的 DEX 创建新版本
        Map<String, byte[]> newDexData = new HashMap<>();
        
        for (Map.Entry<String, List<ClassDef>> entry : modifiedByDex.entrySet()) {
            String dexName = entry.getKey();
            List<ClassDef> modifiedClasses = entry.getValue();
            DexBackedDexFile originalDex = session.dexFiles.get(dexName);
            
            // 合并类
            Set<String> modifiedTypes = new HashSet<>();
            for (ClassDef c : modifiedClasses) {
                modifiedTypes.add(c.getType());
            }
            
            List<ClassDef> allClasses = new ArrayList<>(modifiedClasses);
            for (ClassDef c : originalDex.getClasses()) {
                if (!modifiedTypes.contains(c.getType())) {
                    allClasses.add(c);
                }
            }
            
            // 创建新 DEX
            reportTitle("编译 " + dexName);
            reportMessage("正在编译类...");
            
            java.io.File tempDex = java.io.File.createTempFile("dex_", ".dex");
            DexPool dexPool = new DexPool(Opcodes.getDefault());
            int total = allClasses.size();
            int current = 0;
            for (ClassDef c : allClasses) {
                dexPool.internClass(c);
                current++;
                reportProgress(current, total);
            }
            
            reportMessage("正在写入文件...");
            dexPool.writeTo(new FileDataStore(tempDex));
            
            newDexData.put(dexName, readFileBytes(tempDex));
            tempDex.delete();
        }
        
        reportTitle("更新 APK");
        reportMessage("正在替换 DEX 文件...");
        
        // 替换 APK 中的 DEX
        java.io.File apkFile = new java.io.File(session.apkPath);
        java.io.File tempApk = new java.io.File(session.apkPath + ".tmp");
        
        java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(
            new java.io.BufferedInputStream(new java.io.FileInputStream(apkFile)));
        java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(
            new java.io.BufferedOutputStream(new java.io.FileOutputStream(tempApk)));
        
        java.util.zip.ZipEntry entry;
        while ((entry = zis.getNextEntry()) != null) {
            if (newDexData.containsKey(entry.getName())) {
                // 替换 DEX
                byte[] dexBytes = newDexData.get(entry.getName());
                java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entry.getName());
                newEntry.setMethod(java.util.zip.ZipEntry.DEFLATED);
                zos.putNextEntry(newEntry);
                zos.write(dexBytes);
                zos.closeEntry();
            } else {
                // 复制原条目
                java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entry.getName());
                newEntry.setTime(entry.getTime());
                if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                    newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                    newEntry.setSize(entry.getSize());
                    newEntry.setCrc(entry.getCrc());
                } else {
                    newEntry.setMethod(java.util.zip.ZipEntry.DEFLATED);
                }
                zos.putNextEntry(newEntry);
                if (!entry.isDirectory()) {
                    byte[] buf = new byte[8192];
                    int n;
                    while ((n = zis.read(buf)) != -1) {
                        zos.write(buf, 0, n);
                    }
                }
                zos.closeEntry();
            }
            zis.closeEntry();
        }
        
        zis.close();
        zos.close();
        
        // 替换原文件
        if (!apkFile.delete()) {
            Log.e(TAG, "Failed to delete original APK");
        }
        if (!tempApk.renameTo(apkFile)) {
            copyFile(tempApk, apkFile);
            tempApk.delete();
        }
        
        // 清除修改状态
        session.modifiedClasses.clear();
        session.modified = false;
        
        JSObject result = new JSObject();
        result.put("success", true);
        result.put("message", "DEX 已保存到 APK");
        result.put("apkPath", session.apkPath);
        result.put("needSign", true);
        
        return result;
    }

    /**
     * 保存所有已修改的多 DEX 会话到各自 APK。
     * 逐个会话调用 {@link #saveMultiDexSessionToApk(String)}，单个失败不影响其余，
     * 返回逐会话结果 + 汇总（saved/skipped/failed）。
     */
    public JSObject saveAllSessionsToApk() {
        JSArray sessionResults = new JSArray();
        int saved = 0;
        int skipped = 0;
        int failed = 0;

        // 复制 key 集合，避免保存过程修改 map 时并发遍历
        for (String sessionId : new ArrayList<>(sessionManager.multiDexSessions.keySet())) {
            MultiDexSession session = sessionManager.multiDexSessions.get(sessionId);
            JSObject item = new JSObject();
            item.put("sessionId", sessionId);
            if (session == null) {
                item.put("status", "skipped");
                item.put("message", "会话不存在");
                skipped++;
                sessionResults.put(item);
                continue;
            }
            if (session.apkPath != null) {
                item.put("apkPath", session.apkPath);
            }
            if (!session.modified || session.modifiedClasses.isEmpty()) {
                item.put("status", "skipped");
                item.put("message", "没有需要保存的修改");
                skipped++;
                sessionResults.put(item);
                continue;
            }
            try {
                saveMultiDexSessionToApk(sessionId);
                item.put("status", "saved");
                saved++;
            } catch (Exception e) {
                item.put("status", "failed");
                item.put("error", e.getMessage() != null ? e.getMessage() : e.toString());
                failed++;
            }
            sessionResults.put(item);
        }

        JSObject result = new JSObject();
        result.put("success", failed == 0);
        result.put("saved", saved);
        result.put("skipped", skipped);
        result.put("failed", failed);
        result.put("sessions", sessionResults);
        result.put("needSign", saved > 0);
        return result;
    }

    /**
     * 将 DEX 类型格式转换为 Java 类名格式
     * 例如: Lcom/example/Class; -> com.example.Class
     */
    String convertTypeToClassName(String type) {
        if (type == null) return "";
        String className = type;
        if (className.startsWith("L") && className.endsWith(";")) {
            className = className.substring(1, className.length() - 1);
        }
        return className.replace("/", ".");
    }

    /**
     * 将 Java 类名格式转换为 DEX 类型格式
     * 例如: com.example.Class -> Lcom/example/Class;
     */
    private String convertClassNameToType(String className) {
        if (className == null) return "";
        // 幂等：已是描述符（La/b/C;）直接返回，避免二次包装成 LLa/b/C;;。
        if (className.startsWith("L") && className.endsWith(";")) {
            return className;
        }
        return "L" + className.replace(".", "/") + ";";
    }

    /**
     * 获取或创建 APK DEX 缓存
     */
    private ApkDexCache getOrCreateDexCache(String apkPath, String dexPath) throws Exception {
        String cacheKey = apkPath + ":" + dexPath;
        java.io.File apkFile = new java.io.File(apkPath);
        long currentModified = apkFile.lastModified();
        
        ApkDexCache cache = apkDexCaches.get(cacheKey);
        
        // 检查缓存是否有效
        if (cache != null && cache.lastModified == currentModified && !cache.classDefMap.isEmpty()) {
            Log.d(TAG, "Using DEX cache for: " + cacheKey + " (" + cache.classDefMap.size() + " classes)");
            return cache;
        }
        
        // 需要重新加载
        Log.d(TAG, "Loading DEX into cache: " + cacheKey);
        cache = new ApkDexCache(apkPath, dexPath);
        cache.lastModified = currentModified;
        
        java.util.zip.ZipFile zipFile = new java.util.zip.ZipFile(apkPath);
        try {
            // 尝试多种可能的 dexPath 格式
            java.util.zip.ZipEntry dexEntry = zipFile.getEntry(dexPath);
            if (dexEntry == null) {
                dexEntry = zipFile.getEntry(dexPath.replaceFirst("^/+", ""));
            }
            if (dexEntry == null) {
                String fileName = dexPath;
                if (dexPath.contains("/")) {
                    fileName = dexPath.substring(dexPath.lastIndexOf("/") + 1);
                }
                dexEntry = zipFile.getEntry(fileName);
            }
            
            if (dexEntry == null) {
                throw new Exception("DEX 文件未找到: " + dexPath);
            }
            
            // 读取 DEX 文件
            java.io.InputStream dexInputStream = zipFile.getInputStream(dexEntry);
            java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[16384];
            int len;
            while ((len = dexInputStream.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            dexInputStream.close();
            byte[] dexBytes = baos.toByteArray();
            
            // 保存 DEX 字节用于 C++ 操作
            cache.dexBytes = dexBytes;
            
            // 解析 DEX 文件并缓存所有 ClassDef
            DexBackedDexFile dexFile = new DexBackedDexFile(Opcodes.getDefault(), dexBytes);
            cache.dexVersion = 35; // 默认 DEX 版本
            
            for (ClassDef classDef : dexFile.getClasses()) {
                cache.classDefMap.put(classDef.getType(), classDef);
            }
            
            Log.d(TAG, "Cached " + cache.classDefMap.size() + " classes from " + dexPath);
        } finally {
            zipFile.close();
        }
        
        apkDexCaches.put(cacheKey, cache);
        return cache;
    }
    
    /**
     * 清除指定 APK 的 DEX 缓存
     */
    public void clearDexCache(String apkPath) {
        java.util.Iterator<String> it = apkDexCaches.keySet().iterator();
        while (it.hasNext()) {
            if (it.next().startsWith(apkPath + ":")) {
                it.remove();
            }
        }
        Log.d(TAG, "Cleared DEX cache for: " + apkPath);
    }
    
    /**
     * 从 APK 中的 DEX 文件获取类的 Smali 代码（使用 C++ 实现）
     */
    public JSObject getClassSmaliFromApk(String apkPath, String dexPath, String className) throws Exception {
        JSObject result = new JSObject();
        
        Log.d(TAG, "getClassSmaliFromApk: apkPath=" + apkPath + ", dexPath=" + dexPath + ", className=" + className);
        
        if (className == null || className.isEmpty()) {
            result.put("smali", "# 未指定类名");
            return result;
        }
        
        String targetType = convertClassNameToType(className);
        
        try {
            // 使用 C++ 实现获取 Smali
            if (CppDex.isAvailable()) {
                ApkDexCache cache = getOrCreateDexCache(apkPath, dexPath);
                if (cache.dexBytes != null) {
                    String smaliJson = CppDex.getClassSmali(cache.dexBytes, targetType);
                    if (smaliJson != null && !smaliJson.contains("\"error\"")) {
                        org.json.JSONObject smaliResult = new org.json.JSONObject(smaliJson);
                        String smali = smaliResult.optString("smali", "");
                        if (!smali.isEmpty()) {
                            result.put("smali", smali);
                            return result;
                        }
                    }
                }
            }
            result.put("smali", "# 类未找到或 C++ 库不可用: " + className);
        } catch (Exception e) {
            result.put("smali", "# 加载失败: " + e.getMessage());
        }
        
        return result;
    }

    /**
     * 保存修改后的 Smali 代码到 APK 中的 DEX 文件
     * 注意：这是一个复杂操作，需要重新编译 Smali 并修改 DEX 文件
     */
    public JSObject saveClassSmaliToApk(String apkPath, String dexPath, String className, String smaliContent) throws Exception {
        JSObject result = new JSObject();
        
        Log.d(TAG, "saveClassSmaliToApk: apkPath=" + apkPath + ", dexPath=" + dexPath + ", className=" + className);
        Log.d(TAG, "smaliContent length: " + (smaliContent != null ? smaliContent.length() : 0));
        
        if (className == null || className.isEmpty()) {
            result.put("success", false);
            result.put("error", "未指定类名");
            return result;
        }
        
        if (smaliContent == null || smaliContent.isEmpty()) {
            result.put("success", false);
            result.put("error", "Smali 内容为空");
            return result;
        }
        
        try {
            // 使用 C++ 实现编译 Smali
            reportTitle("编译 Smali");
            reportMessage("正在编译 " + className + "...");
            reportProgress(10, 100);
            
            // 使用 C++ 编译 Smali 代码为 ClassDef
            ClassDef newClassDef;
            try {
                newClassDef = compileSmaliToClass(smaliContent, Opcodes.getDefault());
            } catch (Exception e) {
                result.put("success", false);
                result.put("error", "Smali 编译失败: " + e.getMessage());
                return result;
            }
            
            reportProgress(20, 100);
            Log.d(TAG, "Smali compiled successfully to ClassDef (C++)");
            
            // 使用缓存获取 ClassDef（核心优化）
            reportTitle("合并 DEX");
            reportMessage("获取缓存...");
            
            String targetType = "L" + className.replace(".", "/") + ";";
            ApkDexCache cache = getOrCreateDexCache(apkPath, dexPath);
            
            reportProgress(30, 100);
            reportMessage("更新缓存...");
            
            // 更新缓存中的 ClassDef
            cache.classDefMap.put(targetType, newClassDef);
            
            Log.d(TAG, "Using cached " + cache.classDefMap.size() + " classes");
            
            // 创建新的 DEX 文件（使用缓存的 ClassDef）
            reportMessage("写入 DEX (" + cache.classDefMap.size() + " 个类)...");
            reportProgress(40, 100);
            
            DexPool dexPool = new DexPool(Opcodes.getDefault());
            int totalClasses = cache.classDefMap.size();
            int currentClass = 0;
            for (ClassDef classDef : cache.classDefMap.values()) {
                dexPool.internClass(classDef);
                currentClass++;
                if (currentClass % 200 == 0 || currentClass == totalClasses) {
                    reportProgress(40 + (currentClass * 40 / totalClasses), 100);
                }
            }
            
            // 使用内存写入 DEX（避免临时文件）
            reportProgress(80, 100);
            reportMessage("生成 DEX...");
            com.android.tools.smali.dexlib2.writer.io.MemoryDataStore memoryStore = 
                new com.android.tools.smali.dexlib2.writer.io.MemoryDataStore();
            dexPool.writeTo(memoryStore);
            byte[] newDexBytes = java.util.Arrays.copyOf(memoryStore.getBuffer(), memoryStore.getSize());
            
            Log.d(TAG, "Merged DEX size: " + newDexBytes.length + " bytes");
            
            // MT 风格：直接替换 APK 内的 DEX
            reportTitle("更新 APK");
            reportMessage("正在替换 DEX...");
            reportProgress(85, 100);
            
            java.io.File apkFile = new java.io.File(apkPath);
            java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");
            
            Log.d(TAG, "Replacing DEX in APK (MT style)...");
            
            // 使用 ZipInputStream 流式处理替换 DEX
            java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(
                new java.io.BufferedInputStream(new java.io.FileInputStream(apkFile)));
            java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(
                new java.io.BufferedOutputStream(new java.io.FileOutputStream(tempApkFile)));
            
            java.util.zip.ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.getName().equals(dexPath)) {
                    // 替换 DEX：写入新数据
                    java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(dexPath);
                    newEntry.setMethod(java.util.zip.ZipEntry.DEFLATED);
                    zos.putNextEntry(newEntry);
                    zos.write(newDexBytes);
                    zos.closeEntry();
                    zis.closeEntry();
                } else {
                    // 直接复制其他条目
                    java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entry.getName());
                    newEntry.setTime(entry.getTime());
                    if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                        newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                        newEntry.setSize(entry.getSize());
                        newEntry.setCrc(entry.getCrc());
                    } else {
                        newEntry.setMethod(java.util.zip.ZipEntry.DEFLATED);
                    }
                    zos.putNextEntry(newEntry);
                    if (!entry.isDirectory()) {
                        byte[] buf = new byte[8192];
                        int n;
                        while ((n = zis.read(buf)) != -1) {
                            zos.write(buf, 0, n);
                        }
                    }
                    zos.closeEntry();
                }
            }
            
            zis.close();
            zos.close();
            
            // 用临时文件替换原文件
            if (!apkFile.delete()) {
                Log.e(TAG, "Failed to delete original APK");
            }
            if (!tempApkFile.renameTo(apkFile)) {
                copyFile(tempApkFile, apkFile);
                tempApkFile.delete();
            }
            
            Log.d(TAG, "APK updated successfully: " + apkPath);
            reportProgress(100, 100);
            
            // 更新缓存的 lastModified 以匹配新的 APK
            cache.lastModified = new java.io.File(apkPath).lastModified();
            
            result.put("success", true);
            result.put("message", "Smali 编译成功！APK 已更新");
            result.put("apkPath", apkPath);
            result.put("needSign", true);
            
        } catch (Exception e) {
            Log.e(TAG, "Error saving smali: " + e.getMessage(), e);
            result.put("success", false);
            result.put("error", "保存失败: " + e.getMessage());
        }
        
        return result;
    }

    /**
     * 计算 CRC32
     */
    private long calculateCrc32(byte[] data) {
        java.util.zip.CRC32 crc = new java.util.zip.CRC32();
        crc.update(data);
        return crc.getValue();
    }

    /**
     * 复制文件
     */
    private void copyFile(java.io.File src, java.io.File dst) throws java.io.IOException {
        java.io.FileInputStream fis = new java.io.FileInputStream(src);
        java.io.FileOutputStream fos = new java.io.FileOutputStream(dst);
        byte[] buffer = new byte[8192];
        int len;
        while ((len = fis.read(buffer)) != -1) {
            fos.write(buffer, 0, len);
        }
        fis.close();
        fos.close();
    }

    // ==================== XML/资源操作方法 ====================

    // ==================== Manifest 和资源操作委托到 ApkResourceOperations ====================

    public JSObject getManifestFromApk(String apkPath) throws Exception {
        return ApkResourceOperations.getManifestFromApk(apkPath);
    }

    private String getManifestFallback(String apkPath) {
        return ApkResourceOperations.getManifestFallback(apkPath);
    }

    private String decodeAxml(byte[] axmlData) {
        return ApkResourceOperations.decodeAxml(axmlData);
    }

    public JSObject modifyManifestInApk(String apkPath, String newManifestXml) throws Exception {
        return ApkResourceOperations.modifyManifestInApk(apkPath, newManifestXml);
    }

    private byte[] encodeAxml(String xmlContent) throws Exception {
        return ApkResourceOperations.encodeAxml(xmlContent);
    }

    public JSObject listResourcesInApk(String apkPath, String filter) throws Exception {
        return ApkResourceOperations.listResourcesInApk(apkPath, filter);
    }

    public JSObject getResourceFromApk(String apkPath, String resourcePath) throws Exception {
        return ApkResourceOperations.getResourceFromApk(apkPath, resourcePath);
    }

    public JSObject replaceInManifest(String apkPath, org.json.JSONArray replacements) throws Exception {
        return ApkResourceOperations.replaceInManifest(apkPath, replacements);
    }

    public JSObject patchManifest(String apkPath, org.json.JSONArray patches) throws Exception {
        return ApkResourceOperations.patchManifest(apkPath, patches);
    }

    /**
     * 列出 APK 中的所有文件
     */
    public JSObject listApkFiles(String apkPath, String filter, int limit, int offset) throws Exception {
        JSObject result = new JSObject();
        JSArray files = new JSArray();
        
        java.util.zip.ZipFile zipFile = null;
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.Enumeration<? extends java.util.zip.ZipEntry> entries = zipFile.entries();
            
            java.util.List<JSObject> allFiles = new java.util.ArrayList<>();
            
            while (entries.hasMoreElements()) {
                java.util.zip.ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                
                // 应用过滤
                if (!filter.isEmpty() && !name.contains(filter)) {
                    continue;
                }
                
                JSObject fileInfo = new JSObject();
                fileInfo.put("path", name);
                fileInfo.put("size", entry.getSize());
                fileInfo.put("compressedSize", entry.getCompressedSize());
                fileInfo.put("isDirectory", entry.isDirectory());
                
                // 判断文件类型
                String type = "unknown";
                if (name.endsWith(".dex")) type = "dex";
                else if (name.endsWith(".so")) type = "native";
                else if (name.endsWith(".xml")) type = "xml";
                else if (name.startsWith("res/")) type = "resource";
                else if (name.startsWith("assets/")) type = "asset";
                else if (name.startsWith("lib/")) type = "native";
                else if (name.startsWith("META-INF/")) type = "meta";
                else if (name.equals("AndroidManifest.xml")) type = "manifest";
                else if (name.equals("resources.arsc")) type = "arsc";
                fileInfo.put("type", type);
                
                allFiles.add(fileInfo);
            }
            
            int total = allFiles.size();
            
            // 分页
            int start = Math.min(offset, total);
            int end = Math.min(offset + limit, total);
            
            for (int i = start; i < end; i++) {
                files.put(allFiles.get(i));
            }
            
            result.put("files", files);
            result.put("total", total);
            result.put("offset", offset);
            result.put("limit", limit);
            result.put("returned", files.length());
            result.put("hasMore", end < total);
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 读取 APK 中的任意文件
     */
    public JSObject readApkFile(String apkPath, String filePath, boolean asBase64, int maxBytes, int offset) throws Exception {
        JSObject result = new JSObject();
        
        java.util.zip.ZipFile zipFile = null;
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.zip.ZipEntry entry = zipFile.getEntry(filePath);
            
            if (entry == null) {
                result.put("error", "File not found: " + filePath);
                return result;
            }
            
            result.put("path", filePath);
            result.put("size", entry.getSize());
            result.put("compressedSize", entry.getCompressedSize());
            
            java.io.InputStream is = zipFile.getInputStream(entry);
            
            // 跳过偏移量
            if (offset > 0) {
                is.skip(offset);
            }
            
            // 读取数据
            int readSize = maxBytes > 0 ? maxBytes : (int) entry.getSize();
            if (readSize > 1024 * 1024) { // 限制最大 1MB
                readSize = 1024 * 1024;
            }
            
            byte[] buffer = new byte[readSize];
            int totalRead = 0;
            int read;
            while (totalRead < readSize && (read = is.read(buffer, totalRead, readSize - totalRead)) != -1) {
                totalRead += read;
            }
            is.close();
            
            byte[] data = new byte[totalRead];
            System.arraycopy(buffer, 0, data, 0, totalRead);
            
            if (asBase64) {
                // Base64 编码返回
                result.put("content", android.util.Base64.encodeToString(data, android.util.Base64.NO_WRAP));
                result.put("encoding", "base64");
            } else {
                // 尝试作为文本返回
                String content = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                
                // 检查是否是二进制文件
                boolean isBinary = false;
                for (int i = 0; i < Math.min(100, data.length); i++) {
                    if (data[i] == 0) {
                        isBinary = true;
                        break;
                    }
                }
                
                if (isBinary && !filePath.endsWith(".xml")) {
                    // 二进制文件自动使用 Base64
                    result.put("content", android.util.Base64.encodeToString(data, android.util.Base64.NO_WRAP));
                    result.put("encoding", "base64");
                    result.put("note", "Binary file, auto-encoded as base64");
                } else {
                    // 如果是 XML 文件，尝试解码 AXML
                    if (filePath.endsWith(".xml") && data.length > 4) {
                        int magic = (data[0] & 0xFF) | ((data[1] & 0xFF) << 8) | 
                                   ((data[2] & 0xFF) << 16) | ((data[3] & 0xFF) << 24);
                        if (magic == 0x00080003) {
                            // 是 AXML 格式，解码
                            content = AxmlParser.decode(data);
                        }
                    }
                    result.put("content", content);
                    result.put("encoding", "text");
                }
            }
            
            result.put("offset", offset);
            result.put("bytesRead", totalRead);
            result.put("hasMore", offset + totalRead < entry.getSize());
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 在 APK 中搜索文本内容
     */
    public JSObject searchTextInApk(String apkPath, String pattern, org.json.JSONArray fileExtensions, 
                                     boolean caseSensitive, boolean isRegex, int maxResults, int contextLines) throws Exception {
        JSObject result = new JSObject();
        JSArray results = new JSArray();
        
        // 二进制文件扩展名（跳过）
        java.util.Set<String> binaryExtensions = new java.util.HashSet<>(java.util.Arrays.asList(
            ".dex", ".so", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico",
            ".zip", ".apk", ".jar", ".class", ".ogg", ".mp3", ".wav", ".mp4",
            ".arsc", ".9.png", ".ttf", ".otf", ".woff"
        ));
        
        // 解析文件扩展名过滤
        java.util.Set<String> allowedExtensions = new java.util.HashSet<>();
        if (fileExtensions != null && fileExtensions.length() > 0) {
            for (int i = 0; i < fileExtensions.length(); i++) {
                String ext = fileExtensions.getString(i);
                if (!ext.startsWith(".")) ext = "." + ext;
                allowedExtensions.add(ext.toLowerCase());
            }
        }
        
        // 编译搜索模式
        java.util.regex.Pattern regex;
        int flags = caseSensitive ? 0 : java.util.regex.Pattern.CASE_INSENSITIVE;
        if (isRegex) {
            regex = java.util.regex.Pattern.compile(pattern, flags);
        } else {
            regex = java.util.regex.Pattern.compile(java.util.regex.Pattern.quote(pattern), flags);
        }
        
        int totalFound = 0;
        int filesSearched = 0;
        boolean truncated = false;
        
        java.util.zip.ZipFile zipFile = null;
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);
            java.util.Enumeration<? extends java.util.zip.ZipEntry> entries = zipFile.entries();
            
            while (entries.hasMoreElements() && totalFound < maxResults) {
                java.util.zip.ZipEntry entry = entries.nextElement();
                if (entry.isDirectory()) continue;
                
                String name = entry.getName();
                String ext = "";
                int dotIndex = name.lastIndexOf('.');
                if (dotIndex > 0) {
                    ext = name.substring(dotIndex).toLowerCase();
                }
                
                // 跳过二进制文件
                if (binaryExtensions.contains(ext)) continue;
                
                // 检查扩展名过滤
                if (!allowedExtensions.isEmpty() && !allowedExtensions.contains(ext)) continue;
                
                // 跳过大文件（> 1MB）
                if (entry.getSize() > 1024 * 1024) continue;
                
                try {
                    java.io.InputStream is = zipFile.getInputStream(entry);
                    byte[] data = new byte[(int) entry.getSize()];
                    int totalRead = 0;
                    int read;
                    while (totalRead < data.length && (read = is.read(data, totalRead, data.length - totalRead)) != -1) {
                        totalRead += read;
                    }
                    is.close();
                    
                    // 检查是否是二进制
                    boolean isBinary = false;
                    for (int i = 0; i < Math.min(100, data.length); i++) {
                        if (data[i] == 0) {
                            isBinary = true;
                            break;
                        }
                    }
                    if (isBinary) continue;
                    
                    String content = new String(data, java.nio.charset.StandardCharsets.UTF_8);
                    String[] lines = content.split("\n");
                    
                    filesSearched++;
                    
                    for (int i = 0; i < lines.length && totalFound < maxResults; i++) {
                        java.util.regex.Matcher matcher = regex.matcher(lines[i]);
                        if (matcher.find()) {
                            JSObject match = new JSObject();
                            match.put("file", name);
                            match.put("lineNumber", i + 1);
                            match.put("line", lines[i].trim());
                            
                            // 添加上下文
                            JSArray context = new JSArray();
                            int start = Math.max(0, i - contextLines);
                            int end = Math.min(lines.length, i + contextLines + 1);
                            for (int j = start; j < end; j++) {
                                context.put(lines[j]);
                            }
                            match.put("context", context);
                            
                            results.put(match);
                            totalFound++;
                        }
                    }
                } catch (Exception e) {
                    // 跳过无法读取的文件
                }
            }
            
            truncated = totalFound >= maxResults;
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        result.put("results", results);
        result.put("totalFound", totalFound);
        result.put("filesSearched", filesSearched);
        result.put("truncated", truncated);
        
        return result;
    }

    /**
     * 清理临时目录
     */
    private void cleanupTempDir(java.io.File dir) {
        if (dir != null && dir.exists()) {
            java.io.File[] files = dir.listFiles();
            if (files != null) {
                for (java.io.File file : files) {
                    if (file.isDirectory()) {
                        cleanupTempDir(file);
                    } else {
                        file.delete();
                    }
                }
            }
            dir.delete();
        }
    }
}
