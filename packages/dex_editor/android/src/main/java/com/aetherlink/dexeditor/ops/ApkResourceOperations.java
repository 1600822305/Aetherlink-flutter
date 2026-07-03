package com.aetherlink.dexeditor.ops;

import android.util.Base64;
import android.util.Log;

import com.aetherlink.dexeditor.AxmlEditor;
import com.aetherlink.dexeditor.AxmlManifestPatcher;
import com.aetherlink.dexeditor.AxmlParser;
import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * ApkResourceOperations - APK 资源操作类
 * 提供 Manifest 和资源文件的读取、修改功能
 */
public class ApkResourceOperations {

    private static final String TAG = "ApkResourceOps";

    /**
     * 获取 APK 的 AndroidManifest.xml（解码为可读 XML）
     */
    public static JSObject getManifestFromApk(String apkPath) throws Exception {
        JSObject result = new JSObject();
        
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            ZipEntry manifestEntry = zipFile.getEntry("AndroidManifest.xml");
            
            if (manifestEntry == null) {
                throw new Exception("AndroidManifest.xml not found in APK");
            }
            
            InputStream is = zipFile.getInputStream(manifestEntry);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            is.close();
            
            byte[] axmlData = baos.toByteArray();
            String xmlContent = decodeAxml(axmlData);
            
            result.put("manifest", xmlContent);
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 获取 Manifest 的回退实现（使用简单 AXML 解析器）
     */
    public static String getManifestFallback(String apkPath) {
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            ZipEntry manifestEntry = zipFile.getEntry("AndroidManifest.xml");
            
            if (manifestEntry == null) {
                return "# AndroidManifest.xml not found";
            }
            
            InputStream is = zipFile.getInputStream(manifestEntry);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            is.close();
            
            return decodeAxml(baos.toByteArray());
            
        } catch (Exception e) {
            return "# Error reading manifest: " + e.getMessage();
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
    }

    /**
     * 解码二进制 AXML 为可读 XML
     */
    public static String decodeAxml(byte[] axmlData) {
        try {
            return AxmlParser.decode(axmlData);
        } catch (Exception e) {
            Log.e(TAG, "AXML decode error: " + e.getMessage());
            return "# 无法解码 AXML: " + e.getMessage();
        }
    }

    /**
     * 修改 AndroidManifest.xml
     */
    public static JSObject modifyManifestInApk(String apkPath, String newManifestXml) throws Exception {
        JSObject result = new JSObject();
        
        try {
            byte[] newAxmlData = encodeAxml(newManifestXml);
            
            File apkFile = new File(apkPath);
            File tempApk = new File(apkPath + ".tmp");
            
            ZipInputStream zis = new ZipInputStream(
                new BufferedInputStream(new FileInputStream(apkFile)));
            ZipOutputStream zos = new ZipOutputStream(
                new BufferedOutputStream(new FileOutputStream(tempApk)));
            
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.getName().equals("AndroidManifest.xml")) {
                    ZipEntry newEntry = new ZipEntry("AndroidManifest.xml");
                    newEntry.setMethod(ZipEntry.DEFLATED);
                    zos.putNextEntry(newEntry);
                    zos.write(newAxmlData);
                    zos.closeEntry();
                } else {
                    ZipEntry newEntry = new ZipEntry(entry.getName());
                    newEntry.setTime(entry.getTime());
                    if (entry.getMethod() == ZipEntry.STORED) {
                        newEntry.setMethod(ZipEntry.STORED);
                        newEntry.setSize(entry.getSize());
                        newEntry.setCrc(entry.getCrc());
                    } else {
                        newEntry.setMethod(ZipEntry.DEFLATED);
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
            
            if (!apkFile.delete()) {
                Log.e(TAG, "Failed to delete original APK");
            }
            if (!tempApk.renameTo(apkFile)) {
                copyFile(tempApk, apkFile);
                tempApk.delete();
            }
            
            result.put("success", true);
            result.put("message", "AndroidManifest.xml 已修改");
            
        } catch (Exception e) {
            Log.e(TAG, "Modify manifest error: " + e.getMessage(), e);
            result.put("success", false);
            result.put("error", e.getMessage());
        }
        
        return result;
    }

    /**
     * 将 XML 编码为二进制 AXML
     */
    public static byte[] encodeAxml(String xmlContent) throws Exception {
        throw new UnsupportedOperationException("AXML 编码功能暂不支持，请使用 APKTool 进行 Manifest 修改");
    }

    /**
     * 列出 APK 中的资源文件
     */
    public static JSObject listResourcesInApk(String apkPath, String filter) throws Exception {
        JSObject result = new JSObject();
        JSArray resources = new JSArray();
        
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            Enumeration<? extends ZipEntry> entries = zipFile.entries();
            
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                
                if (name.startsWith("res/")) {
                    if (filter != null && !filter.isEmpty()) {
                        if (!name.contains(filter)) {
                            continue;
                        }
                    }
                    
                    JSObject resource = new JSObject();
                    resource.put("path", name);
                    resource.put("size", entry.getSize());
                    resource.put("isXml", name.endsWith(".xml"));
                    resources.put(resource);
                }
            }
            
            result.put("total", resources.length());
            result.put("resources", resources);
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 获取 APK 中的资源文件内容
     */
    public static JSObject getResourceFromApk(String apkPath, String resourcePath) throws Exception {
        JSObject result = new JSObject();
        
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            ZipEntry entry = zipFile.getEntry(resourcePath);
            
            if (entry == null) {
                throw new Exception("Resource not found: " + resourcePath);
            }
            
            InputStream is = zipFile.getInputStream(entry);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            is.close();
            
            byte[] data = baos.toByteArray();
            
            if (resourcePath.endsWith(".xml")) {
                String xmlContent = decodeAxml(data);
                result.put("content", xmlContent);
                result.put("type", "xml");
            } else {
                result.put("content", Base64.encodeToString(data, Base64.NO_WRAP));
                result.put("type", "binary");
            }
            
            result.put("path", resourcePath);
            result.put("size", data.length);
            
        } finally {
            if (zipFile != null) {
                try { zipFile.close(); } catch (Exception ignored) {}
            }
        }
        
        return result;
    }

    /**
     * 精准替换 AndroidManifest.xml 中的字符串
     */
    public static JSObject replaceInManifest(String apkPath, JSONArray replacements) throws Exception {
        JSObject result = new JSObject();
        JSArray details = new JSArray();
        int replacedCount = 0;
        
        try {
            ZipFile zipFile = new ZipFile(apkPath);
            ZipEntry manifestEntry = zipFile.getEntry("AndroidManifest.xml");
            
            if (manifestEntry == null) {
                zipFile.close();
                throw new Exception("AndroidManifest.xml not found in APK");
            }
            
            InputStream is = zipFile.getInputStream(manifestEntry);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) != -1) {
                baos.write(buffer, 0, len);
            }
            is.close();
            zipFile.close();
            
            byte[] axmlData = baos.toByteArray();
            
            AxmlEditor editor = new AxmlEditor(axmlData);
            
            for (int i = 0; i < replacements.length(); i++) {
                JSONObject replacement = replacements.getJSONObject(i);
                String oldValue = replacement.getString("oldValue");
                String newValue = replacement.getString("newValue");
                
                int count = editor.replaceString(oldValue, newValue);
                
                JSObject detail = new JSObject();
                detail.put("oldValue", oldValue);
                detail.put("newValue", newValue);
                detail.put("count", count);
                details.put(detail);
                
                replacedCount += count;
            }
            
            if (replacedCount == 0) {
                result.put("success", true);
                result.put("replacedCount", 0);
                result.put("details", details);
                result.put("message", "未找到匹配的字符串");
                return result;
            }
            
            byte[] modifiedData = editor.build();
            
            File apkFile = new File(apkPath);
            File tempApk = new File(apkPath + ".tmp");
            
            ZipInputStream zis = new ZipInputStream(
                new BufferedInputStream(new FileInputStream(apkFile)));
            ZipOutputStream zos = new ZipOutputStream(
                new BufferedOutputStream(new FileOutputStream(tempApk)));
            
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.getName().equals("AndroidManifest.xml")) {
                    ZipEntry newEntry = new ZipEntry("AndroidManifest.xml");
                    newEntry.setMethod(ZipEntry.DEFLATED);
                    zos.putNextEntry(newEntry);
                    zos.write(modifiedData);
                    zos.closeEntry();
                } else {
                    ZipEntry newEntry = new ZipEntry(entry.getName());
                    newEntry.setTime(entry.getTime());
                    if (entry.getMethod() == ZipEntry.STORED) {
                        newEntry.setMethod(ZipEntry.STORED);
                        newEntry.setSize(entry.getSize());
                        newEntry.setCrc(entry.getCrc());
                    } else {
                        newEntry.setMethod(ZipEntry.DEFLATED);
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
            
            if (!apkFile.delete()) {
                Log.e(TAG, "Failed to delete original APK");
            }
            if (!tempApk.renameTo(apkFile)) {
                copyFile(tempApk, apkFile);
                tempApk.delete();
            }
            
            result.put("success", true);
            result.put("replacedCount", replacedCount);
            result.put("details", details);
            
        } catch (Exception e) {
            Log.e(TAG, "Replace in manifest error: " + e.getMessage(), e);
            result.put("success", false);
            result.put("error", e.getMessage());
        }
        
        return result;
    }

    /**
     * 修改 APK 中的资源文件
     */
    public static JSObject modifyResourceInApk(String apkPath, String resourcePath, String newContent, boolean isBase64) throws Exception {
        JSObject result = new JSObject();
        
        try {
            byte[] newData;
            if (isBase64) {
                newData = Base64.decode(newContent, Base64.NO_WRAP);
            } else {
                newData = newContent.getBytes("UTF-8");
            }
            
            File apkFile = new File(apkPath);
            File tempApk = new File(apkPath + ".tmp");
            boolean found = false;
            
            ZipInputStream zis = new ZipInputStream(
                new BufferedInputStream(new FileInputStream(apkFile)));
            ZipOutputStream zos = new ZipOutputStream(
                new BufferedOutputStream(new FileOutputStream(tempApk)));
            
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                String entryName = entry.getName();
                
                if (entryName.equals(resourcePath) || entryName.equals(resourcePath.replaceFirst("^/", ""))) {
                    ZipEntry newEntry = new ZipEntry(entryName);
                    newEntry.setMethod(ZipEntry.DEFLATED);
                    zos.putNextEntry(newEntry);
                    zos.write(newData);
                    zos.closeEntry();
                    found = true;
                } else {
                    ZipEntry newEntry = new ZipEntry(entryName);
                    newEntry.setTime(entry.getTime());
                    if (entry.getMethod() == ZipEntry.STORED) {
                        newEntry.setMethod(ZipEntry.STORED);
                        newEntry.setSize(entry.getSize());
                        newEntry.setCrc(entry.getCrc());
                    } else {
                        newEntry.setMethod(ZipEntry.DEFLATED);
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
            
            if (!found) {
                tempApk.delete();
                result.put("success", false);
                result.put("error", "资源文件未找到: " + resourcePath);
                return result;
            }
            
            if (!apkFile.delete()) {
                Log.e(TAG, "Failed to delete original APK");
            }
            if (!tempApk.renameTo(apkFile)) {
                copyFile(tempApk, apkFile);
                tempApk.delete();
            }
            
            result.put("success", true);
            result.put("message", "资源文件已修改: " + resourcePath);
            
        } catch (Exception e) {
            Log.e(TAG, "Modify resource error: " + e.getMessage(), e);
            result.put("success", false);
            result.put("error", e.getMessage());
        }
        
        return result;
    }

    /**
     * 结构化修改 AndroidManifest.xml 的常见标量属性（无需提供完整 XML）。
     *
     * <p>直接在二进制 AXML 上编辑：int/bool 属性原地改写，string 属性复用或追加
     * 字符串池条目。仅支持对 <b>已存在</b> 属性执行 {@code set}；新增/删除元素或
     * 组件（application/permission/activity/...）属于结构性改动，返回失败明细而
     * 不会破坏 manifest。
     *
     * @param patches 每项形如 {@code {type, action, value?, attributes?}}
     */
    public static JSObject patchManifest(String apkPath, JSONArray patches) throws Exception {
        JSObject result = new JSObject();
        JSArray details = new JSArray();

        if (patches == null || patches.length() == 0) {
            result.put("success", true);
            result.put("appliedCount", 0);
            result.put("details", details);
            result.put("message", "未提供任何补丁");
            return result;
        }

        byte[] axmlData = readManifestBytes(apkPath);
        AxmlManifestPatcher patcher = new AxmlManifestPatcher(axmlData);
        if (!patcher.valid()) {
            result.put("success", false);
            result.put("error", "无法解析 AndroidManifest.xml（不是有效的二进制 AXML）");
            return result;
        }

        int applied = 0;
        for (int i = 0; i < patches.length(); i++) {
            JSONObject patch = patches.optJSONObject(i);
            JSObject detail = new JSObject();
            if (patch == null) {
                detail.put("applied", false);
                detail.put("error", "补丁项不是对象");
                details.put(detail);
                continue;
            }
            String type = patch.optString("type", "");
            String action = patch.optString("action", "set");
            String value = patch.has("value") ? patch.optString("value", "") : "";
            detail.put("type", type);
            detail.put("action", action);
            detail.put("value", value);

            if (!"set".equals(action)) {
                detail.put("applied", false);
                detail.put("error", "暂不支持的 action=" + action + "（仅支持 set；新增/删除元素需使用反编译工具）");
                details.put(detail);
                continue;
            }

            boolean ok;
            String err = null;
            switch (type) {
                case "package":
                    ok = patcher.setStringAttr("manifest", "package", false, value);
                    break;
                case "versionName":
                    ok = patcher.setStringAttr("manifest", "versionName", true, value);
                    break;
                case "versionCode":
                    ok = patcher.setIntAttr("manifest", "versionCode", true, parseIntSafe(value));
                    break;
                case "minSdk":
                    ok = patcher.setIntAttr("uses-sdk", "minSdkVersion", true, parseIntSafe(value));
                    if (!ok) {
                        err = "manifest 中不存在 uses-sdk/minSdkVersion 属性，二进制补丁无法新增";
                    }
                    break;
                case "targetSdk":
                    ok = patcher.setIntAttr("uses-sdk", "targetSdkVersion", true, parseIntSafe(value));
                    if (!ok) {
                        err = "manifest 中不存在 uses-sdk/targetSdkVersion 属性，二进制补丁无法新增";
                    }
                    break;
                case "debuggable":
                    ok = patcher.setBoolAttr("application", "debuggable", true, parseBoolSafe(value));
                    if (!ok) {
                        err = "manifest 中不存在 application/debuggable 属性，二进制补丁无法新增";
                    }
                    break;
                case "application":
                case "permission":
                case "activity":
                case "service":
                case "receiver":
                case "provider":
                    ok = false;
                    err = "type=" + type + " 属于结构性改动，二进制补丁不支持（请使用反编译工具修改后回写）";
                    break;
                default:
                    ok = false;
                    err = "未知的 type=" + type;
            }

            detail.put("applied", ok);
            if (ok) {
                applied++;
            } else if (err != null) {
                detail.put("error", err);
            } else {
                detail.put("error", "未找到对应属性: " + type);
            }
            details.put(detail);
        }

        if (applied == 0) {
            result.put("success", false);
            result.put("appliedCount", 0);
            result.put("details", details);
            result.put("error", "没有任何补丁被应用");
            return result;
        }

        byte[] modified = patcher.build();
        writeManifestBytes(apkPath, modified);

        result.put("success", true);
        result.put("appliedCount", applied);
        result.put("details", details);
        result.put("message", "已应用 " + applied + "/" + patches.length() + " 条补丁");
        return result;
    }

    private static int parseIntSafe(String value) {
        try {
            return Integer.parseInt(value.trim());
        } catch (Exception e) {
            return 0;
        }
    }

    private static boolean parseBoolSafe(String value) {
        String v = value == null ? "" : value.trim().toLowerCase();
        return v.equals("true") || v.equals("1") || v.equals("yes");
    }

    /** Reads the raw (binary AXML) AndroidManifest.xml bytes from an APK. */
    private static byte[] readManifestBytes(String apkPath) throws Exception {
        ZipFile zipFile = null;
        try {
            zipFile = new ZipFile(apkPath);
            ZipEntry manifestEntry = zipFile.getEntry("AndroidManifest.xml");
            if (manifestEntry == null) {
                throw new Exception("AndroidManifest.xml not found in APK");
            }
            InputStream is = zipFile.getInputStream(manifestEntry);
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

    /** Writes new AndroidManifest.xml bytes back into the APK, preserving all
     * other entries. Shared by {@link #patchManifest} and manifest editing. */
    private static void writeManifestBytes(String apkPath, byte[] newAxmlData) throws Exception {
        File apkFile = new File(apkPath);
        File tempApk = new File(apkPath + ".tmp");

        ZipInputStream zis = new ZipInputStream(
            new BufferedInputStream(new FileInputStream(apkFile)));
        ZipOutputStream zos = new ZipOutputStream(
            new BufferedOutputStream(new FileOutputStream(tempApk)));

        try {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.getName().equals("AndroidManifest.xml")) {
                    ZipEntry newEntry = new ZipEntry("AndroidManifest.xml");
                    newEntry.setMethod(ZipEntry.DEFLATED);
                    zos.putNextEntry(newEntry);
                    zos.write(newAxmlData);
                    zos.closeEntry();
                } else {
                    ZipEntry newEntry = new ZipEntry(entry.getName());
                    newEntry.setTime(entry.getTime());
                    if (entry.getMethod() == ZipEntry.STORED) {
                        newEntry.setMethod(ZipEntry.STORED);
                        newEntry.setSize(entry.getSize());
                        newEntry.setCrc(entry.getCrc());
                    } else {
                        newEntry.setMethod(ZipEntry.DEFLATED);
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
        } finally {
            try { zis.close(); } catch (Exception ignored) {}
            try { zos.close(); } catch (Exception ignored) {}
        }

        if (!apkFile.delete()) {
            Log.e(TAG, "Failed to delete original APK");
        }
        if (!tempApk.renameTo(apkFile)) {
            copyFile(tempApk, apkFile);
            tempApk.delete();
        }
    }

    /**
     * 复制文件
     */
    private static void copyFile(File src, File dst) throws java.io.IOException {
        try (FileInputStream in = new FileInputStream(src);
             FileOutputStream out = new FileOutputStream(dst)) {
            byte[] buf = new byte[8192];
            int len;
            while ((len = in.read(buf)) > 0) {
                out.write(buf, 0, len);
            }
        }
    }
}
