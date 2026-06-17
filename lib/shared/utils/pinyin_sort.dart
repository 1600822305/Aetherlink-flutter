import 'package:lpinyin/lpinyin.dart';

/// A pinyin-aware sort key for [text], the port of the web's
/// `tinyPinyin.convertToPinyin(name, '', true)` used by the assistant list's
/// 按拼音升序/降序排列.
///
/// Chinese characters are converted to their toneless pinyin (no separators);
/// non-Chinese text passes through unchanged. The result is lower-cased so the
/// comparison is case-insensitive, matching the web's `localeCompare`.
String pinyinSortKey(String text) {
  final pinyin = PinyinHelper.getPinyinE(
    text,
    separator: '',
    defPinyin: '#',
    format: PinyinFormat.WITHOUT_TONE,
  );
  return pinyin.toLowerCase();
}
