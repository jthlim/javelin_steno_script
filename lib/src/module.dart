import 'dart:typed_data';

import 'ast.dart';
import 'byte_code_builder.dart';

abstract class ScriptFunctionDefinition {
  String get name;
  int get numberOfParameters;
  bool get hasReturnValue;
}

enum InBuiltScriptFunction implements ScriptFunctionDefinition {
  // Direct functions, using one byte opcodes.
  pressScanCode('pressScanCode', 1, false, 0, false),
  releaseScanCode('releaseScanCode', 1, false, 1, false),
  tapScanCode('tapScanCode', 1, false, 2, false),
  isScanCodePressed('isScanCodePressed', 1, true, 3, true),
  pressStenoKey('pressStenoKey', 1, false, 4, false),
  releaseStenoKey('releaseStenoKey', 1, false, 5, false),
  isStenoKeyPressed('isStenoKeyPressed', 1, true, 6, true),
  releaseAll('releaseAll', 0, false, 7, false),
  isButtonPressed('isButtonPressed', 1, true, 8, true),
  pressAll('pressAll', 0, false, 9, false),
  sendText('sendText', 1, false, 10, false),
  console('console', 1, true, 11, false),
  checkButtonState('checkButtonState', 1, true, 12, true),
  isInPressAll('isInPressAll', 0, true, 13, true),
  setRgb('setRgb', 4, false, 14, false),
  getTime('getTime', 0, true, 15, false),

  // Extended functions, using two byte 0xcc opcode.
  getLedStatus('getLedStatus', 1, true, 0x100, true),
  setGpioPin('setGpioPin', 2, false, 0x101, false),
  clearDisplay('clearDisplay', 1, false, 0x102, false),
  setAutoDraw('setAutoDraw', 2, false, 0x103, false),
  setScreenOn('setScreenOn', 2, false, 0x104, false),
  setScreenContrast('setScreenContrast', 2, false, 0x105, false),
  drawPixel('drawPixel', 3, false, 0x106, false),
  drawLine('drawLine', 5, false, 0x107, false),
  drawImage('drawImage', 4, false, 0x108, false),
  drawText('drawText', 6, false, 0x109, false),
  setDrawColor('setDrawColor', 2, false, 0x10a, false),
  drawRect('drawRect', 5, false, 0x10b, false),
  setHsv('setHsv', 4, false, 0x10c, false),
  rand('rand', 0, true, 0x10d, false),
  isUsbConnected('isUsbConnected', 0, true, 0x10e, true),
  isUsbSuspended('isUsbSuspended', 0, true, 0x10f, true),
  getParameter('getParameter', 1, true, 0x110, false),
  isConnected('isConnected', 1, true, 0x111, true),
  getActiveConnection('getActiveConnection', 0, true, 0x112, false),
  setPreferredConnection('setPreferredConnection', 3, false, 0x113, false),
  isPairConnected('isPairConnected', 1, true, 0x114, true),
  startBlePairing('startBlePairing', 0, false, 0x115, false),
  getBleProfile('getBleProfile', 0, true, 0x116, false),
  setBleProfile('setBleProfile', 1, false, 0x117, false),
  isHostSleeping('isHostSleeping', 0, true, 0x118, true),
  isPowered('isPowered', 0, true, 0x119, true),
  isCharging('isCharging', 0, true, 0x11a, true),
  getBatteryPercentage('getBatteryPercentage', 0, true, 0x11b, false);

  const InBuiltScriptFunction(
    this.functionName,
    this.numberOfParameters,
    this.hasReturnValue,
    this.functionIndex,
    this.isBooleanResult,
  ) : assert(!(hasReturnValue == false && isBooleanResult == true));

  final String functionName;

  @override
  String get name => functionName;

  @override
  final int numberOfParameters;

  @override
  final bool hasReturnValue;

  final int functionIndex;

  final bool isBooleanResult;
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
    required this.arraySize,
    required this.initializer,
  });

  final String name;
  final int index;
  final int? arraySize;
  final AstNode? initializer;
}

class ScriptModule {
  final functions = <String, ScriptFunctionDefinition>{};
  final constants = <String, AstNode>{};
  final globals = <String, ScriptGlobal>{};

  var globalsUsedCount = 0;

  Uint8List createByteCode(int buttonCount) =>
      ScriptByteCodeBuilder(this).createByteCode(buttonCount);
}
