/// Starter-content templates for newly created files, keyed by extension (or
/// a few well-known bare file names). Pure Dart so it can be reused by a
/// desktop shell. Returns `null` when there is no template — the file is then
/// created empty.
String? fileTemplateFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower == '.gitignore') {
    return '# 忽略规则,每行一个模式\n';
  }
  if (lower == 'dockerfile') {
    return 'FROM alpine:latest\n\nWORKDIR /app\n\nCMD ["sh"]\n';
  }
  if (lower == 'makefile') {
    return '.PHONY: all\n\nall:\n\t@echo "make all"\n';
  }
  final dot = lower.lastIndexOf('.');
  if (dot <= 0 || dot == lower.length - 1) return null;
  final stem = fileName.substring(0, dot);
  return switch (lower.substring(dot + 1)) {
    'md' => '# $stem\n\n',
    'html' || 'htm' =>
      '<!DOCTYPE html>\n'
          '<html lang="zh-CN">\n'
          '<head>\n'
          '  <meta charset="UTF-8">\n'
          '  <meta name="viewport" content="width=device-width, '
          'initial-scale=1.0">\n'
          '  <title>$stem</title>\n'
          '</head>\n'
          '<body>\n\n'
          '</body>\n'
          '</html>\n',
    'sh' || 'bash' => '#!/usr/bin/env bash\nset -euo pipefail\n\n',
    'py' =>
      'def main() -> None:\n'
          '    pass\n\n\n'
          'if __name__ == "__main__":\n'
          '    main()\n',
    'dart' => 'void main() {\n}\n',
    'js' || 'mjs' => "'use strict';\n\n",
    'ts' => 'export {};\n\n',
    'json' => '{\n}\n',
    'yaml' || 'yml' => '# $stem\n',
    'xml' => '<?xml version="1.0" encoding="UTF-8"?>\n',
    'css' || 'scss' || 'less' => '/* $stem */\n',
    'c' =>
      '#include <stdio.h>\n\n'
          'int main(void) {\n'
          '  return 0;\n'
          '}\n',
    'cpp' =>
      '#include <iostream>\n\n'
          'int main() {\n'
          '  return 0;\n'
          '}\n',
    _ => null,
  };
}
