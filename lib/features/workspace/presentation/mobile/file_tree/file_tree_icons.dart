import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 文件树图标系统（参考 VSCode Material Icon Theme）：
/// 按「完整文件名 > 复合扩展名 > 扩展名」匹配文件图标 + 专属颜色，
/// 目录按名称匹配特殊目录图标。颜色为 null 时由行组件回退到主题色。
class FileTreeIcon {
  const FileTreeIcon(this.icon, [this.color]);

  final IconData icon;
  final Color? color;
}

// 常用品牌/语言色（取自 Material Icon Theme 的配色习惯）。
const _dartBlue = Color(0xFF0175C2);
const _jsYellow = Color(0xFFF1DD3F);
const _tsBlue = Color(0xFF3178C6);
const _reactCyan = Color(0xFF61DAFB);
const _pyBlue = Color(0xFF3572A5);
const _javaOrange = Color(0xFFE76F00);
const _kotlinPurple = Color(0xFF9E63F5);
const _swiftOrange = Color(0xFFF05138);
const _cBlue = Color(0xFF599EFF);
const _cppBlue = Color(0xFF0288D1);
const _csPurple = Color(0xFF68217A);
const _goCyan = Color(0xFF00ACD7);
const _rustOrange = Color(0xFFCE422B);
const _rubyRed = Color(0xFFCC342D);
const _phpPurple = Color(0xFF777BB3);
const _luaBlue = Color(0xFF000080);
const _htmlOrange = Color(0xFFE44D26);
const _cssBlue = Color(0xFF42A5F5);
const _sassPink = Color(0xFFCD6799);
const _vueGreen = Color(0xFF41B883);
const _shellGreen = Color(0xFF89E051);
const _yamlRed = Color(0xFFFF5252);
const _jsonAmber = Color(0xFFFBC02D);
const _xmlOrange = Color(0xFFFF6F00);
const _mdBlue = Color(0xFF42A5F5);
const _textGrey = Color(0xFF90A4AE);
const _pdfRed = Color(0xFFE53935);
const _wordBlue = Color(0xFF1565C0);
const _sheetGreen = Color(0xFF33994B);
const _dbTeal = Color(0xFF26A69A);
const _imgPurple = Color(0xFFAB47BC);
const _svgAmber = Color(0xFFFFB300);
const _audioPink = Color(0xFFEC407A);
const _videoRed = Color(0xFFEF5350);
const _zipBrown = Color(0xFFAFB42B);
const _pkgBrown = Color(0xFF8D6E63);
const _keyYellow = Color(0xFFFDD835);
const _fontRed = Color(0xFFE64A19);
const _cfgGrey = Color(0xFF78909C);
const _gitOrange = Color(0xFFE84D31);
const _dockerBlue = Color(0xFF2496ED);
const _gradleTeal = Color(0xFF02303A);
const _npmRed = Color(0xFFCB3837);
const _lockGold = Color(0xFFFFB74D);
const _envLime = Color(0xFFCDDC39);
const _tomlGrey = Color(0xFF9C8E7B);
const _folderBlue = Color(0xFF64B5F6);

/// 完整文件名（小写）优先匹配。
const Map<String, FileTreeIcon> _nameIcons = {
  'dockerfile': FileTreeIcon(LucideIcons.container, _dockerBlue),
  'docker-compose.yml': FileTreeIcon(LucideIcons.container, _dockerBlue),
  'docker-compose.yaml': FileTreeIcon(LucideIcons.container, _dockerBlue),
  '.dockerignore': FileTreeIcon(LucideIcons.container, _dockerBlue),
  'makefile': FileTreeIcon(LucideIcons.wrench, _cfgGrey),
  'cmakelists.txt': FileTreeIcon(LucideIcons.wrench, _cfgGrey),
  'package.json': FileTreeIcon(LucideIcons.package, _npmRed),
  'package-lock.json': FileTreeIcon(LucideIcons.lock, _npmRed),
  'pnpm-lock.yaml': FileTreeIcon(LucideIcons.lock, _lockGold),
  'yarn.lock': FileTreeIcon(LucideIcons.lock, _lockGold),
  'pubspec.yaml': FileTreeIcon(LucideIcons.package, _dartBlue),
  'pubspec.lock': FileTreeIcon(LucideIcons.lock, _dartBlue),
  'cargo.toml': FileTreeIcon(LucideIcons.package, _rustOrange),
  'cargo.lock': FileTreeIcon(LucideIcons.lock, _rustOrange),
  'go.mod': FileTreeIcon(LucideIcons.package, _goCyan),
  'go.sum': FileTreeIcon(LucideIcons.lock, _goCyan),
  'gemfile': FileTreeIcon(LucideIcons.package, _rubyRed),
  'requirements.txt': FileTreeIcon(LucideIcons.package, _pyBlue),
  'pyproject.toml': FileTreeIcon(LucideIcons.package, _pyBlue),
  'readme.md': FileTreeIcon(LucideIcons.bookOpen, _mdBlue),
  'readme': FileTreeIcon(LucideIcons.bookOpen, _mdBlue),
  'changelog.md': FileTreeIcon(LucideIcons.history, _shellGreen),
  'license': FileTreeIcon(LucideIcons.scale, _lockGold),
  'license.md': FileTreeIcon(LucideIcons.scale, _lockGold),
  'license.txt': FileTreeIcon(LucideIcons.scale, _lockGold),
  '.gitignore': FileTreeIcon(LucideIcons.gitBranch, _gitOrange),
  '.gitattributes': FileTreeIcon(LucideIcons.gitBranch, _gitOrange),
  '.gitmodules': FileTreeIcon(LucideIcons.gitBranch, _gitOrange),
  '.editorconfig': FileTreeIcon(LucideIcons.settings2, _cfgGrey),
  '.prettierrc': FileTreeIcon(LucideIcons.paintbrush, _reactCyan),
  '.eslintrc': FileTreeIcon(LucideIcons.shieldCheck, _kotlinPurple),
  'tsconfig.json': FileTreeIcon(LucideIcons.settings2, _tsBlue),
  'analysis_options.yaml': FileTreeIcon(LucideIcons.shieldCheck, _dartBlue),
  'build.gradle': FileTreeIcon(LucideIcons.wrench, _gradleTeal),
  'settings.gradle': FileTreeIcon(LucideIcons.wrench, _gradleTeal),
  'gradle.properties': FileTreeIcon(LucideIcons.wrench, _gradleTeal),
  'androidmanifest.xml': FileTreeIcon(LucideIcons.smartphone, _shellGreen),
  'info.plist': FileTreeIcon(LucideIcons.settings2, _cfgGrey),
  'agents.md': FileTreeIcon(LucideIcons.bot, _kotlinPurple),
};

/// 复合扩展名（如 `.d.ts`、`.g.dart`），在单段扩展名之前匹配。
const Map<String, FileTreeIcon> _compoundExtIcons = {
  'd.ts': FileTreeIcon(LucideIcons.fileType2, _tsBlue),
  'g.dart': FileTreeIcon(LucideIcons.cog, _dartBlue),
  'freezed.dart': FileTreeIcon(LucideIcons.cog, _dartBlue),
  'test.dart': FileTreeIcon(LucideIcons.flaskConical, _shellGreen),
  'spec.ts': FileTreeIcon(LucideIcons.flaskConical, _shellGreen),
  'spec.js': FileTreeIcon(LucideIcons.flaskConical, _shellGreen),
  'test.ts': FileTreeIcon(LucideIcons.flaskConical, _shellGreen),
  'test.js': FileTreeIcon(LucideIcons.flaskConical, _shellGreen),
};

const Map<String, FileTreeIcon> _extIcons = {
  // 代码
  'dart': FileTreeIcon(LucideIcons.code, _dartBlue),
  'js': FileTreeIcon(LucideIcons.fileCode, _jsYellow),
  'mjs': FileTreeIcon(LucideIcons.fileCode, _jsYellow),
  'cjs': FileTreeIcon(LucideIcons.fileCode, _jsYellow),
  'ts': FileTreeIcon(LucideIcons.fileCode, _tsBlue),
  'tsx': FileTreeIcon(LucideIcons.atom, _reactCyan),
  'jsx': FileTreeIcon(LucideIcons.atom, _reactCyan),
  'vue': FileTreeIcon(LucideIcons.fileCode, _vueGreen),
  'py': FileTreeIcon(LucideIcons.fileCode, _pyBlue),
  'java': FileTreeIcon(LucideIcons.coffee, _javaOrange),
  'kt': FileTreeIcon(LucideIcons.fileCode, _kotlinPurple),
  'kts': FileTreeIcon(LucideIcons.fileCode, _kotlinPurple),
  'swift': FileTreeIcon(LucideIcons.bird, _swiftOrange),
  'c': FileTreeIcon(LucideIcons.fileCode, _cBlue),
  'h': FileTreeIcon(LucideIcons.fileCode, _cppBlue),
  'cpp': FileTreeIcon(LucideIcons.fileCode, _cppBlue),
  'cc': FileTreeIcon(LucideIcons.fileCode, _cppBlue),
  'hpp': FileTreeIcon(LucideIcons.fileCode, _cppBlue),
  'cs': FileTreeIcon(LucideIcons.fileCode, _csPurple),
  'go': FileTreeIcon(LucideIcons.fileCode, _goCyan),
  'rs': FileTreeIcon(LucideIcons.cog, _rustOrange),
  'rb': FileTreeIcon(LucideIcons.gem, _rubyRed),
  'php': FileTreeIcon(LucideIcons.fileCode, _phpPurple),
  'lua': FileTreeIcon(LucideIcons.moon, _luaBlue),
  'r': FileTreeIcon(LucideIcons.fileCode, _cBlue),
  'dartpad': FileTreeIcon(LucideIcons.code, _dartBlue),
  // 网页/样式
  'html': FileTreeIcon(LucideIcons.globe, _htmlOrange),
  'htm': FileTreeIcon(LucideIcons.globe, _htmlOrange),
  'css': FileTreeIcon(LucideIcons.palette, _cssBlue),
  'scss': FileTreeIcon(LucideIcons.palette, _sassPink),
  'sass': FileTreeIcon(LucideIcons.palette, _sassPink),
  'less': FileTreeIcon(LucideIcons.palette, _cssBlue),
  // 脚本/终端
  'sh': FileTreeIcon(LucideIcons.fileTerminal, _shellGreen),
  'bash': FileTreeIcon(LucideIcons.fileTerminal, _shellGreen),
  'zsh': FileTreeIcon(LucideIcons.fileTerminal, _shellGreen),
  'fish': FileTreeIcon(LucideIcons.fileTerminal, _shellGreen),
  'bat': FileTreeIcon(LucideIcons.fileTerminal, _cfgGrey),
  'cmd': FileTreeIcon(LucideIcons.fileTerminal, _cfgGrey),
  'ps1': FileTreeIcon(LucideIcons.fileTerminal, _cBlue),
  // 配置/数据
  'yaml': FileTreeIcon(LucideIcons.settings, _yamlRed),
  'yml': FileTreeIcon(LucideIcons.settings, _yamlRed),
  'toml': FileTreeIcon(LucideIcons.settings, _tomlGrey),
  'ini': FileTreeIcon(LucideIcons.settings, _cfgGrey),
  'conf': FileTreeIcon(LucideIcons.settings, _cfgGrey),
  'env': FileTreeIcon(LucideIcons.settings, _envLime),
  'properties': FileTreeIcon(LucideIcons.settings, _cfgGrey),
  'gradle': FileTreeIcon(LucideIcons.wrench, _gradleTeal),
  'json': FileTreeIcon(LucideIcons.fileJson, _jsonAmber),
  'jsonc': FileTreeIcon(LucideIcons.fileJson, _jsonAmber),
  'json5': FileTreeIcon(LucideIcons.fileJson, _jsonAmber),
  'xml': FileTreeIcon(LucideIcons.fileCode2, _xmlOrange),
  'plist': FileTreeIcon(LucideIcons.fileCode2, _cfgGrey),
  'csv': FileTreeIcon(LucideIcons.fileSpreadsheet, _sheetGreen),
  'tsv': FileTreeIcon(LucideIcons.fileSpreadsheet, _sheetGreen),
  'xls': FileTreeIcon(LucideIcons.fileSpreadsheet, _sheetGreen),
  'xlsx': FileTreeIcon(LucideIcons.fileSpreadsheet, _sheetGreen),
  'sql': FileTreeIcon(LucideIcons.database, _dbTeal),
  'db': FileTreeIcon(LucideIcons.database, _dbTeal),
  'sqlite': FileTreeIcon(LucideIcons.database, _dbTeal),
  'proto': FileTreeIcon(LucideIcons.share2, _cssBlue),
  'graphql': FileTreeIcon(LucideIcons.share2, _sassPink),
  'lock': FileTreeIcon(LucideIcons.lock, _lockGold),
  // 文档
  'md': FileTreeIcon(LucideIcons.fileText, _mdBlue),
  'mdx': FileTreeIcon(LucideIcons.fileText, _mdBlue),
  'txt': FileTreeIcon(LucideIcons.fileText, _textGrey),
  'rst': FileTreeIcon(LucideIcons.fileText, _textGrey),
  'log': FileTreeIcon(LucideIcons.scrollText, _textGrey),
  'pdf': FileTreeIcon(LucideIcons.fileText, _pdfRed),
  'doc': FileTreeIcon(LucideIcons.fileText, _wordBlue),
  'docx': FileTreeIcon(LucideIcons.fileText, _wordBlue),
  // 图片
  'png': FileTreeIcon(LucideIcons.image, _imgPurple),
  'jpg': FileTreeIcon(LucideIcons.image, _imgPurple),
  'jpeg': FileTreeIcon(LucideIcons.image, _imgPurple),
  'gif': FileTreeIcon(LucideIcons.image, _imgPurple),
  'webp': FileTreeIcon(LucideIcons.image, _imgPurple),
  'bmp': FileTreeIcon(LucideIcons.image, _imgPurple),
  'ico': FileTreeIcon(LucideIcons.image, _imgPurple),
  'svg': FileTreeIcon(LucideIcons.shapes, _svgAmber),
  // 音视频
  'mp3': FileTreeIcon(LucideIcons.fileAudio, _audioPink),
  'wav': FileTreeIcon(LucideIcons.fileAudio, _audioPink),
  'flac': FileTreeIcon(LucideIcons.fileAudio, _audioPink),
  'ogg': FileTreeIcon(LucideIcons.fileAudio, _audioPink),
  'm4a': FileTreeIcon(LucideIcons.fileAudio, _audioPink),
  'mp4': FileTreeIcon(LucideIcons.fileVideo, _videoRed),
  'mkv': FileTreeIcon(LucideIcons.fileVideo, _videoRed),
  'avi': FileTreeIcon(LucideIcons.fileVideo, _videoRed),
  'mov': FileTreeIcon(LucideIcons.fileVideo, _videoRed),
  'webm': FileTreeIcon(LucideIcons.fileVideo, _videoRed),
  // 压缩包/安装包
  'zip': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'rar': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  '7z': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'tar': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'gz': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'bz2': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'xz': FileTreeIcon(LucideIcons.fileArchive, _zipBrown),
  'apk': FileTreeIcon(LucideIcons.package2, _shellGreen),
  'aab': FileTreeIcon(LucideIcons.package2, _shellGreen),
  'ipa': FileTreeIcon(LucideIcons.package2, _cfgGrey),
  'jar': FileTreeIcon(LucideIcons.package2, _javaOrange),
  'deb': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  'dmg': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  'exe': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  'so': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  'dylib': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  'dll': FileTreeIcon(LucideIcons.package2, _pkgBrown),
  // 证书/密钥
  'pem': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  'key': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  'crt': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  'cer': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  'keystore': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  'jks': FileTreeIcon(LucideIcons.fileKey, _keyYellow),
  // 字体
  'ttf': FileTreeIcon(LucideIcons.fileType, _fontRed),
  'otf': FileTreeIcon(LucideIcons.fileType, _fontRed),
  'woff': FileTreeIcon(LucideIcons.fileType, _fontRed),
  'woff2': FileTreeIcon(LucideIcons.fileType, _fontRed),
};

/// 特殊目录（小写目录名）→ 专属图标；未命中回退普通文件夹。
const Map<String, IconData> _dirIcons = {
  'src': LucideIcons.folderCode,
  'lib': LucideIcons.folderCode,
  'source': LucideIcons.folderCode,
  'test': LucideIcons.folderCheck,
  'tests': LucideIcons.folderCheck,
  '__tests__': LucideIcons.folderCheck,
  'spec': LucideIcons.folderCheck,
  'assets': LucideIcons.folderHeart,
  'images': LucideIcons.folderHeart,
  'img': LucideIcons.folderHeart,
  'icons': LucideIcons.folderHeart,
  'fonts': LucideIcons.folderPen,
  'docs': LucideIcons.folderOpenDot,
  'doc': LucideIcons.folderOpenDot,
  'config': LucideIcons.folderCog,
  'configs': LucideIcons.folderCog,
  'settings': LucideIcons.folderCog,
  '.vscode': LucideIcons.folderCog,
  '.idea': LucideIcons.folderCog,
  'scripts': LucideIcons.folderTree,
  'bin': LucideIcons.folderTree,
  'tools': LucideIcons.folderCog,
  'build': LucideIcons.folderCog,
  'dist': LucideIcons.folderCog,
  'out': LucideIcons.folderCog,
  'node_modules': LucideIcons.folderDown,
  '.git': LucideIcons.folderGit2,
  '.github': LucideIcons.folderGit2,
  'android': LucideIcons.folderRoot,
  'ios': LucideIcons.folderRoot,
  'web': LucideIcons.folderDot,
  'public': LucideIcons.folderDot,
  'api': LucideIcons.folderSymlink,
  'data': LucideIcons.folderArchive,
  'database': LucideIcons.folderArchive,
  'db': LucideIcons.folderArchive,
  'i18n': LucideIcons.folderDot,
  'locales': LucideIcons.folderDot,
  'utils': LucideIcons.folderCog,
  'shared': LucideIcons.folderSync,
  'components': LucideIcons.folderKanban,
  'widgets': LucideIcons.folderKanban,
  'features': LucideIcons.folderKanban,
  'models': LucideIcons.folderArchive,
  'services': LucideIcons.folderSync,
  'packages': LucideIcons.folderDown,
  'vendor': LucideIcons.folderDown,
  'temp': LucideIcons.folderClock,
  'tmp': LucideIcons.folderClock,
  'cache': LucideIcons.folderClock,
  'logs': LucideIcons.folderClock,
  'backup': LucideIcons.folderArchive,
  'downloads': LucideIcons.folderDown,
};

/// 文件图标：完整文件名 > 复合扩展名 > 扩展名 > 兜底。
FileTreeIcon fileTreeFileIcon(String name) {
  final lower = name.toLowerCase();
  final byName = _nameIcons[lower];
  if (byName != null) return byName;
  if (lower.startsWith('.env')) {
    return const FileTreeIcon(LucideIcons.settings, _envLime);
  }
  if (lower.startsWith('.git')) {
    return const FileTreeIcon(LucideIcons.gitBranch, _gitOrange);
  }
  final firstDot = lower.indexOf('.');
  if (firstDot >= 0 && firstDot < lower.length - 1) {
    final compound = lower.substring(firstDot + 1);
    final byCompound = _compoundExtIcons[compound];
    if (byCompound != null) return byCompound;
  }
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) {
    return const FileTreeIcon(LucideIcons.file);
  }
  return _extIcons[lower.substring(dot + 1)] ??
      const FileTreeIcon(LucideIcons.file);
}

/// 目录图标：特殊目录名专属图标，展开态回退 folderOpen。
FileTreeIcon fileTreeDirIcon(String name, {required bool expanded}) {
  final special = _dirIcons[name.toLowerCase()];
  if (special != null) return FileTreeIcon(special, _folderBlue);
  return FileTreeIcon(
    expanded ? LucideIcons.folderOpen : LucideIcons.folder,
    _folderBlue,
  );
}
