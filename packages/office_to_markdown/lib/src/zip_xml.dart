import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_parse_exception.dart';

/// Shared zip/XML plumbing for the OOXML / EPUB converters.

Archive decodeZip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw OfficeParseException('Not a valid zip archive: $e');
  }
}

/// Reads and parses [path] from [archive], or null when the entry is absent.
/// Malformed XML throws [OfficeParseException].
XmlDocument? readXml(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) return null;
  return parseXml(readString(file), path);
}

XmlDocument parseXml(String text, String path) {
  try {
    // Strip a UTF-8 BOM — XmlDocument.parse rejects it as leading content.
    final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;
    return XmlDocument.parse(clean);
  } catch (e) {
    throw OfficeParseException('Failed to parse $path: $e');
  }
}

String readString(ArchiveFile file) =>
    utf8.decode(file.content as List<int>, allowMalformed: true);

XmlElement? childElement(XmlElement? parent, String localName) => parent
    ?.childElements
    .where((e) => e.localName == localName)
    .firstOrNull;
