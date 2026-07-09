#!/usr/bin/env bash
# 编译并运行纯 C++ DEX 引擎单测（不依赖 Android NDK/SDK，仅需 g++）。
# 用法：bash test/run_tests.sh   （在 .../cpp 目录下执行，或任意目录，脚本自定位）
set -euo pipefail

CPP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$CPP_DIR/test/fixtures/sample.dex"
OUT="$(mktemp -d)/dex_engine_test"

echo "compiling from: $CPP_DIR"
g++ -std=c++17 -I"$CPP_DIR/include" \
    "$CPP_DIR/test/dex_engine_test.cpp" \
    "$CPP_DIR/dex/dex_parser.cpp" \
    -o "$OUT"

echo "running: $OUT $FIXTURE"
"$OUT" "$FIXTURE"
