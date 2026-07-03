package com.aetherlink.dexeditor;

import android.util.Log;

import com.android.tools.smali.dexlib2.DexFileFactory;
import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.ClassDef;
import com.android.tools.smali.dexlib2.writer.io.FileDataStore;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;

import org.json.JSONArray;

import java.io.File;

/**
 * DexToolOps - DEX 层面的工具操作。
 *
 * 从 {@link DexManager} 的「工具操作」段抽出：
 *  - {@link #fixDex}：重写 DEX 修复格式；
 *  - {@link #mergeDex}：合并多个 DEX；
 *  - {@link #modifyString}：全局替换字符串（逐类反汇编改写再编译）。
 *
 * 会话查找、Smali 编译/反汇编等能力仍由 DexManager 提供，通过 dex 引用回调。
 */
class DexToolOps {

    private static final String TAG = "DexToolOps";

    private final DexManager dex;

    DexToolOps(DexManager dex) {
        this.dex = dex;
    }

    /**
     * 修复 DEX 文件
     */
    void fixDex(String inputPath, String outputPath) throws Exception {
        // 读取并重新写入 DEX 来修复格式问题
        File inputFile = new File(inputPath);
        DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
            inputFile,
            Opcodes.getDefault()
        );

        DexPool dexPool = new DexPool(dexFile.getOpcodes());
        for (ClassDef classDef : dexFile.getClasses()) {
            dexPool.internClass(classDef);
        }

        File outputFile = new File(outputPath);
        outputFile.getParentFile().mkdirs();
        dexPool.writeTo(new FileDataStore(outputFile));
        
        Log.d(TAG, "Fixed DEX: " + inputPath + " -> " + outputPath);
    }

    /**
     * 合并多个 DEX 文件
     */
    void mergeDex(JSONArray inputPaths, String outputPath) throws Exception {
        DexPool dexPool = new DexPool(Opcodes.getDefault());

        for (int i = 0; i < inputPaths.length(); i++) {
            String path = inputPaths.getString(i);
            DexBackedDexFile dexFile = (DexBackedDexFile) DexFileFactory.loadDexFile(
                new File(path),
                Opcodes.getDefault()
            );

            for (ClassDef classDef : dexFile.getClasses()) {
                dexPool.internClass(classDef);
            }
        }

        File outputFile = new File(outputPath);
        outputFile.getParentFile().mkdirs();
        dexPool.writeTo(new FileDataStore(outputFile));
        
        Log.d(TAG, "Merged " + inputPaths.length() + " DEX files to: " + outputPath);
    }

    /**
     * 修改字符串
     */
    void modifyString(String sessionId, String oldString, String newString) throws Exception {
        DexManager.DexSession session = dex.getSession(sessionId);

        // 需要遍历所有类，替换字符串引用
        for (ClassDef classDef : session.originalDexFile.getClasses()) {
            if (session.removedClasses.contains(classDef.getType())) continue;

            try {
                String smali = dex.classToSmali(sessionId, classDef.getType()).getString("smali");
                if (smali.contains(oldString)) {
                    String modifiedSmali = smali.replace(oldString, newString);
                    ClassDef modifiedClass = dex.compileSmaliToClass(modifiedSmali, session.originalDexFile.getOpcodes());
                    
                    session.removedClasses.add(classDef.getType());
                    session.modifiedClasses.add(modifiedClass);
                }
            } catch (Exception e) {
                Log.w(TAG, "Failed to modify string in class: " + classDef.getType(), e);
            }
        }

        session.modified = true;
    }
}
