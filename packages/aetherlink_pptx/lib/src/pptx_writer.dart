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
  final charts = <String>[];
  final slideXmls = <String>[];
  final slideRels = <String>[];

  // slide index (0-based) → notesSlide number (1-based, dense).
  final notesIndex = <int, int>{};
  for (final (i, slide) in deck.slides.indexed) {
    if (slide.notes != null) notesIndex[i] = notesIndex.length + 1;
  }

  for (final (i, slide) in deck.slides.indexed) {
    final builder = _SlideBuilder(
      deck,
      slide,
      media,
      charts,
      notesSlideNumber: notesIndex[i],
    );
    slideXmls.add(builder.buildXml());
    slideRels.add(builder.buildRelsXml());
  }

  final archive = Archive();
  void addText(String path, String content) {
    final bytes = utf8.encode(content);
    archive.add(ArchiveFile.bytes(path, bytes));
  }

  addText(
    '[Content_Types].xml',
    _contentTypesXml(slideCount, media, charts, notesCount: notesIndex.length),
  );
  addText('_rels/.rels', _rootRelsXml());
  addText('docProps/core.xml', _coreXml(deck.title));
  addText('docProps/app.xml', _appXml(slideCount));
  addText(
    'ppt/presentation.xml',
    _presentationXml(deck, hasNotes: notesIndex.isNotEmpty),
  );
  addText(
    'ppt/_rels/presentation.xml.rels',
    _presentationRelsXml(slideCount, hasNotes: notesIndex.isNotEmpty),
  );
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
  if (notesIndex.isNotEmpty) {
    addText('ppt/notesMasters/notesMaster1.xml', _notesMasterXml());
    addText(
      'ppt/notesMasters/_rels/notesMaster1.xml.rels',
      _notesMasterRelsXml(),
    );
    addText('ppt/theme/theme2.xml', _themeXml(name: 'AetherLink Notes'));
    for (final entry in notesIndex.entries) {
      final slideNumber = entry.key + 1;
      final n = entry.value;
      addText(
        'ppt/notesSlides/notesSlide$n.xml',
        _notesSlideXml(deck.slides[entry.key].notes!),
      );
      addText(
        'ppt/notesSlides/_rels/notesSlide$n.xml.rels',
        _notesSlideRelsXml(slideNumber),
      );
    }
  }
  for (var i = 0; i < charts.length; i++) {
    addText('ppt/charts/chart${i + 1}.xml', charts[i]);
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

String _contentTypesXml(
  int slideCount,
  List<_MediaEntry> media,
  List<String> charts, {
  int notesCount = 0,
}) {
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
  for (var i = 1; i <= charts.length; i++) {
    buf.write(
      '<Override PartName="/ppt/charts/chart$i.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>',
    );
  }
  if (notesCount > 0) {
    buf.write(
      '<Override PartName="/ppt/notesMasters/notesMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"/>',
    );
    buf.write(
      '<Override PartName="/ppt/theme/theme2.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    );
    for (var i = 1; i <= notesCount; i++) {
      buf.write(
        '<Override PartName="/ppt/notesSlides/notesSlide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>',
      );
    }
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

String _presentationXml(DeckDocument deck, {bool hasNotes = false}) {
  final buf = StringBuffer()
    ..write(_xmlDecl)
    ..write('<p:presentation xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">')
    ..write(
      '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>',
    );
  if (hasNotes) {
    // rId = slideCount + 2 (rId1 → slideMaster, rId2.. → slides).
    buf.write(
      '<p:notesMasterIdLst><p:notesMasterId r:id="rId${deck.slides.length + 2}"/></p:notesMasterIdLst>',
    );
  }
  buf.write('<p:sldIdLst>');
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

String _presentationRelsXml(int slideCount, {bool hasNotes = false}) {
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
  if (hasNotes) {
    buf.write(
      '<Relationship Id="rId${slideCount + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="notesMasters/notesMaster1.xml"/>',
    );
  }
  buf.write('</Relationships>');
  return buf.toString();
}

/// Minimal notes master: an empty spTree plus the required color map and
/// notes text styles, themed by theme2.xml.
String _notesMasterXml() =>
    '$_xmlDecl'
    '<p:notesMaster xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">'
    '<p:cSld>$_emptySpTree</p:cSld>'
    '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
    'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
    '<p:notesStyle/>'
    '</p:notesMaster>';

String _notesMasterRelsXml() =>
    '$_xmlDecl'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme2.xml"/>'
    '</Relationships>';

/// One notes page: a body placeholder carrying the speaker [notes] text
/// (one paragraph per line).
String _notesSlideXml(String notes) {
  final paragraphs = notes
      .split('\n')
      .map(
        (line) =>
            '<a:p><a:r><a:rPr lang="zh-CN" dirty="0"/>'
            '<a:t>${_esc(line)}</a:t></a:r></a:p>',
      )
      .join();
  return '$_xmlDecl'
      '<p:notes xmlns:a="$_nsA" xmlns:p="$_nsP" xmlns:r="$_nsR">'
      '<p:cSld><p:spTree>'
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
      '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
      '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
      '<p:sp>'
      '<p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 1"/>'
      '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
      '<p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>'
      '<p:spPr/>'
      '<p:txBody><a:bodyPr/><a:lstStyle/>$paragraphs</p:txBody>'
      '</p:sp>'
      '</p:spTree></p:cSld>'
      '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
      '</p:notes>';
}

String _notesSlideRelsXml(int slideNumber) =>
    '$_xmlDecl'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="../notesMasters/notesMaster1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="../slides/slide$slideNumber.xml"/>'
    '</Relationships>';

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
String _themeXml({String name = 'AetherLink'}) {
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
      '<a:theme xmlns:a="$_nsA" name="${_esc(name)}">'
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
  _SlideBuilder(
    this.deck,
    this.slide,
    this.media,
    this.charts, {
    this.notesSlideNumber,
  });

  final DeckDocument deck;
  final DeckSlide slide;
  final List<_MediaEntry> media;

  /// 1-based notesSlide part number when this slide has speaker notes.
  final int? notesSlideNumber;

  /// Global chart-part XMLs across the whole deck (index → chartN.xml).
  final List<String> charts;

  /// This slide's extra relationships (images/charts), in insertion order.
  final List<({String relId, String type, String target})> _extraRels = [];

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
        DeckChartElement() => _chartXml(element),
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
    for (final rel in _extraRels) {
      buf.write(
        '<Relationship Id="${rel.relId}" Type="${rel.type}" Target="${rel.target}"/>',
      );
    }
    if (notesSlideNumber != null) {
      buf.write(
        '<Relationship Id="rId${_extraRels.length + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide$notesSlideNumber.xml"/>',
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
    var avLst =
        element.kind == DeckShapeKind.roundRect && element.radius != null
        ? '<a:gd name="adj" fmla="val ${(element.radius! * 100000).round()}"/>'
        : '';
    if (element.kind == DeckShapeKind.pie) {
      // OOXML pie 角度单位是 1/60000 度，0 = 3 点钟方向顺时针。
      final start = ((element.angleStart ?? 0) % 360 * 60000).round();
      final end = ((element.angleEnd ?? 270) % 360 * 60000).round();
      avLst =
          '<a:gd name="adj1" fmla="val $start"/>'
          '<a:gd name="adj2" fmla="val $end"/>';
    }
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
    final relId = 'rId${_extraRels.length + 2}';
    _extraRels.add((
      relId: relId,
      type:
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
      target: '../media/$fileName',
    ));
    return '<p:pic>'
        '<p:nvPicPr><p:cNvPr id="$id" name="Picture $id"/>'
        '<p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
        '<p:blipFill><a:blip r:embed="$relId"/>'
        '<a:stretch><a:fillRect/></a:stretch></p:blipFill>'
        '<p:spPr>${_xfrm(element.frame)}'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        '</p:pic>';
  }

  String _chartXml(DeckChartElement element) {
    final id = _nextShapeId++;
    charts.add(_chartPartXml(element));
    final chartIndex = charts.length;
    final relId = 'rId${_extraRels.length + 2}';
    _extraRels.add((
      relId: relId,
      type:
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart',
      target: '../charts/chart$chartIndex.xml',
    ));
    final frame = element.frame;
    return '<p:graphicFrame>'
        '<p:nvGraphicFramePr><p:cNvPr id="$id" name="Chart $id"/>'
        '<p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
        '<p:xfrm><a:off x="${_emuInches(frame.x)}" y="${_emuInches(frame.y)}"/>'
        '<a:ext cx="${_emuInches(frame.w)}" cy="${_emuInches(frame.h)}"/></p:xfrm>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">'
        '<c:chart xmlns:c="$_nsC" xmlns:r="$_nsR" r:id="$relId"/>'
        '</a:graphicData></a:graphic>'
        '</p:graphicFrame>';
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

const String _nsC = 'http://schemas.openxmlformats.org/drawingml/2006/chart';

/// Office-default accent palette used when a series/point has no color.
const List<String> _chartPalette = [
  '4472C4',
  'ED7D31',
  'A5A5A5',
  'FFC000',
  '5B9BD5',
  '70AD47',
];

/// Column letter for series [index] in the cached virtual sheet (A holds
/// categories, B.. hold series values).
String _chartColumn(int index) => String.fromCharCode(0x42 + index); // B..

/// Builds one `c:chartSpace` part with cached category/value data — a fully
/// native chart PowerPoint can restyle and (re-cache aside) edit.
String _chartPartXml(DeckChartElement element) {
  final catCount = element.categories.length;
  final catRef =
      '<c:cat><c:strRef>'
      '<c:f>Sheet1!\$A\$2:\$A\$${catCount + 1}</c:f>'
      '<c:strCache><c:ptCount val="$catCount"/>'
      '${[for (final (i, cat) in element.categories.indexed) '<c:pt idx="$i"><c:v>${_esc(cat)}</c:v></c:pt>'].join()}'
      '</c:strCache></c:strRef></c:cat>';

  String valRef(DeckChartSeries series, int serIndex) {
    final col = _chartColumn(serIndex);
    return '<c:val><c:numRef>'
        '<c:f>Sheet1!\$$col\$2:\$$col\$${catCount + 1}</c:f>'
        '<c:numCache><c:formatCode>General</c:formatCode>'
        '<c:ptCount val="$catCount"/>'
        '${[for (final (i, v) in series.values.indexed) '<c:pt idx="$i"><c:v>$v</c:v></c:pt>'].join()}'
        '</c:numCache></c:numRef></c:val>';
  }

  String serTx(DeckChartSeries series, int serIndex) =>
      '<c:tx><c:strRef><c:f>Sheet1!\$${_chartColumn(serIndex)}\$1</c:f>'
      '<c:strCache><c:ptCount val="1"/>'
      '<c:pt idx="0"><c:v>${_esc(series.name)}</c:v></c:pt>'
      '</c:strCache></c:strRef></c:tx>';

  final palette = element.palette == null
      ? _chartPalette
      : [for (final c in element.palette!) c.value];

  String serColor(DeckChartSeries series, int serIndex) =>
      series.color?.value ?? palette[serIndex % palette.length];

  String catColor(int catIndex) => palette[catIndex % palette.length];

  final String plot;
  switch (element.kind) {
    case DeckChartKind.bar:
    case DeckChartKind.stackedBar:
    case DeckChartKind.horizontalBar:
      final stacked = element.kind == DeckChartKind.stackedBar;
      final horizontal = element.kind == DeckChartKind.horizontalBar;
      final sers = [
        for (final (i, s) in element.series.indexed)
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
              '${serTx(s, i)}'
              '<c:spPr><a:solidFill><a:srgbClr val="${serColor(s, i)}"/></a:solidFill></c:spPr>'
              '$catRef${valRef(s, i)}</c:ser>',
      ].join();
      plot =
          '<c:barChart><c:barDir val="${horizontal ? 'bar' : 'col'}"/>'
          '<c:grouping val="${stacked ? 'stacked' : 'clustered'}"/>'
          '<c:varyColors val="0"/>$sers'
          '<c:gapWidth val="${stacked ? 60 : 150}"/>'
          '${stacked ? '<c:overlap val="100"/>' : ''}'
          '<c:axId val="111111111"/><c:axId val="222222222"/></c:barChart>'
          '${horizontal ? _chartAxesHorizontalXml : _chartAxesXml}';
    case DeckChartKind.line:
      final sers = [
        for (final (i, s) in element.series.indexed)
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
              '${serTx(s, i)}'
              '<c:spPr><a:ln w="28575"><a:solidFill><a:srgbClr val="${serColor(s, i)}"/></a:solidFill></a:ln></c:spPr>'
              '<c:marker><c:symbol val="circle"/><c:size val="5"/></c:marker>'
              '$catRef${valRef(s, i)}<c:smooth val="0"/></c:ser>',
      ].join();
      plot =
          '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>'
          '$sers<c:marker val="1"/>'
          '<c:axId val="111111111"/><c:axId val="222222222"/></c:lineChart>'
          '$_chartAxesXml';
    case DeckChartKind.pie:
    case DeckChartKind.doughnut:
      final series = element.series.first;
      final points = [
        for (var i = 0; i < catCount; i++)
          '<c:dPt><c:idx val="$i"/><c:bubble3D val="0"/>'
              '<c:spPr><a:solidFill><a:srgbClr val="${catColor(i)}"/></a:solidFill></c:spPr></c:dPt>',
      ].join();
      final ser =
          '<c:ser><c:idx val="0"/><c:order val="0"/>'
          '${serTx(series, 0)}$points$catRef${valRef(series, 0)}</c:ser>';
      plot = element.kind == DeckChartKind.pie
          ? '<c:pieChart><c:varyColors val="1"/>$ser'
                '<c:firstSliceAng val="0"/></c:pieChart>'
          : '<c:doughnutChart><c:varyColors val="1"/>$ser'
                '<c:firstSliceAng val="0"/><c:holeSize val="55"/></c:doughnutChart>';
    case DeckChartKind.area:
      final sers = [
        for (final (i, s) in element.series.indexed)
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
              '${serTx(s, i)}'
              '<c:spPr><a:solidFill><a:srgbClr val="${serColor(s, i)}"><a:alpha val="60000"/></a:srgbClr></a:solidFill>'
              '<a:ln w="19050"><a:solidFill><a:srgbClr val="${serColor(s, i)}"/></a:solidFill></a:ln></c:spPr>'
              '$catRef${valRef(s, i)}</c:ser>',
      ].join();
      plot =
          '<c:areaChart><c:grouping val="standard"/><c:varyColors val="0"/>'
          '$sers<c:axId val="111111111"/><c:axId val="222222222"/></c:areaChart>'
          '$_chartAxesXml';
    case DeckChartKind.radar:
      final sers = [
        for (final (i, s) in element.series.indexed)
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
              '${serTx(s, i)}'
              '<c:spPr><a:ln w="25400"><a:solidFill><a:srgbClr val="${serColor(s, i)}"/></a:solidFill></a:ln></c:spPr>'
              '<c:marker><c:symbol val="circle"/><c:size val="5"/></c:marker>'
              '$catRef${valRef(s, i)}</c:ser>',
      ].join();
      plot =
          '<c:radarChart><c:radarStyle val="marker"/><c:varyColors val="0"/>'
          '$sers<c:axId val="111111111"/><c:axId val="222222222"/></c:radarChart>'
          '$_chartAxesXml';
    case DeckChartKind.scatter:
      // x 轴取自 categories：能解析为数字则用数值，否则用 1..n 序号。
      final xs = [
        for (final (i, cat) in element.categories.indexed)
          double.tryParse(cat) ?? (i + 1).toDouble(),
      ];
      final xRef =
          '<c:xVal><c:numRef>'
          '<c:f>Sheet1!\$A\$2:\$A\$${catCount + 1}</c:f>'
          '<c:numCache><c:formatCode>General</c:formatCode>'
          '<c:ptCount val="$catCount"/>'
          '${[for (final (i, x) in xs.indexed) '<c:pt idx="$i"><c:v>$x</c:v></c:pt>'].join()}'
          '</c:numCache></c:numRef></c:xVal>';
      String yRef(DeckChartSeries s, int serIndex) {
        final col = _chartColumn(serIndex);
        return '<c:yVal><c:numRef>'
            '<c:f>Sheet1!\$$col\$2:\$$col\$${catCount + 1}</c:f>'
            '<c:numCache><c:formatCode>General</c:formatCode>'
            '<c:ptCount val="$catCount"/>'
            '${[for (final (i, v) in s.values.indexed) '<c:pt idx="$i"><c:v>$v</c:v></c:pt>'].join()}'
            '</c:numCache></c:numRef></c:yVal>';
      }

      final sers = [
        for (final (i, s) in element.series.indexed)
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>'
              '${serTx(s, i)}'
              '<c:spPr><a:ln><a:noFill/></a:ln></c:spPr>'
              '<c:marker><c:symbol val="circle"/><c:size val="6"/>'
              '<c:spPr><a:solidFill><a:srgbClr val="${serColor(s, i)}"/></a:solidFill></c:spPr></c:marker>'
              '$xRef${yRef(s, i)}</c:ser>',
      ].join();
      plot =
          '<c:scatterChart><c:scatterStyle val="lineMarker"/><c:varyColors val="0"/>'
          '$sers<c:axId val="111111111"/><c:axId val="222222222"/></c:scatterChart>'
          '$_scatterAxesXml';
  }

  final textFill = element.textColor == null
      ? ''
      : '<a:solidFill><a:srgbClr val="${element.textColor!.value}"/></a:solidFill>';
  final title = element.title == null
      ? '<c:autoTitleDeleted val="1"/>'
      : '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/>'
            '<a:p><a:pPr><a:defRPr sz="1400" b="1">$textFill</a:defRPr></a:pPr>'
            '<a:r><a:t>${_esc(element.title!)}</a:t></a:r></a:p>'
            '</c:rich></c:tx><c:overlay val="0"/></c:title>'
            '<c:autoTitleDeleted val="0"/>';
  // 风格下：图表区透明融入幻灯片背景，轴/图例/标题文字用风格正文色。
  final chartSpaceProps = element.textColor == null
      ? ''
      : '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>'
            '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr>'
            '<a:defRPr>$textFill</a:defRPr></a:pPr><a:endParaRPr lang="zh-CN"/></a:p></c:txPr>';

  return '$_xmlDecl'
      '<c:chartSpace xmlns:c="$_nsC" xmlns:a="$_nsA" xmlns:r="$_nsR">'
      '<c:chart>$title'
      '<c:plotArea><c:layout/>$plot</c:plotArea>'
      '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>'
      '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/>'
      '</c:chart>$chartSpaceProps</c:chartSpace>';
}

/// Two value axes for scatter charts.
const String _scatterAxesXml =
    '<c:valAx><c:axId val="111111111"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="b"/>'
    '<c:crossAx val="222222222"/></c:valAx>'
    '<c:valAx><c:axId val="222222222"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="l"/>'
    '<c:majorGridlines/>'
    '<c:crossAx val="111111111"/></c:valAx>';

/// Axes for horizontal bar charts（类别轴在左，数值轴在底）.
const String _chartAxesHorizontalXml =
    '<c:catAx><c:axId val="111111111"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="l"/>'
    '<c:crossAx val="222222222"/></c:catAx>'
    '<c:valAx><c:axId val="222222222"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="b"/>'
    '<c:majorGridlines/>'
    '<c:crossAx val="111111111"/></c:valAx>';

/// Category (bottom) + value (left) axes shared by bar/line charts.
const String _chartAxesXml =
    '<c:catAx><c:axId val="111111111"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="b"/>'
    '<c:crossAx val="222222222"/></c:catAx>'
    '<c:valAx><c:axId val="222222222"/>'
    '<c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="l"/>'
    '<c:majorGridlines/>'
    '<c:crossAx val="111111111"/></c:valAx>';
