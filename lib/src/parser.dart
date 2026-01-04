import 'ast.dart';
import 'module.dart';
import 'token.dart';
import 'tokenizer.dart';

enum _IndexType {
  none,
  globalVariableArray,
  localVariableArray,
  byte,
  halfWord,
  word,
}

class Parser {
  static const maximumGlobalVariableCount = 256;

  factory Parser({
    required String input,
    required String filename,
    required ScriptModule module,
  }) {
    return Parser.tokenizer(Tokenizer(input, filename), module);
  }

  Parser.tokenizer(Tokenizer tokenizer, this._module)
    : _tokens = tokenizer.tokenize().iterator {
    _hasNextToken = _tokens.moveNext();
    _nextToken();
  }

  final Iterator<Token> _tokens;
  final ScriptModule _module;
  final _namedValues = <String, int>{};

  var _currentToken = const Token(type: .eof, line: 0, column: 0);
  var _hasNextToken = false;

  ScriptFunction? _function;

  void _nextToken() {
    if (_hasNextToken) {
      _currentToken = _tokens.current;
      _hasNextToken = _tokens.moveNext();
    } else {
      _currentToken = const Token(type: .eof, line: 0, column: 0);
    }
  }

  Token? peekNextToken() {
    if (_hasNextToken) {
      return _tokens.current;
    } else {
      return const Token(type: .eof, line: 0, column: 0);
    }
  }

  bool _hasTokenAndAdvance(TokenType type) {
    if (_currentToken.type != type) return false;
    _nextToken();
    return true;
  }

  void _assertToken(TokenType type) {
    if (!_hasTokenAndAdvance(type)) {
      throw FormatException('Expected $type, found $_currentToken');
    }
  }

  bool _isScopeEnd(TokenType endToken) {
    if (_currentToken.type != endToken) {
      if (_currentToken.type == .eof) {
        _assertToken(endToken);
      }
      return false;
    }
    _nextToken();
    return true;
  }

  void parse() {
    parseModule();
  }

  void parseModule() {
    while (_currentToken.type != .eof) {
      switch (_currentToken.type) {
        case .constKeyword:
          _parseConst();
          break;

        case .varKeyword:
          _parseGlobalVar();
          break;

        case .funcKeyword:
          _parseFunc();
          break;

        default:
          throw FormatException(
            'Unexpected token $_currentToken. '
            'Expected \'const\', \'var\' or \'func\' declaration.',
          );
      }
    }
  }

  void _assertUniqueName(String name) {
    if (_module.constants.containsKey(name)) {
      throw Exception(
        '$name already defined as a constant near $_currentToken',
      );
    }
    if (_module.globals.containsKey(name)) {
      throw Exception('$name already defined as a global near $_currentToken');
    }
    if (_module.functions.containsKey(name)) {
      throw Exception(
        '$name already defined as a function near $_currentToken',
      );
    }
    if (_function?.locals.variables.containsKey(name) ?? false) {
      throw Exception('$name already defined as a local near $_currentToken');
    }
    if (_function?.locals.constants.containsKey(name) ?? false) {
      throw Exception(
        '$name already defined as a local constant $_currentToken',
      );
    }
  }

  void _parseConst() {
    _assertToken(.constKeyword);
    final nameToken = _currentToken;
    _assertToken(.identifier);
    final name = nameToken.stringValue!;
    _assertToken(.assign);
    final expression = _parseExpression();
    _assertToken(.semiColon);

    // Ignore constants named '_'
    if (name == '_') return;

    if (!expression.isConstant() &&
        expression is! StringValueAstNode &&
        expression is! HalfWordListAstNode) {
      throw Exception('$name not a constant value near $_currentToken');
    }

    if (expression.isEquivalentConstant(
      _module.constants[nameToken.stringValue!],
    )) {
      // Already defined to same value.
      return;
    }

    _assertUniqueName(name);

    _module.constants[nameToken.stringValue!] = expression;
  }

  void _parseGlobalVar() {
    _assertToken(.varKeyword);
    final nameToken = _currentToken;
    _assertToken(.identifier);
    final name = nameToken.stringValue!;

    int? arraySize;
    AstNode? initializer;
    if (_currentToken.type == .openSquareBracket) {
      _assertToken(.openSquareBracket);
      final arraySizeExpression = _parseExpression();
      _assertToken(.closeSquareBracket);

      if (!arraySizeExpression.isConstant()) {
        throw FormatException(
          'Array size must be a constant near $_currentToken',
        );
      }

      arraySize = arraySizeExpression.constantValue();
      if (arraySize <= 0) {
        throw FormatException(
          'Array size must be greater than 0 near $_currentToken',
        );
      }
    } else {
      if (_currentToken.type == .assign) {
        _assertToken(.assign);
        initializer = _parseExpression();
      }
    }
    _assertToken(.semiColon);

    _assertUniqueName(name);

    final index = _module.globalsUsedCount;
    final globalsUsedCount = arraySize ?? 1;

    if (index + globalsUsedCount > maximumGlobalVariableCount) {
      throw FormatException('Too many global variables near $_currentToken');
    }

    _module.globals[name] = ScriptGlobal(
      name: name,
      index: index,
      arraySize: arraySize,
      initializer: initializer,
    );
    _module.globalsUsedCount += globalsUsedCount;
  }

  void _parseFunc() {
    _assertToken(.funcKeyword);
    final nameToken = _currentToken;
    _assertToken(.identifier);
    final name = nameToken.stringValue!;
    _assertToken(.openParen);

    _assertUniqueName(name);

    final function = ScriptFunction(name);
    _module.functions[name] = function;

    final previousFunction = _function;
    _function = function;

    while (!_isScopeEnd(.closeParen)) {
      final parameterName = _currentToken;
      _assertToken(.identifier);
      function.addParameter(parameterName.stringValue!);

      if (_currentToken.type == .comma) {
        _nextToken();
      } else if (_currentToken.type != .closeParen) {
        throw FormatException(
          'Unexpected end of parameter list for $nameToken near $_currentToken',
        );
      }
    }

    if (_currentToken.type == .varKeyword) {
      _nextToken();
      function.hasReturnValue = true;
    }

    function.statements = _parseBlock();

    _function = previousFunction;
  }

  // Returns an AST node that loads the value, or nil if none available.
  AstNode? _parseIdentifier(String name) {
    // Check locals
    final localVariable = _function?.locals.variables[name];
    if (localVariable != null) {
      if (localVariable.arraySize != null) {
        return LoadLocalValueArrayAstNode(localVariable);
      }
      return LoadValueAstNode(isGlobal: false, index: localVariable.index);
    }

    // Check local constants
    final localConstant = _function?.locals.constants[name];
    if (localConstant != null) {
      return localConstant;
    }

    // Check globals
    final globalVariable = _module.globals[name];
    if (globalVariable != null) {
      final arraySize = globalVariable.arraySize;
      if (arraySize != null) {
        return LoadGlobalValueArrayAstNode(globalVariable);
      } else {
        return LoadValueAstNode(isGlobal: true, index: globalVariable.index);
      }
    }

    // Check constants
    final constantValue = _module.constants[name];
    if (constantValue != null) {
      return constantValue;
    }

    return null;
  }

  String _parseLambda() {
    final name =
        '\$anonymous_function_${_currentToken.line}_${_currentToken.column}';

    final function = ScriptFunction(name);
    _module.functions[name] = function;

    final previousFunction = _function;
    _function = function;

    if (_currentToken.type == .openParen) {
      _assertToken(.openParen);

      while (!_isScopeEnd(.closeParen)) {
        final parameterName = _currentToken;
        _assertToken(.identifier);
        function.addParameter(parameterName.stringValue!);

        if (_currentToken.type == .comma) {
          _nextToken();
        } else if (_currentToken.type != .closeParen) {
          throw FormatException(
            'Unexpected end of parameter list for $name near $_currentToken',
          );
        }
      }
    }

    if (_currentToken.type == .varKeyword) {
      _nextToken();
      function.hasReturnValue = true;
    }

    function.statements = _parseBlock();

    _function = previousFunction;

    return name;
  }

  AstNode _parseHalfWordValue() {
    final value = _parseExpression();
    if (value.isConstant()) {
      return value;
    }

    if (value is PushFunctionAddress) {
      return value;
    }

    if (value is StringValueAstNode) {
      return value;
    }

    throw FormatException(
      'Expected constant or function name for half word list elements'
      'near $_currentToken',
    );
  }

  AstNode _parseHalfWordList() {
    final values = [_parseHalfWordValue()];
    while (_currentToken.type == .comma) {
      _nextToken();
      values.add(_parseHalfWordValue());
    }
    return HalfWordListAstNode(values);
  }

  AstNode _parsePrimary() {
    // Brackets, constant or function call.
    switch (_currentToken.type) {
      case .intValue:
        final value = _currentToken.intValue!;
        _nextToken();
        return IntValueAstNode(value);

      case .stringValue:
        final value = _currentToken.stringValue!;
        _nextToken();
        return StringValueAstNode(value);

      case .hash:
        // Supports:
        //   #line
        //   #column
        //   #next("name")
        final hashToken = _currentToken;
        _nextToken();
        if (_currentToken.type != .identifier) {
          throw FormatException(
            'Expected #line, #column, #start or #next near $_currentToken',
          );
        }
        final name = _currentToken.stringValue!;
        _nextToken();
        switch (name) {
          case 'line':
            return IntValueAstNode(hashToken.line);
          case 'column':
            return IntValueAstNode(hashToken.column);
          case 'next':
            _assertToken(.openParen);
            final name = _currentToken.stringValue;
            _assertToken(.stringValue);
            _assertToken(.closeParen);
            final value = (_namedValues[name!] ?? -1) + 1;
            _namedValues[name] = value;
            return IntValueAstNode(value);
          case 'start':
            _assertToken(.openParen);
            final name = _currentToken.stringValue;
            _assertToken(.stringValue);
            _assertToken(.comma);
            final value = _parseExpression();
            _assertToken(.closeParen);
            if (!value.isConstant()) {
              throw FormatException(
                'Unable to #start $name with non-constant value',
              );
            }
            final c = value.constantValue();
            _namedValues[name!] = c;
            return IntValueAstNode(c);
          default:
            break;
        }
        throw FormatException(
          'Expected #line, #column, #start or #next near $_currentToken',
        );

      case .openHalfWordList:
        _nextToken();
        final list = _parseHalfWordList();
        _assertToken(.closeHalfWordList);
        return list;

      case .openParen:
        _nextToken();
        final expression = _parseExpression();
        _assertToken(.closeParen);
        return expression;

      case .at:
        _nextToken();
        switch (_currentToken.type) {
          case .identifier:
            final functionNameToken = _currentToken;
            final functionName = _currentToken.stringValue!;
            _nextToken();
            return PushFunctionAddress(
              token: functionNameToken,
              name: functionName,
            );

          case .varKeyword:
          case .openBrace:
          case .openParen:
            final lambdaToken = _currentToken;
            final lambdaName = _parseLambda();
            return PushFunctionAddress(token: lambdaToken, name: lambdaName);

          default:
            throw FormatException(
              'Expected name of function or inline lambda '
              'near $_currentToken',
            );
        }

      case .identifier:
        // Global, local, constant or function call
        final nameToken = _currentToken;
        final name = _currentToken.stringValue!;
        _nextToken();

        final result = _parseIdentifier(name);
        if (result != null) {
          return result;
        }

        if (_currentToken.type == .openParen) {
          // Function call.
          final parameters = _parseParameterList();
          return CallFunctionAstNode(
            token: nameToken,
            usesValue: true,
            name: name,
            parameters: parameters,
          );
        }

        // Unknown identifier!
        // If the next token is a fallback, then use that instead.
        if (_currentToken.type == .fallback) {
          _nextToken();
          return _parseExpression();
        }

        throw FormatException('Unknown identifier $name near $_currentToken');

      default:
        throw FormatException('Unexpected primary expression $_currentToken');
    }
  }

  AstNode _parseFallback() {
    final result = _parsePrimary();
    if (_currentToken.type == .fallback) {
      _nextToken();

      // Discard the expression.
      _parseExpression();
    }
    return result;
  }

  AstNode _parseSubscript() {
    var result = _parseFallback();
    if (_currentToken.type == .openSquareBracket) {
      if (result is LoadGlobalValueArrayAstNode) {
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(.closeSquareBracket);
        result = LoadIndexedGlobalValueAstNode(result, indexExpression);
      } else if (result is LoadLocalValueArrayAstNode) {
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(.closeSquareBracket);
        result = LoadIndexedLocalValueAstNode(result, indexExpression);
      }
    }

    switch (_currentToken.type) {
      case .openSquareBracket:
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(.closeSquareBracket);
        if (result is StringValueAstNode && indexExpression.isConstant()) {
          final index = indexExpression.constantValue();
          if (index < 0 || index + 1 >= result.value.length) {
            throw FormatException(
              'Index $index out of bounds near $_currentToken',
            );
          }
          return IntValueAstNode(
            result.value.codeUnitAt(indexExpression.constantValue() + 1),
          );
        }
        return ReadByteIndexAstNode(result, indexExpression);
      case .openHalfWordList:
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(.closeHalfWordList);
        return ReadHalfWordIndexAstNode(result, indexExpression);
      case .openWordList:
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(.closeWordList);
        return ReadWordIndexAstNode(result, indexExpression);
      default:
        return result;
    }
  }

  AstNode _parseCallValueFunction() {
    var result = _parseSubscript();
    while (_currentToken.type == .openParen) {
      result = CallValueAstNode(
        value: result,
        parameters: _parseParameterList(),
      );
    }
    return result;
  }

  AstNode _parseUnary() {
    switch (_currentToken.type) {
      case .minus:
        _nextToken();
        return NegateAstNode(_parseCallValueFunction());
      case .not:
        _nextToken();
        return NotAstNode(_parseCallValueFunction());
      case .bitwiseNot:
        _nextToken();
        return BitwiseNotAstNode(_parseCallValueFunction());
      case .plus:
        _nextToken();
        return _parseCallValueFunction();
      default:
        return _parseCallValueFunction();
    }
  }

  AstNode _parseFactor() {
    const factorTokenTypes = {
      TokenType.multiply,
      TokenType.quotient,
      TokenType.remainder,
    };

    var result = _parseUnary();
    while (factorTokenTypes.contains(_currentToken.type)) {
      final type = _currentToken.type;
      _nextToken();
      switch (type) {
        case .multiply:
          result = MultiplyAstNode(result, _parseUnary()).simplify();
          break;
        case .quotient:
          result = QuotientAstNode(result, _parseUnary()).simplify();
          break;
        case .remainder:
          result = RemainderAstNode(result, _parseUnary()).simplify();
          break;
        default:
          throw Exception('Internal error near $_currentToken');
      }
    }
    return result;
  }

  AstNode _parseTerm() {
    const termTokenTypes = {TokenType.plus, TokenType.minus};

    final factor = _parseFactor();
    if (!termTokenTypes.contains(_currentToken.type)) {
      return factor;
    }

    final termsExpression = TermsAstNode();
    termsExpression.terms.add(Term(.add, factor));

    while (termTokenTypes.contains(_currentToken.type)) {
      final type = _currentToken.type;
      _nextToken();
      switch (type) {
        case .plus:
          final factor = _parseFactor();
          if (factor is NegateAstNode) {
            termsExpression.terms.add(Term(.subtract, factor.statement));
          } else {
            termsExpression.terms.add(Term(.add, factor));
          }
          break;
        case .minus:
          final factor = _parseFactor();
          if (factor is NegateAstNode) {
            termsExpression.terms.add(Term(.add, factor.statement));
          } else {
            termsExpression.terms.add(Term(.subtract, factor));
          }
          break;
        default:
          throw Exception('Internal error near $_currentToken');
      }
    }

    return termsExpression.simplify();
  }

  AstNode _parseBitShift() {
    const bitShiftTokenTypes = {
      TokenType.shiftLeft,
      TokenType.arithmeticShiftRight,
      TokenType.logicalShiftRight,
    };

    var result = _parseTerm();
    while (bitShiftTokenTypes.contains(_currentToken.type)) {
      final type = _currentToken.type;
      _nextToken();
      switch (type) {
        case .shiftLeft:
          result = BitShiftLeftAstNode(result, _parseTerm()).simplify();
          break;
        case .arithmeticShiftRight:
          result = ArithmeticBitShiftRightAstNode(
            result,
            _parseTerm(),
          ).simplify();
          break;
        case .logicalShiftRight:
          result = LogicalBitShiftRightAstNode(result, _parseTerm()).simplify();
          break;
        default:
          throw Exception('Internal error near $_currentToken');
      }
    }
    return result;
  }

  AstNode _parseComparison() {
    const comparisonTokenTypes = {
      TokenType.equals,
      TokenType.notEquals,
      TokenType.lessThan,
      TokenType.lessThanOrEqualTo,
      TokenType.greaterThan,
      TokenType.greaterThanOrEqualTo,
    };

    final result = _parseBitShift();

    if (!comparisonTokenTypes.contains(_currentToken.type)) {
      return result;
    }

    final type = _currentToken.type;
    _nextToken();
    switch (type) {
      case .equals:
        return EqualsAstNode(result, _parseBitShift()).simplify();
      case .notEquals:
        return NotEqualsAstNode(result, _parseBitShift()).simplify();
      case .lessThan:
        return LessThanAstNode(result, _parseBitShift()).simplify();
      case .lessThanOrEqualTo:
        return LessThanOrEqualToAstNode(result, _parseBitShift()).simplify();
      case .greaterThan:
        return GreaterThanAstNode(result, _parseBitShift()).simplify();
      case .greaterThanOrEqualTo:
        return GreaterThanOrEqualToAstNode(result, _parseBitShift()).simplify();
      default:
        throw Exception('Internal error near $_currentToken');
    }
  }

  AstNode _parseBitwise() {
    const bitwiseTokenTypes = {
      TokenType.bitwiseAnd,
      TokenType.bitwiseOr,
      TokenType.bitwiseXor,
    };

    var result = _parseComparison();
    while (bitwiseTokenTypes.contains(_currentToken.type)) {
      final type = _currentToken.type;
      _nextToken();
      switch (type) {
        case .bitwiseAnd:
          result = BitwiseAndAstNode(result, _parseComparison()).simplify();
          break;
        case .bitwiseOr:
          result = BitwiseOrAstNode(result, _parseComparison()).simplify();
          break;
        case .bitwiseXor:
          result = BitwiseXorAstNode(result, _parseComparison()).simplify();
          break;
        default:
          throw Exception('Internal error near $_currentToken');
      }
    }
    return result;
  }

  AstNode _parseLogicalAnd() {
    var result = _parseBitwise();
    if (_currentToken.type == .and) {
      _nextToken();
      var rhs = _parseLogicalAnd();
      if (result.isConstant() && rhs.isConstant()) {
        result = LogicalAndAstNode(result, rhs).simplify();
      } else {
        result = IfStatementAstNode(
          condition: result,
          whenTrue: rhs.isBoolean() ? rhs : NotAstNode(NotAstNode(rhs)),
          whenFalse: IntValueAstNode(0),
          isBooleanExpression: true,
        );
      }
    }
    return result;
  }

  AstNode _parseLogicalOr() {
    var result = _parseLogicalAnd();
    if (_currentToken.type == .or) {
      _nextToken();
      var rhs = _parseLogicalOr();
      if (result.isConstant() && rhs.isConstant()) {
        result = LogicalOrAstNode(result, rhs).simplify();
      } else {
        result = IfStatementAstNode(
          condition: NotAstNode(result),
          whenTrue: rhs.isBoolean() ? rhs : NotAstNode(NotAstNode(rhs)),
          whenFalse: IntValueAstNode(1),
          isBooleanExpression: true,
        );
      }
    }
    return result;
  }

  AstNode _parseTernary() {
    var result = _parseLogicalOr();
    if (_currentToken.type == .questionMark) {
      _nextToken();
      var trueExpression = _parseExpression();
      _assertToken(.colon);
      var falseExpression = _parseExpression();
      result = IfStatementAstNode(
        condition: result,
        whenTrue: trueExpression,
        whenFalse: falseExpression,
      );
    }
    return result;
  }

  AstNode _parseExpression() => _parseTernary();

  AstNode _parseIfStatement() {
    _assertToken(.ifKeyword);
    _assertToken(.openParen);
    final condition = _parseExpression();
    _assertToken(.closeParen);
    final whenTrue = _parseStatement();

    if (_currentToken.type != .elseKeyword) {
      return IfStatementAstNode(condition: condition, whenTrue: whenTrue);
    }
    _nextToken();
    if (_currentToken.type == .ifKeyword) {
      return IfStatementAstNode(
        condition: condition,
        whenTrue: whenTrue,
        whenFalse: _parseIfStatement(),
      );
    }
    return IfStatementAstNode(
      condition: condition,
      whenTrue: whenTrue,
      whenFalse: _parseStatement(),
    );
  }

  AstNode _parseLocalVar() {
    _assertToken(.varKeyword);
    final nameToken = _currentToken;
    _assertToken(.identifier);
    final name = nameToken.stringValue!;
    int? arraySize;
    AstNode? initializer;
    if (_currentToken.type == .openSquareBracket) {
      _assertToken(.openSquareBracket);
      final arraySizeExpression = _parseExpression();
      _assertToken(.closeSquareBracket);

      if (!arraySizeExpression.isConstant()) {
        throw FormatException(
          'Array size must be a constant near $_currentToken',
        );
      }

      arraySize = arraySizeExpression.constantValue();
      if (arraySize <= 0) {
        throw FormatException(
          'Array size must be greater than 0 near $_currentToken',
        );
      }
    } else if (_currentToken.type == .assign) {
      _assertToken(.assign);
      initializer = _parseExpression();
    }
    _assertToken(.semiColon);

    _assertUniqueName(name);

    final index = _function!.addLocalVar(name, arraySize);
    if (initializer == null) {
      return NopAstNode();
    }

    return StoreValueAstNode(
      isGlobal: false,
      index: index,
      expression: initializer,
      isInitialization: true,
    );
  }

  void _parseLocalConst() {
    _assertToken(.constKeyword);
    final nameToken = _currentToken;
    _assertToken(.identifier);
    final name = nameToken.stringValue!;
    _assertToken(.assign);
    final expression = _parseExpression();
    _assertToken(.semiColon);

    if (!expression.isConstant() &&
        expression is! StringValueAstNode &&
        expression is! HalfWordListAstNode) {
      throw Exception('$name not a constant value near $_currentToken');
    }

    if (expression.isEquivalentConstant(
      _module.constants[nameToken.stringValue!],
    )) {
      // Already defined to same value.
      return;
    }

    if (expression.isEquivalentConstant(
      _function!.locals.constants[nameToken.stringValue!],
    )) {
      // Already defined to same value.
      return;
    }

    _assertUniqueName(name);

    _function!.addLocalConstant(name, expression);
  }

  AstNode _parseAssignment(String name, {bool requireSemicolon = true}) {
    AstNode? indexExpression;
    var indexType = _IndexType.none;

    // Index test
    switch (_currentToken.type) {
      case .openSquareBracket:
        indexType = _IndexType.byte;
        _assertToken(.openSquareBracket);
        indexExpression = _parseExpression();
        _assertToken(.closeSquareBracket);
        break;
      case .openHalfWordList:
        indexType = _IndexType.halfWord;
        _assertToken(.openHalfWordList);
        indexExpression = _parseExpression();
        _assertToken(.closeHalfWordList);
        break;
      case .openWordList:
        indexType = _IndexType.word;
        _assertToken(.openWordList);
        indexExpression = _parseExpression();
        _assertToken(.closeWordList);
        break;
      default:
        break;
    }

    final assignType = _currentToken.type;
    switch (assignType) {
      case .assign:
      case .addAssign:
      case .subtractAssign:
      case .multiplyAssign:
      case .divideAssign:
      case .remainderAssign:
      case .shiftLeftAssign:
      case .arithmeticShiftRightAssign:
      case .logicalShiftRightAssign:
      case .bitwiseAndAssign:
      case .bitwiseXorAssign:
      case .bitwiseOrAssign:
        break;
      default:
        throw FormatException(
          'Expected assignment operator, found $_currentToken',
        );
    }
    _nextToken();
    var value = _parseExpression();
    if (requireSemicolon) {
      _assertToken(.semiColon);
    }

    if (assignType != .assign) {
      if (indexExpression != null && !indexExpression.isPure()) {
        throw FormatException(
          'Only pure expressions can be used in compound assignments near $_currentToken',
        );
      }

      AstNode loadValueAstNode;
      if (_module.globals.containsKey(name)) {
        final global = _module.globals[name]!;
        if (global.arraySize != null) {
          if (indexExpression == null || indexType != _IndexType.byte) {
            throw FormatException(
              '$name is an array and requires an index near $_currentToken',
            );
          }
          indexType = _IndexType.globalVariableArray;
          loadValueAstNode = LoadIndexedGlobalValueAstNode(
            LoadGlobalValueArrayAstNode(global),
            indexExpression,
          );
        } else {
          loadValueAstNode = LoadValueAstNode(
            isGlobal: true,
            index: global.index,
          );
        }
      } else if (_function!.locals.variables.containsKey(name)) {
        final localVariable = _function!.locals.variables[name]!;
        if (localVariable.arraySize != null) {
          if (indexExpression == null || indexType != _IndexType.byte) {
            throw FormatException(
              '$name is an array and requires an index near $_currentToken',
            );
          }
          indexType = _IndexType.localVariableArray;
          loadValueAstNode = LoadIndexedLocalValueAstNode(
            LoadLocalValueArrayAstNode(localVariable),
            indexExpression,
          );
        } else {
          loadValueAstNode = LoadValueAstNode(
            isGlobal: false,
            index: localVariable.index,
          );
        }
      } else {
        throw FormatException('Unknown variable $name near $_currentToken');
      }

      if (indexExpression != null) {
        switch (indexType) {
          case _IndexType.globalVariableArray:
          case _IndexType.localVariableArray:
            break;
          case _IndexType.byte:
            loadValueAstNode = ReadByteIndexAstNode(
              loadValueAstNode,
              indexExpression,
            );
            break;
          case _IndexType.halfWord:
            loadValueAstNode = ReadHalfWordIndexAstNode(
              loadValueAstNode,
              indexExpression,
            );
            break;
          case _IndexType.word:
            loadValueAstNode = ReadWordIndexAstNode(
              loadValueAstNode,
              indexExpression,
            );
            break;
          default:
            throw FormatException('Unable to handle _IndexType.$indexType');
        }
      }

      switch (assignType) {
        case .addAssign:
          final termsExpression = TermsAstNode();
          termsExpression.terms.add(Term(.add, loadValueAstNode));
          termsExpression.terms.add(Term(.add, value));
          value = termsExpression;
          break;
        case .subtractAssign:
          final termsExpression = TermsAstNode();
          termsExpression.terms.add(Term(.add, loadValueAstNode));
          termsExpression.terms.add(Term(.subtract, value));
          value = termsExpression;
          break;
        case .multiplyAssign:
          value = MultiplyAstNode(loadValueAstNode, value);
          break;
        case .divideAssign:
          value = QuotientAstNode(loadValueAstNode, value);
          break;
        case .remainderAssign:
          value = RemainderAstNode(loadValueAstNode, value);
          break;
        case .shiftLeftAssign:
          value = BitShiftLeftAstNode(loadValueAstNode, value);
          break;
        case .arithmeticShiftRightAssign:
          value = ArithmeticBitShiftRightAstNode(loadValueAstNode, value);
          break;
        case .logicalShiftRightAssign:
          value = LogicalBitShiftRightAstNode(loadValueAstNode, value);
          break;
        case .bitwiseAndAssign:
          value = BitwiseAndAstNode(loadValueAstNode, value);
          break;
        case .bitwiseXorAssign:
          value = BitwiseXorAstNode(loadValueAstNode, value);
          break;
        case .bitwiseOrAssign:
          value = BitwiseOrAstNode(loadValueAstNode, value);
          break;
        default:
          throw UnimplementedError('Unhandled assign $assignType');
      }
    }

    // Assignment can be to global or local.
    // Find out index.
    if (_module.globals.containsKey(name)) {
      final global = _module.globals[name]!;
      if (global.arraySize != null) {
        if (indexExpression == null) {
          throw FormatException(
            '$name is an array and requires an index near $_currentToken',
          );
        }
        return StoreIndexedGlobalValueAstNode(
          globalValueIndex: global.index,
          indexExpression: indexExpression,
          expression: value,
        );
      } else if (indexExpression == null) {
        return StoreValueAstNode(
          isGlobal: true,
          index: global.index,
          expression: value,
          isInitialization: false,
        );
      } else {
        final baseValue = LoadValueAstNode(isGlobal: true, index: global.index);
        switch (indexType) {
          case _IndexType.byte:
            return WriteByteIndexAstNode(baseValue, indexExpression, value);
          case _IndexType.halfWord:
            return WriteHalfWordIndexAstNode(baseValue, indexExpression, value);
          case _IndexType.word:
            return WriteWordIndexAstNode(baseValue, indexExpression, value);
          default:
            throw FormatException('Unexpected IndexType.$indexType');
        }
      }
    } else if (_function!.locals.variables.containsKey(name)) {
      final localVariable = _function!.locals.variables[name]!;
      if (localVariable.arraySize != null) {
        if (indexExpression == null) {
          throw FormatException(
            '$name is an array and requires an index near $_currentToken',
          );
        }
        return StoreIndexedLocalValueAstNode(
          localValueIndex: localVariable.index,
          indexExpression: indexExpression,
          expression: value,
        );
      } else if (indexExpression == null) {
        return StoreValueAstNode(
          isGlobal: false,
          index: localVariable.index,
          expression: value,
          isInitialization: false,
        );
      } else {
        final baseValue = LoadValueAstNode(
          isGlobal: false,
          index: localVariable.index,
        );
        switch (indexType) {
          case _IndexType.byte:
            return WriteByteIndexAstNode(baseValue, indexExpression, value);
          case _IndexType.halfWord:
            return WriteHalfWordIndexAstNode(baseValue, indexExpression, value);
          case _IndexType.word:
            return WriteWordIndexAstNode(baseValue, indexExpression, value);
          default:
            throw FormatException('Unexpected IndexType.$indexType');
        }
      }
    } else {
      throw FormatException('Unknown variable $name near $_currentToken');
    }
  }

  List<AstNode> _parseParameterList() {
    _assertToken(.openParen);
    final result = <AstNode>[];
    while (!_isScopeEnd(.closeParen)) {
      result.add(_parseExpression());

      if (_currentToken.type == .comma) {
        _nextToken();
      } else if (_currentToken.type != .closeParen) {
        throw FormatException(
          'Unexpected end of parameter list near $_currentToken',
        );
      }
    }
    return result;
  }

  AstNode _parseAssignOrFunctionCall({bool requireSemicolon = true}) {
    final nameToken = _currentToken;
    final name = nameToken.stringValue!;

    switch (peekNextToken()?.type) {
      case .assign:
      case .addAssign:
      case .subtractAssign:
      case .multiplyAssign:
      case .divideAssign:
      case .remainderAssign:
      case .shiftLeftAssign:
      case .arithmeticShiftRightAssign:
      case .logicalShiftRightAssign:
      case .bitwiseAndAssign:
      case .bitwiseXorAssign:
      case .bitwiseOrAssign:
      case .openSquareBracket:
      case .openHalfWordList:
      case .openWordList:
        _assertToken(.identifier);
        return _parseAssignment(name, requireSemicolon: requireSemicolon);

      case .openParen:
        final isVariable = _parseIdentifier(name) != null;
        if (isVariable) {
          final value = _parseSubscript();
          final parameters = _parseParameterList();
          _assertToken(.semiColon);
          return CallValueAstNode(value: value, parameters: parameters);
        }

        _assertToken(.identifier);
        final parameters = _parseParameterList();
        _assertToken(.semiColon);
        return CallFunctionAstNode(
          token: nameToken,
          usesValue: false,
          name: name,
          parameters: parameters,
        );

      default:
        throw FormatException(
          'Expected assignment or function call, found $_currentToken',
        );
    }
  }

  AstNode _parseLambdaCall() {
    final pushFunctionAddress = _parsePrimary();
    final parameters = _parseParameterList();
    _assertToken(.semiColon);
    return CallValueAstNode(value: pushFunctionAddress, parameters: parameters);
  }

  AstNode _parseReturn() {
    _assertToken(.returnKeyword);

    AstNode? expression;
    if (_function!.hasReturnValue) {
      expression = _parseExpression();
    }

    _assertToken(.semiColon);
    return ReturnAstNode(expression);
  }

  AstNode _parseForStatement() {
    // Start a new scope.
    _assertToken(.forKeyword);
    _assertToken(.openParen);

    _function?.beginLocalScope();
    AstNode? initialization;

    switch (_currentToken.type) {
      case .varKeyword:
        initialization = _parseLocalVar();
        break;
      case .identifier:
        initialization = _parseAssignOrFunctionCall();
        break;
      case .semiColon:
        _assertToken(.semiColon);
        break;
      default:
        throw FormatException(
          'Expected if-initialization statement, found $_currentToken',
        );
    }

    AstNode? condition;
    if (_currentToken.type != .semiColon) {
      condition = _parseExpression();
    }
    _assertToken(.semiColon);

    AstNode? update;
    switch (_currentToken.type) {
      case .identifier:
        update = _parseAssignOrFunctionCall(requireSemicolon: false);
        break;
      case .closeParen:
        break;
      default:
        throw FormatException(
          'Expected if-update statement, found $_currentToken',
        );
    }

    _assertToken(.closeParen);

    final body = _parseStatement();

    _function?.endLocalScope();

    return ForStatementAstNode(
      initialization: initialization,
      condition: condition,
      update: update,
      body: body,
    );
  }

  AstNode _parseWhileStatement() {
    // Start a new scope.
    _assertToken(.whileKeyword);
    _assertToken(.openParen);

    _function?.beginLocalScope();

    final condition = _parseExpression();
    _assertToken(.closeParen);

    final body = _parseStatement();

    _function?.endLocalScope();

    return ForStatementAstNode(condition: condition, body: body);
  }

  AstNode _parseDoWhileStatement() {
    _assertToken(.doKeyword);

    final body = _parseBlock();

    _assertToken(.whileKeyword);
    _assertToken(.openParen);
    final condition = _parseExpression();
    _assertToken(.closeParen);
    _assertToken(.semiColon);

    return DoWhileStatementAstNode(condition: condition, body: body);
  }

  AstNode _parseContinueStatement() {
    _assertToken(.continueKeyword);
    _assertToken(.semiColon);

    return ContinueStatementAstNode();
  }

  AstNode _parseBreakStatement() {
    _assertToken(.breakKeyword);
    _assertToken(.semiColon);

    return BreakStatementAstNode();
  }

  AstNode _parseStatement() {
    switch (_currentToken.type) {
      case .constKeyword:
        _parseLocalConst();
        return NopAstNode();
      case .openBrace:
        return _parseBlock();
      case .ifKeyword:
        return _parseIfStatement();
      case .varKeyword:
        return _parseLocalVar();
      case .identifier:
        return _parseAssignOrFunctionCall();
      case .returnKeyword:
        return _parseReturn();
      case .forKeyword:
        return _parseForStatement();
      case .whileKeyword:
        return _parseWhileStatement();
      case .doKeyword:
        return _parseDoWhileStatement();
      case .at:
        return _parseLambdaCall();
      case .continueKeyword:
        return _parseContinueStatement();
      case .breakKeyword:
        return _parseBreakStatement();
      default:
        throw FormatException('Expected statement, found $_currentToken');
    }
  }

  StatementListAstNode _parseBlock() {
    // Start a new scope.
    _assertToken(.openBrace);
    final statements = StatementListAstNode();
    _function?.beginLocalScope();
    while (!_isScopeEnd(.closeBrace)) {
      statements.add(_parseStatement());
    }
    _function?.endLocalScope();
    return statements;
  }
}
