package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;

import org.json.JSONArray;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * ApkMultiDexOpener - 从 APK 枚举并打开多 DEX 会话（MCP 工作流入口）。
 *
 * 从 {@link DexManager} 的「MCP 工作流支持方法」段抽出：
 *  - {@link #listDexFilesInApk}：列出 APK 内的所有 DEX 条目；
 *  - {@link #openMultipleDex}：读取指定 DEX 到内存并创建多 DEX 会话；
 *  - {@link #closeMultiDexSession}：关闭多 DEX 会话。
 *
 * 会话存储/生命周期仍由 DexManager 的 sessionManager 提供，通过 dex 引用回调。
 */
class ApkMultiDexOpener {

    private static final String TAG = "ApkMultiDexOpener";

    private final DexManager dex;

    ApkMultiDexOpener(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 列出 APK 中的所有 DEX 文件
     */
    JSObject listDexFilesInApk(String apkPath) throws Exception {
        JSObject result = new JSObject();
        JSArray dexFiles = new JSArray();
        long totalClasses = 0;
        long totalMethods = 0;
        boolean countsAvailable = CppDex.isAvailable();

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
                    // 每个 DEX 的类/方法数（C++ 读 header，成本低）——用于 APK 概览摘要，
                    // 让 dex_open_apk 一次性给出整体规模，而不必先 open。
                    if (countsAvailable) {
                        try {
                            byte[] dexData = readEntryBytes(zipFile, entry);
                            String infoJson = CppDex.getDexInfo(dexData);
                            if (infoJson != null && !infoJson.contains("\"error\"")) {
                                org.json.JSONObject info = new org.json.JSONObject(infoJson);
                                int classes = info.optInt("classes_count", 0);
                                int methods = info.optInt("methods_count", 0);
                                dexInfo.put("classCount", classes);
                                dexInfo.put("methodCount", methods);
                                totalClasses += classes;
                                totalMethods += methods;
                            }
                        } catch (Exception e) {
                            Log.w(TAG, "getDexInfo failed for " + name + ": " + e.getMessage());
                            countsAvailable = false;
                        }
                    }
                    dexFiles.put(dexInfo);
                }
            }

            result.put("apkPath", apkPath);
            result.put("dexFiles", dexFiles);
            result.put("count", dexFiles.length());
            if (countsAvailable) {
                result.put("totalClasses", totalClasses);
                result.put("totalMethods", totalMethods);
            }

            // APK 概要（包名/版本），失败不阻塞列举。
            try {
                JSObject manifest = CppApkHelper.parseManifestFromApk(apkPath);
                result.put("packageName", manifest.optString("packageName", ""));
                result.put("versionCode", manifest.optInt("versionCode", 0));
                result.put("versionName", manifest.optString("versionName", ""));
                result.put("minSdkVersion", manifest.optInt("minSdkVersion", 0));
                result.put("targetSdkVersion", manifest.optInt("targetSdkVersion", 0));
            } catch (Exception e) {
                Log.w(TAG, "parseManifestFromApk failed: " + e.getMessage());
            }

        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }

        return result;
    }

    /** 读取 ZIP 条目全部字节。 */
    private static byte[] readEntryBytes(java.util.zip.ZipFile zipFile,
                                         java.util.zip.ZipEntry entry) throws Exception {
        java.io.InputStream is = zipFile.getInputStream(entry);
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int len;
        while ((len = is.read(buffer)) != -1) {
            baos.write(buffer, 0, len);
        }
        is.close();
        return baos.toByteArray();
    }

    /**
     * 打开多个 DEX 文件创建会话（MCP 工作流）。
     *
     * <p>幂等：同一 apkPath 已有活跃会话时直接复用并返回原 sessionId，不重复读取，
     * 让「重复 open」不再产生一堆孤儿会话（向 MT 的 workspace 常驻体验靠拢）。
     */
    JSObject openMultipleDex(String apkPath, JSONArray dexFiles) throws Exception {
        // 幂等：已有该 APK 的活跃会话则复用
        String existing = dex.sessionManager.aliveSessionIdForApk(apkPath);
        if (existing != null) {
            DexManager.MultiDexSession alive = dex.sessionManager.multiDexSessions.get(existing);
            int classCount = 0;
            for (DexBackedDexFile f : alive.dexFiles.values()) {
                classCount += f.getClasses().size();
            }
            JSObject reused = new JSObject();
            reused.put("sessionId", existing);
            reused.put("apkPath", apkPath);
            reused.put("dexCount", alive.dexFiles.size());
            reused.put("classCount", classCount);
            reused.put("reused", true);
            return reused;
        }

        String sessionId = UUID.randomUUID().toString();
        List<String> dexNames = new ArrayList<>();
        for (int i = 0; i < dexFiles.length(); i++) {
            dexNames.add(dexFiles.getString(i));
        }

        DexManager.MultiDexSession multiSession = new DexManager.MultiDexSession(sessionId, apkPath);
        int totalClasses = loadDexInto(multiSession, apkPath, dexNames);

        // 登记到会话表 + apkPath 索引，并落盘可重建元数据
        dex.sessionManager.registerMultiDexSession(multiSession, dexNames, true);

        JSObject result = new JSObject();
        result.put("sessionId", sessionId);
        result.put("apkPath", apkPath);
        result.put("dexCount", multiSession.dexFiles.size());
        result.put("classCount", totalClasses);

        return result;
    }

    /**
     * 按落盘元数据用 apkPath 重新打开一个会话（保持同一 sessionId，供惰性重建用）。
     * 仅在会话无未保存改动时被调用，因此从磁盘 APK 重读是安全的。
     */
    DexManager.MultiDexSession rebuildSession(SessionMetaStore.SessionMeta meta) throws Exception {
        DexManager.MultiDexSession multiSession =
            new DexManager.MultiDexSession(meta.sessionId, meta.apkPath);
        loadDexInto(multiSession, meta.apkPath, meta.dexFiles);
        // 重建不重新落盘元数据（沿用既有 meta），只放回内存表与索引
        dex.sessionManager.registerMultiDexSession(multiSession, meta.dexFiles, false);
        return multiSession;
    }

    /** 从 APK 读取指定 DEX 到内存并解析进 [session]，返回类总数。 */
    private int loadDexInto(DexManager.MultiDexSession session, String apkPath,
                            List<String> dexNames) throws Exception {
        int totalClasses = 0;
        java.util.zip.ZipFile zipFile = null;
        try {
            zipFile = new java.util.zip.ZipFile(apkPath);

            for (String dexName : dexNames) {
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
                session.addDex(dexName, dexFile, dexData);
                totalClasses += dexFile.getClasses().size();

                Log.d(TAG, "Loaded DEX: " + dexName + " with " + dexFile.getClasses().size() + " classes");
            }

        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        return totalClasses;
    }

    /**
     * 关闭多 DEX 会话
     */
    void closeMultiDexSession(String sessionId) {
        dex.sessionManager.closeMultiDexSession(sessionId);
    }
}
