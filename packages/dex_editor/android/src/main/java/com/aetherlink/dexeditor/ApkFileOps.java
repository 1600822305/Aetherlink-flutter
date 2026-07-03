package com.aetherlink.dexeditor;

import com.aetherlink.dexeditor.compat.JSObject;
import com.aetherlink.dexeditor.ops.ApkResourceOperations;

/**
 * ApkFileOps - APK 内文件/资源的写操作（无需 DEX 会话）。
 *
 * 从 {@link DexManager} 抽出：
 *  - {@link #modifyResourceInApk}：修改 APK 内资源文件（委托 ApkResourceOperations）；
 *  - {@link #deleteFileFromApk}：从 APK 删除文件；
 *  - {@link #addFileToApk}：向 APK 添加/替换文件；
 *  - {@link #getResourceValueInApk}/{@link #setResourceValueInApk}：按资源 ID 读写 resources.arsc。
 *
 * 仅被这些方法使用的私有 helper {@link #replaceApkEntryBytes} 一并迁入本类；
 * 文件复制能力仍由 DexManager 提供，通过 dex 引用回调。
 */
class ApkFileOps {

    private final DexManager dex;

    ApkFileOps(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 修改 APK 中的资源文件
     */
    JSObject modifyResourceInApk(String apkPath, String resourcePath, String newContent) throws Exception {
        return ApkResourceOperations.modifyResourceInApk(apkPath, resourcePath, newContent, false);
    }

    /**
     * 从 APK 中删除指定文件
     */
    JSObject deleteFileFromApk(String apkPath, String filePath) throws Exception {
        JSObject result = new JSObject();
        
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");
        
        java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));
        
        java.util.zip.ZipEntry entry;
        boolean found = false;
        String normalizedPath = filePath.replaceFirst("^/+", "");
        
        while ((entry = zis.getNextEntry()) != null) {
            String entryName = entry.getName();
            
            if (entryName.equals(filePath) || entryName.equals(normalizedPath)) {
                // 跳过要删除的文件
                found = true;
                continue;
            }
            
            // 复制其他文件
            java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                newEntry.setSize(entry.getSize());
                newEntry.setCrc(entry.getCrc());
            }
            zos.putNextEntry(newEntry);
            
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }
        
        zis.close();
        zos.close();
        
        if (!found) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "文件未找到: " + filePath);
            return result;
        }
        
        // 替换原文件
        if (!apkFile.delete()) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "无法删除原 APK");
            return result;
        }
        
        if (!tempApkFile.renameTo(apkFile)) {
            dex.copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
        
        result.put("success", true);
        result.put("message", "文件已删除: " + filePath);
        result.put("needSign", true);
        return result;
    }

    /**
     * 向 APK 中添加或替换文件
     */
    JSObject addFileToApk(String apkPath, String filePath, String content, boolean isBase64) throws Exception {
        JSObject result = new JSObject();
        
        // 解码内容
        byte[] contentBytes;
        if (isBase64) {
            contentBytes = android.util.Base64.decode(content, android.util.Base64.DEFAULT);
        } else {
            contentBytes = content.getBytes("UTF-8");
        }
        
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");
        
        java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos = new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));
        
        java.util.zip.ZipEntry entry;
        String normalizedPath = filePath.replaceFirst("^/+", "");
        boolean replaced = false;
        
        while ((entry = zis.getNextEntry()) != null) {
            String entryName = entry.getName();
            
            if (entryName.equals(filePath) || entryName.equals(normalizedPath)) {
                // 跳过要替换的文件，稍后添加新版本
                replaced = true;
                continue;
            }
            
            // 复制其他文件
            java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                newEntry.setMethod(java.util.zip.ZipEntry.STORED);
                newEntry.setSize(entry.getSize());
                newEntry.setCrc(entry.getCrc());
            }
            zos.putNextEntry(newEntry);
            
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }
        
        // 添加新文件
        java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(normalizedPath);
        newEntry.setSize(contentBytes.length);
        zos.putNextEntry(newEntry);
        zos.write(contentBytes);
        zos.closeEntry();
        
        zis.close();
        zos.close();
        
        // 替换原文件
        if (!apkFile.delete()) {
            tempApkFile.delete();
            result.put("success", false);
            result.put("error", "无法删除原 APK");
            return result;
        }
        
        if (!tempApkFile.renameTo(apkFile)) {
            dex.copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
        
        result.put("success", true);
        result.put("message", replaced ? "文件已替换: " + filePath : "文件已添加: " + filePath);
        result.put("needSign", true);
        return result;
    }

    /**
     * 用原始字节替换 APK 中的某个条目（保持其余条目不变）。
     * resources.arsc 以 STORED（不压缩）写入，以满足 Android 11+ 的安装要求。
     */
    private void replaceApkEntryBytes(String apkPath, String entryName, byte[] newBytes) throws Exception {
        java.io.File apkFile = new java.io.File(apkPath);
        java.io.File tempApkFile = new java.io.File(apkPath + ".tmp");

        boolean storeUncompressed = "resources.arsc".equals(entryName);
        java.util.zip.ZipInputStream zis =
            new java.util.zip.ZipInputStream(new java.io.FileInputStream(apkFile));
        java.util.zip.ZipOutputStream zos =
            new java.util.zip.ZipOutputStream(new java.io.FileOutputStream(tempApkFile));

        java.util.zip.ZipEntry entry;
        while ((entry = zis.getNextEntry()) != null) {
            String name = entry.getName();
            if (name.equals(entryName)) {
                continue; // 稍后写入新版本
            }
            java.util.zip.ZipEntry copy = new java.util.zip.ZipEntry(name);
            if (entry.getMethod() == java.util.zip.ZipEntry.STORED) {
                copy.setMethod(java.util.zip.ZipEntry.STORED);
                copy.setSize(entry.getSize());
                copy.setCrc(entry.getCrc());
            }
            zos.putNextEntry(copy);
            byte[] buffer = new byte[8192];
            int len;
            while ((len = zis.read(buffer)) > 0) {
                zos.write(buffer, 0, len);
            }
            zos.closeEntry();
        }

        java.util.zip.ZipEntry newEntry = new java.util.zip.ZipEntry(entryName);
        if (storeUncompressed) {
            java.util.zip.CRC32 crc = new java.util.zip.CRC32();
            crc.update(newBytes);
            newEntry.setMethod(java.util.zip.ZipEntry.STORED);
            newEntry.setSize(newBytes.length);
            newEntry.setCompressedSize(newBytes.length);
            newEntry.setCrc(crc.getValue());
        }
        zos.putNextEntry(newEntry);
        zos.write(newBytes);
        zos.closeEntry();

        zis.close();
        zos.close();

        if (!apkFile.delete()) {
            tempApkFile.delete();
            throw new Exception("无法删除原 APK");
        }
        if (!tempApkFile.renameTo(apkFile)) {
            dex.copyFile(tempApkFile, apkFile);
            tempApkFile.delete();
        }
    }

    /**
     * 按资源 ID 读取 resources.arsc 里的值（逐 config）。
     */
    JSObject getResourceValueInApk(String apkPath, long resId) throws Exception {
        byte[] arscBytes = CppApkHelper.readFileFromApk(apkPath, "resources.arsc");
        String json = CppDex.getArscResourceValue(arscBytes, resId);
        return new JSObject(json);
    }

    /**
     * 按资源 ID 修改 resources.arsc 里的值并写回 APK。
     */
    JSObject setResourceValueInApk(String apkPath, long resId, String config,
                                          String valueType, String newValue) throws Exception {
        byte[] arscBytes = CppApkHelper.readFileFromApk(apkPath, "resources.arsc");
        byte[] newArsc = CppDex.setArscResourceValue(arscBytes, resId, config, valueType, newValue);
        replaceApkEntryBytes(apkPath, "resources.arsc", newArsc);

        JSObject result = new JSObject();
        result.put("success", true);
        result.put("message", "资源值已修改并写回 resources.arsc");
        result.put("needSign", true);
        return result;
    }
}
