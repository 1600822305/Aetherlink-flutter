// Drives find/replace over a [TextEditingController]: holds the live query,
// options and match set, and mutates the controller's selection / text. Pure
// matching lives in find_replace_engine; this is the stateful glue the editor
// binds its find bar to.

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_bar.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_engine.dart';

class FindSession {
  FindSession(this._controller, this._focus);

  final TextEditingController _controller;
  final FocusNode _focus;

  String query = '';
  FindOptions options = const FindOptions(caseSensitive: false, regex: false);
  List<TextMatch> matches = const [];
  int index = -1;

  void update(String query, FindOptions options) {
    this.query = query;
    this.options = options;
    recompute(moveToCaret: true);
  }

  void recompute({bool moveToCaret = false}) {
    matches = findMatches(
      _controller.text,
      query,
      caseSensitive: options.caseSensitive,
      regex: options.regex,
    );
    if (matches.isEmpty) {
      index = -1;
      return;
    }
    if (moveToCaret || index < 0 || index >= matches.length) {
      final caret = _controller.selection.baseOffset;
      index = nextMatchIndex(matches, caret < 0 ? 0 : caret);
      _select();
    }
  }

  void next() {
    if (matches.isEmpty) return;
    index = nextMatchIndex(matches, _controller.selection.extentOffset);
    _select();
  }

  void prev() {
    if (matches.isEmpty) return;
    index = prevMatchIndex(matches, _controller.selection.baseOffset);
    _select();
  }

  void replaceOne(String replacement) {
    if (index < 0 || index >= matches.length) return;
    final m = matches[index];
    final next = _controller.text.replaceRange(m.start, m.end, replacement);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: m.start + replacement.length),
    );
    recompute();
  }

  /// Replaces every match and returns how many were replaced.
  int replaceEverything(String replacement) {
    final res = replaceAll(
      _controller.text,
      query,
      replacement,
      caseSensitive: options.caseSensitive,
      regex: options.regex,
    );
    _controller.text = res.text;
    recompute();
    return res.replacements;
  }

  void _select() {
    if (index < 0) return;
    final m = matches[index];
    _focus.requestFocus();
    _controller.selection =
        TextSelection(baseOffset: m.start, extentOffset: m.end);
  }
}
