#!/usr/bin/env bash
# 交叉编译 libaether_rg.so 并放进 android/src/main/jniLibs/。
# 依赖：rustup + Android NDK（ANDROID_NDK_HOME 指向 NDK 根目录）。
set -euo pipefail

cd "$(dirname "$0")"
NDK="${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to the NDK root}"
API=24
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
JNI_LIBS="../android/src/main/jniLibs"

declare -A TARGETS=(
  ["aarch64-linux-android"]="arm64-v8a aarch64-linux-android${API}-clang"
  ["armv7-linux-androideabi"]="armeabi-v7a armv7a-linux-androideabi${API}-clang"
  ["x86_64-linux-android"]="x86_64 x86_64-linux-android${API}-clang"
)

for target in "${!TARGETS[@]}"; do
  read -r abi linker <<<"${TARGETS[$target]}"
  rustup target add "$target"
  env_target="${target//-/_}"
  export "CARGO_TARGET_$(echo "$env_target" | tr '[:lower:]' '[:upper:]')_LINKER=$TOOLCHAIN/$linker"
  export "CC_${env_target}=$TOOLCHAIN/$linker"
  cargo build --release --target "$target"
  mkdir -p "$JNI_LIBS/$abi"
  cp "target/$target/release/libaether_rg.so" "$JNI_LIBS/$abi/"
done

echo "done: $(find "$JNI_LIBS" -name libaether_rg.so | sort)"
