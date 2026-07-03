package com.aetherlink.dexeditor;

import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * SessionMetaStore - 多 DEX 会话的「可重建元数据」持久化。
 *
 * <p>会话本体（{@link DexManager.MultiDexSession} 的 dex 字节 / dexlib2 结构）只活在
 * 内存，随插件所属 FlutterEngine / 进程消亡而丢失。本存储只落**元数据**
 * （apkPath + dexFiles 列表 + 是否有未保存改动），使得进程重启后能按 apkPath
 * 惰性重建会话；不落 dex 字节，避免大文件与隐私问题。
 *
 * <p>格式：filesDir/dex_sessions.json，形如
 * {@code {"sessions":[{"sessionId":..,"apkPath":..,"dexFiles":[..],"modified":false,..}]}}。
 */
class SessionMetaStore {

    private static final String TAG = "SessionMetaStore";
    private static final String FILE_NAME = "dex_sessions.json";

    /** 单条会话元数据。{@link #modified} = 有改动但尚未 dex_save 落回 APK。 */
    static class SessionMeta {
        String sessionId;
        String apkPath;
        List<String> dexFiles;
        long createdAt;
        long lastAccessAt;
        boolean modified;

        SessionMeta(String sessionId, String apkPath, List<String> dexFiles) {
            this.sessionId = sessionId;
            this.apkPath = apkPath;
            this.dexFiles = dexFiles != null ? dexFiles : new ArrayList<>();
            this.createdAt = System.currentTimeMillis();
            this.lastAccessAt = this.createdAt;
            this.modified = false;
        }

        private SessionMeta() {}

        JSONObject toJson() {
            JSONObject o = new JSONObject();
            try {
                o.put("sessionId", sessionId);
                o.put("apkPath", apkPath);
                o.put("dexFiles", new JSONArray(dexFiles));
                o.put("createdAt", createdAt);
                o.put("lastAccessAt", lastAccessAt);
                o.put("modified", modified);
            } catch (Exception e) {
                Log.w(TAG, "toJson failed", e);
            }
            return o;
        }

        static SessionMeta fromJson(JSONObject o) {
            SessionMeta m = new SessionMeta();
            m.sessionId = o.optString("sessionId", null);
            m.apkPath = o.optString("apkPath", null);
            m.dexFiles = new ArrayList<>();
            JSONArray arr = o.optJSONArray("dexFiles");
            if (arr != null) {
                for (int i = 0; i < arr.length(); i++) {
                    m.dexFiles.add(arr.optString(i));
                }
            }
            m.createdAt = o.optLong("createdAt", System.currentTimeMillis());
            m.lastAccessAt = o.optLong("lastAccessAt", m.createdAt);
            m.modified = o.optBoolean("modified", false);
            return m;
        }
    }

    private final File file;
    // 保持插入顺序，便于 listSessions 稳定输出
    private final Map<String, SessionMeta> bySession = new LinkedHashMap<>();

    SessionMetaStore(File dir) {
        this.file = new File(dir, FILE_NAME);
        load();
    }

    /** 规范化 APK 路径，用于按 apkPath 匹配/去重（大小写与相对路径归一）。 */
    static String normalizeApkPath(String apkPath) {
        if (apkPath == null) return "";
        try {
            return new File(apkPath).getAbsolutePath();
        } catch (Exception e) {
            return apkPath.trim();
        }
    }

    synchronized SessionMeta getBySessionId(String sessionId) {
        if (sessionId == null) return null;
        return bySession.get(sessionId);
    }

    synchronized SessionMeta getByApkPath(String apkPath) {
        String norm = normalizeApkPath(apkPath);
        for (SessionMeta m : bySession.values()) {
            if (normalizeApkPath(m.apkPath).equals(norm)) {
                return m;
            }
        }
        return null;
    }

    synchronized void put(SessionMeta meta) {
        if (meta == null || meta.sessionId == null) return;
        bySession.put(meta.sessionId, meta);
        save();
    }

    synchronized void remove(String sessionId) {
        if (sessionId == null) return;
        if (bySession.remove(sessionId) != null) {
            save();
        }
    }

    synchronized List<SessionMeta> all() {
        return new ArrayList<>(bySession.values());
    }

    private void load() {
        if (!file.exists()) return;
        try {
            byte[] bytes = readAll(file);
            JSONObject root = new JSONObject(new String(bytes, "UTF-8"));
            JSONArray arr = root.optJSONArray("sessions");
            if (arr == null) return;
            bySession.clear();
            for (int i = 0; i < arr.length(); i++) {
                SessionMeta m = SessionMeta.fromJson(arr.getJSONObject(i));
                if (m.sessionId != null) {
                    bySession.put(m.sessionId, m);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "load failed, starting empty", e);
        }
    }

    private void save() {
        try {
            JSONArray arr = new JSONArray();
            for (SessionMeta m : bySession.values()) {
                arr.put(m.toJson());
            }
            JSONObject root = new JSONObject();
            root.put("sessions", arr);
            File parent = file.getParentFile();
            if (parent != null && !parent.exists()) {
                parent.mkdirs();
            }
            try (FileWriter w = new FileWriter(file, false)) {
                w.write(root.toString());
            }
        } catch (Exception e) {
            Log.w(TAG, "save failed", e);
        }
    }

    private static byte[] readAll(File f) throws Exception {
        try (java.io.FileInputStream in = new java.io.FileInputStream(f)) {
            java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) != -1) {
                out.write(buf, 0, n);
            }
            return out.toByteArray();
        }
    }
}
