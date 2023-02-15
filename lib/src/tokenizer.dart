import 'token.dart';

class Tokenizer {
  Tokenizer(String input, String filename)
      : _input = input,
        _length = input.length,
        _filename = filename;

  final String _input;
  final int _length;
  final String _filename;

  var _offset = 0;
  var _line = 1;
  var _column = 0;

  String get locator => '($_filename:$_line:$_column)';

  Iterable<Token> tokenize() sync* {
    while (_offset < _length) {
      final c = _input.codeUnitAt(_offset++);
      _column++;

      switch (c) {
        case 0x09: // Tab
          _column = (_column + 1) & -2;
          continue;

        case 0x20: // Space
          continue;

        case 0x0d: // CR
          _column = 0;
          continue;

        case 0x0a: // LF
          _column = 0;
          ++_line;
          continue;

        case 0x21: // '!'
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x3d) {
            ++_offset;
            ++_column;
            yield Token(
                type: TokenType.notEquals, line: _line, column: _column);
          } else {
            yield Token(type: TokenType.not, line: _line, column: _column);
          }
          continue;

        case 0x25: // '%'
          yield Token(type: TokenType.remainder, line: _line, column: _column);
          continue;

        case 0x26: // '&'
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x26) {
            ++_column;
            ++_offset;
            yield Token(type: TokenType.and, line: _line, column: _column);
          } else {
            yield Token(
              type: TokenType.bitwiseAnd,
              line: _line,
              column: _column,
            );
          }
          continue;

        case 0x28: // '('
          yield Token(type: TokenType.openParen, line: _line, column: _column);
          continue;

        case 0x29: // ')'
          yield Token(type: TokenType.closeParen, line: _line, column: _column);
          continue;

        case 0x2a: // '*'
          yield Token(type: TokenType.multiply, line: _line, column: _column);
          continue;

        case 0x2b: // '+'
          yield Token(type: TokenType.plus, line: _line, column: _column);
          continue;

        case 0x2c: // ','
          yield Token(type: TokenType.comma, line: _line, column: _column);
          continue;

        case 0x2d: // '-'
          yield Token(type: TokenType.minus, line: _line, column: _column);
          continue;

        case 0x22: // Double quote
        case 0x27: // Single quote
          yield Token(
            type: TokenType.stringValue,
            line: _line,
            column: _column,
            stringValue: _parseString(closingCharacter: c),
          );
          continue;

        case 0x2f: // '/'
          if (_offset >= _length) {
            yield Token(type: TokenType.quotient, line: _line, column: _column);
            continue;
          }
          switch (_input.codeUnitAt(_offset)) {
            case 0x2a: // '/*' -- skip to first '*/'
              ++_offset;
              ++_column;

              var hasAsterisk = false;
              while (true) {
                if (_offset >= _length) {
                  throw FormatException('Unexpected end of input $locator');
                }

                final c = _input.codeUnitAt(_offset++);
                _column++;
                if (c == 0x2f && hasAsterisk) break;

                hasAsterisk = c == 0x2a;
              }
              break;

            case 0x2f: // '//' -- skip to end of line.
              ++_offset;
              ++_column;

              while (_offset < _length) {
                final c = _input.codeUnitAt(_offset);
                ++_offset;
                if (c == 0x0a) break;
              }
              _column = 0;
              ++_line;
              break;

            default:
              yield Token(
                type: TokenType.quotient,
                line: _line,
                column: _column,
              );
              break;
          }
          continue;

        case 0x3a: // ':'
          yield Token(type: TokenType.colon, line: _line, column: _column);
          continue;

        case 0x3b: // ';'
          yield Token(type: TokenType.semiColon, line: _line, column: _column);
          continue;

        case 0x3c: // '<'
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x3d) {
            ++_offset;
            ++_column;
            yield Token(
              type: TokenType.lessThanOrEqualTo,
              line: _line,
              column: _column,
            );
          } else if (_offset < _length && _input.codeUnitAt(_offset) == 0x3c) {
            ++_offset;
            ++_column;
            yield Token(
              type: TokenType.shiftLeft,
              line: _line,
              column: _column,
            );
          } else {
            yield Token(type: TokenType.lessThan, line: _line, column: _column);
          }
          continue;

        case 0x3d: // '='
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x3d) {
            ++_offset;
            ++_column;
            yield Token(type: TokenType.equals, line: _line, column: _column);
          } else {
            yield Token(type: TokenType.assign, line: _line, column: _column);
          }
          continue;

        case 0x3e: // '>'
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x3d) {
            ++_offset;
            ++_column;
            yield Token(
              type: TokenType.greaterThanOrEqualTo,
              line: _line,
              column: _column,
            );
          } else if (_offset < _length && _input.codeUnitAt(_offset) == 0x3e) {
            ++_offset;
            ++_column;
            if (_offset < _length && _input.codeUnitAt(_offset) == 0x3e) {
              ++_offset;
              ++_column;
              yield Token(
                type: TokenType.logicalShiftRight,
                line: _line,
                column: _column,
              );
            } else {
              yield Token(
                type: TokenType.arithmeticShiftRight,
                line: _line,
                column: _column,
              );
            }
          } else {
            yield Token(
              type: TokenType.greaterThan,
              line: _line,
              column: _column,
            );
          }
          continue;

        case 0x3f: // '?'
          yield Token(
            type: TokenType.questionMark,
            line: _line,
            column: _column,
          );
          continue;

        case 0x5e: // '^'
          yield Token(type: TokenType.bitwiseXor, line: _line, column: _column);
          continue;

        case 0x7b: // '{'
          yield Token(type: TokenType.openBrace, line: _line, column: _column);
          continue;

        case 0x7c: // '|'
          if (_offset < _length && _input.codeUnitAt(_offset) == 0x7c) {
            ++_column;
            ++_offset;
            yield Token(type: TokenType.or, line: _line, column: _column);
          } else {
            yield Token(
              type: TokenType.bitwiseOr,
              line: _line,
              column: _column,
            );
          }
          continue;

        case 0x7d: // '}'
          yield Token(type: TokenType.closeBrace, line: _line, column: _column);
          continue;

        default:
          if (_isDigit(c)) {
            yield _parseNumber(c);
            continue;
          }

          if (!_isInitialIdentifierCodeUnit(c)) {
            throw FormatException(
              'Unexpected value in input \'${String.fromCharCode(c)}\' '
              '$locator',
            );
          }
          final startOffset = _offset - 1;
          final startLine = _line;
          final startColumn = _column;
          while (_offset < _length) {
            if (!_isIdentifierCodeUnit(_input.codeUnitAt(_offset))) break;
            ++_offset;
            ++_column;
          }
          final identifier = _input.substring(startOffset, _offset);

          const identifierToTokenContentMap = {
            'const': TokenType.constKeyword,
            'else': TokenType.elseKeyword,
            'for': TokenType.forKeyword,
            'func': TokenType.funcKeyword,
            'if': TokenType.ifKeyword,
            'return': TokenType.returnKeyword,
            'var': TokenType.varKeyword,
          };

          final tokenContent = identifierToTokenContentMap[identifier];
          if (tokenContent != null) {
            yield Token(
              type: tokenContent,
              line: startLine,
              column: startColumn,
            );
          } else {
            yield Token(
              type: TokenType.identifier,
              line: startLine,
              column: startColumn,
              stringValue: identifier,
            );
          }
      }
    }
  }

  String _parseString({required int closingCharacter}) {
    final buffer = StringBuffer();
    while (true) {
      if (_offset >= _length) {
        throw FormatException('Unmatched quote in file $locator');
      }

      final c = _input.codeUnitAt(_offset++);
      _column++;
      if (c == closingCharacter) return buffer.toString();

      if (c == 0x0a) {
        ++_line;
        _column = 0;
      }

      // '\'
      if (c != 0x5c) {
        buffer.writeCharCode(c);
        continue;
      }

      if (_offset >= _length) {
        throw FormatException('Unexepected end of input $locator');
      }

      final v = _input.codeUnitAt(_offset++);
      _column++;

      // Support all string escapes from dart language specification 2.10 §17.7
      // https://dart.dev/guides/language/specifications/DartLangSpec-v2.10.pdf
      switch (v) {
        case 0x62: // 'b' -- Backspace
          buffer.writeCharCode(0x08);
          continue;

        case 0x66: // 'f' -- FF
          buffer.writeCharCode(0x0c);
          continue;

        case 0x6e: // 'n' -- LF
          buffer.writeCharCode(0x0a);
          continue;

        case 0x72: // 'r' -- CR
          buffer.writeCharCode(0x0d);
          continue;

        case 0x74: // 't' -- tab
          buffer.writeCharCode(0x09);
          continue;

        case 0x76: // 'v' -- vertical tab
          buffer.writeCharCode(0x0b);
          continue;

        case 0x75: // 'u'
          _parseHexCharCode(buffer, 2);
          continue;

        case 0x78: // 'x'
          _parseHexCharCode(buffer, 4);
          continue;

        default:
          // This will also take care of '$' and '\' and quotes.
          buffer.writeCharCode(v);
          continue;
      }
    }
  }

  void _parseHexCharCode(StringBuffer buffer, int defaultLength) {
    var c = _getC();
    var value = 0;
    if (c == 0x7b) {
      for (;;) {
        c = _getC();
        if (c == 0x7d) break;
        final hexValue = _hexValue(c);
        if (hexValue == -1) {
          throw FormatException(
            'Invalid hex character \'${String.fromCharCode(c)}\' $locator',
          );
        }
        value = 16 * value + hexValue;
      }
    } else {
      value = _hexValue(c);
      if (value == -1) {
        throw FormatException(
          'Invalid hex character \'${String.fromCharCode(c)}\' $locator',
        );
      }
      for (var i = 1; i < defaultLength; ++i) {
        c = _getC();
        final hexValue = _hexValue(c);
        if (hexValue == -1) {
          throw FormatException(
            'Invalid hex character \'${String.fromCharCode(c)}\' $locator',
          );
        }
        value = 16 * value + hexValue;
      }
    }

    buffer.writeCharCode(value);
  }

  Token _parseNumber(int firstCodeUnit) {
    final line = _line;
    final column = _column;

    var c = firstCodeUnit;

    var value = 0;
    var hasProcessedDigits = false;
    if (_isDigit(c)) {
      value = c - 0x30;
      while (true) {
        c = _getC();
        if (!_isDigit(c)) break;

        value = 10 * value + (c - 0x30);
        hasProcessedDigits = true;
      }
    }

    if (value == 0 && !hasProcessedDigits && (c == 0x58 || c == 0x78)) {
      // '0x' format.
      for (;;) {
        c = _getC();
        final hexValue = _hexValue(c);
        if (hexValue == -1) {
          if (c != -1) --_offset;
          return Token(
            type: TokenType.intValue,
            line: line,
            column: column,
            intValue: value,
          );
        }
        value = value * 16 + hexValue;
      }
    }

    if (c != -1) --_offset;

    return Token(
      type: TokenType.intValue,
      line: line,
      column: column,
      intValue: value,
    );
  }

  int _getC() {
    if (_offset < _length) {
      final c = _input.codeUnitAt(_offset);
      ++_offset;
      ++_column;
      return c;
    } else {
      return -1;
    }
  }

  static bool _isDigit(int c) {
    return 0x30 <= c && c <= 0x39;
  }

  static int _hexValue(int c) {
    if (0x30 <= c && c <= 0x39) return c - 0x30;
    if (0x41 <= c && c <= 0x46) return c - 0x41 + 10;
    if (0x61 <= c && c <= 0x66) return c - 0x61 + 10;
    return -1;
  }

  static bool _isInitialIdentifierCodeUnit(int c) {
    // 'A' -> 'Z'
    if (0x41 <= c && c <= 0x5a) return true;

    // 'a' -> 'z'
    if (0x61 <= c && c <= 0x7a) return true;

    return false;
  }

  static bool _isIdentifierCodeUnit(int c) {
    if (_isInitialIdentifierCodeUnit(c)) return true;

    // '_'
    if (c == 0x5f) return true;

    // '0' -> '9'
    if (0x30 <= c && c <= 0x39) return true;

    return false;
  }
}
