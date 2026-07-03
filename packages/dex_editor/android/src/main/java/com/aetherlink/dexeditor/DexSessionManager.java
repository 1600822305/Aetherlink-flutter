package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

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
 */
class DexSessionManager {

    private static final String TAG = "DexSessionManager";

    // 单 DEX 会话
    final Map<String, DexManager.DexSession> sessions = new HashMap<>();

    // 多 DEX 会话（MCP 工作流）
    final Map<String, DexManager.MultiDexSession> multiDexSessions = new HashMap<>();

    /** 按 id 取单 DEX 会话；不存在抛出异常。 */
    DexManager.DexSession getSession(String sessionId) throws Exception {
        DexManager.DexSession session = sessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        return session;
    }

    /** 按 id 取多 DEX 会话；不存在抛出异常。 */
    DexManager.MultiDexSession requireMultiDexSession(String sessionId) {
        DexManager.MultiDexSession session = multiDexSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }
        return session;
    }

    /** 关闭单 DEX 会话。 */
    void closeSession(String sessionId) {
        sessions.remove(sessionId);
    }

    /** 关闭多 DEX 会话。 */
    void closeMultiDexSession(String sessionId) {
        multiDexSessions.remove(sessionId);
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

        // 多 DEX 会话
        for (Map.Entry<String, DexManager.MultiDexSession> entry : multiDexSessions.entrySet()) {
            JSObject session = new JSObject();
            session.put("sessionId", entry.getKey());
            session.put("type", "multi");
            session.put("apkPath", entry.getValue().apkPath);
            session.put("dexCount", entry.getValue().dexFiles.size());
            session.put("modified", entry.getValue().modified);
            result.put(session);
        }

        return result;
    }
}
