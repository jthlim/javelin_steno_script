import 'ast.dart';
import 'module.dart';
import 'token.dart';
import 'tokenizer.dart';

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

  var _currentToken = const Token(type: TokenType.eof, line: 0, column: 0);
  var _hasNextToken = false;

  ScriptFunction? _function;

  void _nextToken() {
    if (_hasNextToken) {
      _currentToken = _tokens.current;
      _hasNextToken = _tokens.moveNext();
    } else {
      _currentToken = const Token(type: TokenType.eof, line: 0, column: 0);
    }
  }

  Token? peekNextToken() {
    if (_hasNextToken) {
      return _tokens.current;
    } else {
      return const Token(type: TokenType.eof, line: 0, column: 0);
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
      if (_currentToken.type == TokenType.eof) {
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
    while (_currentToken.type != TokenType.eof) {
      switch (_currentToken.type) {
        case TokenType.constKeyword:
          _parseConst();
          break;

        case TokenType.varKeyword:
          _parseGlobalVar();
          break;

        case TokenType.funcKeyword:
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
    _assertToken(TokenType.constKeyword);
    final nameToken = _currentToken;
    _assertToken(TokenType.identifier);
    final name = nameToken.stringValue!;
    _assertToken(TokenType.assign);
    final expression = _parseExpression();
    _assertToken(TokenType.semiColon);

    if (!expression.isConstant() && expression is! StringValueAstNode) {
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
    _assertToken(TokenType.varKeyword);
    final nameToken = _currentToken;
    _assertToken(TokenType.identifier);
    final name = nameToken.stringValue!;

    int? arraySize;
    AstNode? initializer;
    if (_currentToken.type == TokenType.openSquareBracket) {
      _assertToken(TokenType.openSquareBracket);
      final arraySizeExpression = _parseExpression();
      _assertToken(TokenType.closeSquareBracket);

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
      if (_currentToken.type == TokenType.assign) {
        _assertToken(TokenType.assign);
        initializer = _parseExpression();
      }
    }
    _assertToken(TokenType.semiColon);

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
    _assertToken(TokenType.funcKeyword);
    final nameToken = _currentToken;
    _assertToken(TokenType.identifier);
    final name = nameToken.stringValue!;
    _assertToken(TokenType.openParen);

    _assertUniqueName(name);

    final function = ScriptFunction(name);
    _module.functions[name] = function;

    final previousFunction = _function;
    _function = function;

    while (!_isScopeEnd(TokenType.closeParen)) {
      final parameterName = _currentToken;
      _assertToken(TokenType.identifier);
      function.addParameter(parameterName.stringValue!);

      if (_currentToken.type == TokenType.comma) {
        _nextToken();
      } else if (_currentToken.type != TokenType.closeParen) {
        throw FormatException(
          'Unexpected end of parameter list for $nameToken near $_currentToken',
        );
      }
    }

    if (_currentToken.type == TokenType.varKeyword) {
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
      return LoadValueAstNode(
        isGlobal: false,
        index: localVariable.index,
      );
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
        return LoadValueAstNode(
          isGlobal: true,
          index: globalVariable.index,
        );
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

    if (_currentToken.type == TokenType.openParen) {
      _assertToken(TokenType.openParen);

      while (!_isScopeEnd(TokenType.closeParen)) {
        final parameterName = _currentToken;
        _assertToken(TokenType.identifier);
        function.addParameter(parameterName.stringValue!);

        if (_currentToken.type == TokenType.comma) {
          _nextToken();
        } else if (_currentToken.type != TokenType.closeParen) {
          throw FormatException(
            'Unexpected end of parameter list for $name near $_currentToken',
          );
        }
      }
    }

    if (_currentToken.type == TokenType.varKeyword) {
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

    throw FormatException(
      'Expected constant or function name for half word list elements'
      'near $_currentToken',
    );
  }

  AstNode _parseHalfWordList() {
    final values = [_parseHalfWordValue()];
    while (_currentToken.type == TokenType.comma) {
      _nextToken();
      values.add(_parseHalfWordValue());
    }
    return HalfWordListAstNode(values);
  }

  AstNode _parsePrimary() {
    // Brackets, constant or function call.
    switch (_currentToken.type) {
      case TokenType.intValue:
        final value = _currentToken.intValue!;
        _nextToken();
        return IntValueAstNode(value);

      case TokenType.stringValue:
        final value = _currentToken.stringValue!;
        _nextToken();
        return StringValueAstNode(value);

      case TokenType.openHalfWordList:
        _nextToken();
        final list = _parseHalfWordList();
        _assertToken(TokenType.closeHalfWordList);
        return list;

      case TokenType.openParen:
        _nextToken();
        final expression = _parseExpression();
        _assertToken(TokenType.closeParen);
        return expression;

      case TokenType.at:
        _nextToken();
        switch (_currentToken.type) {
          case TokenType.identifier:
            final functionNameToken = _currentToken;
            final functionName = _currentToken.stringValue!;
            _nextToken();
            return PushFunctionAddress(
              token: functionNameToken,
              name: functionName,
            );

          case TokenType.varKeyword:
          case TokenType.openBrace:
          case TokenType.openParen:
            final lambdaToken = _currentToken;
            final lambdaName = _parseLambda();
            return PushFunctionAddress(token: lambdaToken, name: lambdaName);

          default:
            throw FormatException(
              'Expected name of function or inline lambda '
              'near $_currentToken',
            );
        }

      case TokenType.identifier:
        // Global, local, constant or function call
        final nameToken = _currentToken;
        final name = _currentToken.stringValue!;
        _nextToken();

        final result = _parseIdentifier(name);
        if (result != null) {
          return result;
        }

        if (_currentToken.type == TokenType.openParen) {
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
        if (_currentToken.type == TokenType.fallback) {
          _nextToken();
          return _parseExpression();
        }

        throw FormatException('Unknown identifier $name near $_currentToken');

      default:
        throw FormatException(
          'Unexpected primary expression $_currentToken',
        );
    }
  }

  AstNode _parseFallback() {
    final result = _parsePrimary();
    if (_currentToken.type == TokenType.fallback) {
      _nextToken();

      // Discard the expression.
      _parseExpression();
    }
    return result;
  }

  AstNode _parseSubscript() {
    var result = _parseFallback();
    if (_currentToken.type == TokenType.openSquareBracket) {
      if (result is LoadGlobalValueArrayAstNode) {
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(TokenType.closeSquareBracket);
        result = LoadIndexedGlobalValueAstNode(result, indexExpression);
      } else if (result is LoadLocalValueArrayAstNode) {
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(TokenType.closeSquareBracket);
        result = LoadIndexedLocalValueAstNode(result, indexExpression);
      }
    }

    switch (_currentToken.type) {
      case TokenType.openSquareBracket:
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(TokenType.closeSquareBracket);
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
        return ByteIndexAstNode(result, indexExpression);
      case TokenType.openHalfWordList:
        _nextToken();
        final indexExpression = _parseExpression();
        _assertToken(TokenType.closeHalfWordList);
        return HalfWordIndexAstNode(result, indexExpression);
      default:
        return result;
    }
  }

  AstNode _parseCallValueFunction() {
    var result = _parseSubscript();
    while (_currentToken.type == TokenType.openParen) {
      result =
          CallValueAstNode(value: result, parameters: _parseParameterList());
    }
    return result;
  }

  AstNode _parseUnary() {
    switch (_currentToken.type) {
      case TokenType.minus:
        _nextToken();
        return NegateAstNode(_parseCallValueFunction());
      case TokenType.not:
        _nextToken();
        return NotAstNode(_parseCallValueFunction());
      case TokenType.bitwiseNot:
        _nextToken();
        return BitwiseNotAstNode(_parseCallValueFunction());
      case TokenType.plus:
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
        case TokenType.multiply:
          result = MultiplyAstNode(result, _parseUnary()).simplify();
          break;
        case TokenType.quotient:
          result = QuotientAstNode(result, _parseUnary()).simplify();
          break;
        case TokenType.remainder:
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
    termsExpression.terms.add(Term(TermMode.add, factor));

    while (termTokenTypes.contains(_currentToken.type)) {
      final type = _currentToken.type;
      _nextToken();
      switch (type) {
        case TokenType.plus:
          termsExpression.terms.add(Term(TermMode.add, _parseFactor()));
          break;
        case TokenType.minus:
          termsExpression.terms.add(Term(TermMode.subtract, _parseFactor()));
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
        case TokenType.shiftLeft:
          result = BitShiftLeftAstNode(result, _parseTerm()).simplify();
          break;
        case TokenType.arithmeticShiftRight:
          result =
              ArithmeticBitShiftRightAstNode(result, _parseTerm()).simplify();
          break;
        case TokenType.logicalShiftRight:
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
      case TokenType.equals:
        return EqualsAstNode(result, _parseBitShift()).simplify();
      case TokenType.notEquals:
        return NotEqualsAstNode(result, _parseBitShift()).simplify();
      case TokenType.lessThan:
        return LessThanAstNode(result, _parseBitShift()).simplify();
      case TokenType.lessThanOrEqualTo:
        return LessThanOrEqualToAstNode(result, _parseBitShift()).simplify();
      case TokenType.greaterThan:
        return GreaterThanAstNode(result, _parseBitShift()).simplify();
      case TokenType.greaterThanOrEqualTo:
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
        case TokenType.bitwiseAnd:
          result = BitwiseAndAstNode(result, _parseComparison()).simplify();
          break;
        case TokenType.bitwiseOr:
          result = BitwiseOrAstNode(result, _parseComparison()).simplify();
          break;
        case TokenType.bitwiseXor:
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
    if (_currentToken.type == TokenType.and) {
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
    if (_currentToken.type == TokenType.or) {
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
    if (_currentToken.type == TokenType.questionMark) {
      _nextToken();
      var trueExpression = _parseExpression();
      _assertToken(TokenType.colon);
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
    _assertToken(TokenType.ifKeyword);
    _assertToken(TokenType.openParen);
    final condition = _parseExpression();
    _assertToken(TokenType.closeParen);
    final whenTrue = _parseStatement();

    if (_currentToken.type != TokenType.elseKeyword) {
      return IfStatementAstNode(condition: condition, whenTrue: whenTrue);
    }
    _nextToken();
    if (_currentToken.type == TokenType.ifKeyword) {
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
    _assertToken(TokenType.varKeyword);
    final nameToken = _currentToken;
    _assertToken(TokenType.identifier);
    final name = nameToken.stringValue!;
    int? arraySize;
    AstNode? initializer;
    if (_currentToken.type == TokenType.openSquareBracket) {
      _assertToken(TokenType.openSquareBracket);
      final arraySizeExpression = _parseExpression();
      _assertToken(TokenType.closeSquareBracket);

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
    } else if (_currentToken.type == TokenType.assign) {
      _assertToken(TokenType.assign);
      initializer = _parseExpression();
    }
    _assertToken(TokenType.semiColon);

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
    _assertToken(TokenType.constKeyword);
    final nameToken = _currentToken;
    _assertToken(TokenType.identifier);
    final name = nameToken.stringValue!;
    _assertToken(TokenType.assign);
    final expression = _parseExpression();
    _assertToken(TokenType.semiColon);

    if (!expression.isConstant() && expression is! StringValueAstNode) {
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
    if (_currentToken.type == TokenType.openSquareBracket) {
      _assertToken(TokenType.openSquareBracket);
      indexExpression = _parseExpression();
      _assertToken(TokenType.closeSquareBracket);
    }
    final assignType = _currentToken.type;
    switch (assignType) {
      case TokenType.assign:
      case TokenType.addAssign:
      case TokenType.subtractAssign:
      case TokenType.multiplyAssign:
      case TokenType.divideAssign:
      case TokenType.remainderAssign:
      case TokenType.shiftLeftAssign:
      case TokenType.arithmeticShiftRightAssign:
      case TokenType.logicalShiftRightAssign:
      case TokenType.bitwiseAndAssign:
      case TokenType.bitwiseXorAssign:
      case TokenType.bitwiseOrAssign:
        break;
      default:
        throw FormatException(
          'Expected assignment operator, found $_currentToken',
        );
    }
    _nextToken();
    var value = _parseExpression();
    if (requireSemicolon) {
      _assertToken(TokenType.semiColon);
    }

    if (assignType != TokenType.assign) {
      if (indexExpression != null) {
        throw FormatException(
          'Only simple assignment supports index near $_currentToken',
        );
      }
      final AstNode loadValueAstNode;
      if (_module.globals.containsKey(name)) {
        final global = _module.globals[name]!;
        if (global.arraySize != null) {
          throw FormatException(
            '$name is an array and requires an index near $_currentToken',
          );
        }
        if (indexExpression != null) {
          throw FormatException('$name is not an array near $_currentToken');
        }
        loadValueAstNode =
            LoadValueAstNode(isGlobal: true, index: global.index);
      } else if (_function!.locals.variables.containsKey(name)) {
        final localVariable = _function!.locals.variables[name]!;
        if (localVariable.arraySize != null) {
          throw FormatException(
            '$name is an array and requires an index near $_currentToken',
          );
        } else {
          if (indexExpression != null) {
            throw FormatException('$name is not an array near $_currentToken');
          }
          loadValueAstNode =
              LoadValueAstNode(isGlobal: false, index: localVariable.index);
        }
      } else {
        throw FormatException('Unknown variable $name near $_currentToken');
      }

      switch (assignType) {
        case TokenType.addAssign:
          final termsExpression = TermsAstNode();
          termsExpression.terms.add(Term(TermMode.add, loadValueAstNode));
          termsExpression.terms.add(Term(TermMode.add, value));
          value = termsExpression;
          break;
        case TokenType.subtractAssign:
          final termsExpression = TermsAstNode();
          termsExpression.terms.add(Term(TermMode.add, loadValueAstNode));
          termsExpression.terms.add(Term(TermMode.subtract, value));
          value = termsExpression;
          break;
        case TokenType.multiplyAssign:
          value = MultiplyAstNode(loadValueAstNode, value);
          break;
        case TokenType.divideAssign:
          value = QuotientAstNode(loadValueAstNode, value);
          break;
        case TokenType.remainderAssign:
          value = RemainderAstNode(loadValueAstNode, value);
          break;
        case TokenType.shiftLeftAssign:
          value = BitShiftLeftAstNode(loadValueAstNode, value);
          break;
        case TokenType.arithmeticShiftRightAssign:
          value = ArithmeticBitShiftRightAstNode(loadValueAstNode, value);
          break;
        case TokenType.logicalShiftRightAssign:
          value = LogicalBitShiftRightAstNode(loadValueAstNode, value);
          break;
        case TokenType.bitwiseAndAssign:
          value = BitwiseAndAstNode(loadValueAstNode, value);
          break;
        case TokenType.bitwiseXorAssign:
          value = BitwiseXorAstNode(loadValueAstNode, value);
          break;
        case TokenType.bitwiseOrAssign:
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
      } else {
        if (indexExpression != null) {
          throw FormatException('$name is not an array near $_currentToken');
        }
        return StoreValueAstNode(
          isGlobal: true,
          index: global.index,
          expression: value,
          isInitialization: false,
        );
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
      } else {
        if (indexExpression != null) {
          throw FormatException('$name is not an array near $_currentToken');
        }
        return StoreValueAstNode(
          isGlobal: false,
          index: localVariable.index,
          expression: value,
          isInitialization: false,
        );
      }
    } else {
      throw FormatException('Unknown variable $name near $_currentToken');
    }
  }

  List<AstNode> _parseParameterList() {
    _assertToken(TokenType.openParen);
    final result = <AstNode>[];
    while (!_isScopeEnd(TokenType.closeParen)) {
      result.add(_parseExpression());

      if (_currentToken.type == TokenType.comma) {
        _nextToken();
      } else if (_currentToken.type != TokenType.closeParen) {
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
      case TokenType.assign:
      case TokenType.addAssign:
      case TokenType.subtractAssign:
      case TokenType.multiplyAssign:
      case TokenType.divideAssign:
      case TokenType.remainderAssign:
      case TokenType.shiftLeftAssign:
      case TokenType.arithmeticShiftRightAssign:
      case TokenType.logicalShiftRightAssign:
      case TokenType.bitwiseAndAssign:
      case TokenType.bitwiseXorAssign:
      case TokenType.bitwiseOrAssign:
      case TokenType.openSquareBracket:
        _assertToken(TokenType.identifier);
        return _parseAssignment(name, requireSemicolon: requireSemicolon);

      case TokenType.openParen:
        final isVariable = _parseIdentifier(name) != null;
        if (isVariable) {
          final value = _parseSubscript();
          final parameters = _parseParameterList();
          _assertToken(TokenType.semiColon);
          return CallValueAstNode(value: value, parameters: parameters);
        }

        _assertToken(TokenType.identifier);
        final parameters = _parseParameterList();
        _assertToken(TokenType.semiColon);
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
    _assertToken(TokenType.semiColon);
    return CallValueAstNode(value: pushFunctionAddress, parameters: parameters);
  }

  AstNode _parseReturn() {
    _assertToken(TokenType.returnKeyword);

    AstNode? expression;
    if (_function!.hasReturnValue) {
      expression = _parseExpression();
    }

    _assertToken(TokenType.semiColon);
    return ReturnAstNode(expression);
  }

  AstNode _parseForStatement() {
    // Start a new scope.
    _assertToken(TokenType.forKeyword);
    _assertToken(TokenType.openParen);

    _function?.beginLocalScope();
    AstNode? initialization;

    switch (_currentToken.type) {
      case TokenType.varKeyword:
        initialization = _parseLocalVar();
        break;
      case TokenType.identifier:
        initialization = _parseAssignOrFunctionCall();
        break;
      case TokenType.semiColon:
        _assertToken(TokenType.semiColon);
        break;
      default:
        throw FormatException(
          'Expected if-initialization statement, found $_currentToken',
        );
    }

    AstNode? condition;
    if (_currentToken.type != TokenType.semiColon) {
      condition = _parseExpression();
    }
    _assertToken(TokenType.semiColon);

    AstNode? update;
    switch (_currentToken.type) {
      case TokenType.identifier:
        update = _parseAssignOrFunctionCall(requireSemicolon: false);
        break;
      case TokenType.closeParen:
        break;
      default:
        throw FormatException(
          'Expected if-update statement, found $_currentToken',
        );
    }

    _assertToken(TokenType.closeParen);

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
    _assertToken(TokenType.whileKeyword);
    _assertToken(TokenType.openParen);

    _function?.beginLocalScope();

    final condition = _parseExpression();
    _assertToken(TokenType.closeParen);

    final body = _parseStatement();

    _function?.endLocalScope();

    return ForStatementAstNode(condition: condition, body: body);
  }

  AstNode _parseDoWhileStatement() {
    _assertToken(TokenType.doKeyword);

    final body = _parseBlock();

    _assertToken(TokenType.whileKeyword);
    _assertToken(TokenType.openParen);
    final condition = _parseExpression();
    _assertToken(TokenType.closeParen);
    _assertToken(TokenType.semiColon);

    return DoWhileStatementAstNode(condition: condition, body: body);
  }

  AstNode _parseContinueStatement() {
    _assertToken(TokenType.continueKeyword);
    _assertToken(TokenType.semiColon);

    return ContinueStatementAstNode();
  }

  AstNode _parseBreakStatement() {
    _assertToken(TokenType.breakKeyword);
    _assertToken(TokenType.semiColon);

    return BreakStatementAstNode();
  }

  AstNode _parseStatement() {
    switch (_currentToken.type) {
      case TokenType.constKeyword:
        _parseLocalConst();
        return NopAstNode();
      case TokenType.openBrace:
        return _parseBlock();
      case TokenType.ifKeyword:
        return _parseIfStatement();
      case TokenType.varKeyword:
        return _parseLocalVar();
      case TokenType.identifier:
        return _parseAssignOrFunctionCall();
      case TokenType.returnKeyword:
        return _parseReturn();
      case TokenType.forKeyword:
        return _parseForStatement();
      case TokenType.whileKeyword:
        return _parseWhileStatement();
      case TokenType.doKeyword:
        return _parseDoWhileStatement();
      case TokenType.at:
        return _parseLambdaCall();
      case TokenType.continueKeyword:
        return _parseContinueStatement();
      case TokenType.breakKeyword:
        return _parseBreakStatement();
      default:
        throw FormatException('Expected statement, found $_currentToken');
    }
  }

  StatementListAstNode _parseBlock() {
    // Start a new scope.
    _assertToken(TokenType.openBrace);
    final statements = StatementListAstNode();
    _function?.beginLocalScope();
    while (!_isScopeEnd(TokenType.closeBrace)) {
      statements.add(_parseStatement());
    }
    _function?.endLocalScope();
    return statements;
  }
}
