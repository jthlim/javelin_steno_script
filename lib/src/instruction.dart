// spellchecker: words retz retnz

import 'dart:collection';
import 'dart:typed_data';

import 'package:javelin_steno_script/src/ast.dart';

import 'byte_code_builder.dart';
import 'functions.dart';
import 'string_data.dart';

enum ScriptOpcode {
  pushConstantBegin(0),
  pushConstantEnd(0x3b),
  pushBytes1U(0x3c),
  pushBytes2S(0x3d),
  pushBytes3S(0x3e),
  pushBytes4(0x3f),
  loadGlobalBegin(0x40),
  loadGlobalEnd(0x45),
  loadGlobalValue(0x46),
  loadGlobalIndex(0x47),
  storeGlobalBegin(0x48),
  storeGlobalEnd(0x4d),
  storeGlobalValue(0x4e),
  storeGlobalIndex(0x4f),
  loadLocalBegin(0x50),
  loadLocalEnd(0x5d),
  loadLocalValue(0x5e),
  loadLocalIndex(0x5f),
  storeLocalBegin(0x60),
  storeLocalEnd(0x6d),
  storeLocalValue(0x6e),
  storeLocalIndex(0x6f),
  operatorBegin(0x70),
  operatorEnd(0x8f),
  callInternalFunction(0x90),
  callFunction(0x91),
  ret(0x92),
  pop(0x93),
  enterFunction(0x94),
  callValue(0x95),
  jumpValue(0x96),
  retIfZero(0x97),
  retIfNotZero(0x98),
  jumpShortBegin(0xa0),
  jumpShortEnd(0xbe),
  jumpLong(0xbf),
  jumpIfZeroShortBegin(0xc0),
  jumpIfZeroShortEnd(0xde),
  jumpIfZeroLong(0xdf),
  jumpIfNotZeroShortBegin(0xe0),
  jumpIfNotZeroShortEnd(0xfe),
  jumpIfNotZeroLong(0xff);

  const ScriptOpcode(this.value);

  final int value;
}

enum ScriptOperatorOpcode {
  not(0x0, true),
  negative(0x1, false),
  multiply(0x2, false),
  quotient(0x3, false),
  remainder(0x4, false),
  add(0x5, false),
  subtract(0x6, false),
  equals(0x7, true),
  notEquals(0x8, true),
  lessThan(0x9, true),
  lessThanOrEqualTo(0xa, true),
  greaterThan(0xb, true),
  greaterThanOrEqualTo(0xc, true),
  bitwiseAnd(0xd, false),
  bitwiseOr(0xe, false),
  bitwiseXor(0xf, false),
  logicalAnd(0x10, true),
  logicalOr(0x11, true),
  shiftLeft(0x12, false),
  arithmeticShiftRight(0x13, false),
  logicalShiftRight(0x14, false),
  byteLookup(0x15, false),
  wordLookup(0x16, false),
  increment(0x17, false),
  decrement(0x18, false),
  halfWordLookup(0x19, false),
  ;

  const ScriptOperatorOpcode(int value, this.isBooleanResult)
      : value = value + 0x70; // ScriptOpcodeValue.operatorBegin.value

  static const _opposites = {
    equals: notEquals,
    notEquals: equals,
    lessThan: greaterThanOrEqualTo,
    greaterThanOrEqualTo: lessThan,
    greaterThan: lessThanOrEqualTo,
    lessThanOrEqualTo: greaterThan,
  };

  final int value;
  final bool isBooleanResult;

  ScriptOperatorOpcode? get opposite => _opposites[this];
}

sealed class ScriptInstruction extends LinkedListEntry<ScriptInstruction> {
  bool get isBooleanResult => false;
  bool get implicitNext => true;
  bool get hasReference => previous?.implicitNext ?? false;

  int get byteCodeLength;

  int layoutFirstPass(int offset) {
    _firstPassOffset = offset;
    return byteCodeLength;
  }

  int layoutFinalPass(int finalOffset) {
    offset = finalOffset;
    return byteCodeLength;
  }

  void addByteCode(ScriptByteCodeBuilder builder);

  var _firstPassOffset = 0;
  var offset = 0;

  void replaceWith(ScriptInstruction replacement) {
    insertAfter(replacement);
    unlink();
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(Object other) => toString() == other.toString();

  ScriptInstruction get firstNonNopInstruction {
    var instruction = this;
    while (instruction is NopInstruction) {
      instruction = instruction.next!;
    }
    return instruction;
  }

  ScriptInstruction? get previousNonNopInstruction {
    ScriptInstruction? instruction = this;
    while (instruction is NopInstruction) {
      instruction = instruction.previous;
    }
    return instruction;
  }
}

final class LoadLocalValueInstruction extends ScriptInstruction {
  LoadLocalValueInstruction(this.index);

  @override
  int get byteCodeLength {
    return index >
            (ScriptOpcode.loadLocalEnd.value -
                ScriptOpcode.loadLocalBegin.value)
        ? 2
        : 1;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    if (byteCodeLength == 2) {
      builder.addOpcode(ScriptOpcode.loadLocalValue);
      builder.addByte(index);
    } else {
      builder.addByte(ScriptOpcode.loadLocalBegin.value + index);
    }
  }

  final int index;

  @override
  String toString() => '  load l$index';
}

final class StoreLocalValueInstruction extends ScriptInstruction {
  StoreLocalValueInstruction(this.index);

  @override
  int get byteCodeLength {
    return index >
            (ScriptOpcode.storeLocalEnd.value -
                ScriptOpcode.storeLocalBegin.value)
        ? 2
        : 1;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    if (byteCodeLength == 2) {
      builder.addOpcode(ScriptOpcode.storeLocalValue);
      builder.addByte(index);
    } else {
      builder.addByte(ScriptOpcode.storeLocalBegin.value + index);
    }
  }

  final int index;

  @override
  String toString() => '  store l$index';
}

final class LoadGlobalValueInstruction extends ScriptInstruction {
  LoadGlobalValueInstruction(this.index);

  @override
  int get byteCodeLength {
    return index >
            (ScriptOpcode.loadGlobalEnd.value -
                ScriptOpcode.loadGlobalBegin.value)
        ? 2
        : 1;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    if (byteCodeLength == 2) {
      builder.addOpcode(ScriptOpcode.loadGlobalValue);
      builder.addByte(index);
    } else {
      builder.addByte(ScriptOpcode.loadGlobalBegin.value + index);
    }
  }

  final int index;

  @override
  String toString() => '  load g$index';
}

final class LoadIndexedGlobalValueInstruction extends ScriptInstruction {
  LoadIndexedGlobalValueInstruction(this.index);

  final int index;

  @override
  int get byteCodeLength => 2;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.loadGlobalIndex);
    builder.addByte(index);
  }

  @override
  String toString() => '  load g$index[]';
}

final class LoadIndexedLocalValueInstruction extends ScriptInstruction {
  LoadIndexedLocalValueInstruction(this.index);

  final int index;

  @override
  int get byteCodeLength => 2;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.loadLocalIndex);
    builder.addByte(index);
  }

  @override
  String toString() => '  load l$index[]';
}

final class StoreGlobalValueInstruction extends ScriptInstruction {
  StoreGlobalValueInstruction(this.index);

  @override
  int get byteCodeLength {
    return index >
            (ScriptOpcode.storeGlobalEnd.value -
                ScriptOpcode.storeGlobalBegin.value)
        ? 2
        : 1;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    if (byteCodeLength == 2) {
      builder.addOpcode(ScriptOpcode.storeGlobalValue);
      builder.addByte(index);
    } else {
      builder.addByte(ScriptOpcode.storeGlobalBegin.value + index);
    }
  }

  final int index;

  @override
  String toString() => '  store g$index';
}

final class StoreIndexedGlobalValueInstruction extends ScriptInstruction {
  StoreIndexedGlobalValueInstruction(this.index);

  final int index;

  @override
  int get byteCodeLength => 2;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.storeGlobalIndex);
    builder.addByte(index);
  }

  @override
  String toString() => '  store g$index[]';
}

final class StoreIndexedLocalValueInstruction extends ScriptInstruction {
  StoreIndexedLocalValueInstruction(this.index);

  final int index;

  @override
  int get byteCodeLength => 2;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.storeLocalIndex);
    builder.addByte(index);
  }

  @override
  String toString() => '  store l$index[]';
}

final class PopValueInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.pop);
  }

  @override
  String toString() => '  pop';
}

final class CallInBuiltFunctionInstruction extends ScriptInstruction {
  CallInBuiltFunctionInstruction(this.function);

  @override
  bool get isBooleanResult => function.isBooleanResult;

  @override
  int get byteCodeLength => 2;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.callInternalFunction);
    builder.addByte(function.functionIndex);
  }

  final InBuiltScriptFunction function;

  @override
  String toString() => '  call in-built-${function.functionIndex} '
      '(${function.functionName})';
}

sealed class FunctionReferenceScriptInstruction extends ScriptInstruction {
  FunctionReferenceScriptInstruction(this.functionName)
      : targetName = functionName;

  final String functionName;
  String? targetName;
}

final class CallFunctionInstruction extends FunctionReferenceScriptInstruction {
  CallFunctionInstruction(super.functionName);

  @override
  int get byteCodeLength => targetName == null ? 0 : 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final targetName = this.targetName;
    if (targetName == null) return;

    final function = builder.functions[targetName]!;
    final offset = function.offset;

    builder.addOpcode(ScriptOpcode.callFunction);
    builder.addByte(offset);
    builder.addByte(offset >> 8);
  }

  @override
  String toString() => functionName == targetName
      ? '  call $functionName'
      : '  call $targetName ($functionName)';
}

final class CallValueInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.callValue);
  }

  @override
  String toString() => '  callValue';
}

final class JumpValueInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  bool get implicitNext => false;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.jumpValue);
  }

  @override
  String toString() => '  jumpValue';
}

final class PushFunctionAddressInstruction
    extends FunctionReferenceScriptInstruction {
  PushFunctionAddressInstruction(super.functionName);

  @override
  int get byteCodeLength => targetName == null ? 1 : 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final targetName = this.targetName;
    if (targetName == null) {
      // Push 0.
      builder.addOpcode(ScriptOpcode.pushConstantBegin);
      return;
    }

    final function = builder.functions[targetName]!;
    final offset = function.offset;

    builder.addOpcode(ScriptOpcode.pushBytes2S);
    builder.addByte(offset);
    builder.addByte(offset >> 8);
  }

  @override
  String toString() => functionName == targetName
      ? '  push @$functionName'
      : '  push @$targetName ($functionName)';
}

sealed class JumpFunctionInstructionBase
    extends FunctionReferenceScriptInstruction {
  JumpFunctionInstructionBase(super.functionName);

  @override
  int get byteCodeLength => targetName == null ? 1 : 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final targetName = this.targetName;

    if (targetName == null) {
      builder.addOpcode(returnOpcode);
      return;
    }

    final function = builder.functions[targetName]!;
    final offset = function.offset;

    builder.addOpcode(opcode);
    builder.addByte(offset);
    builder.addByte(offset >> 8);
  }

  ScriptOpcode get opcode;
  ScriptOpcode get returnOpcode;
  bool get isConditional;
}

final class JumpFunctionInstruction extends JumpFunctionInstructionBase {
  JumpFunctionInstruction(super.functionName);

  @override
  bool get implicitNext => false;

  @override
  ScriptOpcode get opcode => ScriptOpcode.jumpLong;

  @override
  ScriptOpcode get returnOpcode => ScriptOpcode.ret;

  @override
  bool get isConditional => false;

  @override
  String toString() => functionName == targetName
      ? '  jmp $functionName'
      : '  jmp $targetName ($functionName)';
}

final class JumpIfZeroFunctionInstruction extends JumpFunctionInstructionBase {
  JumpIfZeroFunctionInstruction(super.functionName);

  @override
  ScriptOpcode get opcode => ScriptOpcode.jumpIfZeroLong;

  @override
  ScriptOpcode get returnOpcode => ScriptOpcode.retIfZero;

  @override
  bool get isConditional => true;

  @override
  String toString() => functionName == targetName
      ? '  jz $functionName'
      : '  jz $targetName ($functionName)';
}

final class JumpIfNotZeroFunctionInstruction
    extends JumpFunctionInstructionBase {
  JumpIfNotZeroFunctionInstruction(super.functionName);

  @override
  ScriptOpcode get opcode => ScriptOpcode.jumpIfNotZeroLong;

  @override
  ScriptOpcode get returnOpcode => ScriptOpcode.retIfNotZero;

  @override
  bool get isConditional => true;

  @override
  String toString() => functionName == targetName
      ? '  jnz $functionName'
      : '  jnz $targetName ($functionName)';
}

sealed class JumpInstructionBase extends ScriptInstruction {
  JumpInstructionBase() {
    target = NopInstruction(this);
  }

  @override
  void unlink() {
    target.unlink();
    super.unlink();
  }

  @override
  int get byteCodeLength => throw Exception('Should not be called');

  @override
  int layoutFirstPass(int offset) {
    _firstPassOffset = offset;
    return 3;
  }

  @override
  int layoutFinalPass(int finalOffset) {
    offset = finalOffset;
    final layoutDelta = target._firstPassOffset - _firstPassOffset;
    if (layoutDelta == 3) {
      return isConditional ? 1 : 0;
    }
    if (4 <= layoutDelta && layoutDelta < 35) {
      return 1;
    }
    return 3;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    var delta = target.offset - offset;
    final layoutDelta = target._firstPassOffset - _firstPassOffset;
    if (layoutDelta == 3) {
      if (isConditional) {
        builder.addByte(ScriptOpcode.pop.value);
        --delta;
      }
      if (delta != 0) {
        throw Exception('Internal error on $this');
      }
      return;
    } else if (4 <= layoutDelta && layoutDelta < 35) {
      if (delta < 2 || delta >= 33) {
        throw Exception('Internal error on $this');
      }
      builder.addByte(shortOpcode.value + delta - 2);
    } else {
      final targetOffset = target.offset;
      builder.addOpcode(longOpcode);
      builder.addByte(targetOffset);
      builder.addByte(targetOffset >> 8);
    }
  }

  bool isJumpToNext() {
    var n = next;
    while (n != null) {
      if (identical(n, target)) {
        return true;
      }
      if (n is! NopInstruction) {
        return false;
      }
      n = n.next;
    }
    return false;
  }

  ScriptOpcode get shortOpcode;
  ScriptOpcode get longOpcode;
  bool get isConditional => false;

  late final NopInstruction target;
}

final class JumpInstruction extends JumpInstructionBase {
  @override
  bool get implicitNext => false;

  @override
  ScriptOpcode get shortOpcode => ScriptOpcode.jumpShortBegin;

  @override
  ScriptOpcode get longOpcode => ScriptOpcode.jumpLong;

  @override
  String toString() => '  jump 0x${target.offset.toRadixString(16)}';
}

final class JumpIfZeroInstruction extends JumpInstructionBase {
  @override
  ScriptOpcode get shortOpcode => ScriptOpcode.jumpIfZeroShortBegin;

  @override
  ScriptOpcode get longOpcode => ScriptOpcode.jumpIfZeroLong;

  @override
  String toString() => '  jz 0x${target.offset.toRadixString(16)}';

  @override
  bool get isConditional => true;
}

final class JumpIfNotZeroInstruction extends JumpInstructionBase {
  @override
  ScriptOpcode get shortOpcode => ScriptOpcode.jumpIfNotZeroShortBegin;

  @override
  ScriptOpcode get longOpcode => ScriptOpcode.jumpIfNotZeroLong;

  @override
  String toString() => '  jnz 0x${target.offset.toRadixString(16)}';

  @override
  bool get isConditional => true;
}

final class PushStringValueInstruction extends ScriptInstruction {
  PushStringValueInstruction(this.value);

  @override
  int get byteCodeLength => 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final offset = builder.stringTable[value];
    if (offset == null) {
      throw Exception(
        'Internal error: failed lookup on string value "${formatStringData(value)}"',
      );
    }
    builder.addOpcode(ScriptOpcode.pushBytes2S);
    builder.addByte(offset);
    builder.addByte(offset >> 8);
  }

  @override
  String toString() => '  push offset-of ${formatStringData(value)}';

  final String value;
}

final class SetHalfWordFunctionDataValueInstruction
    extends FunctionReferenceScriptInstruction {
  SetHalfWordFunctionDataValueInstruction({
    required String functionName,
    required this.value,
    required this.valueOffset,
  }) : super(functionName);

  @override
  int get byteCodeLength => 0;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final targetName = this.targetName;
    final int? offset;

    if (targetName == null) {
      offset = 0;
    } else {
      offset = builder.functions[targetName]?.offset;
      if (offset == null) {
        throw Exception('Function $targetName not defined');
      }
    }

    value[valueOffset] = offset & 0xff;
    value[valueOffset + 1] = offset >> 8;
  }

  @override
  String toString() => functionName == targetName
      ? '  ((set2 offset $valueOffset -> $functionName))'
      : '  ((set2 offset $valueOffset -> $targetName ($functionName)))';

  final Uint8List value;
  final int valueOffset;
}

final class PushDataValueInstruction extends ScriptInstruction {
  PushDataValueInstruction(this.value);

  @override
  int get byteCodeLength => 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final offset = builder.data[value];
    if (offset == null) {
      throw Exception('Internal error: failed lookup on data value');
    }
    builder.addOpcode(ScriptOpcode.pushBytes2S);
    builder.addByte(offset);
    builder.addByte(offset >> 8);
  }

  @override
  String toString() => '  push offset-of $value';

  final AstNode value;
}

final class PushIntValueInstruction extends ScriptInstruction {
  PushIntValueInstruction(this.value);

  @override
  int get byteCodeLength {
    if (0 <= value && value < 60) {
      return 1;
    }
    if (-60 <= value && value < 256) {
      return 2;
    }
    if (-32768 <= value && value < 32768) {
      return 3;
    }
    if (-8388608 <= value && value < 8388608) {
      return 4;
    }
    return 5;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    switch (byteCodeLength) {
      case 1:
        builder.addByte(ScriptOpcode.pushConstantBegin.value + value);
        break;
      case 2:
        builder.addOpcode(ScriptOpcode.pushBytes1U);
        final byteValue = value < 0 ? value + 60 : value;
        builder.addByte(byteValue);
        break;
      case 3:
        builder.addOpcode(ScriptOpcode.pushBytes2S);
        builder.addByte(value);
        builder.addByte(value >> 8);
        break;
      case 4:
        builder.addOpcode(ScriptOpcode.pushBytes3S);
        builder.addByte(value);
        builder.addByte(value >> 8);
        builder.addByte(value >> 16);
        break;
      case 5:
        builder.addOpcode(ScriptOpcode.pushBytes4);
        builder.addByte(value);
        builder.addByte(value >> 8);
        builder.addByte(value >> 16);
        builder.addByte(value >> 24);
        break;
    }
  }

  final int value;

  @override
  String toString() => '  push $value';
}

final class NopInstruction extends ScriptInstruction {
  NopInstruction([this.reference]);

  @override
  int get byteCodeLength => 0;

  @override
  bool get hasReference => reference != null || super.hasReference;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {}

  final ScriptInstruction? reference;

  bool isTarget(ScriptInstruction? target) {
    while (target is NopInstruction) {
      if (identical(this, target)) return true;
      target = target.next;
    }
    return false;
  }

  @override
  String toString() => ' 0x${offset.toRadixString(16)}:';
}

final class OpcodeInstruction extends ScriptInstruction {
  OpcodeInstruction(this.opcode);

  @override
  bool get isBooleanResult => opcode.isBooleanResult;

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOperatorOpcode(opcode);
  }

  final ScriptOperatorOpcode opcode;

  @override
  String toString() => '  ${opcode.name}';
}

final class ReturnInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  bool get implicitNext => false;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.ret);
  }

  @override
  String toString() => '  ret';
}

final class ReturnIfZeroInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.retIfZero);
  }

  @override
  String toString() => '  retz';
}

final class ReturnIfNotZeroInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.addOpcode(ScriptOpcode.retIfNotZero);
  }

  @override
  String toString() => '  retnz';
}

final class StartFunctionInstruction extends ScriptInstruction {
  StartFunctionInstruction(this.function, this.isLocked);

  final ScriptFunctionDefinition function;

  // Locked functions cannot have their body completely optimized out.
  final bool isLocked;

  @override
  bool get hasReference => true;

  @override
  int get byteCodeLength {
    return function.numberOfParameters == 0 && function.numberOfLocals == 0
        ? 0
        : 3;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    if (function.numberOfParameters == 0 && function.numberOfLocals == 0) {
      return;
    }

    builder.addOpcode(ScriptOpcode.enterFunction);
    builder.addByte(function.numberOfParameters);
    builder.addByte(function.numberOfLocals - function.numberOfParameters);
  }

  @override
  String toString() {
    if (function.numberOfParameters == 0 && function.numberOfLocals == 0) {
      return '\n${function.functionName} (0x${offset.toRadixString(16)}):';
    } else {
      return '\n'
          '${function.functionName} (0x${offset.toRadixString(16)}):'
          '\n  enterFunction ${function.numberOfParameters} ${function.numberOfLocals - function.numberOfParameters}';
    }
  }
}

final class DataInstruction extends ScriptInstruction {
  DataInstruction(this.data);

  final Uint8List data;

  @override
  bool get implicitNext => false;

  @override
  int get byteCodeLength => data.length;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.add(data);
  }

  @override
  String toString() {
    final bytesText = data.map((e) => e.toRadixString(16).padLeft(2, '0'));
    return '  data [[${bytesText.join(' ')}]]';
  }
}
