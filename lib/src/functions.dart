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

class const InBuiltScriptFunction(
  @override final String functionName,
  @override final int numberOfParameters,
  final ReturnType returnValue,
  final int functionIndex,
) implements ScriptFunctionDefinition {
  @override
  int get numberOfLocals => 0;

  @override
  bool get hasReturnValue => returnValue != ReturnType.none;

  bool get isBooleanResult => returnValue == ReturnType.boolean;
}
