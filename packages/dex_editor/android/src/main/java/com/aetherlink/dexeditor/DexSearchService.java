package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;
import com.aetherlink.dexeditor.utils.SmaliUtils;

import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;

import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * DexSearchService - 单 DEX 会话内的搜索（字符串 / 代码 / 方法 / 字段）。
 *
 * 从 {@link DexManager} 抽出。会话查找与 smali 反汇编仍由 DexManager 负责，
 * 本服务持有其引用做回调，只承载搜索逻辑（C++ 优先 + dexlib2 回退）。
 */
class DexSearchService {

    private static final String TAG = "DexSearchService";

    private final DexManager dex;

    DexSearchService(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 搜索字符串（优先使用 C++ 实现）
     */
    JSArray searchString(String sessionId, String query,
                         boolean regex, boolean caseSensitive) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null && !regex) {
            try {
                String jsonResult = CppDex.searchInDex(session.dexBytes, query, "string", caseSensitive, 1000);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppResults = cppResult.optJSONArray("results");
                    if (cppResults != null) {
                        JSArray results = new JSArray();
                        for (int i = 0; i < cppResults.length(); i++) {
                            org.json.JSONObject r = cppResults.getJSONObject(i);
                            JSObject item = new JSObject();
                            item.put("value", r.optString("value"));
                            item.put("index", r.optInt("index"));
                            results.put(item);
                        }
                        return results;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ searchString failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        JSArray results = new JSArray();
        Pattern pattern = null;
        if (regex) {
            int flags = caseSensitive ? 0 : Pattern.CASE_INSENSITIVE;
            pattern = Pattern.compile(query, flags);
        }

        Set<String> searchedStrings = new HashSet<>();
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            checkAndAddString(classDef.getType(), query, regex, caseSensitive, pattern, searchedStrings, results);
            if (classDef.getSuperclass() != null) {
                checkAndAddString(classDef.getSuperclass(), query, regex, caseSensitive, pattern, searchedStrings, results);
            }
        }
        return results;
    }

    /**
     * 搜索代码
     */
    JSArray searchCode(String sessionId, String query, boolean regex) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        JSArray results = new JSArray();

        Pattern pattern = regex ? Pattern.compile(query) : null;

        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (session.removedClasses.contains(classDef.getType())) continue;

            try {
                String smali = dex.classToSmali(sessionId, classDef.getType()).getString("smali");
                boolean match = regex ? pattern.matcher(smali).find() : smali.contains(query);

                if (match) {
                    JSObject item = new JSObject();
                    item.put("className", classDef.getType());
                    item.put("matchCount", SmaliUtils.countMatches(smali, query, regex));
                    results.put(item);
                }
            } catch (Exception e) {
                Log.w(TAG, "Failed to search class: " + classDef.getType(), e);
            }
        }

        return results;
    }

    /**
     * 搜索方法（优先使用 C++ 实现）
     */
    JSArray searchMethod(String sessionId, String query) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.searchInDex(session.dexBytes, query, "method", false, 1000);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppResults = cppResult.optJSONArray("results");
                    if (cppResults != null) {
                        JSArray results = new JSArray();
                        for (int i = 0; i < cppResults.length(); i++) {
                            org.json.JSONObject r = cppResults.getJSONObject(i);
                            JSObject item = new JSObject();
                            item.put("className", r.optString("className"));
                            item.put("methodName", r.optString("name"));
                            item.put("returnType", r.optString("returnType", ""));
                            results.put(item);
                        }
                        return results;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ searchMethod failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        JSArray results = new JSArray();
        String queryLower = query.toLowerCase();
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (session.removedClasses.contains(classDef.getType())) continue;
            for (Method method : classDef.getMethods()) {
                if (method.getName().toLowerCase().contains(queryLower)) {
                    JSObject item = new JSObject();
                    item.put("className", classDef.getType());
                    item.put("methodName", method.getName());
                    item.put("returnType", method.getReturnType());
                    results.put(item);
                }
            }
        }
        return results;
    }

    /**
     * 搜索字段（优先使用 C++ 实现）
     */
    JSArray searchField(String sessionId, String query) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.searchInDex(session.dexBytes, query, "field", false, 1000);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppResults = cppResult.optJSONArray("results");
                    if (cppResults != null) {
                        JSArray results = new JSArray();
                        for (int i = 0; i < cppResults.length(); i++) {
                            org.json.JSONObject r = cppResults.getJSONObject(i);
                            JSObject item = new JSObject();
                            item.put("className", r.optString("className"));
                            item.put("fieldName", r.optString("name"));
                            item.put("fieldType", r.optString("type", ""));
                            results.put(item);
                        }
                        return results;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ searchField failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        JSArray results = new JSArray();
        String queryLower = query.toLowerCase();
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (session.removedClasses.contains(classDef.getType())) continue;
            for (Field field : classDef.getFields()) {
                if (field.getName().toLowerCase().contains(queryLower)) {
                    JSObject item = new JSObject();
                    item.put("className", classDef.getType());
                    item.put("fieldName", field.getName());
                    item.put("fieldType", field.getType());
                    results.put(item);
                }
            }
        }
        return results;
    }

    private void checkAndAddString(String str, String query, boolean regex,
                                   boolean caseSensitive, Pattern pattern,
                                   Set<String> searchedStrings, JSArray results) {
        if (str == null || searchedStrings.contains(str)) return;
        searchedStrings.add(str);

        boolean match;
        if (regex) {
            match = pattern.matcher(str).find();
        } else if (caseSensitive) {
            match = str.contains(query);
        } else {
            match = str.toLowerCase().contains(query.toLowerCase());
        }

        if (match) {
            JSObject item = new JSObject();
            item.put("index", searchedStrings.size() - 1);
            item.put("value", str);
            results.put(item);
        }
    }
}
