package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.writer.io.FileDataStore;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * ApkDexWriter - 把编辑会话保存回 APK，并维护 APK DEX 缓存。
 *
 * 从 {@link DexManager} 抽出（原「MCP 工作流支持方法」段内的保存/缓存部分）：
 *  - {@link #saveMultiDexSessionToApk}：把某个多 DEX 会话的修改编译并写回 APK；
 *  - {@link #saveAllSessionsToApk}：逐个会话保存并汇总结果；
 *  - {@link #clearDexCache}：清除指定 APK 的 DEX 缓存；
 *  - {@link #getClassSmaliFromApk}：借助缓存读取类的 Smali（C++ 实现）；
 *  - {@link #saveClassSmaliToApk}：编译 Smali 并替换 APK 内的 DEX。
 *
 * APK DEX 缓存（{@link ApkDexCache} + {@link #apkDexCaches} + {@link #getOrCreateDexCache}）
 * 仅被上述方法使用，一并迁入本类；会话状态、进度回调、Smali 编译、文件复制等能力
 * 仍由 DexManager 提供，通过持有的 dex 引用回调。
 */
class ApkDexWriter {

    private static final String TAG = "ApkDexWriter";

    private final DexManager dex;

    // APK DEX 缓存 - 用于加速编译（key: apkPath + ":" + dexPath）
    private final Map<String, ApkDexCache> apkDexCaches = new HashMap<>();

    ApkDexWriter(DexManager dex) {
        this.dex = dex;
    }

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
     * 保存多 DEX 会话的修改到 APK
     */
    JSObject saveMultiDexSessionToApk(String sessionId) throws Exception {
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
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
            dex.reportTitle("编译 " + dexName);
            dex.reportMessage("正在编译类...");
            
            java.io.File tempDex = java.io.File.createTempFile("dex_", ".dex");
            DexPool dexPool = new DexPool(Opcodes.getDefault());
            int total = allClasses.size();
            int current = 0;
            for (ClassDef c : allClasses) {
                dexPool.internClass(c);
                current++;
                dex.reportProgress(current, total);
            }
            
            dex.reportMessage("正在写入文件...");
            dexPool.writeTo(new FileDataStore(tempDex));
            
            newDexData.put(dexName, dex.readFileBytes(tempDex));
            tempDex.delete();
        }
        
        dex.reportTitle("更新 APK");
        dex.reportMessage("正在替换 DEX 文件...");
        
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
            dex.copyFile(tempApk, apkFile);
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
    JSObject saveAllSessionsToApk() {
        JSArray sessionResults = new JSArray();
        int saved = 0;
        int skipped = 0;
        int failed = 0;

        // 复制 key 集合，避免保存过程修改 map 时并发遍历
        for (String sessionId : new ArrayList<>(dex.sessionManager.multiDexSessions.keySet())) {
            DexManager.MultiDexSession session = dex.sessionManager.multiDexSessions.get(sessionId);
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
    void clearDexCache(String apkPath) {
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
    JSObject getClassSmaliFromApk(String apkPath, String dexPath, String className) throws Exception {
        JSObject result = new JSObject();
        
        Log.d(TAG, "getClassSmaliFromApk: apkPath=" + apkPath + ", dexPath=" + dexPath + ", className=" + className);
        
        if (className == null || className.isEmpty()) {
            result.put("smali", "# 未指定类名");
            return result;
        }
        
        String targetType = dex.convertClassNameToType(className);
        
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
    JSObject saveClassSmaliToApk(String apkPath, String dexPath, String className, String smaliContent) throws Exception {
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
            dex.reportTitle("编译 Smali");
            dex.reportMessage("正在编译 " + className + "...");
            dex.reportProgress(10, 100);
            
            // 使用 C++ 编译 Smali 代码为 ClassDef
            ClassDef newClassDef;
            try {
                newClassDef = dex.compileSmaliToClass(smaliContent, Opcodes.getDefault());
            } catch (Exception e) {
                result.put("success", false);
                result.put("error", "Smali 编译失败: " + e.getMessage());
                return result;
            }
            
            dex.reportProgress(20, 100);
            Log.d(TAG, "Smali compiled successfully to ClassDef (C++)");
            
            // 使用缓存获取 ClassDef（核心优化）
            dex.reportTitle("合并 DEX");
            dex.reportMessage("获取缓存...");
            
            String targetType = "L" + className.replace(".", "/") + ";";
            ApkDexCache cache = getOrCreateDexCache(apkPath, dexPath);
            
            dex.reportProgress(30, 100);
            dex.reportMessage("更新缓存...");
            
            // 更新缓存中的 ClassDef
            cache.classDefMap.put(targetType, newClassDef);
            
            Log.d(TAG, "Using cached " + cache.classDefMap.size() + " classes");
            
            // 创建新的 DEX 文件（使用缓存的 ClassDef）
            dex.reportMessage("写入 DEX (" + cache.classDefMap.size() + " 个类)...");
            dex.reportProgress(40, 100);
            
            DexPool dexPool = new DexPool(Opcodes.getDefault());
            int totalClasses = cache.classDefMap.size();
            int currentClass = 0;
            for (ClassDef classDef : cache.classDefMap.values()) {
                dexPool.internClass(classDef);
                currentClass++;
                if (currentClass % 200 == 0 || currentClass == totalClasses) {
                    dex.reportProgress(40 + (currentClass * 40 / totalClasses), 100);
                }
            }
            
            // 使用内存写入 DEX（避免临时文件）
            dex.reportProgress(80, 100);
            dex.reportMessage("生成 DEX...");
            com.android.tools.smali.dexlib2.writer.io.MemoryDataStore memoryStore = 
                new com.android.tools.smali.dexlib2.writer.io.MemoryDataStore();
            dexPool.writeTo(memoryStore);
            byte[] newDexBytes = java.util.Arrays.copyOf(memoryStore.getBuffer(), memoryStore.getSize());
            
            Log.d(TAG, "Merged DEX size: " + newDexBytes.length + " bytes");
            
            // MT 风格：直接替换 APK 内的 DEX
            dex.reportTitle("更新 APK");
            dex.reportMessage("正在替换 DEX...");
            dex.reportProgress(85, 100);
            
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
                dex.copyFile(tempApkFile, apkFile);
                tempApkFile.delete();
            }
            
            Log.d(TAG, "APK updated successfully: " + apkPath);
            dex.reportProgress(100, 100);
            
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
}
