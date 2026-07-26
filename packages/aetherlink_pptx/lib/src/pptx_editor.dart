// M6 —— 直接编辑已有 .pptx / .potx 包。
//
// 与 deck 源级编辑（deck.json → 重新导出）不同，这里在 OOXML 层原地改包：
// 解压 → 定位 shape/文本/图片 → 增删改 → 维护 [Content_Types].xml 与 .rels
// → 重打包。因此第三方文件和模板的母版、主题、版式全部原样保留。
//
// 纯 Dart 且同步——大文件请放进 isolate 调用。

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 编辑失败。[message] 面向模型，说明哪一步、为什么不行。
class PptxEditException implements Exception {
  PptxEditException(this.message);

  final String message;

  @override
  String toString() => 'PptxEditException: $message';
}

const String _relNs =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const String _ctNs =
    'http://schemas.openxmlformats.org/package/2006/content-types';

const String _slideCt =
    'application/vnd.openxmlformats-officedocument.presentationml.slide+xml';
const String _notesSlideCt =
    'application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml';
const String _slideRelType =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';
const String _notesSlideRelType =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide';
const String _imageRelType =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image';

/// 一个 shape 的摘要，供模型在编辑前定位目标。
class PptxShapeOutline {
  const PptxShapeOutline({
    required this.index,
    required this.kind,
    this.name,
    this.placeholder,
    this.text,
  });

  /// 在 spTree 里的 0 基下标——`set_text` 的 `shape` 参数用它。
  final int index;

  /// `sp`（文本/形状）· `pic`（图片）· `graphicFrame`（表格/图表）· `grpSp` 等。
  final String kind;

  /// shape 的名字（`p:cNvPr/@name`），模板里通常有意义，如「标题 1」。
  final String? name;

  /// 占位符类型（`p:ph/@type`），如 title / body / ctrTitle / subTitle。
  final String? placeholder;

  /// 当前纯文本（段落以 \n 连接），无文本时为 null。
  final String? text;

  Map<String, Object?> toJson() => {
    'index': index,
    'kind': kind,
    if (name != null) 'name': name,
    if (placeholder != null) 'placeholder': placeholder,
    if (text != null) 'text': text,
  };
}

/// 一页的摘要。
class PptxSlideOutline {
  const PptxSlideOutline({
    required this.index,
    required this.part,
    required this.shapes,
    required this.imageCount,
    this.layout,
    this.notes,
  });

  final int index;

  /// 包内路径，如 `ppt/slides/slide2.xml`。
  final String part;

  /// 这一页用的版式名（来自 slideLayout 的 `p:cSld/@name`），模板填充时有用。
  final String? layout;
  final List<PptxShapeOutline> shapes;
  final int imageCount;
  final String? notes;

  Map<String, Object?> toJson() => {
    'index': index,
    'part': part,
    if (layout != null) 'layout': layout,
    'imageCount': imageCount,
    if (notes != null) 'notes': notes,
    'shapes': [for (final s in shapes) s.toJson()],
  };
}

/// 可变的内存态 .pptx 包。所有编辑都作用在这上面，最后 [save] 重打包。
class PptxPackage {
  PptxPackage._(this._parts);

  final Map<String, Uint8List> _parts;

  /// 解压 [bytes]。不做深度校验——校验交给 `validatePptxPackage`。
  static PptxPackage open(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw PptxEditException('不是合法的 zip/pptx 文件：$e');
    }
    final parts = <String, Uint8List>{
      for (final f in archive.files)
        if (f.isFile) f.name: f.readBytes() ?? Uint8List(0),
    };
    for (final required in const [
      '[Content_Types].xml',
      'ppt/presentation.xml',
      'ppt/_rels/presentation.xml.rels',
    ]) {
      if (!parts.containsKey(required)) {
        throw PptxEditException('pptx 包缺少必需部件 $required，无法编辑');
      }
    }
    return PptxPackage._(parts);
  }

  /// 重打包为 .pptx 字节。
  Uint8List save() {
    final archive = Archive();
    // [Content_Types].xml 放在最前面：部分实现（含旧版 Keynote）要求它是首个条目。
    final names = _parts.keys.toList()
      ..sort((a, b) {
        if (a == '[Content_Types].xml') return -1;
        if (b == '[Content_Types].xml') return 1;
        return a.compareTo(b);
      });
    for (final name in names) {
      archive.add(ArchiveFile.bytes(name, _parts[name]!));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// 包内所有部件路径。
  Iterable<String> get partNames => _parts.keys;

  Uint8List? partBytes(String path) => _parts[path];

  void setPartBytes(String path, List<int> bytes) {
    _parts[path] = Uint8List.fromList(bytes);
  }

  void removePart(String path) => _parts.remove(path);

  bool hasPart(String path) => _parts.containsKey(path);

  XmlDocument xml(String path) {
    final data = _parts[path];
    if (data == null) throw PptxEditException('pptx 包缺少部件 $path');
    try {
      return XmlDocument.parse(utf8.decode(data));
    } catch (e) {
      throw PptxEditException('部件 $path 不是合法 XML：$e');
    }
  }

  void setXml(String path, XmlDocument doc) {
    _parts[path] = Uint8List.fromList(utf8.encode(doc.toXmlString()));
  }

  // ── 关系（.rels）──

  /// [partPath] 对应的 .rels 路径。
  static String relsPathFor(String partPath) {
    final dir = _dirname(partPath);
    final name = partPath.substring(dir.isEmpty ? 0 : dir.length + 1);
    return dir.isEmpty ? '_rels/$name.rels' : '$dir/_rels/$name.rels';
  }

  /// [partPath] 的 rId → Target（原始相对值，未解析）。
  Map<String, String> relsOf(String partPath) {
    final path = relsPathFor(partPath);
    if (!hasPart(path)) return const {};
    final rels = <String, String>{};
    for (final rel in xml(path).findAllElements('Relationship', namespace: _relNs)) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id != null && target != null) rels[id] = target;
    }
    return rels;
  }

  /// 往 [partPath] 的 .rels 里加一条关系，返回新的 rId。缺 .rels 时自动新建。
  String addRelationship(String partPath, String type, String target) {
    final path = relsPathFor(partPath);
    final XmlDocument doc;
    if (hasPart(path)) {
      doc = xml(path);
    } else {
      doc = XmlDocument.parse(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$_relNs"/>',
      );
    }
    final root = doc.rootElement;
    var max = 0;
    for (final rel in root.findAllElements('Relationship', namespace: _relNs)) {
      final id = rel.getAttribute('Id') ?? '';
      final n = int.tryParse(id.startsWith('rId') ? id.substring(3) : '');
      if (n != null && n > max) max = n;
    }
    final rId = 'rId${max + 1}';
    root.children.add(
      XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), rId),
        XmlAttribute(XmlName('Type'), type),
        XmlAttribute(XmlName('Target'), target),
      ]),
    );
    setXml(path, doc);
    return rId;
  }

  /// 从 [partPath] 的 .rels 里删掉 [rId]。
  void removeRelationship(String partPath, String rId) {
    final path = relsPathFor(partPath);
    if (!hasPart(path)) return;
    final doc = xml(path);
    for (final rel
        in doc.rootElement
            .findAllElements('Relationship', namespace: _relNs)
            .toList()) {
      if (rel.getAttribute('Id') == rId) rel.remove();
    }
    setXml(path, doc);
  }

  /// 把 [partPath] 里 [rId] 的 Target 改成 [target]。
  void retargetRelationship(String partPath, String rId, String target) {
    final path = relsPathFor(partPath);
    if (!hasPart(path)) return;
    final doc = xml(path);
    for (final rel in doc.rootElement.findAllElements(
      'Relationship',
      namespace: _relNs,
    )) {
      if (rel.getAttribute('Id') == rId) {
        rel.setAttribute('Target', target);
      }
    }
    setXml(path, doc);
  }

  // ── [Content_Types].xml ──

  /// 确保 `/[part]` 有 Override 声明（幂等）。
  void ensureOverride(String partPath, String contentType) {
    final doc = xml('[Content_Types].xml');
    final root = doc.rootElement;
    final name = '/$partPath';
    for (final o in root.findAllElements('Override', namespace: _ctNs)) {
      if (o.getAttribute('PartName') == name) return;
    }
    root.children.add(
      XmlElement(XmlName('Override'), [
        XmlAttribute(XmlName('PartName'), name),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
    setXml('[Content_Types].xml', doc);
  }

  void removeOverride(String partPath) {
    final doc = xml('[Content_Types].xml');
    final name = '/$partPath';
    var changed = false;
    for (final o
        in doc.rootElement.findAllElements('Override', namespace: _ctNs).toList()) {
      if (o.getAttribute('PartName') == name) {
        o.remove();
        changed = true;
      }
    }
    if (changed) setXml('[Content_Types].xml', doc);
  }

  /// 确保扩展名 [ext]（不带点）有 Default 声明（图片新扩展名要用）。
  void ensureDefault(String ext, String contentType) {
    final doc = xml('[Content_Types].xml');
    final root = doc.rootElement;
    final lower = ext.toLowerCase();
    for (final d in root.findAllElements('Default', namespace: _ctNs)) {
      if ((d.getAttribute('Extension') ?? '').toLowerCase() == lower) return;
    }
    root.children.add(
      XmlElement(XmlName('Default'), [
        XmlAttribute(XmlName('Extension'), lower),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
    setXml('[Content_Types].xml', doc);
  }

  // ── 幻灯片 ──

  /// 按放映顺序返回幻灯片部件路径。
  List<String> slidePaths() {
    final presRels = relsOf('ppt/presentation.xml');
    final paths = <String>[];
    for (final sldId in xml(
      'ppt/presentation.xml',
    ).findAllElements('sldId', namespace: '*')) {
      final rId = _rAttr(sldId, 'id');
      final target = rId == null ? null : presRels[rId];
      if (target == null) {
        throw PptxEditException('presentation.xml 的 sldId 引用了不存在的关系 "$rId"');
      }
      paths.add(_resolvePath('ppt', target));
    }
    if (paths.isEmpty) throw PptxEditException('这个 pptx 没有任何幻灯片');
    return paths;
  }

  String slidePathAt(int index) {
    final paths = slidePaths();
    if (index < 0 || index >= paths.length) {
      throw PptxEditException('幻灯片下标 $index 越界（共 ${paths.length} 页，合法 0..${paths.length - 1}）');
    }
    return paths[index];
  }

  /// 这一页的 notesSlide 部件路径，没有则 null。
  String? notesPathOf(String slidePath) {
    final dir = _dirname(slidePath);
    for (final entry in relsOf(slidePath).entries) {
      if (entry.value.contains('notesSlide')) {
        return _resolvePath(dir, entry.value);
      }
    }
    return null;
  }

  /// 这一页的 slideLayout 部件路径，没有则 null。
  String? layoutPathOf(String slidePath) {
    final dir = _dirname(slidePath);
    for (final entry in relsOf(slidePath).entries) {
      if (entry.value.contains('slideLayout')) {
        return _resolvePath(dir, entry.value);
      }
    }
    return null;
  }
}

// ══════════════════ 只读：大纲 ══════════════════

/// 逐页列出 shape（下标 / 类型 / 名字 / 占位符 / 当前文本），编辑前先调它定位目标。
List<PptxSlideOutline> describePptxOutline(PptxPackage pkg) {
  final out = <PptxSlideOutline>[];
  for (final (i, path) in pkg.slidePaths().indexed) {
    final doc = pkg.xml(path);
    final spTree = doc.findAllElements('spTree', namespace: '*').firstOrNull;
    final shapes = <PptxShapeOutline>[];
    var imageCount = 0;
    if (spTree != null) {
      var index = 0;
      for (final node in spTree.childElements) {
        final kind = node.name.local;
        // spTree 的前两个子元素是 nvGrpSpPr/grpSpPr，不是 shape。
        if (kind == 'nvGrpSpPr' || kind == 'grpSpPr') continue;
        if (kind == 'pic') imageCount++;
        final text = shapePlainText(node);
        shapes.add(
          PptxShapeOutline(
            index: index,
            kind: kind,
            name: node
                .findAllElements('cNvPr', namespace: '*')
                .firstOrNull
                ?.getAttribute('name'),
            placeholder: node
                .findAllElements('ph', namespace: '*')
                .firstOrNull
                ?.getAttribute('type'),
            text: text.isEmpty ? null : text,
          ),
        );
        index++;
      }
    }
    final layoutPath = pkg.layoutPathOf(path);
    String? layoutName;
    if (layoutPath != null && pkg.hasPart(layoutPath)) {
      layoutName = pkg
          .xml(layoutPath)
          .findAllElements('cSld', namespace: '*')
          .firstOrNull
          ?.getAttribute('name');
    }
    final notesPath = pkg.notesPathOf(path);
    String? notes;
    if (notesPath != null && pkg.hasPart(notesPath)) {
      notes = _notesBodyText(pkg.xml(notesPath));
    }
    out.add(
      PptxSlideOutline(
        index: i,
        part: path,
        layout: layoutName,
        shapes: shapes,
        imageCount: imageCount,
        notes: (notes ?? '').isEmpty ? null : notes,
      ),
    );
  }
  return out;
}

/// 一个 shape 的纯文本（段落以 \n 连接）。
String shapePlainText(XmlElement shape) {
  final paras = <String>[];
  for (final p in shape.findAllElements('p', namespace: '*')) {
    final buf = StringBuffer();
    for (final node in p.descendants.whereType<XmlElement>()) {
      if (node.name.local == 't') buf.write(node.innerText);
      if (node.name.local == 'br') buf.write('\n');
    }
    paras.add(buf.toString());
  }
  return paras.join('\n').trim();
}

// ══════════════════ 编辑操作 ══════════════════

/// 把第 [slide] 页第 [shape] 个 shape 的文字整体换成 [text]（`\n` 分段）。
///
/// 保留原有格式：以该 shape 第一个非空 run 的 `a:rPr` 和第一段的 `a:pPr`
/// 为模板重建段落，因此字体/字号/颜色/对齐都不变。
void setShapeText(PptxPackage pkg, int slide, int shape, String text) {
  final path = pkg.slidePathAt(slide);
  final doc = pkg.xml(path);
  final target = _shapeAt(doc, shape, slide);
  final txBody = target
      .findAllElements('txBody', namespace: '*')
      .firstOrNull;
  if (txBody == null) {
    throw PptxEditException(
      '第 $slide 页第 $shape 个 shape（${target.name.local}）没有文本框，不能设置文字。'
      '先用 outline 确认目标下标。',
    );
  }
  _replaceParagraphs(txBody, text);
  pkg.setXml(path, doc);
}

/// 全文查找替换。[slide] 为 null 时作用于所有页，返回替换发生的次数。
///
/// 只在单个 `a:t` 内匹配：PowerPoint 常把一句话拆进多个 run（拼写检查、
/// 格式变化都会拆），跨 run 的文本匹配不到。要整体改写请用 [setShapeText]。
int replaceTextEverywhere(
  PptxPackage pkg,
  String find,
  String replacement, {
  int? slide,
}) {
  if (find.isEmpty) throw PptxEditException('find 不能为空字符串');
  final paths = slide == null
      ? pkg.slidePaths()
      : [pkg.slidePathAt(slide)];
  var count = 0;
  for (final path in paths) {
    final doc = pkg.xml(path);
    var changed = false;
    for (final t in doc.findAllElements('t', namespace: '*')) {
      final old = t.innerText;
      if (!old.contains(find)) continue;
      count += find.allMatches(old).length;
      t.innerText = old.replaceAll(find, replacement);
      changed = true;
    }
    if (changed) pkg.setXml(path, doc);
  }
  return count;
}

/// 设置第 [slide] 页的演讲者备注。已有 notesSlide 就改，没有就新建
/// （需要包里有 notesMaster；模板通常都有）。
void setSlideNotes(PptxPackage pkg, int slide, String text) {
  final slidePath = pkg.slidePathAt(slide);
  var notesPath = pkg.notesPathOf(slidePath);

  if (notesPath == null || !pkg.hasPart(notesPath)) {
    notesPath = _createNotesSlide(pkg, slidePath);
  }

  final doc = pkg.xml(notesPath);
  final body = _notesBodyShape(doc);
  if (body == null) {
    throw PptxEditException('notesSlide $notesPath 里找不到正文占位符，无法写备注');
  }
  final txBody = body.findAllElements('txBody', namespace: '*').firstOrNull;
  if (txBody == null) {
    throw PptxEditException('notesSlide $notesPath 的正文占位符没有文本框');
  }
  _replaceParagraphs(txBody, text);
  pkg.setXml(notesPath, doc);
}

/// 换掉第 [slide] 页第 [imageIndex] 张图片（0 基，按 z 序）的内容。
///
/// 总是写入**新的** media 部件再重指向，避免同一张图被多页共用时改一处、
/// 到处变；旧部件若因此没人引用了会被回收。
void replaceSlideImage(
  PptxPackage pkg,
  int slide,
  int imageIndex,
  Uint8List imageBytes,
  String extension,
) {
  final ext = extension.toLowerCase().replaceFirst('.', '');
  const knownTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
  };
  final ct = knownTypes[ext];
  if (ct == null) {
    throw PptxEditException(
      '不支持的图片扩展名「$ext」，可用：${knownTypes.keys.join(' / ')}',
    );
  }

  final path = pkg.slidePathAt(slide);
  final doc = pkg.xml(path);
  final pics = doc.findAllElements('pic', namespace: '*').toList();
  if (imageIndex < 0 || imageIndex >= pics.length) {
    throw PptxEditException(
      '第 $slide 页只有 ${pics.length} 张图片，imageIndex $imageIndex 越界',
    );
  }
  final blip = pics[imageIndex]
      .findAllElements('blip', namespace: '*')
      .firstOrNull;
  final rId = blip == null ? null : _rAttr(blip, 'embed');
  if (blip == null || rId == null) {
    throw PptxEditException('第 $slide 页第 $imageIndex 张图片没有 r:embed 引用，无法替换');
  }

  final oldTarget = pkg.relsOf(path)[rId];
  final oldPath = oldTarget == null
      ? null
      : _resolvePath(_dirname(path), oldTarget);

  // 新 media 部件，名字取未占用的 image{N}.{ext}。
  var n = 1;
  while (pkg.hasPart('ppt/media/image$n.$ext')) {
    n++;
  }
  final newPath = 'ppt/media/image$n.$ext';
  pkg.setPartBytes(newPath, imageBytes);
  pkg.ensureDefault(ext, ct);
  pkg.retargetRelationship(path, rId, _relativeTo(_dirname(path), newPath));

  if (oldPath != null && !_isMediaReferenced(pkg, oldPath)) {
    pkg.removePart(oldPath);
  }
}

/// 复制第 [slide] 页并插到 [at]（省略则接在被复制页后面），返回新页下标。
///
/// 连同 .rels 一起复制，所以图片/图表/版式引用都在；备注页会另存一份并把
/// 反向引用指到新页，避免两页共用一个 notesSlide。
int duplicateSlide(PptxPackage pkg, int slide, {int? at}) {
  final srcPath = pkg.slidePathAt(slide);
  final total = pkg.slidePaths().length;
  final insertAt = at ?? slide + 1;
  if (insertAt < 0 || insertAt > total) {
    throw PptxEditException('插入位置 $insertAt 越界（合法 0..$total）');
  }

  final newPath = _freeSlidePath(pkg);
  pkg.setPartBytes(newPath, pkg.partBytes(srcPath)!);
  pkg.ensureOverride(newPath, _slideCt);

  // 复制 .rels，随后单独处理 notesSlide。
  final srcRels = PptxPackage.relsPathFor(srcPath);
  if (pkg.hasPart(srcRels)) {
    pkg.setPartBytes(PptxPackage.relsPathFor(newPath), pkg.partBytes(srcRels)!);
  }
  _detachNotesCopy(pkg, newPath);

  _registerSlide(pkg, newPath, insertAt);
  return insertAt;
}

/// 删除第 [slide] 页，连带它独占的 notesSlide。至少要留一页。
/// 该页独占的 chart/media/embeddings 部件一并回收，避免留下孤儿部件
/// （包结构自检会把无引用的 chart 报错）。
void deleteSlide(PptxPackage pkg, int slide) {
  final paths = pkg.slidePaths();
  if (paths.length <= 1) {
    throw PptxEditException('pptx 至少要保留一页，不能删掉最后一页');
  }
  final path = pkg.slidePathAt(slide);
  final notesPath = pkg.notesPathOf(path);
  // 先记下这一页引用的部件，删完后回收不再被任何关系引用的。
  final slideDir = _dirname(path);
  final reclaimCandidates = <String>{
    for (final target in pkg.relsOf(path).values)
      _resolvePath(slideDir, target),
  };

  // presentation.xml：摘掉 sldId 并记下 rId。
  final presDoc = pkg.xml('ppt/presentation.xml');
  final sldIds = presDoc.findAllElements('sldId', namespace: '*').toList();
  final rId = _rAttr(sldIds[slide], 'id');
  sldIds[slide].remove();
  pkg.setXml('ppt/presentation.xml', presDoc);
  if (rId != null) pkg.removeRelationship('ppt/presentation.xml', rId);

  pkg.removePart(path);
  pkg.removePart(PptxPackage.relsPathFor(path));
  pkg.removeOverride(path);

  if (notesPath != null) {
    pkg.removePart(notesPath);
    pkg.removePart(PptxPackage.relsPathFor(notesPath));
    pkg.removeOverride(notesPath);
  }

  _reclaimOrphanParts(pkg, reclaimCandidates);
}

/// 回收 [candidates] 里不再被任何 .rels 引用的 chart/media/embeddings
/// 部件，连同它们的 .rels、Override 与嵌套引用（如图表缓存工作簿）。
/// 母版/版式等共享部件不在回收范围。
void _reclaimOrphanParts(PptxPackage pkg, Set<String> candidates) {
  for (final part in candidates) {
    final reclaimable =
        part.startsWith('ppt/charts/') ||
        part.startsWith('ppt/media/') ||
        part.startsWith('ppt/embeddings/');
    if (!reclaimable || !pkg.hasPart(part)) continue;
    if (_isMediaReferenced(pkg, part)) continue;
    final nested = <String>{};
    final relsPath = PptxPackage.relsPathFor(part);
    if (pkg.hasPart(relsPath)) {
      final dir = _dirname(part);
      for (final target in pkg.relsOf(part).values) {
        nested.add(_resolvePath(dir, target));
      }
    }
    pkg.removePart(part);
    pkg.removePart(relsPath);
    pkg.removeOverride(part);
    if (nested.isNotEmpty) _reclaimOrphanParts(pkg, nested);
  }
}

/// 把第 [from] 页移到 [to]。只重排 `sldIdLst`，部件本身不动。
void moveSlide(PptxPackage pkg, int from, int to) {
  final total = pkg.slidePaths().length;
  for (final (label, v) in [('from', from), ('to', to)]) {
    if (v < 0 || v >= total) {
      throw PptxEditException('$label $v 越界（共 $total 页，合法 0..${total - 1}）');
    }
  }
  if (from == to) return;
  final doc = pkg.xml('ppt/presentation.xml');
  final lst = doc.findAllElements('sldIdLst', namespace: '*').firstOrNull;
  if (lst == null) throw PptxEditException('presentation.xml 缺少 sldIdLst');
  final items = lst.childElements.where((e) => e.name.local == 'sldId').toList();
  final moving = items[from];
  moving.remove();
  final rest = lst.childElements
      .where((e) => e.name.local == 'sldId')
      .toList();
  if (to >= rest.length) {
    lst.children.add(moving);
  } else {
    final anchor = rest[to];
    lst.children.insert(lst.children.indexOf(anchor), moving);
  }
  pkg.setXml('ppt/presentation.xml', doc);
}

// ══════════════════ 内部实现 ══════════════════

XmlElement _shapeAt(XmlDocument slideDoc, int shape, int slide) {
  final spTree = slideDoc.findAllElements('spTree', namespace: '*').firstOrNull;
  if (spTree == null) throw PptxEditException('第 $slide 页缺少 spTree');
  final shapes = spTree.childElements
      .where((e) => e.name.local != 'nvGrpSpPr' && e.name.local != 'grpSpPr')
      .toList();
  if (shape < 0 || shape >= shapes.length) {
    throw PptxEditException(
      '第 $slide 页只有 ${shapes.length} 个 shape，下标 $shape 越界'
      '（合法 0..${shapes.length - 1}）',
    );
  }
  return shapes[shape];
}

/// 用 [text]（`\n` 分段）重建 [txBody] 的段落，沿用原有段落/run 属性。
void _replaceParagraphs(XmlElement txBody, String text) {
  final paras = txBody.childElements
      .where((e) => e.name.local == 'p')
      .toList();

  // 找一个带 run 的段落当模板；都没有就用第一段（纯空段落）。
  XmlElement? template;
  for (final p in paras) {
    if (p.childElements.any((e) => e.name.local == 'r')) {
      template = p;
      break;
    }
  }
  template ??= paras.firstOrNull;

  final lines = text.split('\n');
  final rebuilt = <XmlElement>[
    for (final line in lines) _buildParagraph(template, line),
  ];

  for (final p in paras) {
    p.remove();
  }
  txBody.children.addAll(rebuilt);
}

/// 以 [template] 为样板造一段只含 [line] 的段落。
XmlElement _buildParagraph(XmlElement? template, String line) {
  if (template == null) {
    // 整个文本框是空的：从零造 <a:p><a:r><a:t>…</a:t></a:r></a:p>。
    return XmlElement(XmlName('p', 'a'), [], [
      XmlElement(XmlName('r', 'a'), [], [
        XmlElement(XmlName('t', 'a'), [], [XmlText(line)]),
      ]),
    ]);
  }

  final p = template.copy();
  XmlElement? firstRun;
  for (final child in p.children.toList()) {
    if (child is! XmlElement) continue;
    final name = child.name.local;
    if (name == 'pPr') continue; // 保留段落属性
    if (name == 'r' && firstRun == null) {
      firstRun = child;
      continue;
    }
    // 其余 run / 换行 / 域 / endParaRPr 之外的东西一律丢掉
    if (name == 'endParaRPr') continue;
    child.remove();
  }

  if (firstRun == null) {
    final run = XmlElement(XmlName('r', 'a'), [], [
      XmlElement(XmlName('t', 'a'), [], [XmlText(line)]),
    ]);
    // 放在 pPr 之后、endParaRPr 之前
    final endPr = p.childElements
        .where((e) => e.name.local == 'endParaRPr')
        .firstOrNull;
    if (endPr != null) {
      p.children.insert(p.children.indexOf(endPr), run);
    } else {
      p.children.add(run);
    }
    return p;
  }

  // 清掉这个 run 里多余的 t/br，只留一个 t
  XmlElement? firstT;
  for (final child in firstRun.children.toList()) {
    if (child is! XmlElement) continue;
    final name = child.name.local;
    if (name == 'rPr') continue; // 保留 run 属性（字体/字号/颜色）
    if (name == 't' && firstT == null) {
      firstT = child;
      continue;
    }
    child.remove();
  }
  if (firstT == null) {
    firstT = XmlElement(XmlName('t', 'a'));
    firstRun.children.add(firstT);
  }
  firstT.innerText = line;
  return p;
}

/// 复制出的新页仍指向原页的 notesSlide——另存一份并把反向引用改到新页。
void _detachNotesCopy(PptxPackage pkg, String newSlidePath) {
  final rels = pkg.relsOf(newSlidePath);
  String? notesRid;
  String? notesTarget;
  for (final entry in rels.entries) {
    if (entry.value.contains('notesSlide')) {
      notesRid = entry.key;
      notesTarget = entry.value;
      break;
    }
  }
  if (notesRid == null || notesTarget == null) return;

  final srcNotes = _resolvePath(_dirname(newSlidePath), notesTarget);
  if (!pkg.hasPart(srcNotes)) {
    // 引用悬空：干脆摘掉，别把坏关系带进新页。
    pkg.removeRelationship(newSlidePath, notesRid);
    return;
  }

  var n = 1;
  while (pkg.hasPart('ppt/notesSlides/notesSlide$n.xml')) {
    n++;
  }
  final newNotes = 'ppt/notesSlides/notesSlide$n.xml';
  pkg.setPartBytes(newNotes, pkg.partBytes(srcNotes)!);
  pkg.ensureOverride(newNotes, _notesSlideCt);

  final srcNotesRels = PptxPackage.relsPathFor(srcNotes);
  if (pkg.hasPart(srcNotesRels)) {
    pkg.setPartBytes(
      PptxPackage.relsPathFor(newNotes),
      pkg.partBytes(srcNotesRels)!,
    );
    // notesSlide 反指幻灯片的关系要改成新页
    for (final entry in pkg.relsOf(newNotes).entries) {
      if (entry.value.contains('slides/')) {
        pkg.retargetRelationship(
          newNotes,
          entry.key,
          _relativeTo(_dirname(newNotes), newSlidePath),
        );
      }
    }
  }

  pkg.retargetRelationship(
    newSlidePath,
    notesRid,
    _relativeTo(_dirname(newSlidePath), newNotes),
  );
}

/// 把 [slidePath] 注册进 presentation.xml 的 sldIdLst 第 [insertAt] 位。
void _registerSlide(PptxPackage pkg, String slidePath, int insertAt) {
  final rId = pkg.addRelationship(
    'ppt/presentation.xml',
    _slideRelType,
    _relativeTo('ppt', slidePath),
  );

  final doc = pkg.xml('ppt/presentation.xml');
  final lst = doc.findAllElements('sldIdLst', namespace: '*').firstOrNull;
  if (lst == null) throw PptxEditException('presentation.xml 缺少 sldIdLst');

  // sldId 的 id 必须唯一且 ≥256。
  var maxId = 255;
  for (final s in lst.childElements.where((e) => e.name.local == 'sldId')) {
    final v = int.tryParse(s.getAttribute('id') ?? '');
    if (v != null && v > maxId) maxId = v;
  }

  final node = XmlElement(XmlName('sldId', lst.name.prefix), [
    XmlAttribute(XmlName('id'), '${maxId + 1}'),
    XmlAttribute(XmlName('id', 'r'), rId),
  ]);

  final items = lst.childElements
      .where((e) => e.name.local == 'sldId')
      .toList();
  if (insertAt >= items.length) {
    lst.children.add(node);
  } else {
    lst.children.insert(lst.children.indexOf(items[insertAt]), node);
  }
  pkg.setXml('ppt/presentation.xml', doc);
}

/// 建一个空的 notesSlide 并挂到 [slidePath] 上，返回它的路径。
String _createNotesSlide(PptxPackage pkg, String slidePath) {
  final hasMaster = pkg.partNames.any(
    (p) => p.startsWith('ppt/notesMasters/') && p.endsWith('.xml'),
  );
  if (!hasMaster) {
    throw PptxEditException(
      '这个 pptx 没有 notesMaster，无法新建备注页。'
      '请先在 PowerPoint 里给任意一页加一次备注，或改用 pptx_render 从 deck 重新生成。',
    );
  }

  var n = 1;
  while (pkg.hasPart('ppt/notesSlides/notesSlide$n.xml')) {
    n++;
  }
  final path = 'ppt/notesSlides/notesSlide$n.xml';

  pkg.setPartBytes(
    path,
    utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<p:notes xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
      '<p:cSld><p:spTree>'
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr/>'
      '<p:sp>'
      '<p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 1"/>'
      '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
      '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>'
      '<p:spPr/>'
      '<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r>'
      '<a:rPr lang="zh-CN" dirty="0"/><a:t></a:t></a:r></a:p></p:txBody>'
      '</p:sp>'
      '</p:spTree></p:cSld></p:notes>',
    ),
  );
  pkg.ensureOverride(path, _notesSlideCt);

  // notesSlide → slide 的反向关系
  pkg.addRelationship(
    path,
    _slideRelType,
    _relativeTo(_dirname(path), slidePath),
  );
  // slide → notesSlide
  pkg.addRelationship(
    slidePath,
    _notesSlideRelType,
    _relativeTo(_dirname(slidePath), path),
  );
  return path;
}

/// notesSlide 里的正文占位符 shape。
XmlElement? _notesBodyShape(XmlDocument notesDoc) {
  XmlElement? fallback;
  for (final sp in notesDoc.findAllElements('sp', namespace: '*')) {
    final phType = sp
        .findAllElements('ph', namespace: '*')
        .firstOrNull
        ?.getAttribute('type');
    if (phType == 'body') return sp;
    // 没有显式 body 占位符时，退而求其次用第一个有文本框的 shape。
    fallback ??= sp.findAllElements('txBody', namespace: '*').isEmpty
        ? null
        : sp;
  }
  return fallback;
}

String _notesBodyText(XmlDocument notesDoc) {
  final body = _notesBodyShape(notesDoc);
  return body == null ? '' : shapePlainText(body);
}

String _freeSlidePath(PptxPackage pkg) {
  var n = 1;
  while (pkg.hasPart('ppt/slides/slide$n.xml')) {
    n++;
  }
  return 'ppt/slides/slide$n.xml';
}

/// [mediaPath] 是否还被任何部件的 .rels 引用。
bool _isMediaReferenced(PptxPackage pkg, String mediaPath) {
  for (final name in pkg.partNames.toList()) {
    if (!name.endsWith('.rels')) continue;
    // .rels 的宿主目录：`a/b/_rels/c.xml.rels` → `a/b`
    final relsDir = _dirname(name);
    final ownerDir = relsDir.endsWith('_rels')
        ? _dirname(relsDir)
        : relsDir;
    for (final rel in pkg
        .xml(name)
        .findAllElements('Relationship', namespace: _relNs)) {
      if (rel.getAttribute('TargetMode') == 'External') continue;
      final target = rel.getAttribute('Target');
      if (target == null) continue;
      if (_resolvePath(ownerDir, target) == mediaPath) return true;
    }
  }
  return false;
}

/// [target] 相对 [baseDir] 的路径（同层直接给文件名，否则回溯 `../`）。
String _relativeTo(String baseDir, String target) {
  final base = baseDir.isEmpty ? <String>[] : baseDir.split('/');
  final dest = target.split('/');
  var common = 0;
  while (common < base.length &&
      common < dest.length - 1 &&
      base[common] == dest[common]) {
    common++;
  }
  final up = List.filled(base.length - common, '..');
  return [...up, ...dest.skip(common)].join('/');
}

String? _rAttr(XmlElement el, String local) => el.attributes
    .where((a) => a.name.local == local && a.name.prefix == 'r')
    .firstOrNull
    ?.value;

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
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

/// 图片扩展名 → 内容类型，供工具层校验用。
const Map<String, String> kPptxImageContentTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'svg': 'image/svg+xml',
};

/// 未使用，占位以便后续扩展图片关系类型常量。
const String kPptxImageRelType = _imageRelType;
