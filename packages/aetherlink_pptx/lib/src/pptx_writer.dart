import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'deck_document.dart';

/// Serialises [deck] into a complete, PowerPoint-openable `.pptx` package.
/// Every element is a native OOXML object (text box / shape / picture /
/// table) — fully editable after opening, never a rendered screenshot.
///
/// Pure Dart and synchronous — call inside an isolate for big decks
/// (e.g. `Isolate.run(() => buildPptxBytes(deck))`).
Uint8List buildPptxBytes(DeckDocument deck) {
  final slideCount = deck.slides.length;
  final media = <_MediaEntry>[];
  final slideXmls = <String>[];
  final slideRels = <String>[];

  for (final slide in deck.slides) {
    final builder = _SlideBuilder(deck, slide, media);
    slideXmls.add(builder.buildXml());
    slideRels.add(builder.buildRelsXml());
  }

  final archive = Archive();
  void addText(String path, String content) {
    final bytes = utf8.encode(content);
    archive.add(ArchiveFile.bytes(path, bytes));
  }

  addText('[Content_Types].xml', _contentTypesXml(slideCount, media));
  addText('_rels/.rels', _rootRelsXml());
  addText('docProps/core.xml', _coreXml(deck.title));
  addText('docProps/app.xml', _appXml(slideCount));
  addText('ppt/presentation.xml', _presentationXml(deck));
  addText('ppt/_rels/presentation.xml.rels', _presentationRelsXml(slideCount));
  addText('ppt/slideMasters/slideMaster1.xml', _slideMasterXml());
  addText(
    'ppt/slideMasters/_rels/slideMaster1.xml.rels',
    _slideMasterRelsXml(),
  );
  addText('ppt/slideLayouts/slideLayout1.xml', _slideLayoutXml());
  addText(
    'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
    _slideLayoutRelsXml(),
  );
  addText('ppt/theme/theme1.xml', _themeXml());
  for (var i = 0; i < slideCount; i++) {
    addText('ppt/slides/slide${i + 1}.xml', slideXmls[i]);
    addText('ppt/slides/_rels/slide${i + 1}.xml.rels', slideRels[i]);
  }
  for (final entry in media) {
    // Images are already compressed — store them raw instead of re-deflating.
    archive.add(
      ArchiveFile.bytes('ppt/media/${entry.fileName}', entry.bytes)
        ..compression = CompressionType.none,
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class _MediaEntry {
  _MediaEntry(this.fileName, this.format, this.bytes);

  final String fileName;
  final String format; // 'png' | 'jpeg'
  final Uint8List bytes;
}

int _emuInches(double inches) => (inches * 914400).round();

int _emuPoints(double points) => (points * 12700).round();

/// Font size in hundredths of a point, floored to OOXML's minimum of 100.
int _sizeHundredths(double points) {
  final v = (points * 100).round();
  return v < 100 ? 100 : v;
}

String _esc(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const String _nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const String _nsP =
    'http://schemas.openxmlformats.org/presentationml/2006/main';
const String _nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const String _xmlDecl =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

String _contentTypesXml(int slideCount, List<_MediaEntry> media) {
  final buf = StringBuffer()
    ..write(_xmlDecl)
    ..write(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    )
    ..write(
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    )
    ..write('<Default Extension="xml" ContentType="application/xml"/>');
  if (media.any((m) => m.format == 'png')) {
    buf.write('<Default Extension="png" ContentType="image/png"/>');
  }
  if (media.any((m) => m.format == 'jpeg')) {
    buf.write('<Default Extension="jpeg" ContentType="image/jpeg"/>');
  }
  buf
    ..write(
      '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    )
    ..write(
      '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
    )
    ..write(
      '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
    )
    ..write(
      '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    );
  for (var i = 1; i <= slideCount; i++) {
    buf.write(
      '<Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    );
  }
  buf
    ..write(
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
    )
    ..write(
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
    )
    ..write('</Types>');
  return buf.toString();
}

String _rootRelsXml() =>
    '$_xmlDecl'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

String _coreXml(String? title) {
  final now = DateTime.now().toUtc().toIso8601String().split('.').first;
  return '$_xmlDecl'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_esc(title ?? '')}</dc:title>'
      '<dc:creator>AetherLink</dc:creator>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">${now}Z</dcterms:modified>'
      '</cp:coreProperties>';
}

String _appXml(int slideCount) =>
    '$_xmlDecl'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>AetherLink</Application>'
    '<Slides>$slideCount</Slides>'
    '</Properties>';

String _presentationXml(DeckDocument deck) {
  final buf = StringBuffer()
    ..write(_xmlDecl)
    ..write('<p:presentation xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">')
    ..write(
      '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>',
    )
    ..write('<p:sldIdLst>');
  for (var i = 0; i < deck.slides.length; i++) {
    buf.write('<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>');
  }
  buf
    ..write('</p:sldIdLst>')
    ..write(
      '<p:sldSz cx="${deck.layout.widthEmu}" cy="${deck.layout.heightEmu}"/>',
    )
    ..write(
      '<p:notesSz cx="${deck.layout.heightEmu}" cy="${deck.layout.widthEmu}"/>',
    )
    ..write('</p:presentation>');
  return buf.toString();
}

String _presentationRelsXml(int slideCount) {
  final buf = StringBuffer()
    ..write(_xmlDecl)
    ..write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    )
    ..write(
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
    );
  for (var i = 0; i < slideCount; i++) {
    buf.write(
      '<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>',
    );
  }
  buf.write('</Relationships>');
  return buf.toString();
}

const String _emptySpTree =
    '<p:spTree>'
    '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
    '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
    '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
    '</p:spTree>';

String _slideMasterXml() =>
    '$_xmlDecl'
    '<p:sldMaster xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">'
    '<p:cSld>'
    '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
    '$_emptySpTree'
    '</p:cSld>'
    '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
    'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
    '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
    '<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>'
    '</p:sldMaster>';

String _slideMasterRelsXml() =>
    '$_xmlDecl'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>'
    '</Relationships>';

String _slideLayoutXml() =>
    '$_xmlDecl'
    '<p:sldLayout xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR" type="blank">'
    '<p:cSld name="Blank">$_emptySpTree</p:cSld>'
    '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
    '</p:sldLayout>';

String _slideLayoutRelsXml() =>
    '$_xmlDecl'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>'
    '</Relationships>';

/// A minimal but schema-complete Office theme (clrScheme + fontScheme +
/// fmtScheme with the required 3-entry style lists).
String _themeXml() {
  const fill =
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
      '<a:gradFill rotWithShape="1"><a:gsLst>'
      '<a:gs pos="0"><a:schemeClr val="phClr"/></a:gs>'
      '<a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs>'
      '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>'
      '<a:gradFill rotWithShape="1"><a:gsLst>'
      '<a:gs pos="0"><a:schemeClr val="phClr"/></a:gs>'
      '<a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs>'
      '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>';
  const lines =
      '<a:ln w="6350" cap="flat" cmpd="sng" algn="ctr">'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
      '<a:ln w="12700" cap="flat" cmpd="sng" algn="ctr">'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
      '<a:ln w="19050" cap="flat" cmpd="sng" algn="ctr">'
      '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>';
  const effects =
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>'
      '<a:effectStyle><a:effectLst/></a:effectStyle>';
  return '$_xmlDecl'
      '<a:theme xmlns:a="$_nsA" name="AetherLink">'
      '<a:themeElements>'
      '<a:clrScheme name="AetherLink">'
      '<a:dk1><a:srgbClr val="000000"/></a:dk1>'
      '<a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>'
      '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
      '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
      '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
      '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
      '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
      '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
      '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
      '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
      '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
      '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
      '</a:clrScheme>'
      '<a:fontScheme name="AetherLink">'
      '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface="微软雅黑"/><a:cs typeface=""/></a:majorFont>'
      '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface="微软雅黑"/><a:cs typeface=""/></a:minorFont>'
      '</a:fontScheme>'
      '<a:fmtScheme name="AetherLink">'
      '<a:fillStyleLst>$fill</a:fillStyleLst>'
      '<a:lnStyleLst>$lines</a:lnStyleLst>'
      '<a:effectStyleLst>$effects</a:effectStyleLst>'
      '<a:bgFillStyleLst>$fill</a:bgFillStyleLst>'
      '</a:fmtScheme>'
      '</a:themeElements>'
      '</a:theme>';
}

/// Builds one slide part plus its rels; appends embedded images to [media].
class _SlideBuilder {
  _SlideBuilder(this.deck, this.slide, this.media);

  final DeckDocument deck;
  final DeckSlide slide;
  final List<_MediaEntry> media;

  /// r:embed ids used by this slide's images, in insertion order.
  final List<({String relId, String fileName})> _imageRels = [];

  int _nextShapeId = 2;

  String buildXml() {
    final buf = StringBuffer()
      ..write(_xmlDecl)
      ..write('<p:sld xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">')
      ..write('<p:cSld>');
    final bg = slide.background;
    if (bg != null) {
      buf.write(
        '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="${bg.value}"/></a:solidFill>'
        '<a:effectLst/></p:bgPr></p:bg>',
      );
    }
    buf
      ..write('<p:spTree>')
      ..write(
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>',
      )
      ..write(
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>',
      );
    for (final element in slide.elements) {
      buf.write(switch (element) {
        DeckTextElement() => _textXml(element),
        DeckShapeElement() => _shapeXml(element),
        DeckImageElement() => _imageXml(element),
        DeckTableElement() => _tableXml(element),
      });
    }
    buf
      ..write('</p:spTree></p:cSld>')
      ..write('<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>')
      ..write('</p:sld>');
    return buf.toString();
  }

  String buildRelsXml() {
    final buf = StringBuffer()
      ..write(_xmlDecl)
      ..write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      )
      ..write(
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>',
      );
    for (final rel in _imageRels) {
      buf.write(
        '<Relationship Id="${rel.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/${rel.fileName}"/>',
      );
    }
    buf.write('</Relationships>');
    return buf.toString();
  }

  String _xfrm(DeckFrame frame) =>
      '<a:xfrm><a:off x="${_emuInches(frame.x)}" y="${_emuInches(frame.y)}"/>'
      '<a:ext cx="${_emuInches(frame.w)}" cy="${_emuInches(frame.h)}"/></a:xfrm>';

  String _solidFill(DeckColor color, {int transparency = 0}) {
    final alpha = transparency > 0
        ? '<a:alpha val="${(100 - transparency) * 1000}"/>'
        : '';
    return '<a:solidFill><a:srgbClr val="${color.value}">$alpha</a:srgbClr></a:solidFill>';
  }

  String _runXml(DeckTextRun run) {
    final props = StringBuffer('<a:rPr lang="zh-CN"');
    if (run.size != null) props.write(' sz="${_sizeHundredths(run.size!)}"');
    if (run.bold) props.write(' b="1"');
    if (run.italic) props.write(' i="1"');
    props.write(' dirty="0">');
    if (run.color != null) props.write(_solidFill(run.color!));
    if (run.font != null) {
      final face = _esc(run.font!);
      props.write('<a:latin typeface="$face"/><a:ea typeface="$face"/>');
    }
    props.write('</a:rPr>');
    return '<a:r>$props<a:t>${_esc(run.text)}</a:t></a:r>';
  }

  String _paragraphXml(DeckParagraph paragraph, {double? lineSpacing}) {
    final props = StringBuffer('<a:pPr');
    if (paragraph.bullet) {
      final level = paragraph.indentLevel;
      final marL = 342900 * (level + 1);
      props.write(' marL="$marL" indent="-342900"');
      if (level > 0) props.write(' lvl="$level"');
    }
    final align = paragraph.align;
    if (align == 'center') props.write(' algn="ctr"');
    if (align == 'right') props.write(' algn="r"');
    props.write('>');
    if (lineSpacing != null) {
      props.write(
        '<a:lnSpc><a:spcPct val="${(lineSpacing * 100000).round()}"/></a:lnSpc>',
      );
    }
    props.write(
      paragraph.bullet
          ? '<a:buFont typeface="Arial"/><a:buChar char="•"/>'
          : '<a:buNone/>',
    );
    props.write('</a:pPr>');
    final runs = paragraph.runs.map(_runXml).join();
    return '<a:p>$props$runs</a:p>';
  }

  String _textXml(DeckTextElement element) {
    final id = _nextShapeId++;
    final anchor = switch (element.valign) {
      'middle' => 'ctr',
      'bottom' => 'b',
      _ => 't',
    };
    final fill = element.fill == null
        ? '<a:noFill/>'
        : _solidFill(element.fill!);
    final paragraphs = element.paragraphs
        .map((p) => _paragraphXml(p, lineSpacing: element.lineSpacing))
        .join();
    return '<p:sp>'
        '<p:nvSpPr><p:cNvPr id="$id" name="TextBox $id"/>'
        '<p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
        '<p:spPr>${_xfrm(element.frame)}'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>$fill</p:spPr>'
        '<p:txBody>'
        '<a:bodyPr wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" anchor="$anchor"/>'
        '<a:lstStyle/>$paragraphs</p:txBody>'
        '</p:sp>';
  }

  String _shapeXml(DeckShapeElement element) {
    final id = _nextShapeId++;
    final avLst =
        element.kind == DeckShapeKind.roundRect && element.radius != null
        ? '<a:gd name="adj" fmla="val ${(element.radius! * 100000).round()}"/>'
        : '';
    final fill = element.fill == null
        ? '<a:noFill/>'
        : _solidFill(element.fill!, transparency: element.fillTransparency);
    final line = element.lineColor == null
        ? (element.kind == DeckShapeKind.line ? '<a:ln/>' : '')
        : '<a:ln w="${_emuPoints(element.lineWidth ?? 1)}">'
              '${_solidFill(element.lineColor!)}</a:ln>';
    return '<p:sp>'
        '<p:nvSpPr><p:cNvPr id="$id" name="Shape $id"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
        '<p:spPr>${_xfrm(element.frame)}'
        '<a:prstGeom prst="${element.kind.preset}"><a:avLst>$avLst</a:avLst></a:prstGeom>'
        '$fill$line</p:spPr>'
        '<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:buNone/></a:pPr></a:p></p:txBody>'
        '</p:sp>';
  }

  String _imageXml(DeckImageElement element) {
    final id = _nextShapeId++;
    final format = detectImageFormat(element.bytes)!;
    final fileName = 'image${media.length + 1}.$format';
    media.add(_MediaEntry(fileName, format, element.bytes));
    final relId = 'rId${_imageRels.length + 2}';
    _imageRels.add((relId: relId, fileName: fileName));
    return '<p:pic>'
        '<p:nvPicPr><p:cNvPr id="$id" name="Picture $id"/>'
        '<p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
        '<p:blipFill><a:blip r:embed="$relId"/>'
        '<a:stretch><a:fillRect/></a:stretch></p:blipFill>'
        '<p:spPr>${_xfrm(element.frame)}'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        '</p:pic>';
  }

  String _tableXml(DeckTableElement element) {
    final id = _nextShapeId++;
    final frame = element.frame;
    final colWidths =
        element.colWidths ??
        List.filled(element.columnCount, frame.w / element.columnCount);
    final rowHeightEmu = _emuInches(frame.h / element.rows.length);
    final border = element.borderColor;
    final borderXml = border == null
        ? ''
        : [
            for (final side in ['lnL', 'lnR', 'lnT', 'lnB'])
              '<a:$side w="12700" cap="flat">${_solidFill(border)}</a:$side>',
          ].join();

    final buf = StringBuffer()
      ..write('<p:graphicFrame>')
      ..write(
        '<p:nvGraphicFramePr><p:cNvPr id="$id" name="Table $id"/>'
        '<p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>',
      )
      ..write(
        '<p:xfrm><a:off x="${_emuInches(frame.x)}" y="${_emuInches(frame.y)}"/>'
        '<a:ext cx="${_emuInches(frame.w)}" cy="${_emuInches(frame.h)}"/></p:xfrm>',
      )
      ..write(
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">',
      )
      ..write('<a:tbl><a:tblPr/><a:tblGrid>');
    for (final w in colWidths) {
      buf.write('<a:gridCol w="${_emuInches(w)}"/>');
    }
    buf.write('</a:tblGrid>');
    for (final (rowIndex, row) in element.rows.indexed) {
      final isHeader = rowIndex == 0 && element.headerFill != null;
      buf.write('<a:tr h="$rowHeightEmu">');
      for (final cell in row) {
        final align = switch (cell.align) {
          'center' => ' algn="ctr"',
          'right' => ' algn="r"',
          _ => '',
        };
        final runs = cell.runs.map((r) {
          final styled =
              isHeader && element.headerColor != null && r.color == null
              ? DeckTextRun(
                  text: r.text,
                  bold: r.bold,
                  italic: r.italic,
                  size: r.size,
                  color: element.headerColor,
                  font: r.font,
                )
              : r;
          return _runXml(styled);
        }).join();
        final cellFill = cell.fill ?? (isHeader ? element.headerFill : null);
        buf
          ..write('<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>')
          ..write('<a:p><a:pPr$align><a:buNone/></a:pPr>$runs</a:p>')
          ..write('</a:txBody><a:tcPr>')
          ..write(borderXml)
          ..write(cellFill == null ? '' : _solidFill(cellFill))
          ..write('</a:tcPr></a:tc>');
      }
      buf.write('</a:tr>');
    }
    buf.write('</a:tbl></a:graphicData></a:graphic></p:graphicFrame>');
    return buf.toString();
  }
}
