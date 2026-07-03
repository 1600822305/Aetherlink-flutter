package com.aetherlink.dexeditor;

import com.aetherlink.dexeditor.compat.JSArray;
import com.aetherlink.dexeditor.compat.JSObject;

import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.iface.Field;
import com.android.tools.smali.dexlib2.iface.Method;
import com.android.tools.smali.dexlib2.iface.MethodImplementation;
import com.android.tools.smali.dexlib2.iface.instruction.Instruction;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * DexXrefAnalyzer - DEX 交叉引用分析。
 *
 * 从 {@link DexManager} 抽出，包含：
 *  - C++ 实现的方法/字段 xref（单 DEX 会话）；
 *  - dexlib2 CHA（类继承分析）实现的方法/字段/类级 xref（多 DEX 会话）。
 *
 * 会话查找仍由 DexManager 负责，本类只接收已解析的会话对象。
 */
class DexXrefAnalyzer {

    // ==================== 交叉引用分析（C++ 实现）====================

    /**
     * 查找方法的交叉引用
     */
    JSObject findMethodXrefs(DexManager.DexSession session, String className, String methodName) throws Exception {
        if (!CppDex.isAvailable() || session.dexBytes == null) {
            throw new UnsupportedOperationException("C++ library not available for xref analysis");
        }

        String jsonResult = CppDex.findMethodXrefs(session.dexBytes, className, methodName);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("Failed to find method xrefs");
        }

        org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
        JSObject result = new JSObject();
        result.put("className", className);
        result.put("methodName", methodName);

        org.json.JSONArray xrefs = cppResult.optJSONArray("xrefs");
        JSArray xrefArray = new JSArray();
        if (xrefs != null) {
            for (int i = 0; i < xrefs.length(); i++) {
                org.json.JSONObject x = xrefs.getJSONObject(i);
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
     * 查找字段的交叉引用
     */
    JSObject findFieldXrefs(DexManager.DexSession session, String className, String fieldName) throws Exception {
        if (!CppDex.isAvailable() || session.dexBytes == null) {
            throw new UnsupportedOperationException("C++ library not available for xref analysis");
        }

        String jsonResult = CppDex.findFieldXrefs(session.dexBytes, className, fieldName);
        if (jsonResult == null || jsonResult.contains("\"error\"")) {
            throw new Exception("Failed to find field xrefs");
        }

        org.json.JSONObject cppResult = new org.json.JSONObject(jsonResult);
        JSObject result = new JSObject();
        result.put("className", className);
        result.put("fieldName", fieldName);

        org.json.JSONArray xrefs = cppResult.optJSONArray("xrefs");
        JSArray xrefArray = new JSArray();
        if (xrefs != null) {
            for (int i = 0; i < xrefs.length(); i++) {
                org.json.JSONObject x = xrefs.getJSONObject(i);
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

    // ==================== 交叉引用分析（dexlib2 CHA 实现）====================

    /**
     * CHA（类继承分析）节点：跨会话内全部 DEX 构建的类型图。
     * 找不到定义的 framework 类（Landroid/、Ljava/…）作为叶子/根存在，defined=false。
     */
    static class ChaNode {
        String type;
        String superclass;                       // 可空
        final List<String> interfaces = new ArrayList<>();
        final List<String> subtypes = new ArrayList<>();  // 反向边：直接子类 + 实现者
        final Set<String> methodKeys = new HashSet<>();   // 本类声明的 name+proto
        final Set<String> fieldKeys = new HashSet<>();    // 本类声明的 name:type
        boolean isInterface = false;
        boolean defined = false;
        String dexName;
    }

    /** 方法唯一键：name + "(" + 参数类型 + ")" + 返回类型。 */
    private static String methodKey(CharSequence name, List<? extends CharSequence> params,
                                    CharSequence returnType) {
        StringBuilder sb = new StringBuilder();
        sb.append(name).append('(');
        if (params != null) {
            for (CharSequence p : params) sb.append(p);
        }
        sb.append(')').append(returnType);
        return sb.toString();
    }

    /** 把 Java 类名或已是描述符的类型归一化为 DEX 描述符 Lcom/foo/Bar;。 */
    private String normalizeType(String s) {
        if (s == null || s.isEmpty()) return s;
        if (s.startsWith("L") && s.endsWith(";")) return s;
        if (s.startsWith("[")) return s;
        return convertClassNameToType(s);
    }

    private ChaNode chaGetOrCreate(Map<String, ChaNode> g, String type) {
        ChaNode n = g.get(type);
        if (n == null) {
            n = new ChaNode();
            n.type = type;
            g.put(type, n);
        }
        return n;
    }

    /** 跨会话内全部 DEX 构建类型图并缓存到会话级，避免每次 xref 全量扫描。 */
    private Map<String, ChaNode> buildChaGraph(DexManager.MultiDexSession session) {
        if (session.chaGraph != null) return session.chaGraph;
        Map<String, ChaNode> g = new HashMap<>();
        for (Map.Entry<String, DexBackedDexFile> entry : session.dexFiles.entrySet()) {
            DexBackedDexFile dexFile = entry.getValue();
            if (dexFile == null) continue;
            for (ClassDef cd : dexFile.getClasses()) {
                ChaNode n = chaGetOrCreate(g, cd.getType());
                n.defined = true;
                n.dexName = entry.getKey();
                n.superclass = cd.getSuperclass();
                n.isInterface = (cd.getAccessFlags()
                        & com.android.tools.smali.dexlib2.AccessFlags.INTERFACE.getValue()) != 0;
                n.interfaces.clear();
                for (String iface : cd.getInterfaces()) n.interfaces.add(iface);
                for (Method m : cd.getMethods()) {
                    n.methodKeys.add(methodKey(m.getName(), m.getParameterTypes(), m.getReturnType()));
                }
                for (Field f : cd.getFields()) {
                    n.fieldKeys.add(f.getName() + ":" + f.getType());
                }
            }
        }
        // 建立反向边（子类型），并为缺失的父类型补占位节点
        for (ChaNode n : new ArrayList<>(g.values())) {
            if (n.superclass != null) chaGetOrCreate(g, n.superclass).subtypes.add(n.type);
            for (String iface : n.interfaces) chaGetOrCreate(g, iface).subtypes.add(n.type);
        }
        session.chaGraph = g;
        return g;
    }

    /** C 的全部严格父类型（superclass + interfaces 传递闭包）。 */
    private Set<String> chaSupertypes(Map<String, ChaNode> g, String c) {
        Set<String> out = new HashSet<>();
        ArrayList<String> stack = new ArrayList<>();
        stack.add(c);
        Set<String> seen = new HashSet<>();
        seen.add(c);
        while (!stack.isEmpty()) {
            String cur = stack.remove(stack.size() - 1);
            ChaNode n = g.get(cur);
            if (n == null) continue;
            if (n.superclass != null && seen.add(n.superclass)) {
                out.add(n.superclass);
                stack.add(n.superclass);
            }
            for (String iface : n.interfaces) {
                if (seen.add(iface)) {
                    out.add(iface);
                    stack.add(iface);
                }
            }
        }
        return out;
    }

    /** C 的全部严格子类型（反向边传递闭包）。 */
    private Set<String> chaSubtypes(Map<String, ChaNode> g, String c) {
        Set<String> out = new HashSet<>();
        ArrayList<String> stack = new ArrayList<>();
        ChaNode root = g.get(c);
        if (root != null) stack.addAll(root.subtypes);
        while (!stack.isEmpty()) {
            String cur = stack.remove(stack.size() - 1);
            if (!out.add(cur)) continue;
            ChaNode n = g.get(cur);
            if (n != null) stack.addAll(n.subtypes);
        }
        out.remove(c);
        return out;
    }

    /** 从 X 沿类（superclass）链向上，返回第一个声明了 key 的类；无则返回 null。 */
    private String chaFirstClassDeclarer(Map<String, ChaNode> g, String x, String key) {
        String cur = x;
        Set<String> seen = new HashSet<>();
        while (cur != null && seen.add(cur)) {
            ChaNode n = g.get(cur);
            if (n == null) return null;
            if (n.methodKeys.contains(key)) return cur;
            cur = n.superclass;
        }
        return null;
    }

    private static final int INV_VIRTUAL = 1, INV_SUPER = 2, INV_DIRECT = 3,
            INV_STATIC = 4, INV_INTERFACE = 5;

    /** 判断 invoke 类别；非方法调用返回 0。 */
    private static int invokeCategory(com.android.tools.smali.dexlib2.Opcode op) {
        switch (op) {
            case INVOKE_VIRTUAL:
            case INVOKE_VIRTUAL_RANGE:
                return INV_VIRTUAL;
            case INVOKE_SUPER:
            case INVOKE_SUPER_RANGE:
                return INV_SUPER;
            case INVOKE_DIRECT:
            case INVOKE_DIRECT_RANGE:
                return INV_DIRECT;
            case INVOKE_STATIC:
            case INVOKE_STATIC_RANGE:
                return INV_STATIC;
            case INVOKE_INTERFACE:
            case INVOKE_INTERFACE_RANGE:
                return INV_INTERFACE;
            default:
                return 0;
        }
    }

    private static String invokeTypeName(int cat) {
        switch (cat) {
            case INV_VIRTUAL: return "invoke-virtual";
            case INV_SUPER: return "invoke-super";
            case INV_DIRECT: return "invoke-direct";
            case INV_STATIC: return "invoke-static";
            case INV_INTERFACE: return "invoke-interface";
            default: return "invoke";
        }
    }

    /**
     * 方法交叉引用（CHA），运行在多 DEX 会话上。
     *
     * @param resolution exact（精确引用）| slot（override 家族）| dispatch（可达分发，默认）
     * @param methodSignature 可空，形如 "(Landroid/os/Bundle;)V"，用于区分重载
     */
    JSObject findMethodXrefsCHA(DexManager.MultiDexSession session, String className, String methodName,
                                String methodSignature, String resolution, int limit)
            throws Exception {
        String mode = (resolution == null || resolution.isEmpty()) ? "dispatch" : resolution;
        int cap = limit > 0 ? limit : 50;
        String targetType = normalizeType(className);
        Map<String, ChaNode> g = buildChaGraph(session);

        String sig = (methodSignature == null) ? "" : methodSignature.trim();
        boolean sigGiven = !sig.isEmpty();

        // 解析目标方法键（name+proto）。exact 下缺签名可退化为按 name 匹配。
        String targetKey = null;
        if (sigGiven) {
            targetKey = methodName + sig;
        } else {
            // 缺签名时在类链上按方法名唯一解析 proto（重载则要求显式签名）
            targetKey = resolveKeyByName(g, targetType, methodName);
            if (targetKey == null && !"exact".equals(mode)) {
                throw new IllegalArgumentException(
                    "方法 " + className + "->" + methodName
                    + " 存在重载或未找到，slot/dispatch 模式需提供 methodSignature 区分");
            }
        }

        // 计算目标所有者集合
        Set<String> owners = new HashSet<>();
        Map<String, String> reason = new HashMap<>();
        if ("exact".equals(mode)) {
            owners.add(targetType);
            reason.put(targetType, "exact");
        } else if ("slot".equals(mode)) {
            owners.add(targetType);
            reason.put(targetType, "slot: self");
            for (String x : chaSupertypes(g, targetType)) {
                ChaNode n = g.get(x);
                if (n != null && n.methodKeys.contains(targetKey)) {
                    owners.add(x);
                    reason.put(x, "slot: ancestor declares");
                }
            }
            for (String x : chaSubtypes(g, targetType)) {
                ChaNode n = g.get(x);
                if (n != null && n.methodKeys.contains(targetKey)) {
                    owners.add(x);
                    reason.put(x, "slot: override");
                }
            }
        } else { // dispatch（默认）
            owners.add(targetType);
            reason.put(targetType, "dispatch: self");
            for (String x : chaSupertypes(g, targetType)) {
                owners.add(x);
                reason.put(x, "dispatch: super-call reaches impl");
            }
            ChaNode targetNode = g.get(targetType);
            boolean targetIsInterface = targetNode != null && targetNode.isInterface;
            for (String x : chaSubtypes(g, targetType)) {
                String decl = chaFirstClassDeclarer(g, x, targetKey);
                if (targetType.equals(decl) || (decl == null && targetIsInterface)) {
                    owners.add(x);
                    reason.put(x, "dispatch: " + shortType(x) + "<:" + shortType(targetType));
                }
            }
        }

        JSArray xrefArray = new JSArray();
        int count = 0;
        int exactCount = 0;
        int possibleCount = 0;
        boolean truncated = false;
        outer:
        for (Map.Entry<String, DexBackedDexFile> entry : session.dexFiles.entrySet()) {
            String dexName = entry.getKey();
            DexBackedDexFile dexFile = entry.getValue();
            if (dexFile == null) continue;
            for (ClassDef cd : dexFile.getClasses()) {
                for (Method m : cd.getMethods()) {
                    MethodImplementation impl = m.getImplementation();
                    if (impl == null) continue;
                    int addr = 0;
                    for (Instruction insn : impl.getInstructions()) {
                        int units = insn.getCodeUnits();
                        int at = addr;
                        addr += units;
                        int cat = invokeCategory(insn.getOpcode());
                        if (cat == 0) continue;
                        if (!(insn instanceof com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction)) {
                            continue;
                        }
                        com.android.tools.smali.dexlib2.iface.reference.Reference ref =
                            ((com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction) insn).getReference();
                        if (!(ref instanceof com.android.tools.smali.dexlib2.iface.reference.MethodReference)) {
                            continue;
                        }
                        com.android.tools.smali.dexlib2.iface.reference.MethodReference mref =
                            (com.android.tools.smali.dexlib2.iface.reference.MethodReference) ref;
                        String owner = mref.getDefiningClass();
                        String callKey = methodKey(mref.getName(), mref.getParameterTypes(),
                                mref.getReturnType());

                        boolean hit;
                        if ("exact".equals(mode)) {
                            hit = owner.equals(targetType)
                                    && (sigGiven ? callKey.equals(targetKey)
                                                 : mref.getName().equals(methodName));
                        } else {
                            if (!callKey.equals(targetKey)) continue;
                            if (cat == INV_DIRECT || cat == INV_STATIC) {
                                // 静态绑定：仅当所有者恰为目标类才计入
                                hit = owner.equals(targetType);
                            } else {
                                hit = owners.contains(owner);
                            }
                        }
                        if (!hit) continue;

                        if (count >= cap) {
                            truncated = true;
                            break outer;
                        }
                        String invType = invokeTypeName(cat);
                        JSObject xref = new JSObject();
                        xref.put("sourceClass", convertTypeToClassName(cd.getType()));
                        xref.put("sourceMethod", m.getName());
                        xref.put("sourceMethodSignature",
                                "(" + joinParams(m.getParameterTypes()) + ")" + m.getReturnType());
                        xref.put("invokeType", invType);
                        xref.put("targetOwner", convertTypeToClassName(owner));
                        xref.put("instruction", invType + " " + owner + "->" + mref.getName()
                                + "(" + joinParams(mref.getParameterTypes()) + ")" + mref.getReturnType());
                        xref.put("codeAddress", at);
                        xref.put("dexFile", dexName);
                        String rs = reason.get(owner);
                        xref.put("matchReason", rs != null ? rs : mode);
                        // 置信度分级（叠加层，不改变命中集合）：
                        //  - 指令 owner 恰为目标类 → exact（100% 引用目标本身）
                        //  - invoke-super/direct/static 静态绑定 → exact（无运行时多态）
                        //  - invoke-virtual/interface 且 owner 是目标的父/子类型 → possible
                        //    （真实分发目标由运行时接收者类型决定）
                        String certainty;
                        if (owner.equals(targetType)
                                || cat == INV_SUPER || cat == INV_DIRECT || cat == INV_STATIC) {
                            certainty = "exact";
                        } else {
                            certainty = "possible";
                        }
                        xref.put("certainty", certainty);
                        if ("exact".equals(certainty)) exactCount++;
                        else possibleCount++;
                        xrefArray.put(xref);
                        count++;
                    }
                }
            }
        }

        JSObject result = new JSObject();
        result.put("className", convertTypeToClassName(targetType));
        result.put("methodName", methodName);
        if (targetKey != null) result.put("resolvedKey", targetKey);
        result.put("resolution", mode);
        result.put("count", xrefArray.length());
        result.put("hasMore", truncated);
        JSObject summary = new JSObject();
        summary.put("total", xrefArray.length());
        summary.put("exact", exactCount);
        summary.put("possible", possibleCount);
        result.put("summary", summary);
        result.put("xrefs", xrefArray);
        result.put("engine", "java-dexlib2-cha");
        ChaNode tn = g.get(targetType);
        if (tn == null || !tn.defined) {
            result.put("note", "目标类未在会话 DEX 中定义，slot/dispatch 家族可能不完整");
        }
        return result;
    }

    /** 从 X 沿类（superclass）链向上，返回第一个声明了字段 key(name:type) 的类；无则返回 null。 */
    private String chaFirstFieldDeclarer(Map<String, ChaNode> g, String x, String key) {
        String cur = x;
        Set<String> seen = new HashSet<>();
        while (cur != null && seen.add(cur)) {
            ChaNode n = g.get(cur);
            if (n == null) return null;
            if (n.fieldKeys.contains(key)) return cur;
            cur = n.superclass;
        }
        return null;
    }

    /** 在 X 的类链上按字段名唯一解析 name:type 键；同名多字段/未找到返回 null。 */
    private String resolveFieldKeyByName(Map<String, ChaNode> g, String type, String fieldName) {
        String cur = type;
        Set<String> seen = new HashSet<>();
        while (cur != null && seen.add(cur)) {
            ChaNode n = g.get(cur);
            if (n == null) break;
            String found = null;
            int hits = 0;
            for (String key : n.fieldKeys) {
                int colon = key.lastIndexOf(':');
                if (colon > 0 && key.substring(0, colon).equals(fieldName)) {
                    found = key;
                    hits++;
                }
            }
            if (hits == 1) return found;
            if (hits > 1) return null; // 同名多字段，需显式 fieldType
            cur = n.superclass;
        }
        return null;
    }

    /** 字段访问类别：1=读(get) 2=写(put)；非字段访问返回 0。基于 opcode smali 名前缀。 */
    private static int fieldAccessCategory(com.android.tools.smali.dexlib2.Opcode op) {
        String nm = op.name;
        if (nm == null) return 0;
        // iget/sget（含 -wide/-object/-boolean 等，及 -volatile/-quick 变体）为读，iput/sput 为写
        if (nm.startsWith("iget") || nm.startsWith("sget")) return 1;
        if (nm.startsWith("iput") || nm.startsWith("sput")) return 2;
        return 0;
    }

    private static boolean isStaticFieldOp(com.android.tools.smali.dexlib2.Opcode op) {
        return op.name != null && op.name.startsWith("s");
    }

    /**
     * 字段交叉引用（dexlib2），运行在多 DEX 会话上。
     *
     * @param fieldType 可空，形如 "I"/"Ljava/lang/String;"，用于区分同名字段
     * @param access    read（iget/sget）| write（iput/sput）| all（默认）
     */
    JSObject findFieldXrefsCHA(DexManager.MultiDexSession session, String className, String fieldName,
                               String fieldType, String access, int limit)
            throws Exception {
        String acc = (access == null || access.isEmpty()) ? "all" : access;
        boolean wantRead = "all".equals(acc) || "read".equals(acc);
        boolean wantWrite = "all".equals(acc) || "write".equals(acc);
        if (!wantRead && !wantWrite) {
            throw new IllegalArgumentException("access 只能是 read | write | all");
        }
        int cap = limit > 0 ? limit : 50;
        String targetType = normalizeType(className);
        Map<String, ChaNode> g = buildChaGraph(session);

        String ft = (fieldType == null) ? "" : fieldType.trim();
        boolean typeGiven = !ft.isEmpty();
        String targetKey;
        if (typeGiven) {
            targetKey = fieldName + ":" + normalizeType(ft);
        } else {
            targetKey = resolveFieldKeyByName(g, targetType, fieldName);
            if (targetKey == null) {
                throw new IllegalArgumentException(
                    "字段 " + className + "->" + fieldName
                    + " 同名多字段或未找到，请提供 fieldType 区分");
            }
        }

        // owners：声明该字段的类 + 继承它（不遮蔽）的子类 + 声明它的祖先，覆盖以父/子类型书写的访问。
        String declClass = chaFirstFieldDeclarer(g, targetType, targetKey);
        Set<String> owners = new HashSet<>();
        Map<String, String> reason = new HashMap<>();
        owners.add(targetType);
        reason.put(targetType, "field: self");
        for (String x : chaSupertypes(g, targetType)) {
            ChaNode n = g.get(x);
            if (n != null && n.fieldKeys.contains(targetKey)) {
                owners.add(x);
                reason.put(x, "field: ancestor declares");
            }
        }
        for (String x : chaSubtypes(g, targetType)) {
            String decl = chaFirstFieldDeclarer(g, x, targetKey);
            if (decl != null && (decl.equals(declClass) || decl.equals(targetType))) {
                owners.add(x);
                reason.put(x, "field: " + shortType(x) + " inherits");
            }
        }

        JSArray xrefArray = new JSArray();
        int count = 0;
        boolean truncated = false;
        outer:
        for (Map.Entry<String, DexBackedDexFile> entry : session.dexFiles.entrySet()) {
            String dexName = entry.getKey();
            DexBackedDexFile dexFile = entry.getValue();
            if (dexFile == null) continue;
            for (ClassDef cd : dexFile.getClasses()) {
                for (Method m : cd.getMethods()) {
                    MethodImplementation impl = m.getImplementation();
                    if (impl == null) continue;
                    int addr = 0;
                    for (Instruction insn : impl.getInstructions()) {
                        int units = insn.getCodeUnits();
                        int at = addr;
                        addr += units;
                        int fac = fieldAccessCategory(insn.getOpcode());
                        if (fac == 0) continue;
                        if ((fac == 1 && !wantRead) || (fac == 2 && !wantWrite)) continue;
                        if (!(insn instanceof com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction)) {
                            continue;
                        }
                        com.android.tools.smali.dexlib2.iface.reference.Reference ref =
                            ((com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction) insn).getReference();
                        if (!(ref instanceof com.android.tools.smali.dexlib2.iface.reference.FieldReference)) {
                            continue;
                        }
                        com.android.tools.smali.dexlib2.iface.reference.FieldReference fref =
                            (com.android.tools.smali.dexlib2.iface.reference.FieldReference) ref;
                        if (!fref.getName().equals(fieldName)) continue;
                        String callKey = fref.getName() + ":" + fref.getType();
                        if (!callKey.equals(targetKey)) continue;
                        String owner = fref.getDefiningClass();
                        if (!owners.contains(owner)) continue;

                        if (count >= cap) {
                            truncated = true;
                            break outer;
                        }
                        String accType = insn.getOpcode().name;
                        JSObject xref = new JSObject();
                        xref.put("sourceClass", convertTypeToClassName(cd.getType()));
                        xref.put("sourceMethod", m.getName());
                        xref.put("sourceMethodSignature",
                                "(" + joinParams(m.getParameterTypes()) + ")" + m.getReturnType());
                        xref.put("accessType", accType);
                        xref.put("access", fac == 1 ? "read" : "write");
                        xref.put("isStatic", isStaticFieldOp(insn.getOpcode()));
                        xref.put("fieldOwner", convertTypeToClassName(owner));
                        xref.put("fieldType", fref.getType());
                        xref.put("instruction", accType + " " + owner + "->" + fref.getName()
                                + ":" + fref.getType());
                        xref.put("codeAddress", at);
                        xref.put("dexFile", dexName);
                        String rs = reason.get(owner);
                        xref.put("matchReason", rs != null ? rs : "field");
                        xrefArray.put(xref);
                        count++;
                    }
                }
            }
        }

        JSObject result = new JSObject();
        result.put("className", convertTypeToClassName(targetType));
        result.put("fieldName", fieldName);
        result.put("resolvedKey", targetKey);
        result.put("access", acc);
        result.put("count", xrefArray.length());
        result.put("hasMore", truncated);
        result.put("xrefs", xrefArray);
        result.put("engine", "java-dexlib2-cha");
        ChaNode tn = g.get(targetType);
        if (tn == null || !tn.defined) {
            result.put("note", "目标类未在会话 DEX 中定义，字段家族可能不完整");
        }
        return result;
    }

    /** 在 X 的类链上按方法名唯一解析 proto 键；重载/未找到返回 null。 */
    private String resolveKeyByName(Map<String, ChaNode> g, String type, String methodName) {
        String cur = type;
        Set<String> seen = new HashSet<>();
        while (cur != null && seen.add(cur)) {
            ChaNode n = g.get(cur);
            if (n == null) break;
            String found = null;
            int hits = 0;
            for (String key : n.methodKeys) {
                int paren = key.indexOf('(');
                if (paren > 0 && key.substring(0, paren).equals(methodName)) {
                    found = key;
                    hits++;
                }
            }
            if (hits == 1) return found;
            if (hits > 1) return null; // 重载，需签名
            cur = n.superclass;
        }
        return null;
    }

    private static String joinParams(List<? extends CharSequence> params) {
        if (params == null) return "";
        StringBuilder sb = new StringBuilder();
        for (CharSequence p : params) sb.append(p);
        return sb.toString();
    }

    private static String shortType(String type) {
        if (type == null) return "?";
        int slash = type.lastIndexOf('/');
        String s = slash >= 0 ? type.substring(slash + 1) : type;
        if (s.endsWith(";")) s = s.substring(0, s.length() - 1);
        return s;
    }

    /** 剥离数组前缀 '['，返回基础类型描述符（如 "[[Lp/A;" -> "Lp/A;"）。 */
    private static String arrayBase(String t) {
        if (t == null) return null;
        int i = 0;
        while (i < t.length() && t.charAt(i) == '[') i++;
        return t.substring(i);
    }

    /** 数组维度（'[' 个数）；非数组为 0。 */
    private static int arrayDepth(String t) {
        if (t == null) return 0;
        int i = 0;
        while (i < t.length() && t.charAt(i) == '[') i++;
        return i;
    }

    /**
     * 类级交叉引用（dexlib2），运行在多 DEX 会话上。
     * 覆盖对目标类型的各类引用形式（含数组包装）：
     *   指令级：new-instance、check-cast、instance-of、const-class、new-array/
     *          filled-new-array、字段访问的字段类型、方法调用的参数/返回类型；
     *   声明级：extends（父类）、implements（接口）、字段声明类型、
     *          方法声明的参数/返回类型。
     * 每条引用含 sourceClass、sourceMethod?/sourceMethodSignature?、refKind、
     * detail（指令或位置描述）、codeAddress?（指令级）、arrayDepth、dexFile。
     */
    JSObject findClassXrefsCHA(DexManager.MultiDexSession session, String className, int limit)
            throws Exception {
        int cap = limit > 0 ? limit : 50;
        String targetType = normalizeType(className);

        JSArray xrefArray = new JSArray();
        boolean truncated = false;

        outer:
        for (Map.Entry<String, DexBackedDexFile> entry : session.dexFiles.entrySet()) {
            String dexName = entry.getKey();
            DexBackedDexFile dexFile = entry.getValue();
            if (dexFile == null) continue;
            for (ClassDef cd : dexFile.getClasses()) {
                String srcClass = cd.getType();
                // ---- 声明级：extends / implements ----
                if (targetType.equals(cd.getSuperclass())) {
                    if (xrefArray.length() >= cap) { truncated = true; break outer; }
                    xrefArray.put(classXref(srcClass, null, null, "extends",
                            shortType(srcClass) + " extends " + shortType(targetType), -1, 0, dexName));
                }
                for (String iface : cd.getInterfaces()) {
                    if (targetType.equals(iface)) {
                        if (xrefArray.length() >= cap) { truncated = true; break outer; }
                        xrefArray.put(classXref(srcClass, null, null, "implements",
                                shortType(srcClass) + " implements " + shortType(targetType), -1, 0, dexName));
                    }
                }
                // ---- 声明级：字段声明类型 ----
                for (Field f : cd.getFields()) {
                    if (targetType.equals(arrayBase(f.getType()))) {
                        if (xrefArray.length() >= cap) { truncated = true; break outer; }
                        xrefArray.put(classXref(srcClass, null, null, "field-decl-type",
                                f.getName() + ":" + f.getType(), -1, arrayDepth(f.getType()), dexName));
                    }
                }
                // ---- 声明级：方法参数/返回类型 + 指令级 ----
                for (Method m : cd.getMethods()) {
                    String msig = "(" + joinParams(m.getParameterTypes()) + ")" + m.getReturnType();
                    if (targetType.equals(arrayBase(m.getReturnType()))) {
                        if (xrefArray.length() >= cap) { truncated = true; break outer; }
                        xrefArray.put(classXref(srcClass, m.getName(), msig, "method-decl-return-type",
                                m.getName() + msig, -1, arrayDepth(m.getReturnType()), dexName));
                    }
                    for (CharSequence p : m.getParameterTypes()) {
                        if (targetType.equals(arrayBase(p.toString()))) {
                            if (xrefArray.length() >= cap) { truncated = true; break outer; }
                            xrefArray.put(classXref(srcClass, m.getName(), msig, "method-decl-param-type",
                                    m.getName() + msig, -1, arrayDepth(p.toString()), dexName));
                        }
                    }

                    MethodImplementation impl = m.getImplementation();
                    if (impl == null) continue;
                    int addr = 0;
                    for (Instruction insn : impl.getInstructions()) {
                        int at = addr;
                        addr += insn.getCodeUnits();
                        if (!(insn instanceof com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction)) {
                            continue;
                        }
                        com.android.tools.smali.dexlib2.iface.reference.Reference ref =
                            ((com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction) insn).getReference();
                        com.android.tools.smali.dexlib2.Opcode op = insn.getOpcode();

                        if (ref instanceof com.android.tools.smali.dexlib2.iface.reference.TypeReference) {
                            String t = ((com.android.tools.smali.dexlib2.iface.reference.TypeReference) ref).getType();
                            if (!targetType.equals(arrayBase(t))) continue;
                            String kind = typeRefKind(op);
                            if (kind == null) continue;
                            if (xrefArray.length() >= cap) { truncated = true; break outer; }
                            xrefArray.put(classXref(srcClass, m.getName(), msig, kind,
                                    op.name + " " + t, at, arrayDepth(t), dexName));
                        } else if (ref instanceof com.android.tools.smali.dexlib2.iface.reference.FieldReference) {
                            com.android.tools.smali.dexlib2.iface.reference.FieldReference fr =
                                (com.android.tools.smali.dexlib2.iface.reference.FieldReference) ref;
                            if (targetType.equals(arrayBase(fr.getType()))) {
                                if (xrefArray.length() >= cap) { truncated = true; break outer; }
                                xrefArray.put(classXref(srcClass, m.getName(), msig, "field-access-type",
                                        op.name + " " + fr.getDefiningClass() + "->" + fr.getName()
                                        + ":" + fr.getType(), at, arrayDepth(fr.getType()), dexName));
                            }
                        } else if (ref instanceof com.android.tools.smali.dexlib2.iface.reference.MethodReference) {
                            com.android.tools.smali.dexlib2.iface.reference.MethodReference mr =
                                (com.android.tools.smali.dexlib2.iface.reference.MethodReference) ref;
                            String callSig = mr.getDefiningClass() + "->" + mr.getName()
                                    + "(" + joinParams(mr.getParameterTypes()) + ")" + mr.getReturnType();
                            if (targetType.equals(arrayBase(mr.getReturnType()))) {
                                if (xrefArray.length() >= cap) { truncated = true; break outer; }
                                xrefArray.put(classXref(srcClass, m.getName(), msig, "method-call-return-type",
                                        op.name + " " + callSig, at, arrayDepth(mr.getReturnType()), dexName));
                            }
                            for (CharSequence p : mr.getParameterTypes()) {
                                if (targetType.equals(arrayBase(p.toString()))) {
                                    if (xrefArray.length() >= cap) { truncated = true; break outer; }
                                    xrefArray.put(classXref(srcClass, m.getName(), msig, "method-call-param-type",
                                            op.name + " " + callSig, at, arrayDepth(p.toString()), dexName));
                                }
                            }
                        }
                    }
                }
            }
        }

        JSObject result = new JSObject();
        result.put("className", convertTypeToClassName(targetType));
        result.put("count", xrefArray.length());
        result.put("hasMore", truncated);
        result.put("xrefs", xrefArray);
        result.put("engine", "java-dexlib2");
        buildChaGraph(session);
        ChaNode tn = session.chaGraph.get(targetType);
        if (tn == null || !tn.defined) {
            result.put("note", "目标类未在会话 DEX 中定义（可能是 framework 类）；仍会列出对它的引用");
        }
        return result;
    }

    /** 组装一条类级 xref 记录。codeAddress<0 表示声明级（无指令地址）。 */
    private JSObject classXref(String srcClass, String srcMethod, String srcMethodSig,
                               String refKind, String detail, int codeAddress,
                               int arrayDepth, String dexName) {
        JSObject o = new JSObject();
        o.put("sourceClass", convertTypeToClassName(srcClass));
        if (srcMethod != null) o.put("sourceMethod", srcMethod);
        if (srcMethodSig != null) o.put("sourceMethodSignature", srcMethodSig);
        o.put("refKind", refKind);
        o.put("detail", detail);
        if (codeAddress >= 0) o.put("codeAddress", codeAddress);
        o.put("arrayDepth", arrayDepth);
        o.put("dexFile", dexName);
        return o;
    }

    /** 携带 TypeReference 的指令 → refKind；非目标指令返回 null。 */
    private static String typeRefKind(com.android.tools.smali.dexlib2.Opcode op) {
        switch (op) {
            case NEW_INSTANCE: return "new-instance";
            case CHECK_CAST: return "check-cast";
            case INSTANCE_OF: return "instance-of";
            case CONST_CLASS: return "const-class";
            case NEW_ARRAY: return "new-array";
            case FILLED_NEW_ARRAY:
            case FILLED_NEW_ARRAY_RANGE: return "filled-new-array";
            default: return null;
        }
    }

    // ==================== 类名格式转换（与 DexManager 一致）====================

    /**
     * 将 DEX 类型格式转换为 Java 类名格式
     * 例如: Lcom/example/Class; -> com.example.Class
     */
    private static String convertTypeToClassName(String type) {
        if (type == null) return "";
        String className = type;
        if (className.startsWith("L") && className.endsWith(";")) {
            className = className.substring(1, className.length() - 1);
        }
        return className.replace("/", ".");
    }

    /**
     * 将 Java 类名格式转换为 DEX 类型格式
     * 例如: com.example.Class -> Lcom/example/Class;
     */
    private static String convertClassNameToType(String className) {
        if (className == null) return "";
        // 幂等：已是描述符（La/b/C;）直接返回，避免二次包装成 LLa/b/C;;。
        if (className.startsWith("L") && className.endsWith(";")) {
            return className;
        }
        return "L" + className.replace(".", "/") + ";";
    }
}
