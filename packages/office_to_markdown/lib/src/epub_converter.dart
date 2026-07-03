import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'office_parse_exception.dart';
import 'zip_xml.dart';

/// Converts an EPUB e-book to Markdown.
///
/// Follows the standard container chain: `META-INF/container.xml` → OPF
/// package document → spine of XHTML content documents, each converted to
/// simplified Markdown (headings, paragraphs, lists, emphasis, links, line
/// breaks) with scripts / styles stripped. The book title (from OPF
/// `dc:title`) becomes a leading `# ` heading.
///
/// Pure Dart and synchronous — heavy books should be converted inside an
/// isolate (e.g. `compute(EpubToMarkdown.convert, bytes)`).
class EpubToMarkdown {
  EpubToMarkdown._();

  /// Converts EPUB [bytes] to Markdown.
  static String convert(Uint8List bytes) {
    final archive = decodeZip(bytes);
    final container = readXml(archive, 'META-INF/container.xml');
    if (container == null) {
      throw OfficeParseException('META-INF/container.xml not found');
    }
    final opfPath = container.rootElement
        .findAllElements('*')
        .where((e) => e.localName == 'rootfile')
        .map((e) => e.getAttribute('full-path'))
        .firstOrNull;
    if (opfPath == null || opfPath.isEmpty) {
      throw OfficeParseException('container.xml has no rootfile full-path');
    }
    final opf = readXml(archive, opfPath);
    if (opf == null) {
      throw OfficeParseException('OPF package document not found: $opfPath');
    }

    final title = opf.rootElement
        .findAllElements('*')
        .where((e) => e.localName == 'title')
        .map((e) => e.innerText.trim())
        .where((t) => t.isNotEmpty)
        .firstOrNull;

    final manifest = <String, String>{};
    for (final item in opf.rootElement.findAllElements('*').where(
      (e) => e.localName == 'item',
    )) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) manifest[id] = href;
    }

    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';
    final sections = <String>[];
    for (final itemref in opf.rootElement.findAllElements('*').where(
      (e) => e.localName == 'itemref',
    )) {
      final href = manifest[itemref.getAttribute('idref')];
      if (href == null) continue;
      final file = archive.findFile(_resolvePath(opfDir, href));
      if (file == null) continue;
      final markdown = _xhtmlToMarkdown(readString(file));
      if (markdown.isNotEmpty) sections.add(markdown);
    }
    if (sections.isEmpty && title == null) {
      throw OfficeParseException('EPUB spine has no readable content');
    }

    final buffer = StringBuffer();
    if (title != null) buffer.write('# $title');
    for (final section in sections) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(section);
    }
    return buffer.toString();
  }

  /// Resolves a manifest [href] (percent-encoded, possibly `../`-relative)
  /// against the OPF's directory.
  static String _resolvePath(String baseDir, String href) {
    final decoded = Uri.decodeComponent(href.split('#').first);
    final segments = <String>[
      ...baseDir.split('/').where((s) => s.isNotEmpty),
    ];
    for (final segment in decoded.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(segment);
      }
    }
    return segments.join('/');
  }

  /// Simplified XHTML → Markdown, same regex approach as the app's
  /// `@aether/fetch` HTML conversion (kept package-local so this stays a
  /// pure Dart dependency-free library).
  static String _xhtmlToMarkdown(String html) {
    var content = html;
    // Only the body, when present.
    final body = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(content);
    if (body != null) content = body.group(1)!;
    content = content.replaceAll(
      RegExp(
        r'<(script|style|nav|header|footer|aside|iframe|noscript|svg)[^>]*>[\s\S]*?</\1>',
        caseSensitive: false,
      ),
      '',
    );
    content = content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    content = content.replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>([\s\S]*?)</h\1>', caseSensitive: false),
      (m) {
        final level = int.parse(m.group(1)!);
        final text = _stripTags(m.group(2)!);
        return '\n${'#' * level} $text\n';
      },
    );
    content = content.replaceAllMapped(
      RegExp(
        r'<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>',
        caseSensitive: false,
      ),
      (m) {
        final text = _stripTags(m.group(2)!);
        return text.isEmpty ? '' : '[$text](${m.group(1)!})';
      },
    );
    // Emphasis first, so bold/italic inside <p> / <li> survive their
    // tag-stripping below.
    content = content.replaceAllMapped(
      RegExp(r'<(strong|b)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
      (m) => '**${_stripTags(m.group(2)!)}**',
    );
    content = content.replaceAllMapped(
      RegExp(r'<(em|i)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
      (m) => '*${_stripTags(m.group(2)!)}*',
    );
    content = content.replaceAllMapped(
      RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false),
      (m) => '\n- ${_stripTags(m.group(1)!)}',
    );
    content = content.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    content = content.replaceAllMapped(
      RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false),
      (m) => '\n\n${_stripTags(m.group(1)!)}\n',
    );
    content = _decodeEntities(content.replaceAll(RegExp(r'<[^>]+>'), ''));
    content = content.split('\n').map((line) => line.trim()).join('\n');
    return content.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _decodeEntities(String text) => text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAll('&amp;', '&');
}
