package com.aetherlink.dexeditor.ops;

import android.util.Base64;
import android.util.Log;

import com.aetherlink.dexeditor.AxmlEditor;
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
