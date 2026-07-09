package com.aetherlink.dexeditor;

import android.util.Log;
import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * CppDexHelper - C++ DEX 操作的封装类
 * 提供高层 API，自动处理 JSON 解析和错误处理
 */
public class CppDexHelper {
    private static final String TAG = "CppDexHelper";

    /**
     * 检查 C++ 库是否可用
     */
    public static boolean isAvailable() {
        return CppDex.isAvailable();
    }

    // ==================== DEX 信息获取 ====================

    /**
     * 获取 DEX 文件信息
     */
    public static JSObject getDexInfo(byte[] dexBytes) throws Exception {
        String jsonResult = CppDex.getDexInfo(dexBytes);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ getDexInfo failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject info = new JSObject();
        info.put("classCount", cppResult.optInt("classCount", 0));
        info.put("methodCount", cppResult.optInt("methodCount", 0));
        info.put("fieldCount", cppResult.optInt("fieldCount", 0));
        info.put("stringCount", cppResult.optInt("stringCount", 0));
        info.put("version", cppResult.optInt("version", 35));
        info.put("engine", "cpp");
        return info;
    }

    /**
     * 列出类
     */
    public static JSArray listClasses(byte[] dexBytes, String packageFilter, int offset, int limit) throws Exception {
        String jsonResult = CppDex.listClasses(dexBytes, packageFilter, offset, limit);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ listClasses failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppClasses = cppResult.optJSONArray("classes");
        JSArray classes = new JSArray();
        if (cppClasses != null) {
            for (int i = 0; i < cppClasses.length(); i++) {
                classes.put(cppClasses.getJSONObject(i).optString("className"));
            }
        }
        return classes;
    }

    /**
     * 列出方法
     */
    public static JSArray listMethods(byte[] dexBytes, String className) throws Exception {
        String jsonResult = CppDex.listMethods(dexBytes, className);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ listMethods failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppMethods = cppResult.optJSONArray("methods");
        JSArray methods = new JSArray();
        if (cppMethods != null) {
            for (int i = 0; i < cppMethods.length(); i++) {
                JSONObject m = cppMethods.getJSONObject(i);
                JSObject methodInfo = new JSObject();
                methodInfo.put("name", m.optString("name"));
                methodInfo.put("signature", m.optString("prototype"));
                methodInfo.put("accessFlags", m.optInt("accessFlags"));
                methods.put(methodInfo);
            }
        }
        return methods;
    }

    /**
     * 列出字段
     */
    public static JSArray listFields(byte[] dexBytes, String className) throws Exception {
        String jsonResult = CppDex.listFields(dexBytes, className);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ listFields failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppFields = cppResult.optJSONArray("fields");
        JSArray fields = new JSArray();
        if (cppFields != null) {
            for (int i = 0; i < cppFields.length(); i++) {
                JSONObject f = cppFields.getJSONObject(i);
                JSObject fieldInfo = new JSObject();
                fieldInfo.put("name", f.optString("name"));
                fieldInfo.put("type", f.optString("type"));
                fieldInfo.put("accessFlags", f.optInt("accessFlags"));
                fields.put(fieldInfo);
            }
        }
        return fields;
    }

    /**
     * 列出字符串池
     */
    public static JSObject listStrings(byte[] dexBytes, String filter, int limit) throws Exception {
        String jsonResult = CppDex.listStrings(dexBytes, filter != null ? filter : "", limit);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ listStrings failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject result = new JSObject();
        
        JSONArray cppStrings = cppResult.optJSONArray("strings");
        JSArray strings = new JSArray();
        if (cppStrings != null) {
            for (int i = 0; i < cppStrings.length(); i++) {
                strings.put(cppStrings.getString(i));
            }
        }
        result.put("strings", strings);
        result.put("total", cppResult.optInt("total", strings.length()));
        result.put("engine", "cpp");
        return result;
    }

    // ==================== Smali 操作 ====================

    /**
     * 获取类的 Smali 代码
     */
    public static String getClassSmali(byte[] dexBytes, String className) throws Exception {
        String jsonResult = CppDex.getClassSmali(dexBytes, className);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ getClassSmali failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        return cppResult.optString("smali", "");
    }

    /**
     * 获取方法的 Smali 代码
     */
    public static String getMethodSmali(byte[] dexBytes, String className, 
                                         String methodName, String methodSignature) throws Exception {
        String jsonResult = CppDex.getMethodSmali(dexBytes, className, methodName, methodSignature);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ getMethodSmali failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        return cppResult.optString("smali", "");
    }

    /**
     * Smali 转 Java 伪代码
     */
    public static String smaliToJava(byte[] dexBytes, String className) throws Exception {
        String jsonResult = CppDex.smaliToJava(dexBytes, className);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ smaliToJava failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        return cppResult.optString("java", "");
    }

    /**
     * Smali 编译为 DEX
     */
    public static byte[] smaliToDex(String smaliCode) throws Exception {
        byte[] dexBytes = CppDex.smaliToDex(smaliCode);
        if (dexBytes == null || dexBytes.length == 0) {
            throw new Exception("C++ smaliToDex failed");
        }
        return dexBytes;
    }

    // ==================== 搜索操作 ====================

    /**
     * 搜索字符串
     */
    public static JSArray searchStrings(byte[] dexBytes, String query, 
                                         boolean caseSensitive, int maxResults) throws Exception {
        String jsonResult = CppDex.searchInDex(dexBytes, query, "string", caseSensitive, maxResults);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchStrings failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppResults = cppResult.optJSONArray("results");
        JSArray results = new JSArray();
        if (cppResults != null) {
            for (int i = 0; i < cppResults.length(); i++) {
                JSONObject r = cppResults.getJSONObject(i);
                JSObject item = new JSObject();
                item.put("value", r.optString("value"));
                item.put("index", r.optInt("index"));
                results.put(item);
            }
        }
        return results;
    }

    /**
     * 搜索方法
     */
    public static JSArray searchMethods(byte[] dexBytes, String query, int maxResults) throws Exception {
        String jsonResult = CppDex.searchInDex(dexBytes, query, "method", false, maxResults);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchMethods failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppResults = cppResult.optJSONArray("results");
        JSArray results = new JSArray();
        if (cppResults != null) {
            for (int i = 0; i < cppResults.length(); i++) {
                JSONObject r = cppResults.getJSONObject(i);
                JSObject item = new JSObject();
                item.put("className", r.optString("className"));
                item.put("methodName", r.optString("name"));
                item.put("returnType", r.optString("returnType", ""));
                results.put(item);
            }
        }
        return results;
    }

    /**
     * 搜索字段
     */
    public static JSArray searchFields(byte[] dexBytes, String query, int maxResults) throws Exception {
        String jsonResult = CppDex.searchInDex(dexBytes, query, "field", false, maxResults);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchFields failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppResults = cppResult.optJSONArray("results");
        JSArray results = new JSArray();
        if (cppResults != null) {
            for (int i = 0; i < cppResults.length(); i++) {
                JSONObject r = cppResults.getJSONObject(i);
                JSObject item = new JSObject();
                item.put("className", r.optString("className"));
                item.put("fieldName", r.optString("name"));
                item.put("fieldType", r.optString("type", ""));
                results.put(item);
            }
        }
        return results;
    }

    // ==================== 交叉引用分析 ====================

    /**
     * 查找方法交叉引用
     */
    public static JSObject findMethodXrefs(byte[] dexBytes, String className, String methodName) throws Exception {
        String jsonResult = CppDex.findMethodXrefs(dexBytes, className, methodName);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ findMethodXrefs failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject result = new JSObject();
        result.put("className", className);
        result.put("methodName", methodName);
        
        JSONArray xrefs = cppResult.optJSONArray("xrefs");
        JSArray xrefArray = new JSArray();
        if (xrefs != null) {
            for (int i = 0; i < xrefs.length(); i++) {
                JSONObject x = xrefs.getJSONObject(i);
                JSObject xref = new JSObject();
                xref.put("callerClass", x.optString("callerClass"));
                xref.put("callerMethod", x.optString("callerMethod"));
                xref.put("offset", x.optInt("offset"));
                xrefArray.put(xref);
            }
        }
        result.put("xrefs", xrefArray);
        result.put("count", xrefArray.length());
        return result;
    }

    /**
     * 查找字段交叉引用
     */
    public static JSObject findFieldXrefs(byte[] dexBytes, String className, String fieldName) throws Exception {
        String jsonResult = CppDex.findFieldXrefs(dexBytes, className, fieldName);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ findFieldXrefs failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject result = new JSObject();
        result.put("className", className);
        result.put("fieldName", fieldName);
        
        JSONArray xrefs = cppResult.optJSONArray("xrefs");
        JSArray xrefArray = new JSArray();
        if (xrefs != null) {
            for (int i = 0; i < xrefs.length(); i++) {
                JSONObject x = xrefs.getJSONObject(i);
                JSObject xref = new JSObject();
                xref.put("accessorClass", x.optString("accessorClass"));
                xref.put("accessorMethod", x.optString("accessorMethod"));
                xref.put("accessType", x.optString("accessType"));
                xrefArray.put(xref);
            }
        }
        result.put("xrefs", xrefArray);
        result.put("count", xrefArray.length());
        return result;
    }

    // ==================== DEX 修改操作 ====================

    /**
     * 添加类
     */
    public static byte[] addClass(byte[] dexBytes, String smaliCode) throws Exception {
        byte[] newDexBytes = CppDex.addClass(dexBytes, smaliCode);
        if (newDexBytes == null) {
            throw new Exception("C++ addClass failed");
        }
        return newDexBytes;
    }

    /**
     * 删除类
     */
    public static byte[] deleteClass(byte[] dexBytes, String className) throws Exception {
        byte[] newDexBytes = CppDex.deleteClass(dexBytes, className);
        if (newDexBytes == null) {
            throw new Exception("C++ deleteClass failed");
        }
        return newDexBytes;
    }

    /**
     * 修改类
     */
    public static byte[] modifyClass(byte[] dexBytes, String className, String newSmali) throws Exception {
        byte[] newDexBytes = CppDex.modifyClass(dexBytes, className, newSmali);
        if (newDexBytes == null) {
            throw new Exception("C++ modifyClass failed");
        }
        return newDexBytes;
    }
}
