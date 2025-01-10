import 'package:javelin_steno_script/src/token.dart';
import 'package:javelin_steno_script/src/tokenizer.dart';
import 'package:test/test.dart';

void main() {
  group(Tokenizer, () {
    test('should tokenize simple tokens', () {
      final result = Tokenizer(',:;< <= = == != > >=?{}()', '').tokenize();

      expect(
        result.toList().map((token) => token.type),
        [
          TokenType.comma,
          TokenType.colon,
          TokenType.semiColon,
          TokenType.lessThan,
          TokenType.lessThanOrEqualTo,
          TokenType.assign,
          TokenType.equals,
          TokenType.notEquals,
          TokenType.greaterThan,
          TokenType.greaterThanOrEqualTo,
          TokenType.questionMark,
          TokenType.openBrace,
          TokenType.closeBrace,
          TokenType.openParen,
          TokenType.closeParen,
        ],
      );
    });

    test('should tokenize words', () {
      final result = Tokenizer('const var func test', '').tokenize();

      expect(
        result.toList(),
        const [
          Token(type: TokenType.constKeyword, line: 1, column: 1),
          Token(type: TokenType.varKeyword, line: 1, column: 7),
          Token(type: TokenType.funcKeyword, line: 1, column: 11),
          Token(
            type: TokenType.identifier,
            line: 1,
            column: 16,
            stringValue: 'test',
          ),
        ],
      );
    });

    test('should tokenize character constants', () {
      final result = Tokenizer('\'a\' \'\\\\\' \'\\n\'', '').tokenize();

      expect(
        result.toList().map((token) => token.intValue),
        const [0x61, 0x5c, 0x0a],
      );
    });

    test('should tokenize hex values correctly', () {
      final result = Tokenizer('0xff 0x10000', '').tokenize();
      expect(
        result.toList().map((token) => token.intValue),
        const [255, 65536],
      );
    });

    test('should tokenize numbers correctly', () {
      final result = Tokenizer(
        '0 1 12 0x123',
        '',
      ).tokenize();

      expect(
        result.toList().map((token) => token.intValue),
        const [0, 1, 12, 0x123],
      );
    });

    test('should ignore comments', () {
      final result = Tokenizer(
        'const /* something */ myValue // false\n 1',
        '',
      ).tokenize();

      expect(
        result.toList(),
        [
          const Token(type: TokenType.constKeyword, line: 1, column: 1),
          const Token(
            type: TokenType.identifier,
            line: 1,
            column: 23,
            stringValue: 'myValue',
          ),
          const Token(
            type: TokenType.intValue,
            line: 2,
            column: 2,
            intValue: 1,
          ),
        ],
      );
    });
  });
}
