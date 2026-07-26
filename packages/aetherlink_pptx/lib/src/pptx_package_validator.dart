import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// One structural finding on a .pptx package: which part, what's wrong.
/// Aligned with the check surface of Anthropic's `validate.py`（XML 合法性 /
/// 内容类型覆盖 / 关系完整性 / 图表与备注引用）, minus XSD.
class PptxPackageIssue {
  const PptxPackageIssue({required this.part, required this.message});

  final String part;
  final String message;

  Map<String, Object?> toJson() => {'part': part, 'message': message};
}

const String _relNs =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const String _ctNs =
    'http://schemas.openxmlformats.org/package/2006/content-types';

/// Validates the structural integrity of a .pptx package: every XML part is
/// well-formed, every part is covered by [Content_Types].xml, every
/// relationship target exists, every slide in `sldIdLst` resolves, and every
/// chart/notesSlide part is referenced. Returns all findings; an empty list
/// means the package passed.
List<PptxPackageIssue> validatePptxPackage(Uint8List bytes) {
  final issues = <PptxPackageIssue>[];
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    return [PptxPackageIssue(part: '(package)', message: '不是合法的 zip：$e')];
  }
  final parts = <String, Uint8List>{
    for (final f in archive.files)
      if (f.isFile) f.name: f.readBytes() ?? Uint8List(0),
  };

  // ── XML well-formedness ──
  final docs = <String, XmlDocument>{};
  for (final entry in parts.entries) {
    final name = entry.key;
    if (!name.endsWith('.xml') && !name.endsWith('.rels')) continue;
    try {
      docs[name] = XmlDocument.parse(utf8.decode(entry.value));
    } catch (e) {
      issues.add(PptxPackageIssue(part: name, message: 'XML 解析失败：$e'));
    }
  }

  // ── required parts ──
  for (final required in const [
    '[Content_Types].xml',
    '_rels/.rels',
    'ppt/presentation.xml',
  ]) {
    if (!parts.containsKey(required)) {
      issues.add(PptxPackageIssue(part: required, message: '缺少必需部件'));
    }
  }

  // ── content-type coverage ──
  final contentTypes = docs['[Content_Types].xml'];
  if (contentTypes != null) {
    final defaults = <String>{};
    final overrides = <String>{};
    for (final el in contentTypes.findAllElements(
      'Default',
      namespace: _ctNs,
    )) {
      final ext = el.getAttribute('Extension');
      if (ext != null) defaults.add(ext.toLowerCase());
    }
    for (final el in contentTypes.findAllElements(
      'Override',
      namespace: _ctNs,
    )) {
      final part = el.getAttribute('PartName');
      if (part != null) overrides.add(part);
    }
    for (final name in parts.keys) {
      if (name == '[Content_Types].xml') continue;
      final dot = name.lastIndexOf('.');
      final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
      if (!defaults.contains(ext) && !overrides.contains('/$name')) {
        issues.add(
          PptxPackageIssue(
            part: name,
            message: '[Content_Types].xml 没有覆盖这个部件（缺 Default/Override）',
          ),
        );
      }
    }
    for (final part in overrides) {
      if (!parts.containsKey(part.substring(1))) {
        issues.add(
          PptxPackageIssue(
            part: part,
            message: '[Content_Types].xml 的 Override 指向不存在的部件',
          ),
        );
      }
    }
  }

  // ── relationship targets ──
  final referenced = <String>{};
  for (final entry in docs.entries) {
    if (!entry.key.endsWith('.rels')) continue;
    final baseDir = _relsBaseDir(entry.key);
    for (final rel in entry.value.findAllElements(
      'Relationship',
      namespace: _relNs,
    )) {
      if (rel.getAttribute('TargetMode') == 'External') continue;
      final target = rel.getAttribute('Target');
      if (target == null) continue;
      final resolved = _resolvePath(baseDir, target);
      referenced.add(resolved);
      if (!parts.containsKey(resolved)) {
        issues.add(
          PptxPackageIssue(
            part: entry.key,
            message: '关系 ${rel.getAttribute('Id') ?? '?'} 指向不存在的部件: $resolved',
          ),
        );
      }
    }
  }

  // ── sldIdLst → rels resolution ──
  final presentation = docs['ppt/presentation.xml'];
  final presRelsDoc = docs['ppt/_rels/presentation.xml.rels'];
  if (presentation != null) {
    final presRels = <String, String>{};
    if (presRelsDoc != null) {
      for (final rel in presRelsDoc.findAllElements(
        'Relationship',
        namespace: _relNs,
      )) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) presRels[id] = target;
      }
    }
    for (final sldId in presentation.findAllElements('sldId', namespace: '*')) {
      final rId = sldId.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
          .firstOrNull
          ?.value;
      if (rId == null || !presRels.containsKey(rId)) {
        issues.add(
          PptxPackageIssue(
            part: 'ppt/presentation.xml',
            message: 'sldIdLst 引用了 presentation.xml.rels 里不存在的关系 "$rId"',
          ),
        );
      }
    }
  }

  // ── orphaned chart / notesSlide parts ──
  for (final name in parts.keys) {
    final isChart =
        name.startsWith('ppt/charts/chart') && name.endsWith('.xml');
    final isNotes =
        name.startsWith('ppt/notesSlides/notesSlide') && name.endsWith('.xml');
    if ((isChart || isNotes) && !referenced.contains(name)) {
      issues.add(PptxPackageIssue(part: name, message: '部件没有被任何关系引用（孤儿部件）'));
    }
  }

  return issues;
}

/// `ppt/slides/_rels/slide1.xml.rels` → base dir `ppt/slides` of its owner.
String _relsBaseDir(String relsPath) {
  final i = relsPath.lastIndexOf('/_rels/');
  return i < 0 ? '' : relsPath.substring(0, i);
}

String _resolvePath(String baseDir, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final stack = baseDir.isEmpty ? <String>[] : baseDir.split('/');
  for (final seg in target.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (stack.isNotEmpty) stack.removeLast();
      continue;
    }
    stack.add(seg);
  }
  return stack.join('/');
}
