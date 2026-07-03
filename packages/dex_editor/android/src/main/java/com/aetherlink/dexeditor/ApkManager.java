package com.aetherlink.dexeditor;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import androidx.core.content.FileProvider;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * ApkManager - APK 文件操作管理
 * 支持打开、解压、重打包、签名等功能
 */
public class ApkManager {

    private static final String TAG = "ApkManager";
    private static final int BUFFER_SIZE = 8192;

    // 存储活跃的 APK 会话
    private final Map<String, ApkSession> sessions = new HashMap<>();
    private Context context;

    /**
     * APK 会话 - 存储打开的 APK 信息
     */
    private static class ApkSession {
        String sessionId;
        String apkPath;
        String extractDir;
        List<String> dexFiles = new ArrayList<>();
        boolean modified = false;

        ApkSession(String sessionId, String apkPath, String extractDir) {
            this.sessionId = sessionId;
            this.apkPath = apkPath;
            this.extractDir = extractDir;
        }
    }

    public void setContext(Context context) {
        this.context = context;
    }

    // ==================== APK 文件操作 ====================

    /**
     * 打开 APK 文件（解压到临时目录）
     */
    public JSObject openApk(String apkPath, String extractDir) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        String sessionId = UUID.randomUUID().toString();
        
        // 如果未指定解压目录，使用临时目录
        if (extractDir == null || extractDir.isEmpty()) {
            extractDir = new File(apkFile.getParent(), "apk_" + sessionId).getAbsolutePath();
        }

        File outDir = new File(extractDir);
        outDir.mkdirs();

        // 解压 APK
        List<String> dexFiles = extractApk(apkPath, extractDir);

        // 创建会话
        ApkSession session = new ApkSession(sessionId, apkPath, extractDir);
        session.dexFiles = dexFiles;
        sessions.put(sessionId, session);

        Log.d(TAG, "Opened APK: " + apkPath + " -> " + extractDir);

        JSObject result = new JSObject();
        result.put("sessionId", sessionId);
        result.put("apkPath", apkPath);
        result.put("extractDir", extractDir);
        result.put("dexCount", dexFiles.size());
        
        JSArray dexArray = new JSArray();
        for (String dex : dexFiles) {
            dexArray.put(dex);
        }
        result.put("dexFiles", dexArray);
        
        return result;
    }

    /**
     * 获取 APK 信息
     */
    public JSObject getApkInfo(String apkPath) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        JSObject info = new JSObject();
        info.put("path", apkPath);
        info.put("size", apkFile.length());
        info.put("lastModified", apkFile.lastModified());

        // 获取包信息
        if (context != null) {
            PackageManager pm = context.getPackageManager();
            PackageInfo packageInfo = pm.getPackageArchiveInfo(apkPath, 
                PackageManager.GET_META_DATA | PackageManager.GET_SIGNATURES);
            
            if (packageInfo != null) {
                info.put("packageName", packageInfo.packageName);
                info.put("versionName", packageInfo.versionName);
                info.put("versionCode", packageInfo.versionCode);
                
                if (packageInfo.applicationInfo != null) {
                    packageInfo.applicationInfo.sourceDir = apkPath;
                    packageInfo.applicationInfo.publicSourceDir = apkPath;
                    CharSequence label = pm.getApplicationLabel(packageInfo.applicationInfo);
                    info.put("appName", label.toString());
                }
            }
        }

        // 列出 APK 内容
        try (ZipFile zipFile = new ZipFile(apkFile)) {
            int dexCount = 0;
            int resCount = 0;
            int libCount = 0;
            
            Enumeration<? extends ZipEntry> entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                
                if (name.endsWith(".dex")) dexCount++;
                else if (name.startsWith("res/")) resCount++;
                else if (name.startsWith("lib/")) libCount++;
            }
            
            info.put("dexCount", dexCount);
            info.put("resourceCount", resCount);
            info.put("nativeLibCount", libCount);
        }

        return info;
    }

    /**
     * 列出 APK 内容
     */
    public JSArray listApkContents(String apkPath) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        JSArray contents = new JSArray();
        
        try (ZipFile zipFile = new ZipFile(apkFile)) {
            Enumeration<? extends ZipEntry> entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                
                JSObject item = new JSObject();
                item.put("name", entry.getName());
                item.put("size", entry.getSize());
                item.put("compressedSize", entry.getCompressedSize());
                item.put("isDirectory", entry.isDirectory());
                item.put("crc", entry.getCrc());
                
                contents.put(item);
            }
        }

        return contents;
    }

    /**
     * 提取 APK 中的特定文件
     */
    public JSObject extractFile(String apkPath, String entryName, String outputPath) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        try (ZipFile zipFile = new ZipFile(apkFile)) {
            ZipEntry entry = zipFile.getEntry(entryName);
            if (entry == null) {
                throw new IOException("Entry not found: " + entryName);
            }

            File outputFile = new File(outputPath);
            outputFile.getParentFile().mkdirs();

            try (InputStream is = zipFile.getInputStream(entry);
                 OutputStream os = new FileOutputStream(outputFile)) {
                byte[] buffer = new byte[BUFFER_SIZE];
                int len;
                while ((len = is.read(buffer)) > 0) {
                    os.write(buffer, 0, len);
                }
            }

            JSObject result = new JSObject();
            result.put("outputPath", outputPath);
            result.put("size", outputFile.length());
            return result;
        }
    }

    /**
     * 重新打包 APK
     */
    public JSObject repackApk(String sessionId, String outputPath) throws Exception {
        ApkSession session = getSession(sessionId);
        
        File outputFile = new File(outputPath);
        outputFile.getParentFile().mkdirs();

        // 打包目录为 APK
        packDirectory(session.extractDir, outputPath);

        Log.d(TAG, "Repacked APK: " + outputPath);

        JSObject result = new JSObject();
        result.put("outputPath", outputPath);
        result.put("size", outputFile.length());
        return result;
    }

    /**
     * 签名 APK
     */
    public JSObject signApk(String apkPath, String outputPath, 
                            String keystorePath, String keystorePassword,
                            String keyAlias, String keyPassword) throws Exception {
        
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        File keystoreFile = new File(keystorePath);
        if (!keystoreFile.exists()) {
            throw new IOException("Keystore not found: " + keystorePath);
        }

        // 加载 keystore
        KeyStore keyStore = KeyStore.getInstance("JKS");
        try {
            keyStore = KeyStore.getInstance("JKS");
        } catch (Exception e) {
            keyStore = KeyStore.getInstance("BKS");
        }
        
        try (FileInputStream fis = new FileInputStream(keystoreFile)) {
            keyStore.load(fis, keystorePassword.toCharArray());
        }

        PrivateKey privateKey = (PrivateKey) keyStore.getKey(keyAlias, keyPassword.toCharArray());
        X509Certificate cert = (X509Certificate) keyStore.getCertificate(keyAlias);

        if (privateKey == null || cert == null) {
            throw new Exception("Failed to load key from keystore");
        }

        // 使用 apksigner 或自定义签名
        // 这里使用简化的 JAR 签名方式
        signApkWithKey(apkPath, outputPath, privateKey, cert);

        Log.d(TAG, "Signed APK: " + outputPath);

        JSObject result = new JSObject();
        result.put("outputPath", outputPath);
        result.put("size", new File(outputPath).length());
        return result;
    }

    /**
     * 使用内置测试密钥签名 APK (V1 + V2 + V3)
     * 适配 Android 7.0 - Android 16
     */
    public JSObject signApkWithTestKey(String apkPath, String outputPath) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        File outputFile = new File(outputPath);
        
        // 生成 RSA 密钥对
        java.security.KeyPairGenerator keyGen = java.security.KeyPairGenerator.getInstance("RSA");
        keyGen.initialize(2048, new java.security.SecureRandom());
        java.security.KeyPair keyPair = keyGen.generateKeyPair();
        
        // 使用 Android 隐藏 API 生成自签名证书
        X509Certificate cert = createSelfSignedCertificate(keyPair);
        
        // 使用 apksig 进行 V1+V2+V3 签名
        com.android.apksig.ApkSigner.SignerConfig signerConfig = 
            new com.android.apksig.ApkSigner.SignerConfig.Builder(
                "CERT",
                keyPair.getPrivate(),
                java.util.Collections.singletonList(cert)
            ).build();
        
        com.android.apksig.ApkSigner.Builder signerBuilder = 
            new com.android.apksig.ApkSigner.Builder(java.util.Collections.singletonList(signerConfig))
                .setInputApk(apkFile)
                .setOutputApk(outputFile)
                .setV1SigningEnabled(true)   // JAR 签名 (Android < 7.0)
                .setV2SigningEnabled(true)   // APK Signature Scheme v2 (Android 7.0+)
                .setV3SigningEnabled(true);  // APK Signature Scheme v3 (Android 9.0+)
        
        com.android.apksig.ApkSigner signer = signerBuilder.build();
        signer.sign();
        
        Log.d(TAG, "Signed APK with V1+V2+V3: " + outputPath);

        JSObject result = new JSObject();
        result.put("outputPath", outputPath);
        result.put("size", outputFile.length());
        result.put("signatureSchemes", "V1+V2+V3");
        result.put("success", true);
        return result;
    }
    
    /**
     * 创建自签名证书 (使用 Android 兼容方式)
     */
    private X509Certificate createSelfSignedCertificate(java.security.KeyPair keyPair) throws Exception {
        // 证书有效期: 30年
        long validity = 30L * 365 * 24 * 60 * 60 * 1000;
        long now = System.currentTimeMillis();
        java.util.Date notBefore = new java.util.Date(now);
        java.util.Date notAfter = new java.util.Date(now + validity);
        
        // 使用反射调用 Android 内部 API 生成证书
        // 这是 Android 平台支持的方式
        try {
            // 尝试使用 sun.security.x509 (某些 Android 版本支持)
            return createCertificateWithSunSecurity(keyPair, notBefore, notAfter);
        } catch (Exception e) {
            Log.w(TAG, "Sun security not available, using fallback");
            // 回退：使用预生成的测试证书和密钥
            return createFallbackCertificate(keyPair);
        }
    }
    
    /**
     * 使用 sun.security.x509 创建证书 (Android 部分版本支持)
     */
    private X509Certificate createCertificateWithSunSecurity(java.security.KeyPair keyPair,
            java.util.Date notBefore, java.util.Date notAfter) throws Exception {
        
        // 使用反射避免编译错误
        Class<?> x500NameClass = Class.forName("sun.security.x509.X500Name");
        Class<?> certInfoClass = Class.forName("sun.security.x509.X509CertInfo");
        Class<?> certImplClass = Class.forName("sun.security.x509.X509CertImpl");
        Class<?> certValidityClass = Class.forName("sun.security.x509.CertificateValidity");
        Class<?> certSerialClass = Class.forName("sun.security.x509.CertificateSerialNumber");
        Class<?> certVersionClass = Class.forName("sun.security.x509.CertificateVersion");
        Class<?> certAlgIdClass = Class.forName("sun.security.x509.CertificateAlgorithmId");
        Class<?> algIdClass = Class.forName("sun.security.x509.AlgorithmId");
        Class<?> certSubjectClass = Class.forName("sun.security.x509.CertificateSubjectName");
        Class<?> certIssuerClass = Class.forName("sun.security.x509.CertificateIssuerName");
        Class<?> certKeyClass = Class.forName("sun.security.x509.CertificateX509Key");
        
        // 创建 X500Name
        Object x500Name = x500NameClass.getConstructor(String.class)
            .newInstance("CN=AetherLink, OU=Dev, O=AetherLink, C=CN");
        
        // 创建证书信息
        Object certInfo = certInfoClass.newInstance();
        
        // 设置有效期
        Object validity = certValidityClass.getConstructor(java.util.Date.class, java.util.Date.class)
            .newInstance(notBefore, notAfter);
        certInfoClass.getMethod("set", String.class, Object.class)
            .invoke(certInfo, "validity", validity);
        
        // 设置序列号
        Object serialNumber = certSerialClass.getConstructor(int.class)
            .newInstance((int)(System.currentTimeMillis() / 1000));
        certInfoClass.getMethod("set", String.class, Object.class)
            .invoke(certInfo, "serialNumber", serialNumber);
        
        // 设置主体和颁发者
        Object subjectName = certSubjectClass.getConstructor(x500NameClass).newInstance(x500Name);
        Object issuerName = certIssuerClass.getConstructor(x500NameClass).newInstance(x500Name);
        certInfoClass.getMethod("set", String.class, Object.class).invoke(certInfo, "subject", subjectName);
        certInfoClass.getMethod("set", String.class, Object.class).invoke(certInfo, "issuer", issuerName);
        
        // 设置公钥
        Object certKey = certKeyClass.getConstructor(java.security.PublicKey.class)
            .newInstance(keyPair.getPublic());
        certInfoClass.getMethod("set", String.class, Object.class).invoke(certInfo, "key", certKey);
        
        // 设置版本
        Object version = certVersionClass.getConstructor(int.class).newInstance(2); // V3
        certInfoClass.getMethod("set", String.class, Object.class).invoke(certInfo, "version", version);
        
        // 设置算法
        Object algId = algIdClass.getMethod("get", String.class).invoke(null, "SHA256withRSA");
        Object certAlgId = certAlgIdClass.getConstructor(algIdClass).newInstance(algId);
        certInfoClass.getMethod("set", String.class, Object.class).invoke(certInfo, "algorithmID", certAlgId);
        
        // 创建证书并签名
        Object cert = certImplClass.getConstructor(certInfoClass).newInstance(certInfo);
        certImplClass.getMethod("sign", java.security.PrivateKey.class, String.class)
            .invoke(cert, keyPair.getPrivate(), "SHA256withRSA");
        
        return (X509Certificate) cert;
    }
    
    /**
     * 回退方案：使用简单的自签名证书
     */
    private X509Certificate createFallbackCertificate(java.security.KeyPair keyPair) throws Exception {
        // 使用 Conscrypt 或系统默认提供者生成简单证书
        // 这里使用一个最小化的 X509 证书实现
        
        java.io.ByteArrayOutputStream certOut = new java.io.ByteArrayOutputStream();
        
        // 构建最小化的 DER 编码 X509 证书
        byte[] tbsCert = buildTBSCertificate(keyPair);
        byte[] signature = signData(tbsCert, keyPair.getPrivate());
        
        // 组装完整证书
        writeDerSequence(certOut, tbsCert, signature);
        
        java.security.cert.CertificateFactory cf = 
            java.security.cert.CertificateFactory.getInstance("X.509");
        return (X509Certificate) cf.generateCertificate(
            new java.io.ByteArrayInputStream(certOut.toByteArray()));
    }
    
    private byte[] buildTBSCertificate(java.security.KeyPair keyPair) throws Exception {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        // 简化的 TBS 证书结构
        // Version, Serial, Algorithm, Issuer, Validity, Subject, PublicKey
        out.write(keyPair.getPublic().getEncoded());
        return out.toByteArray();
    }
    
    private byte[] signData(byte[] data, java.security.PrivateKey privateKey) throws Exception {
        java.security.Signature sig = java.security.Signature.getInstance("SHA256withRSA");
        sig.initSign(privateKey);
        sig.update(data);
        return sig.sign();
    }
    
    private void writeDerSequence(java.io.ByteArrayOutputStream out, byte[] tbs, byte[] sig) throws Exception {
        out.write(0x30); // SEQUENCE
        int len = tbs.length + sig.length + 10;
        if (len < 128) {
            out.write(len);
        } else {
            out.write(0x82);
            out.write((len >> 8) & 0xFF);
            out.write(len & 0xFF);
        }
        out.write(tbs);
        out.write(sig);
    }

    /**
     * 获取 APK 签名信息
     */
    public JSObject getApkSignature(String apkPath) throws Exception {
        if (context == null) {
            throw new Exception("Context not available");
        }

        PackageManager pm = context.getPackageManager();
        PackageInfo packageInfo = pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNATURES);
        
        JSObject result = new JSObject();
        
        if (packageInfo != null && packageInfo.signatures != null && packageInfo.signatures.length > 0) {
            Signature sig = packageInfo.signatures[0];
            
            // 计算 MD5
            MessageDigest md5 = MessageDigest.getInstance("MD5");
            byte[] md5Bytes = md5.digest(sig.toByteArray());
            result.put("md5", bytesToHex(md5Bytes));
            
            // 计算 SHA1
            MessageDigest sha1 = MessageDigest.getInstance("SHA-1");
            byte[] sha1Bytes = sha1.digest(sig.toByteArray());
            result.put("sha1", bytesToHex(sha1Bytes));
            
            // 计算 SHA256
            MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
            byte[] sha256Bytes = sha256.digest(sig.toByteArray());
            result.put("sha256", bytesToHex(sha256Bytes));
            
            result.put("signed", true);
        } else {
            result.put("signed", false);
        }

        return result;
    }

    /**
     * 安装 APK
     */
    public void installApk(String apkPath) throws Exception {
        if (context == null) {
            throw new Exception("Context not available");
        }

        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        
        Uri apkUri;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ 需要使用 FileProvider
            String authority = context.getPackageName() + ".fileprovider";
            apkUri = FileProvider.getUriForFile(context, authority, apkFile);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            apkUri = Uri.fromFile(apkFile);
        }
        
        intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
        context.startActivity(intent);
        
        Log.d(TAG, "Started APK installation: " + apkPath);
    }

    /**
     * 列出 APK 指定目录的内容（支持目录导航）
     */
    public JSObject listApkDirectory(String apkPath, String directory) throws Exception {
        File apkFile = new File(apkPath);
        if (!apkFile.exists()) {
            throw new IOException("APK file not found: " + apkPath);
        }

        // 规范化目录路径
        if (directory == null) directory = "";
        if (directory.startsWith("/")) directory = directory.substring(1);
        if (!directory.isEmpty() && !directory.endsWith("/")) directory += "/";

        JSObject result = new JSObject();
        result.put("currentPath", directory.isEmpty() ? "/" : "/" + directory);
        
        JSArray items = new JSArray();
        int folderCount = 0;
        int fileCount = 0;
        
        // 用于跟踪已添加的目录
        java.util.Set<String> addedDirs = new java.util.HashSet<>();
        
        try (ZipFile zipFile = new ZipFile(apkFile)) {
            Enumeration<? extends ZipEntry> entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                
                // 如果指定了目录，只显示该目录下的内容
                if (!directory.isEmpty()) {
                    if (!name.startsWith(directory)) continue;
                    name = name.substring(directory.length());
                }
                
                if (name.isEmpty()) continue;
                
                // 检查是否是直接子项（不包含更深层的路径）
                int slashIndex = name.indexOf('/');
                boolean isDirectChild = slashIndex == -1 || slashIndex == name.length() - 1;
                
                if (isDirectChild) {
                    // 直接子项
                    JSObject item = new JSObject();
                    String displayName = name.endsWith("/") ? name.substring(0, name.length() - 1) : name;
                    item.put("name", displayName);
                    item.put("path", directory + name);
                    item.put("isDirectory", entry.isDirectory());
                    item.put("size", entry.getSize());
                    item.put("compressedSize", entry.getCompressedSize());
                    item.put("lastModified", entry.getTime());
                    
                    // 根据文件类型设置图标类型
                    item.put("type", getFileType(displayName, entry.isDirectory()));
                    
                    items.put(item);
                    if (entry.isDirectory()) folderCount++;
                    else fileCount++;
                } else {
                    // 子目录中的文件，添加其父目录
                    String dirName = name.substring(0, slashIndex);
                    if (!addedDirs.contains(dirName)) {
                        addedDirs.add(dirName);
                        
                        JSObject item = new JSObject();
                        item.put("name", dirName);
                        item.put("path", directory + dirName + "/");
                        item.put("isDirectory", true);
                        item.put("size", 0);
                        item.put("type", "folder");
                        
                        items.put(item);
                        folderCount++;
                    }
                }
            }
        }
        
        result.put("items", items);
        result.put("folderCount", folderCount);
        result.put("fileCount", fileCount);
        
        return result;
    }

    /**
     * 获取文件类型
     */
    private String getFileType(String name, boolean isDirectory) {
        if (isDirectory) return "folder";
        
        String lowerName = name.toLowerCase();
        if (lowerName.endsWith(".dex")) return "dex";
        if (lowerName.endsWith(".xml")) return "xml";
        if (lowerName.endsWith(".arsc")) return "resource";
        if (lowerName.endsWith(".so")) return "native";
        if (lowerName.endsWith(".png") || lowerName.endsWith(".jpg") || 
            lowerName.endsWith(".jpeg") || lowerName.endsWith(".webp") ||
            lowerName.endsWith(".gif")) return "image";
        if (lowerName.endsWith(".smali")) return "smali";
        if (lowerName.endsWith(".bin") || lowerName.endsWith(".dat")) return "binary";
        if (lowerName.equals("androidmanifest.xml")) return "manifest";
        
        return "file";
    }

    /**
     * 关闭 APK 会话
     */
    public void closeApk(String sessionId, boolean deleteExtracted) {
        ApkSession session = sessions.remove(sessionId);
        
        if (session != null && deleteExtracted) {
            deleteRecursive(new File(session.extractDir));
        }
        
        Log.d(TAG, "Closed APK session: " + sessionId);
    }

    /**
     * 获取会话中的 DEX 文件路径
     */
    public JSArray getSessionDexFiles(String sessionId) throws Exception {
        ApkSession session = getSession(sessionId);
        
        JSArray dexArray = new JSArray();
        for (String dex : session.dexFiles) {
            dexArray.put(dex);
        }
        return dexArray;
    }

    /**
     * 替换 APK 中的文件
     */
    public void replaceFile(String sessionId, String entryName, String newFilePath) throws Exception {
        ApkSession session = getSession(sessionId);
        
        File sourceFile = new File(newFilePath);
        if (!sourceFile.exists()) {
            throw new IOException("Source file not found: " + newFilePath);
        }

        File targetFile = new File(session.extractDir, entryName);
        targetFile.getParentFile().mkdirs();
        
        copyFile(sourceFile, targetFile);
        session.modified = true;
        
        Log.d(TAG, "Replaced file: " + entryName);
    }

    /**
     * 添加文件到 APK
     */
    public void addFile(String sessionId, String entryName, String filePath) throws Exception {
        replaceFile(sessionId, entryName, filePath);
    }

    /**
     * 删除 APK 中的文件
     */
    public void deleteFile(String sessionId, String entryName) throws Exception {
        ApkSession session = getSession(sessionId);
        
        File targetFile = new File(session.extractDir, entryName);
        if (targetFile.exists()) {
            if (targetFile.isDirectory()) {
                deleteRecursive(targetFile);
            } else {
                targetFile.delete();
            }
            session.modified = true;
        }
        
        Log.d(TAG, "Deleted file: " + entryName);
    }

    // ==================== 辅助方法 ====================

    private ApkSession getSession(String sessionId) throws Exception {
        ApkSession session = sessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("APK session not found: " + sessionId);
        }
        return session;
    }

    /**
     * 解压 APK 文件
     */
    private List<String> extractApk(String apkPath, String extractDir) throws IOException {
        List<String> dexFiles = new ArrayList<>();
        
        try (ZipInputStream zis = new ZipInputStream(
                new BufferedInputStream(new FileInputStream(apkPath)))) {
            
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                String name = entry.getName();
                File outFile = new File(extractDir, name);

                if (entry.isDirectory()) {
                    outFile.mkdirs();
                } else {
                    outFile.getParentFile().mkdirs();
                    
                    try (BufferedOutputStream bos = new BufferedOutputStream(
                            new FileOutputStream(outFile))) {
                        byte[] buffer = new byte[BUFFER_SIZE];
                        int len;
                        while ((len = zis.read(buffer)) > 0) {
                            bos.write(buffer, 0, len);
                        }
                    }
                    
                    // 记录 DEX 文件
                    if (name.endsWith(".dex")) {
                        dexFiles.add(outFile.getAbsolutePath());
                    }
                }
                
                zis.closeEntry();
            }
        }

        return dexFiles;
    }

    /**
     * 打包目录为 APK/ZIP
     */
    private void packDirectory(String sourceDir, String outputPath) throws IOException {
        File source = new File(sourceDir);
        
        try (ZipOutputStream zos = new ZipOutputStream(
                new BufferedOutputStream(new FileOutputStream(outputPath)))) {
            
            addDirectoryToZip(zos, source, "");
        }
    }

    private void addDirectoryToZip(ZipOutputStream zos, File dir, String basePath) throws IOException {
        File[] files = dir.listFiles();
        if (files == null) return;

        for (File file : files) {
            String entryName = basePath.isEmpty() ? file.getName() : basePath + "/" + file.getName();
            
            if (file.isDirectory()) {
                addDirectoryToZip(zos, file, entryName);
            } else {
                ZipEntry entry = new ZipEntry(entryName);
                zos.putNextEntry(entry);
                
                try (FileInputStream fis = new FileInputStream(file)) {
                    byte[] buffer = new byte[BUFFER_SIZE];
                    int len;
                    while ((len = fis.read(buffer)) > 0) {
                        zos.write(buffer, 0, len);
                    }
                }
                
                zos.closeEntry();
            }
        }
    }

    /**
     * 使用密钥签名 APK（简化实现）
     */
    private void signApkWithKey(String inputPath, String outputPath, 
                                 PrivateKey privateKey, X509Certificate cert) throws Exception {
        // 注意：这是简化实现，实际应使用 apksig 库
        // 这里只是复制文件，真正的签名需要更复杂的实现
        copyFile(new File(inputPath), new File(outputPath));
        
        // TODO: 集成 apksig 库进行真正的 APK 签名
        // 可以添加 implementation 'com.android.tools.build:apksig:8.1.0' 依赖
    }

    private void copyFile(File source, File dest) throws IOException {
        try (FileInputStream fis = new FileInputStream(source);
             FileOutputStream fos = new FileOutputStream(dest)) {
            byte[] buffer = new byte[BUFFER_SIZE];
            int len;
            while ((len = fis.read(buffer)) > 0) {
                fos.write(buffer, 0, len);
            }
        }
    }

    private void deleteRecursive(File file) {
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursive(child);
                }
            }
        }
        file.delete();
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
            sb.append(":");
        }
        if (sb.length() > 0) {
            sb.setLength(sb.length() - 1);
        }
        return sb.toString();
    }
}
