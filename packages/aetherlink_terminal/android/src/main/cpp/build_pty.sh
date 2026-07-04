#!/usr/bin/env bash
# 重新编译 libaether_pty.so 并落到各 ABI 的 jniLibs（预编译产物随仓库提交，
# 日常构建不跑 NDK/CMake）。改了 aether_pty.c 之后跑一次即可。
#
# 用法：ANDROID_NDK=/path/to/android-ndk-r25c ./build_pty.sh
set -euo pipefail

cd "$(dirname "$0")"
NDK="${ANDROID_NDK:?请设置 ANDROID_NDK 指向 NDK 根目录}"
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
JNI="../jniLibs"

declare -A TARGETS=(
  [arm64-v8a]=aarch64-linux-android24
  [armeabi-v7a]=armv7a-linux-androideabi24
  [x86_64]=x86_64-linux-android24
)

for abi in "${!TARGETS[@]}"; do
  out="$JNI/$abi/libaether_pty.so"
  "$TC/${TARGETS[$abi]}-clang" -O2 -shared -fPIC -Wall -Wextra \
    -o "$out" aether_pty.c -llog
  "$TC/llvm-strip" "$out"
  echo "built $out"
done
