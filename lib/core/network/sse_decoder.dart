import 'dart:convert';

/// A single Server-Sent Event: an optional [event] name plus its [data] payload
/// (multiple `data:` lines joined with `\n`, per the SSE spec).
class SseEvent {
  const SseEvent({this.event, required this.data});

  final String? event;
  final String data;
}

/// Decodes a raw byte stream into [SseEvent]s following the SSE framing rules:
/// `field: value` lines, a leading `:` marks a comment, and a blank line
/// dispatches the accumulated event.
///
/// This is mechanical, provider-agnostic plumbing shared by every adapter — it
/// knows nothing about OpenAI / Anthropic / Gemini payload shapes (ADR-0006).
/// The byte → text decode is chunked, so multi-byte characters and event
/// boundaries that straddle network chunks are handled.
Stream<SseEvent> decodeSse(Stream<List<int>> byteStream) async* {
  var buffer = '';
  String? eventName;
  final dataLines = <String>[];

  await for (final text in utf8.decoder.bind(byteStream)) {
    buffer += text;

    int newline;
    while ((newline = buffer.indexOf('\n')) != -1) {
      var line = buffer.substring(0, newline);
      buffer = buffer.substring(newline + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }

      if (line.isEmpty) {
        if (dataLines.isNotEmpty || eventName != null) {
          yield SseEvent(event: eventName, data: dataLines.join('\n'));
        }
        eventName = null;
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue; // comment / keep-alive
      }

      final colon = line.indexOf(':');
      final String field;
      final String value;
      if (colon == -1) {
        field = line;
        value = '';
      } else {
        field = line.substring(0, colon);
        final raw = line.substring(colon + 1);
        value = raw.startsWith(' ') ? raw.substring(1) : raw;
      }

      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          dataLines.add(value);
      }
    }
  }

  // Flush a trailing event if the stream ended without a final blank line.
  if (dataLines.isNotEmpty || eventName != null) {
    yield SseEvent(event: eventName, data: dataLines.join('\n'));
  }
}
