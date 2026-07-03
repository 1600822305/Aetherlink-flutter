package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.DexFileFactory;
import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;
import com.android.tools.smali.dexlib2.immutable.ImmutableDexFile;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * DexFileOps - 单 DEX 会话的加载/保存/信息读取。
 *
 * 从 {@link DexManager} 的「DEX 文件操作」段抽出：
 *  - {@link #loadDex}：加载 DEX 文件并创建会话；
 *  - {@link #saveDex}：把会话写回 DEX（优先 C++ 修改的字节，回退 dexlib2）；
 *  - {@link #closeDex}：关闭会话；
 *  - {@link #getSessionDexBytes}：取会话的 DEX 字节；
 *  - {@link #getDexInfo}：读取 DEX 概要信息（优先 C++ 实现）。
 *
 * 会话存储、文件读取等能力仍由 DexManager 提供，通过持有的 dex 引用回调。
 */
class DexFileOps {

    private static final String TAG = "DexFileOps";

    private final DexManager dex;

    DexFileOps(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 加载 DEX 文件
     */
    JSObject loadDex(String path, String sessionId) throws Exception {
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
        byte[] dexBytes = dex.readFileBytes(file);

        // 加载 DEX 文件 (使用官方推荐的 DexFileFactory)
        DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
            file, 
            Opcodes.getDefault()
        );

        // 创建会话
        DexManager.DexSession session = new DexManager.DexSession(sid, path, dexFile, dexBytes);
        dex.sessionManager.sessions.put(sid, session);

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
    void saveDex(String sessionId, String outputPath) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        
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
    void closeDex(String sessionId) {
        dex.sessionManager.closeSession(sessionId);
        Log.d(TAG, "Closed session: " + sessionId);
    }

    /**
     * 获取会话的 DEX 字节数据（用于 C++ 操作）
     */
    byte[] getSessionDexBytes(String sessionId) {
        DexManager.DexSession session = dex.sessionManager.sessions.get(sessionId);
        return session != null ? session.dexBytes : null;
    }

    /**
     * 获取 DEX 文件信息（优先使用 C++ 实现）
     */
    JSObject getDexInfo(String sessionId) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        
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
}
