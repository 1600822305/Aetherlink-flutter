package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;

import org.json.JSONArray;

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
    JSObject openMultipleDex(String apkPath, JSONArray dexFiles) throws Exception {
        JSObject result = new JSObject();
        String sessionId = UUID.randomUUID().toString();
        
        // 创建复合会话
        DexManager.MultiDexSession multiSession = new DexManager.MultiDexSession(sessionId, apkPath);
        
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
        
        dex.sessionManager.multiDexSessions.put(sessionId, multiSession);
        
        result.put("sessionId", sessionId);
        result.put("apkPath", apkPath);
        result.put("dexCount", multiSession.dexFiles.size());
        result.put("classCount", totalClasses);
        
        return result;
    }

    /**
     * 关闭多 DEX 会话
     */
    void closeMultiDexSession(String sessionId) {
        dex.sessionManager.closeMultiDexSession(sessionId);
    }
}
