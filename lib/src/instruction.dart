import 'dart:collection';

import 'byte_code_builder.dart';

enum ScriptOpCode {
  not(0x40),
  negative(0x41),
  multiply(0x42),
  quotient(0x43),
  remainder(0x44),
  add(0x45),
  subtract(0x46),
  equals(0x47),
  notEquals(0x48),
  lessThan(0x49),
  lessThanOrEqualTo(0x4a),
  greaterThan(0x4b),
  greaterThanOrEqualTo(0x4c),
  bitwiseAnd(0x4d),
  bitwiseOr(0x4e),
  bitwiseXor(0x4f),
  logicalAnd(0x50),
  logicalOr(0x51);

  const ScriptOpCode(this.value);

  final int value;
}

abstract class ScriptInstruction extends LinkedListEntry<ScriptInstruction> {
  int get byteCodeLength;

  bool get implicitNext => true;

  bool get hasReference => previous?.implicitNext ?? false;

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

  ScriptInstruction get nextNonNopInstruction {
    var instruction = this;
    while (instruction is NopScriptInstruction) {
      instruction = instruction.next!;
    }
    return instruction;
  }

  ScriptInstruction? get previousNonNopInstruction {
    ScriptInstruction? instruction = this;
    while (instruction is NopScriptInstruction) {
      instruction = instruction.previous;
    }
    return instruction;
  }
}

class LoadParamInstruction extends ScriptInstruction {
  LoadParamInstruction(this.index);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xd0 + index);
  }

  final int index;

  @override
  String toString() => '  load p$index';
}

class StoreParamCountInstruction extends ScriptInstruction {
  StoreParamCountInstruction(this.count);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xd7 + count);
  }

  final int count;

  @override
  String toString() => '  store-param-count $count';
}

class LoadLocalValueInstruction extends ScriptInstruction {
  LoadLocalValueInstruction(this.index);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xe0 + index);
  }

  final int index;

  @override
  String toString() => '  load l$index';
}

class StoreLocalValueInstruction extends ScriptInstruction {
  StoreLocalValueInstruction(this.index);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xe4 + index);
  }

  final int index;

  @override
  String toString() => '  store l$index';
}

class LoadGlobalValueInstruction extends ScriptInstruction {
  LoadGlobalValueInstruction(this.index);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xe8 + index);
  }

  final int index;

  @override
  String toString() => '  load g$index';
}

class StoreGlobalValueInstruction extends ScriptInstruction {
  StoreGlobalValueInstruction(this.index);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xec + index);
  }

  final int index;

  @override
  String toString() => '  store g$index';
}

class CallInBuiltFunctionInstruction extends ScriptInstruction {
  CallInBuiltFunctionInstruction(this.functionIndex);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xf0 + functionIndex);
  }

  final int functionIndex;

  @override
  String toString() => '  call in-built-$functionIndex';
}

class CallFunctionInstruction extends ScriptInstruction {
  CallFunctionInstruction(this.functionName);

  @override
  int get byteCodeLength => 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final function = builder.functions[functionName]!;
    final offset = function.offset;

    builder.bytesBuilder.addByte(0xc5);
    builder.bytesBuilder.addByte(offset);
    builder.bytesBuilder.addByte(offset >> 8);
  }

  final String functionName;

  @override
  String toString() => '  call $functionName';
}

abstract class JumpFunctionScriptInstructionBase extends ScriptInstruction {
  JumpFunctionScriptInstructionBase(this.functionName);

  @override
  int get byteCodeLength => 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    final function = builder.functions[functionName]!;
    final offset = function.offset;

    builder.bytesBuilder.addByte(opcode);
    builder.bytesBuilder.addByte(offset);
    builder.bytesBuilder.addByte(offset >> 8);
  }

  int get opcode;

  final String functionName;
}

class JumpFunctionScriptInstruction extends JumpFunctionScriptInstructionBase {
  JumpFunctionScriptInstruction(super.functionName);

  @override
  bool get implicitNext => false;
  @override
  int get opcode => 0xc6;

  @override
  String toString() => '  jmp $functionName';
}

class JumpIfZeroFunctionScriptInstruction
    extends JumpFunctionScriptInstructionBase {
  JumpIfZeroFunctionScriptInstruction(super.functionName);

  @override
  int get opcode => 0xc7;

  @override
  String toString() => '  jz $functionName';
}

class JumpIfNotZeroFunctionScriptInstruction
    extends JumpFunctionScriptInstructionBase {
  JumpIfNotZeroFunctionScriptInstruction(super.functionName);

  @override
  int get opcode => 0xc8;

  @override
  String toString() => '  jz $functionName';
}

abstract class JumpScriptInstructionBase extends ScriptInstruction {
  JumpScriptInstructionBase() {
    target = NopScriptInstruction(this);
  }

  @override
  void unlink() {
    target.unlink();
    super.unlink();
  }

  @override
  int get byteCodeLength {
    int delta = target.offset - offset;
    if (delta == 0) {
      return 0;
    }
    if (2 <= delta && delta <= 33) {
      return 1;
    }
    return 3;
  }

  @override
  int layoutFirstPass(int offset) {
    _firstPassOffset = offset;
    return 3;
  }

  @override
  int layoutFinalPass(int finalOffset) {
    offset = finalOffset;
    int delta = target._firstPassOffset - _firstPassOffset;
    if (delta == 3) {
      return 0;
    }
    if (4 <= delta && delta <= 35) {
      return 1;
    }
    return 3;
  }

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    int delta = target.offset - offset;
    if (delta == 0) {
      return;
    } else if (2 <= delta && delta <= 33) {
      builder.bytesBuilder.addByte(shortOpcode + delta - 2);
    } else {
      final targetOffset = target.offset;
      builder.bytesBuilder.addByte(longOpcode);
      builder.bytesBuilder.addByte(targetOffset);
      builder.bytesBuilder.addByte(targetOffset >> 8);
    }
  }

  int get shortOpcode;
  int get longOpcode;

  late final NopScriptInstruction target;
}

class JumpScriptInstruction extends JumpScriptInstructionBase {
  @override
  bool get implicitNext => false;

  @override
  int get shortOpcode => 0x60;

  @override
  int get longOpcode => 0xc6;

  @override
  String toString() => '  jump 0x${target.offset.toRadixString(16)}';
}

class JumpIfZeroScriptInstruction extends JumpScriptInstructionBase {
  @override
  int get shortOpcode => 0x80;

  @override
  int get longOpcode => 0xc7;

  @override
  String toString() => '  jz 0x${target.offset.toRadixString(16)}';
}

class JumpIfNotZeroScriptInstruction extends JumpScriptInstructionBase {
  @override
  int get shortOpcode => 0xa0;

  @override
  int get longOpcode => 0xc8;

  @override
  String toString() => '  jnz 0x${target.offset.toRadixString(16)}';
}

class PushStringValueScriptInstruction extends ScriptInstruction {
  PushStringValueScriptInstruction(this.value);

  @override
  int get byteCodeLength => 3;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    int offset = builder.stringTable[value]!;
    builder.bytesBuilder.addByte(0xc1);
    builder.bytesBuilder.addByte(offset);
    builder.bytesBuilder.addByte(offset >> 8);
  }

  @override
  String toString() => '  push offset_of("$value")';

  final String value;
}

class PushIntValueScriptInstruction extends ScriptInstruction {
  PushIntValueScriptInstruction(this.value);

  @override
  int get byteCodeLength {
    if (0 <= value && value < 64) {
      return 1;
    }
    if (-64 <= value && value < 256) {
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
    if (0 <= value && value < 64) {
      builder.bytesBuilder.addByte(value);
    } else if (-64 <= value && value < 256) {
      builder.bytesBuilder.addByte(0xc0);
      final byteValue = value < 0 ? value + 64 : value;
      builder.bytesBuilder.addByte(byteValue);
    } else if (-32768 <= value && value < 32768) {
      builder.bytesBuilder.addByte(0xc1);
      builder.bytesBuilder.addByte(value);
      builder.bytesBuilder.addByte(value >> 8);
    } else if (-8388608 <= value && value < 8388608) {
      builder.bytesBuilder.addByte(0xc2);
      builder.bytesBuilder.addByte(value);
      builder.bytesBuilder.addByte(value >> 8);
      builder.bytesBuilder.addByte(value >> 16);
    } else {
      builder.bytesBuilder.addByte(0xc2);
      builder.bytesBuilder.addByte(value);
      builder.bytesBuilder.addByte(value >> 8);
      builder.bytesBuilder.addByte(value >> 16);
      builder.bytesBuilder.addByte(value >> 24);
    }
  }

  final int value;

  @override
  String toString() => '  push $value';
}

class NopScriptInstruction extends ScriptInstruction {
  NopScriptInstruction(this.reference);

  @override
  int get byteCodeLength => 0;

  @override
  bool get hasReference => true;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {}

  final ScriptInstruction reference;

  @override
  String toString() => ' 0x${offset.toRadixString(16)}:';
}

class OpcodeScriptInstruction extends ScriptInstruction {
  OpcodeScriptInstruction(this.opcode);

  @override
  int get byteCodeLength => 1;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(opcode.value);
  }

  final ScriptOpCode opcode;

  @override
  String toString() => '  ${opcode.name}';
}

class ReturnScriptInstruction extends ScriptInstruction {
  @override
  int get byteCodeLength => 1;

  @override
  bool get implicitNext => false;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {
    builder.bytesBuilder.addByte(0xc4);
  }

  @override
  String toString() => '  ret';
}

class FunctionStartPlaceholderScriptInstruction extends ScriptInstruction {
  FunctionStartPlaceholderScriptInstruction(this.functionName);

  final String functionName;

  @override
  bool get hasReference => true;

  @override
  int get byteCodeLength => 0;

  @override
  void addByteCode(ScriptByteCodeBuilder builder) {}

  @override
  String toString() => '\n$functionName (0x${offset.toRadixString(16)}): ';
}
