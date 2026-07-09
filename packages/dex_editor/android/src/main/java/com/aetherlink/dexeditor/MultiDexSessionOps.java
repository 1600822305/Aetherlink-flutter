package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;
import com.aetherlink.dexeditor.utils.SmaliUtils;

import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.Annotation;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * MultiDexSessionOps - 多 DEX 会话（MCP 工作流）内的类/方法/字段读写操作。
 *
 * 从 {@link DexManager} 抽出（原「MCP 工作流支持方法」段里针对 multiDexSessions 的读写）：
 *  - 列类/搜索：getClassesFromMultiSession、searchInMultiSession；
 *  - 类级：getClassSmaliFromSession、modify/add/deleteClassInSession、renameClassInSession；
 *  - 方法级：getMethodFromSession、modifyMethodInSession；
 *  - 结构：listMethodsFromSession、listFieldsFromSession、outlineClassFromSession。
 *
 * 会话查找走 DexManager.sessionManager.multiDexSessions，类名/描述符转换回调
 * DexManager.convertClassNameToType/convertTypeToClassName；C++ 读写走 CppDex，
 * Smali 文本处理走 SmaliUtils。DexManager 保留同名 public 方法作为薄委派。
 */
class MultiDexSessionOps {

    private static final String TAG = "MultiDexSessionOps";

    private final DexManager dex;

    MultiDexSessionOps(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 获取多 DEX 会话中的类列表（Rust 实现）
     */
    public JSObject getClassesFromMultiSession(String sessionId, String packageFilter, int offset, int limit) throws Exception {
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);

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
                        String type = item.optString("type", searchType);
                        JSObject jsItem = new JSObject();
                        jsItem.put("type", type);
                        jsItem.put("dexFile", dexName);
                        // C++ searchInDex 的键随类型而异：
                        //   class  -> {name}
                        //   method -> {class, name, prototype}
                        //   field  -> {class, name, fieldType}
                        //   string -> {value}
                        // 统一归一到 className/methodName/fieldName 等，供 Dart 层消费。
                        switch (type) {
                            case "class":
                                jsItem.put("className", item.optString("className",
                                        item.optString("name", "")));
                                break;
                            case "method":
                                jsItem.put("className", item.optString("className",
                                        item.optString("class", "")));
                                jsItem.put("methodName", item.optString("methodName",
                                        item.optString("name", "")));
                                if (item.has("prototype")) {
                                    jsItem.put("prototype", item.getString("prototype"));
                                }
                                break;
                            case "field":
                                jsItem.put("className", item.optString("className",
                                        item.optString("class", "")));
                                jsItem.put("fieldName", item.optString("fieldName",
                                        item.optString("name", "")));
                                if (item.has("fieldType")) {
                                    jsItem.put("fieldType", item.getString("fieldType"));
                                }
                                break;
                            case "string":
                                jsItem.put("value", item.optString("value", ""));
                                break;
                            default:
                                jsItem.put("className", item.optString("className", ""));
                                if (item.has("methodName")) {
                                    jsItem.put("methodName", item.getString("methodName"));
                                }
                                if (item.has("fieldName")) {
                                    jsItem.put("fieldName", item.getString("fieldName"));
                                }
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
    private JSObject searchStructuralInSession(DexManager.MultiDexSession session, String query,
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换后再查询。
        String targetType = dex.convertClassNameToType(className);
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
                result.put("smaliContent", rustResult.optString("smali", ""));
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换。
        String targetType = dex.convertClassNameToType(className);
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }
        
        // C++ 侧按类型描述符（La/b/C;）匹配，统一转换。
        String targetType = dex.convertClassNameToType(className);
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
        
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        String targetType = dex.convertClassNameToType(className);
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        String targetType = dex.convertClassNameToType(className);
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
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);

        if (!CppDex.isAvailable()) {
            throw new RuntimeException("C++ DEX library not available");
        }

        String targetType = dex.convertClassNameToType(className);

        for (Map.Entry<String, byte[]> entry : session.dexBytes.entrySet()) {
            byte[] dexData = entry.getValue();
            String jsonResult = CppDex.outlineClass(dexData, targetType);
            if (jsonResult == null || jsonResult.contains("\"error\"")) {
                continue;
            }

            org.json.JSONObject obj = new org.json.JSONObject(jsonResult);
            if (!obj.optBoolean("found", false)) {
                continue;
            }

            JSObject result = new JSObject();
            result.put("className", className);
            result.put("dexFile", entry.getKey());
            result.put("accessFlags", obj.optInt("accessFlags", 0));

            String superType = obj.optString("superclass", "");
            if (!superType.isEmpty()) {
                result.put("superclass", dex.convertTypeToClassName(superType));
            }

            JSArray interfaces = new JSArray();
            org.json.JSONArray ifaceArr = obj.optJSONArray("interfaces");
            if (ifaceArr != null) {
                for (int i = 0; i < ifaceArr.length(); i++) {
                    interfaces.put(dex.convertTypeToClassName(ifaceArr.getString(i)));
                }
            }
            result.put("interfaces", interfaces);

            JSArray fields = new JSArray();
            org.json.JSONArray fieldArr = obj.optJSONArray("fields");
            if (fieldArr != null) {
                for (int i = 0; i < fieldArr.length(); i++) {
                    org.json.JSONObject f = fieldArr.getJSONObject(i);
                    JSObject fieldInfo = new JSObject();
                    fieldInfo.put("name", f.optString("name", ""));
                    fieldInfo.put("type", f.optString("type", ""));
                    fieldInfo.put("accessFlags", f.optInt("accessFlags", 0));
                    fields.put(fieldInfo);
                }
            }
            result.put("fields", fields);
            result.put("fieldCount", fields.length());

            JSArray methods = new JSArray();
            org.json.JSONArray methodArr = obj.optJSONArray("methods");
            if (methodArr != null) {
                for (int i = 0; i < methodArr.length(); i++) {
                    org.json.JSONObject m = methodArr.getJSONObject(i);
                    JSObject methodInfo = new JSObject();
                    methodInfo.put("name", m.optString("name", ""));
                    methodInfo.put("returnType", m.optString("returnType", ""));
                    methodInfo.put("accessFlags", m.optInt("accessFlags", 0));
                    methodInfo.put("signature", m.optString("signature", ""));
                    methodInfo.put("instructionsCount", m.optInt("instructionsCount", 0));
                    methods.put(methodInfo);
                }
            }
            result.put("methods", methods);
            result.put("methodCount", methods.length());
            result.put("instructionsCount", obj.optInt("instructionsCount", 0));
            result.put("engine", "cpp");
            return result;
        }

        throw new IllegalArgumentException("Class not found: " + className);
    }

    /**
     * 重命名会话中的类
     */
    public void renameClassInSession(String sessionId, String oldClassName, String newClassName) throws Exception {
        DexManager.MultiDexSession session = dex.sessionManager.requireOrRebuild(sessionId);
        
        // 获取原类的 Smali
        JSObject classResult = getClassSmaliFromSession(sessionId, oldClassName);
        String smaliContent = classResult.optString("smaliContent", "");
        
        if (smaliContent.isEmpty()) {
            throw new IllegalArgumentException("Class not found: " + oldClassName);
        }
        
        String oldType = dex.convertClassNameToType(oldClassName);
        String newType = dex.convertClassNameToType(newClassName);
        
        // 替换类名
        String newSmaliContent = smaliContent.replace(oldType, newType);
        
        // 删除旧类，添加新类
        deleteClassFromSession(sessionId, oldClassName);
        addClassToSession(sessionId, newClassName, newSmaliContent);
        
        Log.d(TAG, "Renamed class: " + oldClassName + " -> " + newClassName);
    }
}
