import 'dart:typed_data';

import 'ast.dart';
import 'byte_code_builder.dart';

abstract class ScriptFunctionDefinition {
  String get name;
  int get numberOfParameters;
  bool get hasReturnValue;
}

enum InBuiltScriptFunction implements ScriptFunctionDefinition {
  pressScanCode('pressScanCode', 1, false, 0),
  releaseScanCode('releaseScanCode', 1, false, 1),
  tapScanCode('tapScanCode', 1, false, 2),
  isScanCodePressed('isScanCodePressed', 1, true, 3),
  pressStenoKey('pressStenoKey', 1, false, 4),
  releaseStenoKey('releaseStenoKey', 1, false, 5),
  isStenoKeyPressed('isStenoKeyPressed', 1, true, 6),
  releaseAll('releaseAll', 0, false, 7),
  isButtonPressed('isButtonPressed', 1, true, 8),
  pressAll('pressAll', 0, false, 9),
  sendText('sendText', 1, false, 10),
  console('console', 1, false, 11),
  checkButtonState('checkButtonState', 1, true, 12),
  isInPressAll('isInPressAll', 0, true, 13),
  setPixel('setPixel', 4, false, 14);

  const InBuiltScriptFunction(
    this.functionName,
    this.numberOfParameters,
    this.hasReturnValue,
    this.functionIndex,
  );

  final String functionName;

  @override
  String get name => functionName;

  @override
  final int numberOfParameters;

  @override
  final bool hasReturnValue;

  final int functionIndex;
}

class ScriptFunction implements ScriptFunctionDefinition {
  ScriptFunction(this.name);

  @override
  final String name;

  @override
  bool hasReturnValue = false;

  final parameters = <String, int>{};
  var locals = <String, int>{};
  late final StatementListAstNode statements;

  final localsStack = <Map<String, int>>[];

  @override
  int get numberOfParameters => parameters.length;

  void addParameter(String parameterName) {
    if (parameters.length >= 8) {
      throw Exception('Too many parameters for $name');
    }
    parameters[parameterName] = parameters.length;
  }

  int addLocalVar(String localName) {
    if (locals.length >= 4) {
      throw Exception('Too many local variables for $name');
    }

    // Copy on write.
    if (localsStack.isNotEmpty && localsStack.last == locals) {
      locals = {...locals};
    }

    final index = locals.length;
    locals[localName] = index;
    return index;
  }

  void beginLocalScope() {
    localsStack.add(locals);
  }

  void endLocalScope() {
    locals = localsStack.removeLast();
  }
}

class ScriptGlobal {
  ScriptGlobal({
    required this.name,
    required this.index,
    required this.initializer,
  });

  final String name;
  final int index;
  final AstNode? initializer;
}

class ScriptModule {
  final functions = <String, ScriptFunctionDefinition>{};
  final constants = <String, AstNode>{};
  final globals = <String, ScriptGlobal>{};

  Uint8List createByteCode(int buttonCount) =>
      ScriptByteCodeBuilder(this).createByteCode(buttonCount);
}
