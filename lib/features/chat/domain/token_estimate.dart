/// Rough token estimate for a piece of text, used as a fallback when a message
/// carries no provider [Usage].
///
/// Port of the web `estimateTokens` heuristic (its `approximateTokenSize`
/// library is unavailable here, so this mirrors the JS fallback branch): each
/// CJK character counts as ~1 token and every other 4 characters count as ~1
/// token.
int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  final chineseCount = _cjk.allMatches(text).length;
  final otherCount = text.length - chineseCount;
  return chineseCount + (otherCount / 4).ceil();
}

final RegExp _cjk = RegExp(r'[\u4e00-\u9fa5]');
