package com.aetherlink.dexeditor;

import android.util.Log;

/**
 * CppDex - C++ 实现的 DEX 解析器 JNI 接口
 * 高性能 DEX 解析、搜索、反汇编
 */
public class CppDex {
    private static final String TAG = "CppDex";
    private static boolean libraryLoaded = false;

    static {
        try {
            System.loadLibrary("dex_cpp");
            libraryLoaded = true;
            Log.d(TAG, "C++ library loaded successfully");
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Failed to load C++ library: " + e.getMessage());
            libraryLoaded = false;
        }
    }

    /**
     * 检查 C++ 库是否可用
     */
    public static boolean isAvailable() {
        return libraryLoaded;
    }

    // ==================== DEX 解析操作 ====================

    /**
     * 获取 DEX 文件信息
     * @param dexBytes DEX 文件字节数组
     * @return JSON 格式的 DEX 信息
     */
    public static native String getDexInfo(byte[] dexBytes);

    /**
     * 列出 DEX 中的类
     * @param dexBytes DEX 文件字节数组
     * @param packageFilter 包名过滤器
     * @param offset 偏移量
     * @param limit 限制数量
     * @return JSON 格式的类列表
     */
    public static native String listClasses(
        byte[] dexBytes,
        String packageFilter,
        int offset,
        int limit
    );

    /**
     * 在 DEX 中搜索
     * @param dexBytes DEX 文件字节数组
     * @param query 搜索查询
     * @param searchType 搜索类型: class, method, field, string
     * @param caseSensitive 是否区分大小写
     * @param maxResults 最大结果数
     * @return JSON 格式的搜索结果
     */
    public static native String searchInDex(
        byte[] dexBytes,
        String query,
        String searchType,
        boolean caseSensitive,
        int maxResults
    );

    /**
     * 获取类的 Smali 代码
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @return JSON 格式的 Smali 代码
     */
    public static native String getClassSmali(
        byte[] dexBytes,
        String className
    );

    /**
     * 获取单个方法的 Smali 代码
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @param methodName 方法名
     * @param methodSignature 方法签名
     * @return JSON 格式的方法 Smali 代码
     */
    public static native String getMethodSmali(
        byte[] dexBytes,
        String className,
        String methodName,
        String methodSignature
    );

    // ==================== Smali 转 Java ====================

    /**
     * 将 Smali 代码转换为 Java 伪代码
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @return JSON 格式的 Java 伪代码
     */
    public static native String smaliToJava(
        byte[] dexBytes,
        String className
    );

    // ==================== DEX 修改操作 ====================

    /**
     * 修改 DEX 中的类
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @param newSmali 新的 Smali 代码
     * @return 修改后的 DEX 字节数组，失败返回 null
     */
    public static native byte[] modifyClass(
        byte[] dexBytes,
        String className,
        String newSmali
    );

    /**
     * 添加新类到 DEX
     * @param dexBytes DEX 文件字节数组
     * @param newSmali 新类的 Smali 代码
     * @return 修改后的 DEX 字节数组，失败返回 null
     */
    public static native byte[] addClass(
        byte[] dexBytes,
        String newSmali
    );

    /**
     * 从 DEX 中删除类
     * @param dexBytes DEX 文件字节数组
     * @param className 要删除的类名
     * @return 修改后的 DEX 字节数组，失败返回 null
     */
    public static native byte[] deleteClass(
        byte[] dexBytes,
        String className
    );

    // ==================== 方法级操作 ====================

    /**
     * 列出类中的所有方法
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @return JSON 格式的方法列表
     */
    public static native String listMethods(
        byte[] dexBytes,
        String className
    );

    /**
     * 列出类中的所有字段
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @return JSON 格式的字段列表
     */
    public static native String listFields(
        byte[] dexBytes,
        String className
    );

    // ==================== 字符串操作 ====================

    /**
     * 列出 DEX 中的字符串
     * @param dexBytes DEX 文件字节数组
     * @param filter 过滤器
     * @param limit 限制数量
     * @return JSON 格式的字符串列表
     */
    public static native String listStrings(
        byte[] dexBytes,
        String filter,
        int limit
    );

    // ==================== 交叉引用分析 ====================

    /**
     * 查找方法的交叉引用
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @param methodName 方法名
     * @return JSON 格式的交叉引用列表
     */
    public static native String findMethodXrefs(
        byte[] dexBytes,
        String className,
        String methodName
    );

    /**
     * 查找字段的交叉引用
     * @param dexBytes DEX 文件字节数组
     * @param className 类名
     * @param fieldName 字段名
     * @return JSON 格式的交叉引用列表
     */
    public static native String findFieldXrefs(
        byte[] dexBytes,
        String className,
        String fieldName
    );

    // ==================== Smali 编译 ====================

    /**
     * 将 Smali 代码编译为 DEX
     * @param smaliCode Smali 代码
     * @return 编译后的 DEX 字节数组，失败返回 null
     */
    public static native byte[] smaliToDex(String smaliCode);

    // ==================== XML/资源解析 ====================

    /**
     * 解析二进制 XML (AndroidManifest.xml)
     * @param axmlBytes AXML 字节数组
     * @return JSON 格式的解析结果
     */
    public static native String parseAxml(byte[] axmlBytes);

    /**
     * 编辑 AndroidManifest.xml 属性
     * @param axmlBytes AXML 字节数组
     * @param action 操作: set_package, set_version_name, set_version_code, set_min_sdk, set_target_sdk
     * @param value 新值
     * @return 修改后的 AXML 字节数组，失败返回 null
     */
    public static native byte[] editManifest(
        byte[] axmlBytes,
        String action,
        String value
    );

    /**
     * 在 AndroidManifest.xml 中搜索
     * @param axmlBytes AXML 字节数组
     * @param attrName 属性名
     * @param value 值
     * @param limit 限制数量
     * @return JSON 格式的搜索结果
     */
    public static native String searchXml(
        byte[] axmlBytes,
        String attrName,
        String value,
        int limit
    );

    /**
     * 解析 resources.arsc
     * @param arscBytes ARSC 字节数组
     * @return JSON 格式的解析结果
     */
    public static native String parseArsc(byte[] arscBytes);

    /**
     * 搜索 ARSC 字符串
     * @param arscBytes ARSC 字节数组
     * @param pattern 搜索模式
     * @param limit 限制数量
     * @return JSON 格式的搜索结果
     */
    public static native String searchArscStrings(
        byte[] arscBytes,
        String pattern,
        int limit
    );

    /**
     * 搜索 ARSC 资源
     * @param arscBytes ARSC 字节数组
     * @param pattern 搜索模式
     * @param type 资源类型 (string, drawable, layout 等)
     * @param limit 限制数量
     * @return JSON 格式的搜索结果
     */
    public static native String searchArscResources(
        byte[] arscBytes,
        String pattern,
        String type,
        int limit
    );
}
