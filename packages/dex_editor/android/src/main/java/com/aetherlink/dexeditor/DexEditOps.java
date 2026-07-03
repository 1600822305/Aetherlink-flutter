package com.aetherlink.dexeditor;

import android.util.Log;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;
import com.aetherlink.dexeditor.utils.SmaliUtils;

import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;
import com.android.tools.smali.dexlib2.iface.MethodImplementation;
import com.android.tools.smali.dexlib2.iface.instruction.Instruction;
import com.android.tools.smali.dexlib2.immutable.ImmutableClassDef;

/**
 * DexEditOps - 单 DEX 会话内的类/方法/字段 CRUD。
 *
 * 从 {@link DexManager} 抽出（原「类操作 / 方法操作 / 字段操作」三段）。
 * 每个操作均 C++ 优先 + dexlib2 回退。会话查找、classToSmali 反汇编、
 * findClass/findMethod/compileSmaliToClass 等基础能力仍由 DexManager 提供，
 * 本类持有其引用做回调，smali 文本拼接直接走 {@link SmaliUtils}。
 */
class DexEditOps {

    private static final String TAG = "DexEditOps";

    private final DexManager dex;

    DexEditOps(DexManager dex) {
        this.dex = dex;
    }

    // ==================== 类操作 ====================

    /** 获取所有类列表（优先使用 C++ 实现）。 */
    JSArray getClasses(String sessionId) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.listClasses(session.dexBytes, "", 0, 100000);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppClasses = cppResult.optJSONArray("classes");
                    if (cppClasses != null) {
                        JSArray classes = new JSArray();
                        for (int i = 0; i < cppClasses.length(); i++) {
                            String className = cppClasses.getString(i);
                            if (!session.removedClasses.contains(className)) {
                                JSObject classInfo = new JSObject();
                                classInfo.put("type", className);
                                classes.put(classInfo);
                            }
                        }
                        return classes;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ getClasses failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        JSArray classes = new JSArray();
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (!session.removedClasses.contains(classDef.getType())) {
                JSObject classInfo = new JSObject();
                classInfo.put("type", classDef.getType());
                classInfo.put("accessFlags", classDef.getAccessFlags());
                classInfo.put("superclass", classDef.getSuperclass());
                classes.put(classInfo);
            }
        }
        return classes;
    }

    /** 获取类详细信息。 */
    JSObject getClassInfo(String sessionId, String className) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        JSObject info = new JSObject();
        info.put("type", classDef.getType());
        info.put("accessFlags", classDef.getAccessFlags());
        info.put("superclass", classDef.getSuperclass());

        // 接口
        JSArray interfaces = new JSArray();
        for (String iface : classDef.getInterfaces()) {
            interfaces.put(iface);
        }
        info.put("interfaces", interfaces);

        // 方法数量
        int methodCount = 0;
        for (Method ignored : classDef.getMethods()) {
            methodCount++;
        }
        info.put("methodCount", methodCount);

        // 字段数量
        int fieldCount = 0;
        for (Field ignored : classDef.getFields()) {
            fieldCount++;
        }
        info.put("fieldCount", fieldCount);

        return info;
    }

    /** 添加类（优先使用 C++ 实现）。 */
    void addClass(String sessionId, String smaliCode) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                byte[] newDexBytes = CppDex.addClass(session.dexBytes, smaliCode);
                if (newDexBytes != null) {
                    session.dexBytes = newDexBytes;
                    session.modified = true;
                    Log.d(TAG, "Added class via C++");
                    return;
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ addClass failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        ClassDef newClass = dex.compileSmaliToClass(smaliCode, session.originalDexFile.getOpcodes());
        session.modifiedClasses.add(newClass);
        session.modified = true;

        Log.d(TAG, "Added class: " + newClass.getType());
    }

    /** 删除类（优先使用 C++ 实现）。 */
    void removeClass(String sessionId, String className) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                byte[] newDexBytes = CppDex.deleteClass(session.dexBytes, className);
                if (newDexBytes != null) {
                    session.dexBytes = newDexBytes;
                    session.modified = true;
                    Log.d(TAG, "Removed class via C++: " + className);
                    return;
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ removeClass failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        session.removedClasses.add(className);
        session.modified = true;

        Log.d(TAG, "Removed class: " + className);
    }

    /** 重命名类。 */
    void renameClass(String sessionId, String oldName, String newName) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef originalClass = dex.findClass(session, oldName);

        if (originalClass == null) {
            throw new IllegalArgumentException("Class not found: " + oldName);
        }

        // 创建重命名后的类
        ImmutableClassDef renamedClass = new ImmutableClassDef(
            newName,
            originalClass.getAccessFlags(),
            originalClass.getSuperclass(),
            originalClass.getInterfaces(),
            originalClass.getSourceFile(),
            originalClass.getAnnotations(),
            originalClass.getFields(),
            originalClass.getMethods()
        );

        session.removedClasses.add(oldName);
        session.modifiedClasses.add(renamedClass);
        session.modified = true;

        Log.d(TAG, "Renamed class: " + oldName + " -> " + newName);
    }

    // ==================== 方法操作 ====================

    /** 获取类的所有方法（优先使用 C++ 实现）。 */
    JSArray getMethods(String sessionId, String className) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.listMethods(session.dexBytes, className);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppMethods = cppResult.optJSONArray("methods");
                    if (cppMethods != null) {
                        JSArray methods = new JSArray();
                        for (int i = 0; i < cppMethods.length(); i++) {
                            org.json.JSONObject m = cppMethods.getJSONObject(i);
                            JSObject methodInfo = new JSObject();
                            methodInfo.put("name", m.optString("name"));
                            methodInfo.put("signature", m.optString("prototype"));
                            methodInfo.put("accessFlags", m.optInt("accessFlags"));
                            methods.put(methodInfo);
                        }
                        return methods;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ getMethods failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        ClassDef classDef = dex.findClass(session, className);
        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        JSArray methods = new JSArray();
        for (Method method : classDef.getMethods()) {
            JSObject methodInfo = new JSObject();
            methodInfo.put("name", method.getName());
            methodInfo.put("returnType", method.getReturnType());
            methodInfo.put("accessFlags", method.getAccessFlags());

            JSArray params = new JSArray();
            for (CharSequence param : method.getParameterTypes()) {
                params.put(param.toString());
            }
            methodInfo.put("parameters", params);

            StringBuilder sig = new StringBuilder("(");
            for (CharSequence param : method.getParameterTypes()) {
                sig.append(param);
            }
            sig.append(")").append(method.getReturnType());
            methodInfo.put("signature", sig.toString());

            methods.put(methodInfo);
        }
        return methods;
    }

    /** 获取方法详细信息。 */
    JSObject getMethodInfo(String sessionId, String className,
                           String methodName, String methodSignature) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        Method method = dex.findMethod(session, className, methodName, methodSignature);

        if (method == null) {
            throw new IllegalArgumentException("Method not found: " + methodName);
        }

        JSObject info = new JSObject();
        info.put("name", method.getName());
        info.put("returnType", method.getReturnType());
        info.put("accessFlags", method.getAccessFlags());
        info.put("definingClass", method.getDefiningClass());

        // 参数
        JSArray params = new JSArray();
        for (CharSequence param : method.getParameterTypes()) {
            params.put(param.toString());
        }
        info.put("parameters", params);

        // 实现信息
        MethodImplementation impl = method.getImplementation();
        if (impl != null) {
            info.put("registerCount", impl.getRegisterCount());
            int instructionCount = 0;
            for (Instruction ignored : impl.getInstructions()) {
                instructionCount++;
            }
            info.put("instructionCount", instructionCount);
        }

        return info;
    }

    /** 获取方法的 Smali 代码（优先使用 C++ 实现）。 */
    JSObject getMethodSmali(String sessionId, String className,
                            String methodName, String methodSignature) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.getMethodSmali(session.dexBytes, className, methodName, methodSignature);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    String smali = cppResult.optString("smali", "");
                    if (!smali.isEmpty()) {
                        JSObject result = new JSObject();
                        result.put("className", className);
                        result.put("methodName", methodName);
                        result.put("methodSignature", methodSignature);
                        result.put("smali", smali);
                        result.put("engine", "cpp");
                        return result;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ getMethodSmali failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        JSObject result = new JSObject();
        result.put("className", className);
        result.put("methodName", methodName);
        result.put("methodSignature", methodSignature);
        result.put("smali", SmaliUtils.extractMethodSmali(classSmali, methodName, methodSignature));
        result.put("engine", "java");
        return result;
    }

    /** 设置方法的 Smali 代码（优先使用 C++ 实现）。 */
    void setMethodSmali(String sessionId, String className,
                        String methodName, String methodSignature,
                        String smaliCode) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 获取原类的 Smali 并替换方法
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        String modifiedSmali = SmaliUtils.replaceMethodInSmali(classSmali, methodName, methodSignature, smaliCode);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                byte[] newDexBytes = CppDex.modifyClass(session.dexBytes, className, modifiedSmali);
                if (newDexBytes != null) {
                    session.dexBytes = newDexBytes;
                    session.modified = true;
                    Log.d(TAG, "Modified method via C++: " + className + "->" + methodName);
                    return;
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ modifyClass failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        ClassDef classDef = dex.findClass(session, className);
        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());
        session.removedClasses.add(className);
        session.modifiedClasses.add(modifiedClass);
        session.modified = true;

        Log.d(TAG, "Modified method: " + className + "->" + methodName);
    }

    /** 添加方法。 */
    void addMethod(String sessionId, String className, String smaliCode) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        // 获取原类 Smali 并添加新方法
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        String modifiedSmali = SmaliUtils.insertMethodToSmali(classSmali, smaliCode);

        // 重新编译
        ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());

        session.removedClasses.add(className);
        session.modifiedClasses.add(modifiedClass);
        session.modified = true;
    }

    /** 删除方法。 */
    void removeMethod(String sessionId, String className,
                      String methodName, String methodSignature) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        // 获取原类 Smali 并删除方法
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        String modifiedSmali = SmaliUtils.removeMethodFromSmali(classSmali, methodName, methodSignature);

        // 重新编译
        ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());

        session.removedClasses.add(className);
        session.modifiedClasses.add(modifiedClass);
        session.modified = true;
    }

    // ==================== 字段操作 ====================

    /** 获取类的所有字段（优先使用 C++ 实现）。 */
    JSArray getFields(String sessionId, String className) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 优先使用 C++ 实现
        if (CppDex.isAvailable() && session.dexBytes != null) {
            try {
                String jsonResult = CppDex.listFields(session.dexBytes, className);
                if (jsonResult != null && !jsonResult.contains("\"error\"")) {
                    org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
                    org.json.JSONArray cppFields = cppResult.optJSONArray("fields");
                    if (cppFields != null) {
                        JSArray fields = new JSArray();
                        for (int i = 0; i < cppFields.length(); i++) {
                            org.json.JSONObject f = cppFields.getJSONObject(i);
                            JSObject fieldInfo = new JSObject();
                            fieldInfo.put("name", f.optString("name"));
                            fieldInfo.put("type", f.optString("type"));
                            fieldInfo.put("accessFlags", f.optInt("accessFlags"));
                            fields.put(fieldInfo);
                        }
                        return fields;
                    }
                }
            } catch (Exception e) {
                Log.w(TAG, "C++ getFields failed, fallback to Java", e);
            }
        }

        // Java 回退实现
        ClassDef classDef = dex.findClass(session, className);
        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        JSArray fields = new JSArray();
        for (Field field : classDef.getFields()) {
            JSObject fieldInfo = new JSObject();
            fieldInfo.put("name", field.getName());
            fieldInfo.put("type", field.getType());
            fieldInfo.put("accessFlags", field.getAccessFlags());
            fields.put(fieldInfo);
        }

        return fields;
    }

    /** 获取字段详细信息。 */
    JSObject getFieldInfo(String sessionId, String className, String fieldName) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        for (Field field : classDef.getFields()) {
            if (field.getName().equals(fieldName)) {
                JSObject info = new JSObject();
                info.put("name", field.getName());
                info.put("type", field.getType());
                info.put("accessFlags", field.getAccessFlags());
                info.put("definingClass", field.getDefiningClass());
                return info;
            }
        }

        throw new IllegalArgumentException("Field not found: " + fieldName);
    }

    /** 添加字段。 */
    void addField(String sessionId, String className, String fieldDef) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        // 获取原类 Smali 并添加字段定义
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        String modifiedSmali = SmaliUtils.insertFieldToSmali(classSmali, fieldDef);

        // 重新编译
        ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());

        session.removedClasses.add(className);
        session.modifiedClasses.add(modifiedClass);
        session.modified = true;
    }

    /** 删除字段。 */
    void removeField(String sessionId, String className, String fieldName) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);
        ClassDef classDef = dex.findClass(session, className);

        if (classDef == null) {
            throw new IllegalArgumentException("Class not found: " + className);
        }

        // 获取原类 Smali 并删除字段
        String classSmali = dex.classToSmali(sessionId, className).getString("smali");
        String modifiedSmali = SmaliUtils.removeFieldFromSmali(classSmali, fieldName);

        // 重新编译
        ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());

        session.removedClasses.add(className);
        session.modifiedClasses.add(modifiedClass);
        session.modified = true;
    }
}
