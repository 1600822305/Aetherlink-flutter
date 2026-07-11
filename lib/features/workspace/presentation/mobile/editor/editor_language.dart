// 文件名 → highlight.js 语言 ID 的映射，供工作区编辑器的语法高亮用。
// 返回 null 表示按纯文本渲染（未知扩展名 / 天生无高亮的文件）。

String? languageForFileName(String name) {
  final lower = name.toLowerCase();
  switch (lower) {
    case 'makefile':
    case 'gnumakefile':
      return 'makefile';
    case 'dockerfile':
      return 'dockerfile';
    case 'cmakelists.txt':
      return 'cmake';
  }
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) return null;
  final ext = lower.substring(dot + 1);
  return switch (ext) {
    'dart' => 'dart',
    'py' => 'python',
    'js' || 'mjs' || 'cjs' || 'jsx' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'json' || 'jsonc' => 'json',
    'yaml' || 'yml' => 'yaml',
    'md' || 'markdown' => 'markdown',
    'html' || 'htm' || 'xml' || 'svg' || 'xhtml' || 'plist' => 'xml',
    'css' => 'css',
    'scss' => 'scss',
    'less' => 'less',
    'sh' || 'bash' || 'zsh' => 'bash',
    'c' || 'h' => 'c',
    'cpp' || 'cc' || 'cxx' || 'hpp' || 'hh' || 'hxx' => 'cpp',
    'java' => 'java',
    'kt' || 'kts' => 'kotlin',
    'rs' => 'rust',
    'go' => 'go',
    'rb' => 'ruby',
    'php' => 'php',
    'swift' => 'swift',
    'sql' => 'sql',
    'gradle' => 'gradle',
    'groovy' => 'groovy',
    'lua' => 'lua',
    'pl' || 'pm' => 'perl',
    'r' => 'r',
    'm' || 'mm' => 'objectivec',
    'cs' => 'csharp',
    'toml' || 'ini' || 'cfg' || 'conf' => 'ini',
    'properties' => 'properties',
    'bat' || 'cmd' => 'dos',
    'ps1' || 'psm1' => 'powershell',
    'proto' => 'protobuf',
    'diff' || 'patch' => 'diff',
    _ => null,
  };
}
