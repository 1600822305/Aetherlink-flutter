cmake_minimum_required(VERSION 3.18)
project(dex_cpp VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 源文件
set(SOURCES
    # DEX 操作
    dex/dex_parser.cpp
    dex/dex_builder.cpp
    dex/smali_disasm.cpp
    dex/smali_to_java.cpp
    # XML 操作
    xml/axml_parser.cpp
    # ARSC 操作
    arsc/arsc_parser.cpp
    # APK 操作
    apk/apk_handler.cpp
    apk/zip_utils.cpp
    # miniz (ZIP 库)
    third_party/miniz.c
    third_party/miniz_tinfl.c
    third_party/miniz_tdef.c
    third_party/miniz_zip.c
    # JNI 绑定
    jni_bridge.cpp
)

# 头文件目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/nlohmann_json/single_include
)

# 编译为共享库
add_library(dex_cpp SHARED ${SOURCES})

# 查找 Android log 库
find_library(log-lib log)

# 链接库
target_link_libraries(dex_cpp ${log-lib})

# 编译选项
target_compile_options(dex_cpp PRIVATE
    -Wall
    -Wextra
    -O2
    -fvisibility=hidden
)

# 链接选项 - 16KB 页面对齐 (Android 15+ 兼容性)
# 参考: https://developer.android.com/guide/practices/page-sizes
target_link_options(dex_cpp PRIVATE
    -Wl,-z,max-page-size=16384
    -Wl,-z,common-page-size=16384
)

# 定义宏
target_compile_definitions(dex_cpp PRIVATE
    ANDROID
)
