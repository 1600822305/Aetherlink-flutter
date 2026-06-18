import 'dart:math' as math;

/// Evaluates a math expression string — the local port of `CalculatorServer`'s
/// `evaluateExpression` (`src/shared/services/mcp/servers/CalculatorServer.ts`).
///
/// Supports `+ - * / %`, parentheses, unary `+`/`-`, the constants `pi`/`e`
/// (case-insensitive) and the `Math` functions the web exposes. Matching the
/// web's `new Function('Math', ...)` eval: trigonometry is in **radians**,
/// exponentiation is `pow(x, y)` (there is no `^` operator) and `log` is the
/// natural logarithm. Throws [FormatException] on a malformed expression.
double evaluateMathExpression(String input) => _ExprParser(input).parse();

class _ExprParser {
  _ExprParser(this._src);

  final String _src;
  int _pos = 0;

  double parse() {
    final value = _parseExpr();
    _skipWs();
    if (_pos != _src.length) {
      throw const FormatException('无效的数学表达式');
    }
    return value;
  }

  double _parseExpr() {
    var value = _parseTerm();
    while (true) {
      _skipWs();
      final ch = _peek();
      if (ch == '+') {
        _pos++;
        value += _parseTerm();
      } else if (ch == '-') {
        _pos++;
        value -= _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (true) {
      _skipWs();
      final ch = _peek();
      if (ch == '*') {
        _pos++;
        value *= _parseUnary();
      } else if (ch == '/') {
        _pos++;
        value /= _parseUnary();
      } else if (ch == '%') {
        _pos++;
        value %= _parseUnary();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseUnary() {
    _skipWs();
    final ch = _peek();
    if (ch == '+') {
      _pos++;
      return _parseUnary();
    }
    if (ch == '-') {
      _pos++;
      return -_parseUnary();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipWs();
    final ch = _peek();
    if (ch == '(') {
      _pos++;
      final value = _parseExpr();
      _skipWs();
      if (_peek() != ')') throw const FormatException('括号不匹配');
      _pos++;
      return value;
    }
    if (_isDigit(ch) || ch == '.') return _parseNumber();
    if (_isIdentStart(ch)) return _parseIdent();
    throw const FormatException('无效的数学表达式');
  }

  double _parseNumber() {
    final start = _pos;
    while (_pos < _src.length && _isDigit(_src[_pos])) {
      _pos++;
    }
    if (_pos < _src.length && _src[_pos] == '.') {
      _pos++;
      while (_pos < _src.length && _isDigit(_src[_pos])) {
        _pos++;
      }
    }
    // Optional scientific-notation exponent (e.g. 1e3, 2.5E-4).
    if (_pos < _src.length && (_src[_pos] == 'e' || _src[_pos] == 'E')) {
      final save = _pos;
      _pos++;
      if (_pos < _src.length && (_src[_pos] == '+' || _src[_pos] == '-')) {
        _pos++;
      }
      if (_pos < _src.length && _isDigit(_src[_pos])) {
        while (_pos < _src.length && _isDigit(_src[_pos])) {
          _pos++;
        }
      } else {
        _pos = save; // A bare trailing 'e' is not an exponent.
      }
    }
    final text = _src.substring(start, _pos);
    final value = double.tryParse(text);
    if (value == null) throw FormatException('无效的数字: $text');
    return value;
  }

  double _parseIdent() {
    final start = _pos;
    while (_pos < _src.length && _isIdentPart(_src[_pos])) {
      _pos++;
    }
    final name = _src.substring(start, _pos).toLowerCase();
    _skipWs();
    if (_peek() == '(') {
      _pos++;
      final args = <double>[];
      _skipWs();
      if (_peek() != ')') {
        args.add(_parseExpr());
        _skipWs();
        while (_peek() == ',') {
          _pos++;
          args.add(_parseExpr());
          _skipWs();
        }
      }
      if (_peek() != ')') throw const FormatException('括号不匹配');
      _pos++;
      return _callFunction(name, args);
    }
    switch (name) {
      case 'pi':
        return math.pi;
      case 'e':
        return math.e;
    }
    throw FormatException('未知的标识符: $name');
  }

  double _callFunction(String name, List<double> args) {
    double one(double Function(double) fn) {
      if (args.length != 1) throw FormatException('$name 需要 1 个参数');
      return fn(args[0]);
    }

    switch (name) {
      case 'abs':
        return one((x) => x.abs());
      case 'acos':
        return one(math.acos);
      case 'asin':
        return one(math.asin);
      case 'atan':
        return one(math.atan);
      case 'atan2':
        if (args.length != 2) throw const FormatException('atan2 需要 2 个参数');
        return math.atan2(args[0], args[1]);
      case 'ceil':
        return one((x) => x.ceilToDouble());
      case 'cos':
        return one(math.cos);
      case 'exp':
        return one(math.exp);
      case 'floor':
        return one((x) => x.floorToDouble());
      case 'log':
      case 'ln':
        return one(math.log);
      case 'log10':
        return one((x) => math.log(x) / math.ln10);
      case 'log2':
        return one((x) => math.log(x) / math.ln2);
      case 'max':
        if (args.isEmpty) throw const FormatException('max 需要至少 1 个参数');
        return args.reduce(math.max);
      case 'min':
        if (args.isEmpty) throw const FormatException('min 需要至少 1 个参数');
        return args.reduce(math.min);
      case 'pow':
        if (args.length != 2) throw const FormatException('pow 需要 2 个参数');
        return math.pow(args[0], args[1]).toDouble();
      case 'random':
        if (args.isNotEmpty) throw const FormatException('random 不接受参数');
        return _random.nextDouble();
      case 'round':
        return one((x) => x.roundToDouble());
      case 'sin':
        return one(math.sin);
      case 'sqrt':
        return one(math.sqrt);
      case 'tan':
        return one(math.tan);
    }
    throw FormatException('未知的函数: $name');
  }

  String _peek() => _pos < _src.length ? _src[_pos] : '';

  void _skipWs() {
    while (_pos < _src.length) {
      final ch = _src[_pos];
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        _pos++;
      } else {
        break;
      }
    }
  }

  static bool _isDigit(String ch) =>
      ch.length == 1 && ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;

  static bool _isIdentStart(String ch) =>
      ch.length == 1 &&
      ((ch.compareTo('a') >= 0 && ch.compareTo('z') <= 0) ||
          (ch.compareTo('A') >= 0 && ch.compareTo('Z') <= 0) ||
          ch == '_');

  static bool _isIdentPart(String ch) => _isIdentStart(ch) || _isDigit(ch);

  static final math.Random _random = math.Random();
}
