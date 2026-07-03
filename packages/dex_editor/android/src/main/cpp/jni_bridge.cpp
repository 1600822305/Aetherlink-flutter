#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>

#include "dex/dex_parser.h"
#include "dex/dex_builder.h"
#include "dex/smali_disasm.h"
#include "dex/smali_to_java.h"
#include "xml/axml_parser.h"
#include "arsc/arsc_parser.h"
#include "apk/apk_handler.h"

#include <nlohmann/json.hpp>

#define LOG_TAG "CppDex"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using json = nlohmann::json;

// Helper: Convert jbyteArray to std::vector<uint8_t>
static std::vector<uint8_t> jbyteArray_to_vector(JNIEnv* env, jbyteArray array) {
    if (!array) return {};
    jsize len = env->GetArrayLength(array);
    std::vector<uint8_t> result(len);
    env->GetByteArrayRegion(array, 0, len, reinterpret_cast<jbyte*>(result.data()));
    return result;
}

// Helper: Convert std::vector<uint8_t> to jbyteArray
static jbyteArray vector_to_jbyteArray(JNIEnv* env, const std::vector<uint8_t>& data) {
    jbyteArray result = env->NewByteArray(static_cast<jsize>(data.size()));
    if (result) {
        env->SetByteArrayRegion(result, 0, static_cast<jsize>(data.size()),
                                reinterpret_cast<const jbyte*>(data.data()));
    }
    return result;
}

// Helper: Convert jstring to std::string
static std::string jstring_to_string(JNIEnv* env, jstring str) {
    if (!str) return "";
    const char* chars = env->GetStringUTFChars(str, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(str, chars);
    return result;
}

// Helper: Convert std::string to jstring
static jstring string_to_jstring(JNIEnv* env, const std::string& str) {
    return env->NewStringUTF(str.c_str());
}

extern "C" {

// ==================== DEX 解析操作 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_getDexInfo(JNIEnv* env, jclass, jbyteArray dexBytes) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    const auto& header = parser.header();
    json result = {
        {"version", std::string(reinterpret_cast<const char*>(header.magic + 4), 3)},
        {"file_size", header.file_size},
        {"strings_count", header.string_ids_size},
        {"types_count", header.type_ids_size},
        {"protos_count", header.proto_ids_size},
        {"fields_count", header.field_ids_size},
        {"methods_count", header.method_ids_size},
        {"classes_count", header.class_defs_size}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_listClasses(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring packageFilter, jint offset, jint limit) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string filter = jstring_to_string(env, packageFilter);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    json class_list = json::array();
    const auto& classes = parser.classes();
    int count = 0;
    int matched = 0;
    
    for (const auto& cls : classes) {
        std::string class_name = parser.get_class_name(cls.class_idx);
        
        if (!filter.empty() && class_name.find(filter) == std::string::npos) {
            continue;
        }
        
        matched++;
        if (matched > offset && count < limit) {
            class_list.push_back(class_name);
            count++;
        }
    }
    
    json result = {
        {"classes", class_list},
        {"shown", class_list.size()},
        {"total", matched}
    };
    
    return string_to_jstring(env, result.dump());
}

// Helper: Safe ASCII lowercase (UTF-8 safe - only converts ASCII a-z)
static std::string safe_tolower_ascii(const std::string& s) {
    std::string result = s;
    for (char& c : result) {
        if (c >= 'A' && c <= 'Z') {
            c = c + ('a' - 'A');
        }
    }
    return result;
}

// Helper: Safe string contains check (UTF-8 safe)
static bool safe_contains(const std::string& haystack, const std::string& needle, bool caseSensitive) {
    if (caseSensitive) {
        return haystack.find(needle) != std::string::npos;
    }
    // Only lowercase ASCII for case-insensitive search
    std::string h_lower = safe_tolower_ascii(haystack);
    std::string n_lower = safe_tolower_ascii(needle);
    return h_lower.find(n_lower) != std::string::npos;
}

// Helper: Sanitize string for JSON (replace invalid UTF-8 sequences)
static std::string sanitize_utf8(const std::string& s) {
    std::string result;
    result.reserve(s.size());
    size_t i = 0;
    while (i < s.size()) {
        unsigned char c = s[i];
        if (c < 0x80) {
            // ASCII
            result += c;
            i++;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < s.size()) {
            // 2-byte UTF-8
            if ((s[i+1] & 0xC0) == 0x80) {
                result += s[i];
                result += s[i+1];
                i += 2;
            } else {
                result += '?';
                i++;
            }
        } else if ((c & 0xF0) == 0xE0 && i + 2 < s.size()) {
            // 3-byte UTF-8
            if ((s[i+1] & 0xC0) == 0x80 && (s[i+2] & 0xC0) == 0x80) {
                result += s[i];
                result += s[i+1];
                result += s[i+2];
                i += 3;
            } else {
                result += '?';
                i++;
            }
        } else if ((c & 0xF8) == 0xF0 && i + 3 < s.size()) {
            // 4-byte UTF-8
            if ((s[i+1] & 0xC0) == 0x80 && (s[i+2] & 0xC0) == 0x80 && (s[i+3] & 0xC0) == 0x80) {
                result += s[i];
                result += s[i+1];
                result += s[i+2];
                result += s[i+3];
                i += 4;
            } else {
                result += '?';
                i++;
            }
        } else {
            // Invalid UTF-8, replace with ?
            result += '?';
            i++;
        }
    }
    return result;
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_searchInDex(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring query, jstring searchType,
                                                  jboolean caseSensitive, jint maxResults) {
    try {
        auto data = jbyteArray_to_vector(env, dexBytes);
        std::string q = jstring_to_string(env, query);
        std::string type = jstring_to_string(env, searchType);
        
        dex::DexParser parser;
        if (!parser.parse(data)) {
            json error = {{"error", "Failed to parse DEX"}};
            return string_to_jstring(env, error.dump());
        }
        
        json results = json::array();
        int count = 0;
        
        if (type == "string") {
            for (const auto& s : parser.strings()) {
                if (count >= maxResults) break;
                
                if (safe_contains(s, q, caseSensitive)) {
                    // Sanitize string for JSON
                    results.push_back({{"type", "string"}, {"value", sanitize_utf8(s)}});
                    count++;
                }
            }
        } else if (type == "class") {
            for (const auto& cls : parser.classes()) {
                if (count >= maxResults) break;
                std::string class_name = parser.get_class_name(cls.class_idx);
                
                if (safe_contains(class_name, q, caseSensitive)) {
                    results.push_back({{"type", "class"}, {"name", sanitize_utf8(class_name)}});
                    count++;
                }
            }
        } else if (type == "method") {
            auto methods = parser.get_methods();
            for (const auto& m : methods) {
                if (count >= maxResults) break;
                
                if (safe_contains(m.method_name, q, caseSensitive)) {
                    results.push_back({
                        {"type", "method"},
                        {"class", sanitize_utf8(m.class_name)},
                        {"name", sanitize_utf8(m.method_name)},
                        {"prototype", sanitize_utf8(m.prototype)}
                    });
                    count++;
                }
            }
        } else if (type == "field") {
            auto fields = parser.get_fields();
            for (const auto& f : fields) {
                if (count >= maxResults) break;
                
                if (safe_contains(f.field_name, q, caseSensitive)) {
                    results.push_back({
                        {"type", "field"},
                        {"class", sanitize_utf8(f.class_name)},
                        {"name", sanitize_utf8(f.field_name)},
                        {"fieldType", sanitize_utf8(f.type_name)}
                    });
                    count++;
                }
            }
        }
        
        json result = {
            {"query", sanitize_utf8(q)},
            {"searchType", type},
            {"results", results},
            {"count", results.size()}
        };
        
        return string_to_jstring(env, result.dump());
    } catch (const std::exception& e) {
        LOGE("searchInDex exception: %s", e.what());
        json error = {{"error", std::string("Search failed: ") + e.what()}};
        return string_to_jstring(env, error.dump());
    } catch (...) {
        LOGE("searchInDex unknown exception");
        json error = {{"error", "Search failed: unknown error"}};
        return string_to_jstring(env, error.dump());
    }
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_getClassSmali(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                    jstring className) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    // 设置反汇编器上下文
    dex::SmaliDisassembler disasm;
    disasm.set_strings(parser.strings());
    disasm.set_types(parser.types());
    disasm.set_methods(parser.get_method_signatures());
    disasm.set_fields(parser.get_field_signatures());
    
    // 查找类并反汇编所有方法
    std::stringstream smali;
    bool found = false;
    
    for (const auto& cls : parser.classes()) {
        if (parser.get_class_name(cls.class_idx) == class_name) {
            found = true;
            
            // 输出类声明
            smali << ".class public " << class_name << "\n";
            smali << ".super Ljava/lang/Object;\n\n";
            
            // 获取该类的所有方法
            auto methods = parser.get_methods();
            for (const auto& m : methods) {
                if (m.class_name == class_name) {
                    dex::CodeItem code;
                    if (parser.get_method_code(class_name, m.method_name, code, m.prototype)) {
                        auto insns = disasm.disassemble_method(code.insns.data(), code.insns.size());
                        
                        smali << ".method public " << m.method_name << m.prototype << "\n";
                        smali << "    .registers " << code.registers_size << "\n";
                        smali << disasm.to_smali(insns);
                        smali << ".end method\n\n";
                    }
                }
            }
            break;
        }
    }
    
    if (!found) {
        json error = {{"error", "Class not found: " + class_name}};
        return string_to_jstring(env, error.dump());
    }
    
    json result = {
        {"className", class_name},
        {"smali", smali.str()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_getMethodSmali(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                     jstring className, jstring methodName,
                                                     jstring methodSignature) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    std::string method_name = jstring_to_string(env, methodName);
    std::string method_sig = jstring_to_string(env, methodSignature);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    dex::CodeItem code;
    if (!parser.get_method_code(class_name, method_name, code)) {
        json error = {{"error", "Method not found or has no code"}};
        return string_to_jstring(env, error.dump());
    }
    
    dex::SmaliDisassembler disasm;
    disasm.set_strings(parser.strings());
    disasm.set_types(parser.types());
    disasm.set_methods(parser.get_method_signatures());
    disasm.set_fields(parser.get_field_signatures());
    
    auto insns = disasm.disassemble_method(code.insns.data(), code.insns.size());
    std::string smali_code = disasm.to_smali(insns);
    
    json result = {
        {"className", class_name},
        {"methodName", method_name},
        {"registers", code.registers_size},
        {"smali", smali_code}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== Smali 转 Java ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_smaliToJava(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring className) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    // 先获取类的 Smali 代码
    dex::SmaliDisassembler disasm;
    disasm.set_strings(parser.strings());
    disasm.set_types(parser.types());
    disasm.set_methods(parser.get_method_signatures());
    disasm.set_fields(parser.get_field_signatures());
    
    std::stringstream smali;
    bool found = false;
    
    for (const auto& cls : parser.classes()) {
        if (parser.get_class_name(cls.class_idx) == class_name) {
            found = true;
            smali << ".class public " << class_name << "\n";
            smali << ".super Ljava/lang/Object;\n\n";
            
            auto methods = parser.get_methods();
            for (const auto& m : methods) {
                if (m.class_name == class_name) {
                    dex::CodeItem code;
                    if (parser.get_method_code(class_name, m.method_name, code, m.prototype)) {
                        auto insns = disasm.disassemble_method(code.insns.data(), code.insns.size());
                        smali << ".method public " << m.method_name << m.prototype << "\n";
                        smali << "    .registers " << code.registers_size << "\n";
                        smali << disasm.to_smali(insns);
                        smali << ".end method\n\n";
                    }
                }
            }
            break;
        }
    }
    
    if (!found) {
        json error = {{"error", "Class not found: " + class_name}};
        return string_to_jstring(env, error.dump());
    }
    
    // 转换为 Java 伪代码
    dex::SmaliToJava converter;
    std::string java_code = converter.convert(smali.str());
    
    if (java_code.empty()) {
        json error = {{"error", "Failed to convert class: " + class_name}};
        return string_to_jstring(env, error.dump());
    }
    
    json result = {
        {"className", class_name},
        {"java", java_code}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== Smali 解析辅助函数 ====================

// 解析 Smali 类声明 (前向声明)
static bool parse_smali_class(const std::string& smali, std::string& class_name, 
                               std::string& super_class, uint32_t& access_flags);
static bool parse_smali_method(const std::string& method_block, dex::MethodDef& method);

// ==================== DEX 修改操作 ====================

JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_modifyClass(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring className, jstring newSmali) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string target_class = jstring_to_string(env, className);
    std::string smali_code = jstring_to_string(env, newSmali);
    
    // 解析新的 Smali 代码
    std::string class_name, super_class;
    uint32_t access_flags;
    if (!parse_smali_class(smali_code, class_name, super_class, access_flags)) {
        LOGE("Failed to parse Smali class declaration");
        return nullptr;
    }
    
    LOGI("Modifying class: %s", target_class.c_str());
    
    // 加载原 DEX
    dex::DexBuilder builder;
    if (!builder.load(data)) {
        LOGE("Failed to load DEX for modification");
        return nullptr;
    }
    
    // 获取或创建类
    auto* cls = builder.get_class(target_class);
    if (!cls) {
        // 类不存在，创建新类
        cls = &builder.make_class(class_name);
    }
    cls->set_super(super_class);
    cls->set_access(access_flags);
    
    // 解析并添加方法
    size_t method_start = 0;
    while ((method_start = smali_code.find(".method", method_start)) != std::string::npos) {
        size_t method_end = smali_code.find(".end method", method_start);
        if (method_end == std::string::npos) break;
        method_end += 11;
        
        std::string method_block = smali_code.substr(method_start, method_end - method_start);
        dex::MethodDef method;
        if (parse_smali_method(method_block, method)) {
            cls->add_method(method);
            LOGI("Modified method: %s", method.name.c_str());
        }
        method_start = method_end;
    }
    
    auto result = builder.build();
    if (result.empty()) {
        LOGE("Failed to build modified DEX");
        return nullptr;
    }
    
    LOGI("Built modified DEX: %zu bytes", result.size());
    return vector_to_jbyteArray(env, result);
}

JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_addClass(JNIEnv* env, jclass, jbyteArray dexBytes,
                                               jstring newSmali) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string smali_code = jstring_to_string(env, newSmali);
    
    // 解析 Smali 代码
    std::string class_name, super_class;
    uint32_t access_flags;
    if (!parse_smali_class(smali_code, class_name, super_class, access_flags)) {
        LOGE("Failed to parse Smali class declaration");
        return nullptr;
    }
    
    LOGI("Adding class: %s", class_name.c_str());
    
    dex::DexBuilder builder;
    if (!builder.load(data)) {
        LOGE("Failed to load DEX");
        return nullptr;
    }
    
    // 创建新类
    auto& cls = builder.make_class(class_name);
    cls.set_super(super_class);
    cls.set_access(access_flags);
    
    // 解析并添加方法
    size_t method_start = 0;
    while ((method_start = smali_code.find(".method", method_start)) != std::string::npos) {
        size_t method_end = smali_code.find(".end method", method_start);
        if (method_end == std::string::npos) break;
        method_end += 11;
        
        std::string method_block = smali_code.substr(method_start, method_end - method_start);
        dex::MethodDef method;
        if (parse_smali_method(method_block, method)) {
            cls.add_method(method);
            LOGI("Added method: %s", method.name.c_str());
        }
        method_start = method_end;
    }
    
    auto result = builder.build();
    if (result.empty()) {
        LOGE("Failed to build DEX with new class");
        return nullptr;
    }
    
    LOGI("Built DEX with new class: %zu bytes", result.size());
    return vector_to_jbyteArray(env, result);
}

JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_deleteClass(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring className) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    
    LOGI("Deleting class: %s (not fully implemented)", class_name.c_str());
    
    // 删除类需要重建整个 DEX，排除目标类
    // 目前返回原数据，因为完整实现较复杂
    return vector_to_jbyteArray(env, data);
}

// ==================== 方法级操作 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_listMethods(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring className) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    json method_list = json::array();
    auto methods = parser.get_methods();
    
    for (const auto& m : methods) {
        if (m.class_name == class_name) {
            method_list.push_back({
                {"name", m.method_name},
                {"prototype", m.prototype},
                {"accessFlags", m.access_flags}
            });
        }
    }
    
    json result = {
        {"className", class_name},
        {"methods", method_list},
        {"count", method_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_listFields(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                 jstring className) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    json field_list = json::array();
    auto fields = parser.get_fields();
    
    for (const auto& f : fields) {
        if (f.class_name == class_name) {
            field_list.push_back({
                {"name", f.field_name},
                {"type", f.type_name},
                {"accessFlags", f.access_flags}
            });
        }
    }
    
    json result = {
        {"className", class_name},
        {"fields", field_list},
        {"count", field_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== 字符串操作 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_listStrings(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                  jstring filter, jint limit) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string filter_str = jstring_to_string(env, filter);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    json string_list = json::array();
    const auto& strings = parser.strings();
    int count = 0;
    int matched = 0;
    
    for (const auto& s : strings) {
        if (!filter_str.empty() && s.find(filter_str) == std::string::npos) {
            continue;
        }
        matched++;
        if (count < limit) {
            string_list.push_back(s);
            count++;
        }
    }
    
    json result = {
        {"strings", string_list},
        {"shown", string_list.size()},
        {"matched", matched},
        {"total", strings.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== 交叉引用分析 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_findMethodXrefs(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                      jstring className, jstring methodName) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    std::string method_name = jstring_to_string(env, methodName);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    auto xrefs = parser.find_method_xrefs(class_name, method_name);
    
    json xref_list = json::array();
    for (const auto& xref : xrefs) {
        xref_list.push_back({
            {"callerClass", xref.caller_class},
            {"callerMethod", xref.caller_method},
            {"offset", xref.offset}
        });
    }
    
    json result = {
        {"className", class_name},
        {"methodName", method_name},
        {"xrefs", xref_list},
        {"count", xref_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_findFieldXrefs(JNIEnv* env, jclass, jbyteArray dexBytes,
                                                     jstring className, jstring fieldName) {
    auto data = jbyteArray_to_vector(env, dexBytes);
    std::string class_name = jstring_to_string(env, className);
    std::string field_name = jstring_to_string(env, fieldName);
    
    dex::DexParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse DEX"}};
        return string_to_jstring(env, error.dump());
    }
    
    auto xrefs = parser.find_field_xrefs(class_name, field_name);
    
    json xref_list = json::array();
    for (const auto& xref : xrefs) {
        xref_list.push_back({
            {"callerClass", xref.caller_class},
            {"callerMethod", xref.caller_method},
            {"offset", xref.offset}
        });
    }
    
    json result = {
        {"className", class_name},
        {"fieldName", field_name},
        {"xrefs", xref_list},
        {"count", xref_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== Smali 编译 ====================

// 解析 Smali 类声明
static bool parse_smali_class(const std::string& smali, std::string& class_name, 
                               std::string& super_class, uint32_t& access_flags) {
    std::istringstream iss(smali);
    std::string line;
    class_name = "";
    super_class = "Ljava/lang/Object;";
    access_flags = dex::ACC_PUBLIC;
    
    while (std::getline(iss, line)) {
        // 跳过空行和注释
        size_t start = line.find_first_not_of(" \t");
        if (start == std::string::npos || line[start] == '#') continue;
        
        // .class directive
        if (line.find(".class") != std::string::npos) {
            // 解析访问修饰符和类名
            if (line.find("public") != std::string::npos) access_flags |= dex::ACC_PUBLIC;
            if (line.find("private") != std::string::npos) access_flags = (access_flags & ~dex::ACC_PUBLIC) | dex::ACC_PRIVATE;
            if (line.find("final") != std::string::npos) access_flags |= dex::ACC_FINAL;
            if (line.find("abstract") != std::string::npos) access_flags |= dex::ACC_ABSTRACT;
            if (line.find("interface") != std::string::npos) access_flags |= dex::ACC_INTERFACE;
            
            // 提取类名 (最后一个 L...;)
            size_t lpos = line.rfind('L');
            if (lpos != std::string::npos) {
                size_t spos = line.find(';', lpos);
                if (spos != std::string::npos) {
                    class_name = line.substr(lpos, spos - lpos + 1);
                }
            }
        }
        // .super directive
        else if (line.find(".super") != std::string::npos) {
            size_t lpos = line.find('L');
            if (lpos != std::string::npos) {
                size_t spos = line.find(';', lpos);
                if (spos != std::string::npos) {
                    super_class = line.substr(lpos, spos - lpos + 1);
                }
            }
        }
    }
    
    return !class_name.empty();
}

// 解析 Smali 方法
static bool parse_smali_method(const std::string& method_block, dex::MethodDef& method) {
    std::istringstream iss(method_block);
    std::string line;
    std::vector<std::string> code_lines;
    bool in_method = false;
    
    method.registers_size = 2;
    method.ins_size = 1;
    method.outs_size = 0;
    method.access_flags = dex::ACC_PUBLIC;
    
    while (std::getline(iss, line)) {
        size_t start = line.find_first_not_of(" \t");
        if (start == std::string::npos) continue;
        line = line.substr(start);
        
        if (line.find(".method") == 0) {
            in_method = true;
            // 解析方法签名
            if (line.find("public") != std::string::npos) method.access_flags |= dex::ACC_PUBLIC;
            if (line.find("private") != std::string::npos) method.access_flags = (method.access_flags & ~dex::ACC_PUBLIC) | dex::ACC_PRIVATE;
            if (line.find("static") != std::string::npos) method.access_flags |= dex::ACC_STATIC;
            if (line.find("constructor") != std::string::npos) method.access_flags |= dex::ACC_CONSTRUCTOR;
            if (line.find("final") != std::string::npos) method.access_flags |= dex::ACC_FINAL;
            if (line.find("native") != std::string::npos) method.access_flags |= dex::ACC_NATIVE;
            if (line.find("abstract") != std::string::npos) method.access_flags |= dex::ACC_ABSTRACT;
            
            // 提取方法名和签名
            size_t name_start = line.rfind(' ');
            if (name_start != std::string::npos) {
                std::string sig = line.substr(name_start + 1);
                size_t paren = sig.find('(');
                if (paren != std::string::npos) {
                    method.name = sig.substr(0, paren);
                    // 解析参数和返回类型
                    size_t end_paren = sig.find(')');
                    if (end_paren != std::string::npos) {
                        method.prototype.return_type = sig.substr(end_paren + 1);
                        // TODO: 解析参数类型
                    }
                }
            }
        }
        else if (line.find(".end method") == 0) {
            break;
        }
        else if (line.find(".registers") == 0) {
            size_t num_start = line.find_first_of("0123456789");
            if (num_start != std::string::npos) {
                method.registers_size = static_cast<uint16_t>(std::stoi(line.substr(num_start)));
            }
        }
        else if (line.find(".locals") == 0) {
            size_t num_start = line.find_first_of("0123456789");
            if (num_start != std::string::npos) {
                method.registers_size = static_cast<uint16_t>(std::stoi(line.substr(num_start))) + method.ins_size;
            }
        }
        else if (in_method && line[0] != '.' && line[0] != ':' && line[0] != '#') {
            // 这是一条指令
            code_lines.push_back(line);
        }
    }
    
    // 如果没有代码，添加 return-void
    if (code_lines.empty()) {
        method.code = {0x0e, 0x00}; // return-void
    } else {
        // 使用 SmaliAssembler 汇编代码
        dex::SmaliAssembler assembler;
        std::string error;
        std::string all_code;
        for (const auto& cl : code_lines) {
            all_code += cl + "\n";
        }
        if (!assembler.assemble(all_code, method.code, error)) {
            LOGW("SmaliAssembler failed: %s, using return-void", error.c_str());
            method.code = {0x0e, 0x00}; // fallback to return-void
        }
    }
    
    return !method.name.empty();
}

JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_smaliToDex(JNIEnv* env, jclass, jstring smaliCode) {
    std::string smali = jstring_to_string(env, smaliCode);
    
    // 解析类信息
    std::string class_name, super_class;
    uint32_t access_flags;
    
    if (!parse_smali_class(smali, class_name, super_class, access_flags)) {
        LOGE("Failed to parse Smali class declaration");
        return nullptr;
    }
    
    LOGI("Compiling Smali class: %s", class_name.c_str());
    
    // 创建 DexBuilder
    dex::DexBuilder builder;
    auto& cls = builder.make_class(class_name);
    cls.set_super(super_class);
    cls.set_access(access_flags);
    
    // 解析方法
    size_t method_start = 0;
    while ((method_start = smali.find(".method", method_start)) != std::string::npos) {
        size_t method_end = smali.find(".end method", method_start);
        if (method_end == std::string::npos) break;
        method_end += 11; // ".end method" 长度
        
        std::string method_block = smali.substr(method_start, method_end - method_start);
        dex::MethodDef method;
        if (parse_smali_method(method_block, method)) {
            cls.add_method(method);
            LOGI("Added method: %s", method.name.c_str());
        }
        
        method_start = method_end;
    }
    
    // 构建 DEX
    auto result = builder.build();
    if (result.empty()) {
        LOGE("Failed to build DEX from Smali");
        return nullptr;
    }
    
    LOGI("Built DEX: %zu bytes", result.size());
    return vector_to_jbyteArray(env, result);
}

// ==================== AXML 解析 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_parseAxml(JNIEnv* env, jclass, jbyteArray axmlBytes) {
    auto data = jbyteArray_to_vector(env, axmlBytes);
    
    axml::AxmlParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse AXML"}};
        return string_to_jstring(env, error.dump());
    }
    
    json result = {
        {"packageName", parser.get_package_name()},
        {"versionName", parser.get_version_name()},
        {"versionCode", parser.get_version_code()},
        {"minSdk", parser.get_min_sdk()},
        {"targetSdk", parser.get_target_sdk()},
        {"permissions", parser.get_permissions()},
        {"activities", parser.get_activities()},
        {"services", parser.get_services()},
        {"xml", parser.to_xml()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_editManifest(JNIEnv* env, jclass, jbyteArray axmlBytes,
                                                   jstring action, jstring value) {
    auto data = jbyteArray_to_vector(env, axmlBytes);
    std::string action_str = jstring_to_string(env, action);
    std::string value_str = jstring_to_string(env, value);
    
    axml::AxmlEditor editor;
    if (!editor.load(data)) {
        LOGE("Failed to load AXML for editing");
        return nullptr;
    }
    
    bool success = false;
    if (action_str == "set_package") {
        success = editor.set_package_name(value_str);
    } else if (action_str == "set_version_name") {
        success = editor.set_version_name(value_str);
    } else if (action_str == "set_version_code") {
        success = editor.set_version_code(std::stoi(value_str));
    } else if (action_str == "set_min_sdk") {
        success = editor.set_min_sdk(std::stoi(value_str));
    } else if (action_str == "set_target_sdk") {
        success = editor.set_target_sdk(std::stoi(value_str));
    } else {
        LOGE("Unknown action: %s", action_str.c_str());
        return nullptr;
    }
    
    if (!success) {
        LOGE("Failed to execute action: %s", action_str.c_str());
        return nullptr;
    }
    
    auto result = editor.save();
    if (result.empty()) {
        LOGE("Failed to save modified AXML");
        return nullptr;
    }
    
    return vector_to_jbyteArray(env, result);
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_searchXml(JNIEnv* env, jclass, jbyteArray axmlBytes,
                                                jstring attrName, jstring value, jint limit) {
    auto data = jbyteArray_to_vector(env, axmlBytes);
    std::string attr_name = jstring_to_string(env, attrName);
    std::string value_str = jstring_to_string(env, value);
    
    axml::AxmlEditor editor;
    if (!editor.load(data)) {
        json error = {{"error", "Failed to load AXML"}};
        return string_to_jstring(env, error.dump());
    }
    
    std::vector<axml::SearchResult> results;
    if (!attr_name.empty()) {
        results = editor.search_by_attribute(attr_name, value_str);
    } else if (!value_str.empty()) {
        results = editor.search_by_value(value_str);
    }
    
    json result_list = json::array();
    int count = 0;
    for (const auto& r : results) {
        if (count >= limit) break;
        result_list.push_back({
            {"elementPath", r.element_path},
            {"elementName", r.element_name},
            {"attributeName", r.attribute_name},
            {"attributeValue", r.attribute_value},
            {"elementIndex", r.element_index}
        });
        count++;
    }
    
    json result = {
        {"results", result_list},
        {"count", result_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

// ==================== ARSC 解析 ====================

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_parseArsc(JNIEnv* env, jclass, jbyteArray arscBytes) {
    auto data = jbyteArray_to_vector(env, arscBytes);
    
    arsc::ArscParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse ARSC"}};
        return string_to_jstring(env, error.dump());
    }
    
    json result = {
        {"packageName", parser.package_name()},
        {"stringCount", parser.strings().size()},
        {"resourceCount", parser.resources().size()},
        {"info", parser.get_info()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_searchArscStrings(JNIEnv* env, jclass, jbyteArray arscBytes,
                                                        jstring pattern, jint limit) {
    auto data = jbyteArray_to_vector(env, arscBytes);
    std::string pattern_str = jstring_to_string(env, pattern);
    
    arsc::ArscParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse ARSC"}};
        return string_to_jstring(env, error.dump());
    }
    
    auto results = parser.search_strings(pattern_str);
    
    json result_list = json::array();
    int count = 0;
    for (const auto& r : results) {
        if (count >= limit) break;
        result_list.push_back({
            {"index", r.index},
            {"value", r.value}
        });
        count++;
    }
    
    json result = {
        {"pattern", pattern_str},
        {"results", result_list},
        {"count", result_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_searchArscResources(JNIEnv* env, jclass, jbyteArray arscBytes,
                                                          jstring pattern, jstring type, jint limit) {
    auto data = jbyteArray_to_vector(env, arscBytes);
    std::string pattern_str = jstring_to_string(env, pattern);
    std::string type_str = jstring_to_string(env, type);
    
    arsc::ArscParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse ARSC"}};
        return string_to_jstring(env, error.dump());
    }
    
    auto results = parser.search_resources(pattern_str, type_str);
    
    json result_list = json::array();
    int count = 0;
    for (const auto& r : results) {
        if (count >= limit) break;
        result_list.push_back({
            {"id", r.id},
            {"name", r.name},
            {"type", r.type},
            {"value", r.value},
            {"package", r.package}
        });
        count++;
    }
    
    json result = {
        {"pattern", pattern_str},
        {"type", type_str},
        {"results", result_list},
        {"count", result_list.size()}
    };
    
    return string_to_jstring(env, result.dump());
}

JNIEXPORT jstring JNICALL
Java_com_aetherlink_dexeditor_CppDex_getArscResourceValue(JNIEnv* env, jclass, jbyteArray arscBytes,
                                                          jlong resId) {
    auto data = jbyteArray_to_vector(env, arscBytes);
    arsc::ArscParser parser;
    if (!parser.parse(data)) {
        json error = {{"error", "Failed to parse ARSC"}};
        return string_to_jstring(env, error.dump());
    }
    std::string out = parser.get_resource_value_json(static_cast<uint32_t>(resId));
    return string_to_jstring(env, out);
}

// Returns the modified arsc bytes on success; throws RuntimeException (message = failure reason)
// on failure so the Java side sees it as an exception.
JNIEXPORT jbyteArray JNICALL
Java_com_aetherlink_dexeditor_CppDex_setArscResourceValue(JNIEnv* env, jclass, jbyteArray arscBytes,
                                                          jlong resId, jstring config, jstring valueType,
                                                          jstring newValue) {
    auto data = jbyteArray_to_vector(env, arscBytes);
    std::string config_str = jstring_to_string(env, config);
    std::string vtype_str = jstring_to_string(env, valueType);
    std::string value_str = jstring_to_string(env, newValue);

    arsc::ArscParser parser;
    if (!parser.parse(data)) {
        jclass ex = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(ex, "Failed to parse ARSC");
        return nullptr;
    }

    std::vector<uint8_t> out;
    std::string error;
    if (!parser.set_resource_value(static_cast<uint32_t>(resId), config_str, vtype_str,
                                   value_str, out, error)) {
        jclass ex = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(ex, error.c_str());
        return nullptr;
    }

    jbyteArray result = env->NewByteArray(static_cast<jsize>(out.size()));
    env->SetByteArrayRegion(result, 0, static_cast<jsize>(out.size()),
                            reinterpret_cast<const jbyte*>(out.data()));
    return result;
}

} // extern "C"
