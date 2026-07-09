package com.aetherlink.dexeditor;

import android.util.Log;
import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;

/**
 * CppApkHelper - C++ APK/资源操作的封装类
 * 处理 AndroidManifest.xml 和 resources.arsc 的解析和编辑
 */
public class CppApkHelper {
    private static final String TAG = "CppApkHelper";

    /**
     * 检查 C++ 库是否可用
     */
    public static boolean isAvailable() {
        return CppDex.isAvailable();
    }

    // ==================== AndroidManifest.xml 操作 ====================

    /**
     * 解析 AndroidManifest.xml
     */
    public static JSObject parseManifest(byte[] axmlBytes) throws Exception {
        String jsonResult = CppDex.parseAxml(axmlBytes);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ parseAxml failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject result = new JSObject();
        
        result.put("packageName", cppResult.optString("packageName", ""));
        result.put("versionCode", cppResult.optInt("versionCode", 0));
        result.put("versionName", cppResult.optString("versionName", ""));
        result.put("minSdkVersion", cppResult.optInt("minSdkVersion", 0));
        result.put("targetSdkVersion", cppResult.optInt("targetSdkVersion", 0));
        
        // 解析 activities
        JSONArray activities = cppResult.optJSONArray("activities");
        if (activities != null) {
            JSArray activityArray = new JSArray();
            for (int i = 0; i < activities.length(); i++) {
                activityArray.put(activities.getString(i));
            }
            result.put("activities", activityArray);
        }
        
        // 解析 permissions
        JSONArray permissions = cppResult.optJSONArray("permissions");
        if (permissions != null) {
            JSArray permArray = new JSArray();
            for (int i = 0; i < permissions.length(); i++) {
                permArray.put(permissions.getString(i));
            }
            result.put("permissions", permArray);
        }
        
        result.put("engine", "cpp");
        return result;
    }

    /**
     * 从 APK 文件解析 AndroidManifest.xml
     */
    public static JSObject parseManifestFromApk(String apkPath) throws Exception {
        byte[] axmlBytes = readFileFromApk(apkPath, "AndroidManifest.xml");
        return parseManifest(axmlBytes);
    }

    /**
     * 编辑 AndroidManifest.xml 属性
     * @param action 操作: set_package, set_version_name, set_version_code, set_min_sdk, set_target_sdk
     */
    public static byte[] editManifest(byte[] axmlBytes, String action, String value) throws Exception {
        byte[] newAxmlBytes = CppDex.editManifest(axmlBytes, action, value);
        if (newAxmlBytes == null) {
            throw new Exception("C++ editManifest failed for action: " + action);
        }
        return newAxmlBytes;
    }

    /**
     * 在 AndroidManifest.xml 中搜索
     */
    public static JSArray searchManifest(byte[] axmlBytes, String attrName, String value, int limit) throws Exception {
        String jsonResult = CppDex.searchXml(axmlBytes, attrName, value, limit);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchXml failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppResults = cppResult.optJSONArray("results");
        JSArray results = new JSArray();
        if (cppResults != null) {
            for (int i = 0; i < cppResults.length(); i++) {
                JSONObject r = cppResults.getJSONObject(i);
                JSObject item = new JSObject();
                // C++ searchXml 的键为 elementName/attributeName/attributeValue/
                // elementPath/elementIndex，之前误读 element/attribute/value 导致全空。
                item.put("element", r.optString("elementName"));
                item.put("attribute", r.optString("attributeName"));
                item.put("value", r.optString("attributeValue"));
                item.put("elementPath", r.optString("elementPath"));
                item.put("elementIndex", r.optInt("elementIndex", -1));
                results.put(item);
            }
        }
        return results;
    }

    // ==================== resources.arsc 操作 ====================

    /**
     * 解析 resources.arsc
     */
    public static JSObject parseArsc(byte[] arscBytes) throws Exception {
        String jsonResult = CppDex.parseArsc(arscBytes);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ parseArsc failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSObject result = new JSObject();
        
        result.put("packageCount", cppResult.optInt("packageCount", 0));
        result.put("stringCount", cppResult.optInt("stringCount", 0));
        result.put("typeCount", cppResult.optInt("typeCount", 0));
        
        // 解析资源类型
        JSONArray types = cppResult.optJSONArray("types");
        if (types != null) {
            JSArray typeArray = new JSArray();
            for (int i = 0; i < types.length(); i++) {
                typeArray.put(types.getString(i));
            }
            result.put("types", typeArray);
        }
        
        result.put("engine", "cpp");
        return result;
    }

    /**
     * 从 APK 文件解析 resources.arsc
     */
    public static JSObject parseArscFromApk(String apkPath) throws Exception {
        byte[] arscBytes = readFileFromApk(apkPath, "resources.arsc");
        return parseArsc(arscBytes);
    }

    /**
     * 搜索 ARSC 字符串
     */
    public static JSArray searchArscStrings(byte[] arscBytes, String pattern, int limit) throws Exception {
        String jsonResult = CppDex.searchArscStrings(arscBytes, pattern, limit);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchArscStrings failed");
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
     * 搜索 ARSC 资源
     */
    public static JSArray searchArscResources(byte[] arscBytes, String pattern, String type, int limit) throws Exception {
        String jsonResult = CppDex.searchArscResources(arscBytes, pattern, type != null ? type : "", limit);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("C++ searchArscResources failed");
        }
        
        JSONObject cppResult = new JSONObject(jsonResult);
        JSONArray cppResults = cppResult.optJSONArray("results");
        JSArray results = new JSArray();
        if (cppResults != null) {
            for (int i = 0; i < cppResults.length(); i++) {
                JSONObject r = cppResults.getJSONObject(i);
                JSObject item = new JSObject();
                item.put("name", r.optString("name"));
                item.put("type", r.optString("type"));
                item.put("value", r.optString("value"));
                item.put("id", r.optString("id"));
                // C++ 已给资源命中补配置限定符 variant（default/zh-rCN/xxhdpi/...）。
                item.put("variant", r.optString("variant", "default"));
                results.put(item);
            }
        }
        return results;
    }

    /**
     * 从 APK 搜索 ARSC 字符串
     */
    public static JSArray searchArscStringsFromApk(String apkPath, String pattern, int limit) throws Exception {
        byte[] arscBytes = readFileFromApk(apkPath, "resources.arsc");
        return searchArscStrings(arscBytes, pattern, limit);
    }

    /**
     * 从 APK 搜索 ARSC 资源
     */
    public static JSArray searchArscResourcesFromApk(String apkPath, String pattern, String type, int limit) throws Exception {
        byte[] arscBytes = readFileFromApk(apkPath, "resources.arsc");
        return searchArscResources(arscBytes, pattern, type, limit);
    }

    // ==================== 辅助方法 ====================

    /**
     * 从 APK 中读取文件
     */
    public static byte[] readFileFromApk(String apkPath, String entryName) throws Exception {
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            ZipEntry entry = zipFile.getEntry(entryName);
            if (entry == null) {
                throw new Exception("Entry not found in APK: " + entryName);
            }
            
            InputStream is = zipFile.getInputStream(entry);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            is.close();
            return baos.toByteArray();
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
    }
}
