package com.aetherlink.dexeditor;

import android.content.Context;

import com.aetherlink.dexeditor.compat.JSObject;

/**
 * Transport-agnostic action dispatcher for all DEX/APK operations.
 *
 * <p>Architecture note: in the original Capacitor plugin this giant switch lived
 * inside the {@code Plugin} subclass, coupling the operation catalogue to the
 * Capacitor bridge. Here it is extracted into a plain class that depends only on
 * {@link DexManager}/{@link ApkManager} and the compat {@link JSObject}, so the
 * Flutter bridge ({@code DexEditorFlutterPlugin}) — or any future transport — is
 * a thin marshalling layer over {@link #dispatch(String, JSObject)}.
 */
public class DexActionDispatcher {

    private final DexManager dexManager = new DexManager();
    private final ApkManager apkManager = new ApkManager();

    public DexActionDispatcher(Context context) {
        apkManager.setContext(context);
    }

    public DexManager dexManager() {
        return dexManager;
    }

    /** Registers a compile-progress callback (streamed to Dart via EventChannel). */
    public void setProgressCallback(DexManager.CompileProgress callback) {
        dexManager.setProgressCallback(callback);
    }

    /**
     * Runs {@code action} with {@code params} and returns a result object of the
     * shape {@code { success: bool, data?: ..., error?: string }}.
     */
    public JSObject dispatch(String action, JSObject params) throws Exception {
        JSObject result = new JSObject();
        result.put("success", true);

        switch (action) {
            // ============ DEX 文件操作 ============
            case "loadDex":
                result.put("data", dexManager.loadDex(
                    params.getString("path"),
                    params.optString("sessionId", null)
                ));
                break;

            case "saveDex":
                dexManager.saveDex(
                    params.getString("sessionId"),
                    params.getString("outputPath")
                );
                break;

            case "closeDex":
                dexManager.closeDex(params.getString("sessionId"));
                break;

            case "getDexInfo":
                result.put("data", dexManager.getDexInfo(params.getString("sessionId")));
                break;

            // ============ 类操作 ============
            case "getClasses":
                result.put("data", dexManager.getClasses(params.getString("sessionId")));
                break;

            case "getClassInfo":
                result.put("data", dexManager.getClassInfo(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "addClass":
                dexManager.addClass(
                    params.getString("sessionId"),
                    params.getString("smaliCode")
                );
                break;

            case "removeClass":
                dexManager.removeClass(
                    params.getString("sessionId"),
                    params.getString("className")
                );
                break;

            case "renameClass":
                dexManager.renameClass(
                    params.getString("sessionId"),
                    params.getString("oldName"),
                    params.getString("newName")
                );
                break;

            // ============ 方法操作 ============
            case "getMethods":
                result.put("data", dexManager.getMethods(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "getMethodInfo":
                result.put("data", dexManager.getMethodInfo(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.getString("methodSignature")
                ));
                break;

            case "getMethodSmali":
                result.put("data", dexManager.getMethodSmali(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.getString("methodSignature")
                ));
                break;

            case "setMethodSmali":
                dexManager.setMethodSmali(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.getString("methodSignature"),
                    params.getString("smaliCode")
                );
                break;

            case "addMethod":
                dexManager.addMethod(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("smaliCode")
                );
                break;

            case "removeMethod":
                dexManager.removeMethod(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.getString("methodSignature")
                );
                break;

            // ============ 字段操作 ============
            case "getFields":
                result.put("data", dexManager.getFields(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "getFieldInfo":
                result.put("data", dexManager.getFieldInfo(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("fieldName")
                ));
                break;

            case "addField":
                dexManager.addField(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("fieldDef")
                );
                break;

            case "removeField":
                dexManager.removeField(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("fieldName")
                );
                break;

            // ============ Smali 操作 ============
            case "classToSmali":
                result.put("data", dexManager.classToSmali(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "smaliToClass":
                dexManager.smaliToClass(
                    params.getString("sessionId"),
                    params.getString("smaliCode")
                );
                break;

            case "disassemble":
                dexManager.disassemble(
                    params.getString("sessionId"),
                    params.getString("outputDir")
                );
                break;

            case "assemble":
                result.put("data", dexManager.assemble(
                    params.getString("smaliDir"),
                    params.getString("outputPath")
                ));
                break;

            // ============ 搜索操作 ============
            case "searchString":
                result.put("data", dexManager.searchString(
                    params.getString("sessionId"),
                    params.getString("query"),
                    params.optBoolean("regex", false),
                    params.optBoolean("caseSensitive", false)
                ));
                break;

            case "searchCode":
                result.put("data", dexManager.searchCode(
                    params.getString("sessionId"),
                    params.getString("query"),
                    params.optBoolean("regex", false)
                ));
                break;

            case "searchMethod":
                result.put("data", dexManager.searchMethod(
                    params.getString("sessionId"),
                    params.getString("query")
                ));
                break;

            case "searchField":
                result.put("data", dexManager.searchField(
                    params.getString("sessionId"),
                    params.getString("query")
                ));
                break;

            // ============ 交叉引用分析（C++ 实现）============
            case "findMethodXrefs":
                result.put("data", dexManager.findMethodXrefs(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName")
                ));
                break;

            case "findFieldXrefs":
                result.put("data", dexManager.findFieldXrefs(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("fieldName")
                ));
                break;

            // ============ Smali 转 Java（C++ 实现）============
            case "smaliToJava":
                result.put("data", dexManager.smaliToJava(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            // ============ 工具操作 ============
            case "fixDex":
                dexManager.fixDex(
                    params.getString("inputPath"),
                    params.getString("outputPath")
                );
                break;

            case "mergeDex":
                dexManager.mergeDex(
                    params.getJSONArray("inputPaths"),
                    params.getString("outputPath")
                );
                break;

            case "splitDex":
                result.put("data", dexManager.splitDex(
                    params.getString("sessionId"),
                    params.getInt("maxClasses")
                ));
                break;

            case "getStrings":
                result.put("data", dexManager.getStrings(params.getString("sessionId")));
                break;

            case "listStrings":
                // C++ 实现的字符串列表
                if (CppApkHelper.isAvailable()) {
                    byte[] dexBytes = dexManager.getSessionDexBytes(params.getString("sessionId"));
                    if (dexBytes != null) {
                        result.put("data", CppDexHelper.listStrings(
                            dexBytes,
                            params.optString("filter", ""),
                            params.optInt("limit", 100)
                        ));
                    }
                }
                break;

            // ============ C++ APK/资源操作 ============
            case "parseManifestCpp":
                result.put("data", CppApkHelper.parseManifestFromApk(
                    params.getString("apkPath")
                ));
                break;

            case "searchManifestCpp":
                byte[] axmlBytes = CppApkHelper.readFileFromApk(
                    params.getString("apkPath"),
                    "AndroidManifest.xml"
                );
                result.put("data", CppApkHelper.searchManifest(
                    axmlBytes,
                    params.optString("attrName", ""),
                    params.optString("value", ""),
                    params.optInt("limit", 50)
                ));
                break;

            case "parseArscCpp":
                result.put("data", CppApkHelper.parseArscFromApk(
                    params.getString("apkPath")
                ));
                break;

            case "searchArscStrings":
                result.put("data", CppApkHelper.searchArscStringsFromApk(
                    params.getString("apkPath"),
                    params.getString("pattern"),
                    params.optInt("limit", 50)
                ));
                break;

            case "searchArscResources":
                result.put("data", CppApkHelper.searchArscResourcesFromApk(
                    params.getString("apkPath"),
                    params.getString("pattern"),
                    params.optString("type", ""),
                    params.optInt("limit", 50)
                ));
                break;

            case "modifyString":
                dexManager.modifyString(
                    params.getString("sessionId"),
                    params.getString("oldString"),
                    params.getString("newString")
                );
                break;

            // ============ APK 操作 ============
            case "openApk":
                result.put("data", apkManager.openApk(
                    params.getString("apkPath"),
                    params.optString("extractDir", null)
                ));
                break;

            case "closeApk":
                apkManager.closeApk(
                    params.getString("sessionId"),
                    params.optBoolean("deleteExtracted", true)
                );
                break;

            case "getApkInfo":
                result.put("data", apkManager.getApkInfo(params.getString("apkPath")));
                break;

            case "listApkContents":
                result.put("data", apkManager.listApkContents(params.getString("apkPath")));
                break;

            case "extractFile":
                result.put("data", apkManager.extractFile(
                    params.getString("apkPath"),
                    params.getString("entryName"),
                    params.getString("outputPath")
                ));
                break;

            case "replaceFile":
                apkManager.replaceFile(
                    params.getString("sessionId"),
                    params.getString("entryName"),
                    params.getString("newFilePath")
                );
                break;

            case "addFile":
                apkManager.addFile(
                    params.getString("sessionId"),
                    params.getString("entryName"),
                    params.getString("filePath")
                );
                break;

            case "deleteFile":
                apkManager.deleteFile(
                    params.getString("sessionId"),
                    params.getString("entryName")
                );
                break;

            case "repackApk":
                result.put("data", apkManager.repackApk(
                    params.getString("sessionId"),
                    params.getString("outputPath")
                ));
                break;

            case "signApk":
                result.put("data", apkManager.signApk(
                    params.getString("apkPath"),
                    params.getString("outputPath"),
                    params.getString("keystorePath"),
                    params.getString("keystorePassword"),
                    params.getString("keyAlias"),
                    params.getString("keyPassword")
                ));
                break;

            case "signApkWithTestKey":
                result.put("data", apkManager.signApkWithTestKey(
                    params.getString("apkPath"),
                    params.getString("outputPath")
                ));
                break;

            case "getApkSignature":
                result.put("data", apkManager.getApkSignature(params.getString("apkPath")));
                break;

            case "getSessionDexFiles":
                result.put("data", apkManager.getSessionDexFiles(params.getString("sessionId")));
                break;

            case "installApk":
                apkManager.installApk(params.getString("apkPath"));
                break;

            case "listApkDirectory":
                result.put("data", apkManager.listApkDirectory(
                    params.getString("apkPath"),
                    params.optString("directory", "")
                ));
                break;

            // ==================== DEX 编辑器操作 ====================
            case "listDexClasses":
                result.put("data", dexManager.listDexClassesFromApk(
                    params.getString("apkPath"),
                    params.getString("dexPath")
                ));
                break;

            case "getDexStrings":
                result.put("data", dexManager.getDexStringsFromApk(
                    params.getString("apkPath"),
                    params.getString("dexPath")
                ));
                break;

            case "searchInDex":
                result.put("data", dexManager.searchInDexFromApk(
                    params.getString("apkPath"),
                    params.getString("dexPath"),
                    params.getString("query")
                ));
                break;

            case "getClassSmali":
                result.put("data", dexManager.getClassSmaliFromApk(
                    params.getString("apkPath"),
                    params.getString("dexPath"),
                    params.getString("className")
                ));
                break;

            case "saveClassSmali":
                result.put("data", dexManager.saveClassSmaliToApk(
                    params.getString("apkPath"),
                    params.getString("dexPath"),
                    params.getString("className"),
                    params.getString("smaliContent")
                ));
                break;

            // ==================== MCP 工作流操作 ====================
            case "listDexFiles":
                result.put("data", dexManager.listDexFilesInApk(
                    params.getString("apkPath")
                ));
                break;

            case "openDex":
                result.put("data", dexManager.openMultipleDex(
                    params.getString("apkPath"),
                    params.getJSONArray("dexFiles")
                ));
                break;

            case "listClasses":
                result.put("data", dexManager.getClassesFromMultiSession(
                    params.getString("sessionId"),
                    params.optString("packageFilter", ""),
                    params.optInt("offset", 0),
                    params.optInt("limit", 100)
                ));
                break;

            case "searchInDexSession":
                result.put("data", dexManager.searchInMultiSession(
                    params.getString("sessionId"),
                    params.getString("query"),
                    params.getString("searchType"),
                    params.optBoolean("caseSensitive", false),
                    params.optInt("maxResults", 50)
                ));
                break;

            case "getClassSmaliFromSession":
                result.put("data", dexManager.getClassSmaliFromSession(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "modifyClass":
                dexManager.modifyClassInSession(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("smaliContent")
                );
                break;

            case "saveDexToApk":
                result.put("data", dexManager.saveMultiDexSessionToApk(
                    params.getString("sessionId")
                ));
                break;

            case "saveAllDexToApk":
                result.put("data", dexManager.saveAllSessionsToApk());
                break;

            case "closeMultiDexSession":
                dexManager.closeMultiDexSession(params.getString("sessionId"));
                break;

            case "addClassToSession":
                dexManager.addClassToSession(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("smaliContent")
                );
                break;

            case "deleteClassFromSession":
                dexManager.deleteClassFromSession(
                    params.getString("sessionId"),
                    params.getString("className")
                );
                break;

            case "getMethodFromSession":
                result.put("data", dexManager.getMethodFromSession(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.optString("methodSignature", "")
                ));
                break;

            case "modifyMethodInSession":
                dexManager.modifyMethodInSession(
                    params.getString("sessionId"),
                    params.getString("className"),
                    params.getString("methodName"),
                    params.optString("methodSignature", ""),
                    params.getString("newMethodCode")
                );
                break;

            case "listMethodsFromSession":
                result.put("data", dexManager.listMethodsFromSession(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "listFieldsFromSession":
                result.put("data", dexManager.listFieldsFromSession(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "outlineClassFromSession":
                result.put("data", dexManager.outlineClassFromSession(
                    params.getString("sessionId"),
                    params.getString("className")
                ));
                break;

            case "renameClassInSession":
                dexManager.renameClassInSession(
                    params.getString("sessionId"),
                    params.getString("oldClassName"),
                    params.getString("newClassName")
                );
                break;

            case "modifyResource":
                result.put("data", dexManager.modifyResourceInApk(
                    params.getString("apkPath"),
                    params.getString("resourcePath"),
                    params.getString("newContent")
                ));
                break;

            case "getResourceValue":
                result.put("data", dexManager.getResourceValueInApk(
                    params.getString("apkPath"),
                    parseResourceId(params.getString("id"))
                ));
                break;

            case "setResourceValue":
                result.put("data", dexManager.setResourceValueInApk(
                    params.getString("apkPath"),
                    parseResourceId(params.getString("id")),
                    params.optString("config", ""),
                    params.optString("valueType", "auto"),
                    params.getString("value")
                ));
                break;

            case "deleteFileFromApk":
                result.put("data", dexManager.deleteFileFromApk(
                    params.getString("apkPath"),
                    params.getString("filePath")
                ));
                break;

            case "addFileToApk":
                result.put("data", dexManager.addFileToApk(
                    params.getString("apkPath"),
                    params.getString("filePath"),
                    params.getString("content"),
                    params.optBoolean("isBase64", false)
                ));
                break;

            case "listSessions":
                result.put("data", dexManager.listAllSessions());
                break;

            // ==================== XML/资源操作 ====================
            case "getManifest":
                result.put("data", dexManager.getManifestFromApk(
                    params.getString("apkPath")
                ));
                break;

            case "modifyManifest":
                result.put("data", dexManager.modifyManifestInApk(
                    params.getString("apkPath"),
                    params.getString("newManifest")
                ));
                break;

            case "listResources":
                result.put("data", dexManager.listResourcesInApk(
                    params.getString("apkPath"),
                    params.optString("filter", "")
                ));
                break;

            case "getResource":
                result.put("data", dexManager.getResourceFromApk(
                    params.getString("apkPath"),
                    params.getString("resourcePath")
                ));
                break;

            case "replaceInManifest":
                result.put("data", dexManager.replaceInManifest(
                    params.getString("apkPath"),
                    params.getJSONArray("replacements")
                ));
                break;

            case "patchManifest":
                result.put("data", dexManager.patchManifest(
                    params.getString("apkPath"),
                    params.getJSONArray("patches")
                ));
                break;

            case "listApkFiles":
                result.put("data", dexManager.listApkFiles(
                    params.getString("apkPath"),
                    params.optString("filter", ""),
                    params.optInt("limit", 100),
                    params.optInt("offset", 0)
                ));
                break;

            case "searchTextInApk":
                result.put("data", dexManager.searchTextInApk(
                    params.getString("apkPath"),
                    params.getString("pattern"),
                    params.optJSONArray("fileExtensions"),
                    params.optBoolean("caseSensitive", false),
                    params.optBoolean("isRegex", false),
                    params.optInt("maxResults", 50),
                    params.optInt("contextLines", 2)
                ));
                break;

            case "readApkFile":
                result.put("data", dexManager.readApkFile(
                    params.getString("apkPath"),
                    params.getString("filePath"),
                    params.optBoolean("asBase64", false),
                    params.optInt("maxBytes", 0),
                    params.optInt("offset", 0)
                ));
                break;

            default:
                result.put("success", false);
                result.put("error", "Unknown action: " + action);
        }

        return result;
    }

    /** 把资源 ID 文本（如 "0x7f010000" 或十进制）解析为 long。 */
    private static long parseResourceId(String id) {
        String s = id == null ? "" : id.trim();
        if (s.startsWith("0x") || s.startsWith("0X")) {
            return Long.parseLong(s.substring(2), 16);
        }
        if (s.startsWith("@")) {
            s = s.substring(1);
            if (s.startsWith("0x") || s.startsWith("0X")) {
                return Long.parseLong(s.substring(2), 16);
            }
        }
        return Long.parseLong(s);
    }
}
