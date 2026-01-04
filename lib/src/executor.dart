import 'module.dart';

enum ExecutionState { running, finished, timeout, error, doBreak, doContinue }

class ExecutionValue {
  const ExecutionValue(this.intValue, this.stringValue);
  const ExecutionValue.int(this.intValue) : stringValue = null;
  const ExecutionValue.string(String this.stringValue) : intValue = 0;

  final int intValue;
  final String? stringValue;

  static const zero = ExecutionValue.int(0);
  static const one = ExecutionValue.int(1);

  bool isInt() => stringValue == null;
  bool isString() => stringValue != null;

  bool isFalse() => intValue == 0 && stringValue == null;
  bool isTrue() => !isFalse();

  ExecutionValue? operator +(ExecutionValue other) {
    if (!isString()) {
      return ExecutionValue(intValue + other.intValue, other.stringValue);
    }
    if (!other.isString()) {
      return ExecutionValue(intValue + other.intValue, stringValue);
    }
    return null;
  }

  ExecutionValue? operator -(ExecutionValue other) {
    if (isString()) {
      if (other.isString()) {
        if (stringValue != other.stringValue) return null;
        return ExecutionValue.int(intValue - other.intValue);
      }
      return ExecutionValue(intValue - other.intValue, stringValue);
    }
    if (other.isString()) return null;

    return ExecutionValue.int(intValue - other.intValue);
  }
}

class ExecutionContext {
  ExecutionContext(int maximumLocalsCount, this.module)
    : locals = List.generate(
        maximumLocalsCount,
        (_) => const ExecutionValue.int(0),
      );

  var state = ExecutionState.running;

  var scriptCallDepth = 0;
  ExecutionValue? returnValue;
  final List<ExecutionValue> locals;
  final ScriptModule module;

  static const maxScriptCallDepth = 8;
}
