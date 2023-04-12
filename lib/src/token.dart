enum TokenType {
  constKeyword,
  elseKeyword,
  forKeyword,
  funcKeyword,
  ifKeyword,
  returnKeyword,
  varKeyword,
  questionMark,
  colon,
  semiColon,
  openParen,
  closeParen,
  comma,
  openBrace,
  closeBrace,
  openSquareBracket,
  closeSquareBracket,
  identifier,
  minus,
  plus,
  multiply,
  quotient,
  remainder,
  assign,
  equals,
  notEquals,
  lessThan,
  lessThanOrEqualTo,
  greaterThan,
  greaterThanOrEqualTo,
  intValue,
  stringValue,
  bitwiseOr,
  bitwiseAnd,
  bitwiseXor,
  bitwiseNot,
  not,
  and,
  or,
  eof,
  shiftLeft,
  arithmeticShiftRight,
  logicalShiftRight,
}

class Token {
  const Token({
    required this.type,
    required this.line,
    required this.column,
    this.intValue,
    this.stringValue,
  });

  final TokenType type;
  final int line;
  final int column;

  final int? intValue;
  final String? stringValue;

  @override
  int get hashCode =>
      type.hashCode ^
      line.hashCode ^
      column.hashCode ^
      (intValue?.hashCode ?? 0) ^
      (stringValue?.hashCode ?? 0);

  @override
  bool operator ==(Object other) {
    return other is Token &&
        type == other.type &&
        line == other.line &&
        column == other.column &&
        intValue == other.intValue &&
        stringValue == other.stringValue;
  }

  @override
  String toString() => "$type:$line:$column";
}
