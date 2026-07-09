#!/usr/bin/env bash
# 重新生成 test/fixtures/sample.dex（真实 d8 产出）。仅在需要更新夹具时手动跑。
#
# 依赖：javac（JDK）+ R8 的 D8。R8 jar 不入库，用环境变量指定：
#   R8_JAR=/path/to/r8.jar bash test/gen_fixture.sh
# 没有的话可从 Maven 取：
#   curl -sSL -o r8.jar https://maven.google.com/com/android/tools/r8/8.3.37/r8-8.3.37.jar
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$DIR/fixtures"
: "${R8_JAR:?请用 R8_JAR=/path/to/r8.jar 指定 R8 jar 路径}"

WORK="$(mktemp -d)"
mkdir -p "$WORK/com/example"
cp "$FIX/Base.java" "$FIX/Child.java" "$WORK/com/example/"

( cd "$WORK"
  javac --release 8 com/example/Base.java com/example/Child.java
  mkdir -p out
  java -cp "$R8_JAR" com.android.tools.r8.D8 \
      --release --min-api 21 --output out \
      com/example/Base.class com/example/Child.class )

cp "$WORK/out/classes.dex" "$FIX/sample.dex"
echo "updated $FIX/sample.dex"
