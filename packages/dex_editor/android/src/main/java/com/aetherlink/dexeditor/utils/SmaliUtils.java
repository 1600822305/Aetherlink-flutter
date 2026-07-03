package com.aetherlink.dexeditor.utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * SmaliUtils - Smali 代码操作工具类
 * 提供 Smali 代码的解析、修改、提取等功能
 */
public class SmaliUtils {

    /**
     * 从类的 Smali 代码中提取指定方法
     * @param classSmali 类的完整 Smali 代码
     * @param methodName 方法名
     * @param signature 方法签名（可选）
     * @return 方法的 Smali 代码，未找到返回空字符串
     */
    public static String extractMethodSmali(String classSmali, String methodName, String signature) {
        String methodStart = ".method";
        String methodEnd = ".end method";
        
        int searchStart = 0;
        while (true) {
            int start = classSmali.indexOf(methodStart, searchStart);
            if (start == -1) break;
            
            int end = classSmali.indexOf(methodEnd, start);
            if (end == -1) break;
            
            String methodBlock = classSmali.substring(start, end + methodEnd.length());
            if (methodBlock.contains(methodName)) {
                return methodBlock;
            }
            
            searchStart = end + methodEnd.length();
        }
        
        return "";
    }

    /**
     * 从 Smali 代码中提取指定方法（更精确的版本）
     * @param smaliContent Smali 代码
     * @param methodName 方法名
     * @param methodSignature 方法签名（可选）
     * @return 方法的 Smali 代码
     */
    public static String extractMethodFromSmali(String smaliContent, String methodName, String methodSignature) {
        String[] lines = smaliContent.split("\n");
        StringBuilder methodCode = new StringBuilder();
        boolean inMethod = false;
        boolean found = false;
        
        for (String line : lines) {
            if (line.startsWith(".method ")) {
                if (line.contains(" " + methodName + "(") || line.contains(" " + methodName + ";")) {
                    if (methodSignature == null || methodSignature.isEmpty() || line.contains(methodSignature)) {
                        inMethod = true;
                        found = true;
                    }
                }
            }
            
            if (inMethod) {
                methodCode.append(line).append("\n");
                if (line.equals(".end method")) {
                    break;
                }
            }
        }
        
        if (!found) {
            return "# 方法未找到: " + methodName + (methodSignature != null ? methodSignature : "");
        }
        
        return methodCode.toString();
    }

    /**
     * 在类的 Smali 代码中插入新方法
     * @param classSmali 类的完整 Smali 代码
     * @param methodCode 要插入的方法代码
     * @return 修改后的 Smali 代码
     */
    public static String insertMethodToSmali(String classSmali, String methodCode) {
        int endClass = classSmali.lastIndexOf(".end class");
        if (endClass != -1) {
            return classSmali.substring(0, endClass) + "\n" + methodCode + "\n\n" + 
                   classSmali.substring(endClass);
        }
        return classSmali + "\n" + methodCode;
    }

    /**
     * 从类的 Smali 代码中移除指定方法
     * @param classSmali 类的完整 Smali 代码
     * @param methodName 方法名
     * @param signature 方法签名（可选）
     * @return 修改后的 Smali 代码
     */
    public static String removeMethodFromSmali(String classSmali, String methodName, String signature) {
        String methodStart = ".method";
        String methodEnd = ".end method";
        
        int searchStart = 0;
        while (true) {
            int start = classSmali.indexOf(methodStart, searchStart);
            if (start == -1) break;
            
            int end = classSmali.indexOf(methodEnd, start);
            if (end == -1) break;
            
            String methodBlock = classSmali.substring(start, end + methodEnd.length());
            if (methodBlock.contains(methodName)) {
                return classSmali.substring(0, start) + classSmali.substring(end + methodEnd.length());
            }
            
            searchStart = end + methodEnd.length();
        }
        
        return classSmali;
    }

    /**
     * 替换 Smali 代码中的指定方法
     * @param smaliContent Smali 代码
     * @param methodName 方法名
     * @param methodSignature 方法签名（可选）
     * @param newMethodCode 新的方法代码
     * @return 修改后的 Smali 代码
     */
    public static String replaceMethodInSmali(String smaliContent, String methodName, 
                                               String methodSignature, String newMethodCode) {
        String[] lines = smaliContent.split("\n");
        StringBuilder result = new StringBuilder();
        boolean inMethod = false;
        boolean replaced = false;
        
        for (String line : lines) {
            if (line.startsWith(".method ")) {
                if (line.contains(" " + methodName + "(") || line.contains(" " + methodName + ";")) {
                    if (methodSignature == null || methodSignature.isEmpty() || line.contains(methodSignature)) {
                        result.append(newMethodCode.trim()).append("\n");
                        inMethod = true;
                        replaced = true;
                        continue;
                    }
                }
            }
            
            if (inMethod) {
                if (line.equals(".end method")) {
                    inMethod = false;
                }
                continue;
            }
            
            result.append(line).append("\n");
        }
        
        if (!replaced) {
            throw new IllegalArgumentException("Method not found: " + methodName);
        }
        
        return result.toString();
    }

    /**
     * 在类的 Smali 代码中插入新字段
     * @param classSmali 类的完整 Smali 代码
     * @param fieldDef 字段定义
     * @return 修改后的 Smali 代码
     */
    public static String insertFieldToSmali(String classSmali, String fieldDef) {
        int methodPos = classSmali.indexOf(".method");
        if (methodPos != -1) {
            return classSmali.substring(0, methodPos) + fieldDef + "\n\n" + 
                   classSmali.substring(methodPos);
        }
        
        int endClass = classSmali.lastIndexOf(".end class");
        if (endClass != -1) {
            return classSmali.substring(0, endClass) + fieldDef + "\n\n" + 
                   classSmali.substring(endClass);
        }
        
        return classSmali + "\n" + fieldDef;
    }

    /**
     * 从类的 Smali 代码中移除指定字段
     * @param classSmali 类的完整 Smali 代码
     * @param fieldName 字段名
     * @return 修改后的 Smali 代码
     */
    public static String removeFieldFromSmali(String classSmali, String fieldName) {
        String[] lines = classSmali.split("\n");
        StringBuilder result = new StringBuilder();
        
        for (String line : lines) {
            if (!(line.trim().startsWith(".field") && line.contains(fieldName))) {
                result.append(line).append("\n");
            }
        }
        
        return result.toString();
    }

    /**
     * 统计文本中匹配项的数量
     * @param text 要搜索的文本
     * @param query 搜索查询
     * @param regex 是否使用正则表达式
     * @return 匹配数量
     */
    public static int countMatches(String text, String query, boolean regex) {
        int count = 0;
        if (regex) {
            java.util.regex.Matcher matcher = Pattern.compile(query).matcher(text);
            while (matcher.find()) count++;
        } else {
            int index = 0;
            while ((index = text.indexOf(query, index)) != -1) {
                count++;
                index += query.length();
            }
        }
        return count;
    }
}
