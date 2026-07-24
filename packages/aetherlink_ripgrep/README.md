# aetherlink_ripgrep

进程内 ripgrep 式文件搜索：Rust cdylib（`native/`）经 dart:ffi 直接调用，
一次调用完成宿主目录的递归遍历 + 文件名/内容匹配，返回命中行
（lineNumber / line / matchCount）。给 PRoot 工作区后端做搜索快路径用——
rootfs 就是应用私有目录，直接在宿主路径上搜索即可，不需要 spawn proot
进程跑容器内的 rg/grep/find。

## 结构

- `native/` — Rust crate（`aether_rg`），C ABI 两个导出：
  - `aether_rg_search(request_json) -> response_json`
  - `aether_rg_free_string(ptr)` — 释放返回值（分配器归属原生侧）
- `lib/src/models.dart` — 请求/响应 JSON 的 Dart 镜像
- `lib/src/ffi_search.dart` — `AetherlinkRipgrep.search()`：在后台 isolate
  里 dlopen `libaether_rg.so` 并调用，不阻塞 UI 线程
- `android/src/main/jniLibs/` — 预编译的 `libaether_rg.so`
  （arm64-v8a / armeabi-v7a / x86_64），构建期无 NDK/CMake 步骤

## 匹配语义

与工作区后端约定一致：大小写不敏感（literal 子串或 `(?i)` 正则）、
`skipDirs` 目录名剪枝、`fileTypes` 后缀过滤、`maxResults` 截断
（`truncated` 标记）、每文件最多 `maxMatchesPerFile` 条命中行
（`matchCount` 为全量）、超过 `maxFileBytes` 或疑似二进制（前 8KB 含
NUL）的文件跳过内容扫描。

## 重新构建 .so

```bash
export ANDROID_NDK_HOME=/path/to/ndk
packages/aetherlink_ripgrep/native/build_android.sh
```
