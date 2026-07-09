// 纯 C++ DEX 引擎单测（不依赖 Android/JNI）。
//
// 加载一个由真实 d8 编译产出的 DEX 夹具（test/fixtures/sample.dex，源码见同目录
// Base.java / Child.java），用 DexParser 解析并断言引擎输出。重点覆盖 dex_editor
// 工具的核心逻辑：
//   - get_class_name(superclass_idx)：smaliToJava 的 .super 正是靠它拿真实父类
//     （回归 #4：过去恒定 java.lang.Object）；
//   - get_class_outline()：dex_outline_class 的父类/接口/字段/方法/指令数来源。
//
// 用真实 d8 输出而非从零 DexBuilder 合成，保证与设备端解析同一种字节布局。
// 覆盖不到 JNI 编组、Java(dexlib2) 回退、会话与 Dart 层——那些仍需设备端复测。
//
// 用法：dex_engine_test <path/to/sample.dex>；编译运行见同目录 run_tests.sh。

#include "dex/dex_parser.h"

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

static int g_failures = 0;
static int g_checks = 0;

#define CHECK(cond, msg)                                                       \
    do {                                                                       \
        ++g_checks;                                                            \
        if (!(cond)) {                                                         \
            ++g_failures;                                                      \
            std::printf("  [FAIL] %s (line %d)\n", (msg), __LINE__);           \
        } else {                                                               \
            std::printf("  [ ok ] %s\n", (msg));                               \
        }                                                                      \
    } while (0)

#define CHECK_EQ_STR(actual, expected, msg)                                    \
    do {                                                                       \
        ++g_checks;                                                            \
        std::string a__ = (actual);                                            \
        std::string e__ = (expected);                                          \
        if (a__ != e__) {                                                      \
            ++g_failures;                                                      \
            std::printf("  [FAIL] %s (line %d): got \"%s\", want \"%s\"\n",    \
                        (msg), __LINE__, a__.c_str(), e__.c_str());            \
        } else {                                                               \
            std::printf("  [ ok ] %s = \"%s\"\n", (msg), a__.c_str());         \
        }                                                                      \
    } while (0)

// 夹具（Child.java）：
//   public final class Child extends Base implements Runnable {
//       private int mFlag;
//       public void run() { mFlag = 1; }
//   }
int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: %s <path/to/sample.dex>\n", argv[0]);
        return 2;
    }
    const std::string dex_path = argv[1];
    std::printf("== dex engine test (fixture: %s) ==\n", dex_path.c_str());

    dex::DexParser parser;
    CHECK(parser.parse(dex_path), "DexParser.parse() loads the fixture DEX");
    if (parser.classes().empty()) {
        std::printf("no classes parsed; cannot continue\n");
        return 1;
    }

    // ---- 类枚举 + 真实父类（smaliToJava .super 的核心原语，回归 #4）----
    bool saw_child = false;
    for (const auto& cls : parser.classes()) {
        if (parser.get_class_name(cls.class_idx) == "Lcom/example/Child;") {
            saw_child = true;
            CHECK(cls.superclass_idx != 0xFFFFFFFF,
                  "Child.superclass_idx is not NO_INDEX");
            CHECK_EQ_STR(parser.get_class_name(cls.superclass_idx),
                         "Lcom/example/Base;",
                         "Child superclass resolves to Base (not Object)");
        }
    }
    CHECK(saw_child, "found Lcom/example/Child;");

    // ---- get_class_outline（dex_outline_class 的数据源）----
    dex::DexParser::ClassOutline outline =
        parser.get_class_outline("Lcom/example/Child;");
    CHECK(outline.found, "outline found for Child");
    CHECK_EQ_STR(outline.superclass, "Lcom/example/Base;", "outline.superclass");

    bool has_runnable = false;
    for (const auto& itf : outline.interfaces) {
        if (itf == "Ljava/lang/Runnable;") has_runnable = true;
    }
    CHECK(has_runnable, "outline.interfaces contains Runnable");

    bool has_field = false;
    for (const auto& f : outline.fields) {
        if (f.name == "mFlag") {
            has_field = true;
            CHECK_EQ_STR(f.type, "I", "field mFlag type is int");
        }
    }
    CHECK(has_field, "outline exposes field mFlag");

    bool has_run = false;
    for (const auto& m : outline.methods) {
        if (m.name == "run") {
            has_run = true;
            CHECK(m.signature.rfind("()", 0) == 0 || m.signature.find(")V") != std::string::npos,
                  "run() signature returns void");
            CHECK(m.instructions_size > 0, "run() has non-zero instruction count");
        }
    }
    CHECK(has_run, "outline exposes method run");
    CHECK(outline.instructions_count > 0, "outline aggregate instructions_count > 0");

    std::printf("\n%d checks, %d failures\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
