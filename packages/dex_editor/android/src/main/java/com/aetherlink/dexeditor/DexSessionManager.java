package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import java.io.File;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

/**
 * DexSessionManager - DEX 编辑会话的存储与生命周期管理。
 *
 * 从 {@link DexManager} 抽出，集中持有两套会话表：
 *  - {@link #sessions}：单 DEX 会话（旧路径，如 loadDex）；
 *  - {@link #multiDexSessions}：多 DEX 会话（MCP 工作流，如 dex_open）。
 *
 * 会话对象类型 {@link DexManager.DexSession} / {@link DexManager.MultiDexSession}
 * 仍定义在 DexManager 内，本类只负责存取、查找与关闭/列举。
 *
 * <p>会话本体只活在内存，随进程/引擎消亡而丢失。为消除测试中常见的
 * {@code Session not found}，多 DEX 会话额外维护：
 *  - {@link #apkPathToSessionId}：按规范化 apkPath 反查 sessionId（幂等 open + 便捷寻址）；
 *  - {@link #metaStore}：把可重建元数据落盘，配合 {@link #rebuilder} 在查找失败时
 *    按 apkPath 惰性重建会话（{@link #requireOrRebuild}）。
 */
class DexSessionManager {

    private static final String TAG = "DexSessionManager";

    /** 惰性重建回调：根据落盘的元数据用 apkPath 重新打开一个多 DEX 会话。 */
    interface SessionRebuilder {
        DexManager.MultiDexSession rebuild(SessionMetaStore.SessionMeta meta) throws Exception;
    }

    // 单 DEX 会话
    final Map<String, DexManager.DexSession> sessions = new HashMap<>();

    // 多 DEX 会话（MCP 工作流）
    final Map<String, DexManager.MultiDexSession> multiDexSessions = new HashMap<>();

    // 规范化 apkPath → sessionId 索引（用于幂等 open 与按 apkPath 寻址）
    private final Map<String, String> apkPathToSessionId = new HashMap<>();

    // 可重建元数据落盘（进程重启后惰性重建的依据）；未初始化 Context 时为 null
    private SessionMetaStore metaStore;

    // 惰性重建回调（由 DexManager 用 ApkMultiDexOpener 注入）
    private SessionRebuilder rebuilder;

    /** 由 DexManager.setContext 调用，初始化元数据落盘目录。 */
    void initPersistence(File dir) {
        if (dir != null) {
            this.metaStore = new SessionMetaStore(dir);
        }
    }

    void setRebuilder(SessionRebuilder rebuilder) {
        this.rebuilder = rebuilder;
    }

    /** 按规范化 apkPath 取活跃会话的 sessionId，无则返回 null（供幂等 open 用）。 */
    String aliveSessionIdForApk(String apkPath) {
        String sid = apkPathToSessionId.get(SessionMetaStore.normalizeApkPath(apkPath));
        if (sid != null && multiDexSessions.containsKey(sid)) {
            return sid;
        }
        return null;
    }

    /** 登记一个新建/重建的多 DEX 会话到会话表与索引；[recordMeta] 为 true 时同时落盘元数据。 */
    void registerMultiDexSession(DexManager.MultiDexSession session, List<String> dexFiles,
                                 boolean recordMeta) {
        multiDexSessions.put(session.sessionId, session);
        apkPathToSessionId.put(SessionMetaStore.normalizeApkPath(session.apkPath), session.sessionId);
        if (recordMeta && metaStore != null) {
            metaStore.put(new SessionMetaStore.SessionMeta(session.sessionId, session.apkPath, dexFiles));
        }
    }

    /** 标记会话有未保存改动（写类操作后调用），并落盘。key 可为 sessionId 或 apkPath。 */
    void markModified(String key) {
        if (metaStore == null) return;
        SessionMetaStore.SessionMeta meta = resolveMeta(key);
        if (meta != null && !meta.modified) {
            meta.modified = true;
            meta.lastAccessAt = System.currentTimeMillis();
            metaStore.put(meta);
        }
    }

    /** 标记会话改动已保存到 APK（dex_save 成功后调用）。key 可为 sessionId 或 apkPath。 */
    void markSaved(String key) {
        if (metaStore == null) return;
        SessionMetaStore.SessionMeta meta = resolveMeta(key);
        if (meta != null && meta.modified) {
            meta.modified = false;
            meta.lastAccessAt = System.currentTimeMillis();
            metaStore.put(meta);
        }
    }

    /** 所有已知会话的元数据已保存（saveAll 成功后调用）。 */
    void markAllSaved() {
        if (metaStore == null) return;
        for (SessionMetaStore.SessionMeta meta : metaStore.all()) {
            if (meta.modified) {
                meta.modified = false;
                metaStore.put(meta);
            }
        }
    }

    private SessionMetaStore.SessionMeta resolveMeta(String key) {
        if (metaStore == null || key == null) return null;
        SessionMetaStore.SessionMeta meta = metaStore.getBySessionId(key);
        if (meta != null) return meta;
        // key 可能是 apkPath；也可能是活跃会话的 sessionId，需借索引反查其 apkPath
        DexManager.MultiDexSession live = multiDexSessions.get(key);
        if (live != null) {
            return metaStore.getBySessionId(live.sessionId);
        }
        return metaStore.getByApkPath(key);
    }

    /** 按 id 取单 DEX 会话；不存在抛出异常。 */
    DexManager.DexSession getSession(String sessionId) throws Exception {
        DexManager.DexSession session = sessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        return session;
    }

    /**
     * 按 key（sessionId 或 apkPath）取多 DEX 会话；不存在则尝试按落盘元数据惰性重建。
     *
     * <p>历史上会话丢失就直接抛 {@code Session not found}。现在改为：
     *  1) 命中活跃会话（key=sessionId）→ 直接返回；
     *  2) 命中 apkPath 索引的活跃会话 → 返回；
     *  3) 有落盘元数据 → 用 apkPath 重新打开（只读命令完全无感）；
     *  4) 元数据显示上次有未保存(dex_save)的改动 → 那些改动已随进程丢失，
     *     清掉过期元数据并抛出**可读**错误，明确告知需重做，而非假装成功；
     *  5) 从未打开过 → 仍抛 Session not found。
     */
    DexManager.MultiDexSession requireMultiDexSession(String sessionId) {
        return requireOrRebuild(sessionId);
    }

    DexManager.MultiDexSession requireOrRebuild(String key) {
        // 1. 直接命中活跃会话（key = sessionId）
        DexManager.MultiDexSession session = multiDexSessions.get(key);
        if (session != null) {
            return session;
        }
        // 2. 命中 apkPath 索引的活跃会话
        String indexed = apkPathToSessionId.get(SessionMetaStore.normalizeApkPath(key));
        if (indexed != null) {
            session = multiDexSessions.get(indexed);
            if (session != null) {
                return session;
            }
        }
        // 3/4/5. 尝试按落盘元数据惰性重建
        SessionMetaStore.SessionMeta meta = null;
        if (metaStore != null) {
            meta = metaStore.getBySessionId(key);
            if (meta == null) {
                meta = metaStore.getByApkPath(key);
            }
        }
        if (meta == null || rebuilder == null) {
            throw new IllegalArgumentException("Session not found: " + key);
        }
        if (meta.modified) {
            // 未保存改动随进程消失，无法从磁盘 APK 恢复 → 明确告知，不静默丢失
            metaStore.remove(meta.sessionId);
            apkPathToSessionId.remove(SessionMetaStore.normalizeApkPath(meta.apkPath));
            throw new IllegalStateException(
                "会话已失效，且上次有未保存的改动（未 dex_save），这些改动已随会话丢失，"
                + "请重新打开并重做修改。APK: " + meta.apkPath);
        }
        try {
            session = rebuilder.rebuild(meta);
            Log.d(TAG, "Rebuilt multi-dex session " + meta.sessionId + " from " + meta.apkPath);
            return session;
        } catch (Exception e) {
            throw new RuntimeException("会话重建失败（apkPath=" + meta.apkPath + "）: " + e.getMessage(), e);
        }
    }

    /** 关闭单 DEX 会话。 */
    void closeSession(String sessionId) {
        sessions.remove(sessionId);
    }

    /** 关闭多 DEX 会话（同时清理 apkPath 索引与落盘元数据）。key 可为 sessionId 或 apkPath。 */
    void closeMultiDexSession(String key) {
        String sessionId = key;
        DexManager.MultiDexSession session = multiDexSessions.get(key);
        if (session == null) {
            String indexed = apkPathToSessionId.get(SessionMetaStore.normalizeApkPath(key));
            if (indexed != null) {
                sessionId = indexed;
                session = multiDexSessions.get(indexed);
            }
        }
        if (session != null) {
            multiDexSessions.remove(session.sessionId);
            apkPathToSessionId.remove(SessionMetaStore.normalizeApkPath(session.apkPath));
            sessionId = session.sessionId;
        } else {
            apkPathToSessionId.remove(SessionMetaStore.normalizeApkPath(key));
        }
        if (metaStore != null) {
            metaStore.remove(sessionId);
        }
        Log.d(TAG, "Closed multi-dex session: " + sessionId);
    }

    /** 列出所有打开的会话（单 DEX + 多 DEX）。 */
    JSArray listAllSessions() {
        JSArray result = new JSArray();

        // 单 DEX 会话
        for (Map.Entry<String, DexManager.DexSession> entry : sessions.entrySet()) {
            JSObject session = new JSObject();
            session.put("sessionId", entry.getKey());
            session.put("type", "single");
            session.put("filePath", entry.getValue().filePath);
            session.put("modified", entry.getValue().modified);
            result.put(session);
        }

        // 多 DEX 会话（内存中活跃）
        for (Map.Entry<String, DexManager.MultiDexSession> entry : multiDexSessions.entrySet()) {
            JSObject session = new JSObject();
            session.put("sessionId", entry.getKey());
            session.put("type", "multi");
            session.put("apkPath", entry.getValue().apkPath);
            session.put("dexCount", entry.getValue().dexFiles.size());
            session.put("modified", entry.getValue().modified);
            session.put("alive", true);
            result.put(session);
        }

        // 进程重启后仅存于落盘元数据、尚未重建到内存的会话（可按 apkPath 惰性恢复）
        if (metaStore != null) {
            for (SessionMetaStore.SessionMeta meta : metaStore.all()) {
                if (multiDexSessions.containsKey(meta.sessionId)) {
                    continue;
                }
                JSObject session = new JSObject();
                session.put("sessionId", meta.sessionId);
                session.put("type", "multi");
                session.put("apkPath", meta.apkPath);
                session.put("dexCount", meta.dexFiles.size());
                session.put("modified", meta.modified);
                session.put("alive", false);
                session.put("restorable", !meta.modified);
                result.put(session);
            }
        }

        return result;
    }
}
