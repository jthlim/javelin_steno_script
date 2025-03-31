abstract class ScriptFunctionDefinition {
  String get functionName;
  int get numberOfParameters;
  int get numberOfLocals;
  bool get hasReturnValue;
}

enum ReturnType {
  none,
  boolean,
  value,
}

class InBuiltScriptFunction implements ScriptFunctionDefinition {
  const InBuiltScriptFunction(
    this.functionName,
    this.numberOfParameters,
    this.returnValue,
    this.functionIndex,
  );

  @override
  final String functionName;

  final ReturnType returnValue;

  @override
  final int numberOfParameters;

  @override
  int get numberOfLocals => 0;

  @override
  bool get hasReturnValue => returnValue != ReturnType.none;

  final int functionIndex;

  bool get isBooleanResult => returnValue == ReturnType.boolean;
}
