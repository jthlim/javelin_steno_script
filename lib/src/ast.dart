import 'dart:typed_data';

import 'package:javelin_steno_script/src/token.dart';

import 'instruction.dart';
import 'functions.dart';
import 'byte_code_builder.dart';
import 'module.dart';

class ScriptReachability {
  ScriptReachability(this.module);

  final ScriptModule module;

  final strings = <String>{};
  final functions = <String>{};
  final globals = <int>{};
  final pendingGlobalStatements = <int, List<AstNode>>{};

  // data + lengths
  final data = <AstNode, int>{};
}

abstract class AstNode {
  bool isEmpty() => false;
  bool isBoolean() => false;
  bool isReturn() => false;
  bool isConstant();

  int constantValue();
  void addInstructions(ScriptByteCodeBuilder builder);

  void mark(ScriptReachability context) {}

  Uint8List getData() => throw UnsupportedError('Internal error');

  AstNode simplify() {
    if (isConstant()) {
      return IntValueAstNode(constantValue());
    }
    return this;
  }
}

class StringValueAstNode extends AstNode {
  StringValueAstNode(this.value);

  // Do NOT mark this as constant, otherwise integer folding instructions
  // will be attempted.
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    context.strings.add(value);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    builder.strings.add(value);
    builder.addInstruction(PushStringValueInstruction(value));
  }

  final String value;
}

class HalfWordListAstNode extends AstNode {
  HalfWordListAstNode(this.values);

  // Do NOT mark this as constant, otherwise integer folding instructions
  // will be attempted.
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    for (final e in values) {
      e.mark(context);
    }
    context.data[this] = values.length * 2;
  }

  @override
  Uint8List getData() => bytes;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final bytesBuilder = BytesBuilder();
    for (final e in values) {
      if (e.isConstant()) {
        final v = e.constantValue();
        bytesBuilder.addByte(v & 0xff);
        bytesBuilder.addByte(v >> 8);
      } else if (e is PushFunctionAddress) {
        bytesBuilder.addByte(0xff);
        bytesBuilder.addByte(0xff);
      }
    }
    bytes = bytesBuilder.toBytes();

    var offset = 0;
    for (final e in values) {
      if (!e.isConstant() && e is PushFunctionAddress) {
        builder.addInstruction(
          SetHalfWordFunctionDataValueInstruction(
            value: bytes,
            valueOffset: offset,
            functionName: e.name,
          ),
        );
      }
      offset += 2;
    }

    builder.addInstruction(PushDataValueInstruction(this));
  }

  late Uint8List bytes;
  final List<AstNode> values;

  @override
  String toString() {
    final result = <String>[];
    for (final e in values) {
      if (e.isConstant()) {
        result.add('${e.constantValue()}');
      } else if (e is PushFunctionAddress) {
        result.add('@${e.name}');
      }
    }
    return '[${result.join(', ')}]';
  }
}

class ByteIndexAstNode extends AstNode {
  ByteIndexAstNode(this.byteValue, this.index);

  // Do NOT mark this as constant, otherwise integer folding instructions
  // will be attempted.
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    byteValue.mark(context);
    index.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    byteValue.addInstructions(builder);
    index.addInstructions(builder);

    builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.byteLookup));
  }

  final AstNode byteValue;
  final AstNode index;
}

class HalfWordIndexAstNode extends AstNode {
  HalfWordIndexAstNode(this.value, this.index);

  // Do NOT mark this as constant, otherwise integer folding instructions
  // will be attempted.
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    value.mark(context);
    index.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    value.addInstructions(builder);
    index.addInstructions(builder);

    builder
        .addInstruction(OpcodeInstruction(ScriptOperatorOpcode.halfWordLookup));
  }

  final AstNode value;
  final AstNode index;
}

class IntValueAstNode extends AstNode {
  IntValueAstNode(this.value);

  @override
  bool isConstant() => true;

  @override
  int constantValue() => value;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    builder.addInstruction(PushIntValueInstruction(value));
  }

  @override
  AstNode simplify() {
    return this;
  }

  final int value;
}

abstract class UnaryOperatorAstNode extends AstNode {
  UnaryOperatorAstNode(this.statement);

  @override
  bool isConstant() => statement.isConstant();

  @override
  void mark(ScriptReachability context) {
    statement.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (isConstant()) {
      builder.addInstruction(PushIntValueInstruction(constantValue()));
      return;
    }
    statement.addInstructions(builder);
    builder.addInstruction(OpcodeInstruction(opcode));
  }

  ScriptOperatorOpcode get opcode;

  final AstNode statement;
}

class NotAstNode extends UnaryOperatorAstNode {
  NotAstNode(super.statement);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() => statement.constantValue() == 0 ? 1 : 0;

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.not;
}

class NegateAstNode extends UnaryOperatorAstNode {
  NegateAstNode(super.statement);

  @override
  int constantValue() => -statement.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.negative;
}

class BitwiseNotAstNode extends AstNode {
  BitwiseNotAstNode(this.expression);

  @override
  bool isConstant() => expression.isConstant();

  @override
  int constantValue() => ~expression.constantValue();

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (isConstant()) {
      builder.addInstruction(PushIntValueInstruction(constantValue()));
      return;
    }
    expression.addInstructions(builder);
    builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.negative));
    builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.decrement));
  }

  final AstNode expression;
}

abstract class BinaryOperatorAstNode extends AstNode {
  BinaryOperatorAstNode(this.statementA, this.statementB);

  @override
  bool isConstant() => statementA.isConstant() && statementB.isConstant();

  @override
  void mark(ScriptReachability context) {
    statementA.mark(context);
    statementB.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    statementA.addInstructions(builder);
    statementB.addInstructions(builder);
    builder.addInstruction(OpcodeInstruction(opcode));
  }

  ScriptOperatorOpcode get opcode;

  final AstNode statementA;
  final AstNode statementB;
}

enum TermMode {
  add,
  subtract,
}

class Term {
  const Term(this.mode, this.statement);

  final TermMode mode;
  final AstNode statement;
}

class TermsAstNode extends AstNode {
  @override
  bool isConstant() => terms.every((e) => e.statement.isConstant());

  @override
  void mark(ScriptReachability context) {
    for (final term in terms) {
      term.statement.mark(context);
    }
  }

  @override
  int constantValue() {
    var result = 0;
    for (final term in terms) {
      if (!term.statement.isConstant()) {
        continue;
      }
      final value = term.statement.constantValue();
      switch (term.mode) {
        case TermMode.add:
          result += value;
          break;
        case TermMode.subtract:
          result -= value;
          break;
      }
    }
    return result;
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    var constantsSum = constantValue();
    if (isConstant()) {
      builder.addInstruction(PushIntValueInstruction(constantsSum));
      return;
    }

    var isFirst = true;

    for (final term in terms) {
      if (term.statement.isConstant()) {
        // Already tallied into constantsSum
        continue;
      }
      switch (term.mode) {
        case TermMode.add:
          term.statement.addInstructions(builder);
          if (isFirst) {
            isFirst = false;
          } else {
            builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.add));
          }
          break;
        case TermMode.subtract:
          if (isFirst) {
            isFirst = false;
            if (constantsSum == 0) {
              term.statement.addInstructions(builder);
              builder.addInstruction(
                OpcodeInstruction(ScriptOperatorOpcode.negative),
              );
            } else {
              builder.addInstruction(PushIntValueInstruction(constantsSum));
              constantsSum = 0;
              term.statement.addInstructions(builder);
              builder.addInstruction(
                OpcodeInstruction(ScriptOperatorOpcode.subtract),
              );
            }
          } else {
            term.statement.addInstructions(builder);
            builder.addInstruction(
              OpcodeInstruction(ScriptOperatorOpcode.subtract),
            );
          }
      }
    }
    switch (constantsSum) {
      case 1:
        builder
            .addInstruction(OpcodeInstruction(ScriptOperatorOpcode.increment));
        break;
      case -1:
        builder
            .addInstruction(OpcodeInstruction(ScriptOperatorOpcode.decrement));
        break;
      case 0:
        break;
      default:
        if (constantsSum < 0) {
          // The bytecode format has a bias towards positive numbers,
          // so using a subtract operation can be slightly smaller size.
          builder.addInstruction(PushIntValueInstruction(-constantsSum));
          builder
              .addInstruction(OpcodeInstruction(ScriptOperatorOpcode.subtract));
        } else {
          builder.addInstruction(PushIntValueInstruction(constantsSum));
          builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.add));
        }
        break;
    }
  }

  final terms = <Term>[];
}

class MultiplyAstNode extends BinaryOperatorAstNode {
  MultiplyAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() * statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.multiply;
}

class QuotientAstNode extends BinaryOperatorAstNode {
  QuotientAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ~/ statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.quotient;
}

class RemainderAstNode extends BinaryOperatorAstNode {
  RemainderAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue().remainder(statementB.constantValue());

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.remainder;
}

class BitwiseAndAstNode extends BinaryOperatorAstNode {
  BitwiseAndAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() & statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseAnd;
}

class BitwiseOrAstNode extends BinaryOperatorAstNode {
  BitwiseOrAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() | statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseOr;
}

class BitwiseXorAstNode extends BinaryOperatorAstNode {
  BitwiseXorAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ^ statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseXor;
}

class BitShiftLeftAstNode extends BinaryOperatorAstNode {
  BitShiftLeftAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() << statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.shiftLeft;
}

class ArithmeticBitShiftRightAstNode extends BinaryOperatorAstNode {
  ArithmeticBitShiftRightAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() >> statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.arithmeticShiftRight;
}

class LogicalBitShiftRightAstNode extends BinaryOperatorAstNode {
  LogicalBitShiftRightAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() >>> statementB.constantValue();

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.logicalShiftRight;
}

class LogicalAndAstNode extends BinaryOperatorAstNode {
  LogicalAndAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  bool isConstant() {
    if (statementA.isConstant()) {
      if (statementA.constantValue() == 0) {
        return true;
      }
      return statementB.isConstant();
    }
    return false;
  }

  @override
  int constantValue() {
    if (statementA.constantValue() == 0) {
      return 0;
    }
    return statementB.constantValue() != 0 ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.logicalAnd;
}

class LogicalOrAstNode extends BinaryOperatorAstNode {
  LogicalOrAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  bool isConstant() {
    if (statementA.isConstant()) {
      if (statementA.constantValue() == 1) {
        return true;
      }
      return statementB.isConstant();
    }
    return false;
  }

  @override
  int constantValue() {
    if (statementA.constantValue() == 1) {
      return 1;
    }
    return statementB.constantValue() != 0 ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.logicalOr;
}

class EqualsAstNode extends BinaryOperatorAstNode {
  EqualsAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() == statementB.constantValue() ? 1 : 0;
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (statementA.isConstant() && statementA.constantValue() == 0) {
      statementB.addInstructions(builder);
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
    } else if (statementB.isConstant() && statementB.constantValue() == 0) {
      statementA.addInstructions(builder);
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
    } else {
      super.addInstructions(builder);
    }
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.equals;
}

class NotEqualsAstNode extends BinaryOperatorAstNode {
  NotEqualsAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() != statementB.constantValue() ? 1 : 0;
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (statementA.isConstant() && statementA.constantValue() == 0) {
      statementB.addInstructions(builder);
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
    } else if (statementB.isConstant() && statementB.constantValue() == 0) {
      statementA.addInstructions(builder);
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
      builder.addInstruction(OpcodeInstruction(ScriptOperatorOpcode.not));
    } else {
      super.addInstructions(builder);
    }
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.notEquals;
}

class LessThanAstNode extends BinaryOperatorAstNode {
  LessThanAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() < statementB.constantValue() ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.lessThan;
}

class LessThanOrEqualToAstNode extends BinaryOperatorAstNode {
  LessThanOrEqualToAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() <= statementB.constantValue() ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.lessThanOrEqualTo;
}

class GreaterThanAstNode extends BinaryOperatorAstNode {
  GreaterThanAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() > statementB.constantValue() ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.greaterThan;
}

class GreaterThanOrEqualToAstNode extends BinaryOperatorAstNode {
  GreaterThanOrEqualToAstNode(super.statementA, super.statementB);

  @override
  bool isBoolean() => true;

  @override
  int constantValue() {
    return statementA.constantValue() >= statementB.constantValue() ? 1 : 0;
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.greaterThanOrEqualTo;
}

class NopAstNode extends AstNode {
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {}
}

class ForStatementAstNode extends AstNode {
  ForStatementAstNode({
    this.initialization,
    required this.condition,
    this.update,
    required this.body,
  });

  final AstNode? initialization;
  final AstNode? condition;
  final AstNode? update;
  final AstNode body;

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    initialization?.mark(context);
    final condition = this.condition;
    if (condition == null) {
      update?.mark(context);
      body.mark(context);
    } else {
      condition.mark(context);
      if (!condition.isConstant() || condition.constantValue() != 0) {
        update?.mark(context);
        body.mark(context);
      }
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    // Layout is:
    //   initialization:
    //  condition:
    //   condition -> end
    //   body
    //   update
    //   jmp condition
    //  end:

    initialization?.addInstructions(builder);
    final condition = this.condition;
    final originalContinueTargets = builder.continueTargets;
    final originalBreakTargets = builder.breakTargets;
    final continueTargets = <NopInstruction>[];
    final breakTargets = <NopInstruction>[];
    builder.continueTargets = continueTargets;
    builder.breakTargets = breakTargets;
    if (condition == null) {
      final jumpToStartInstruction = JumpInstruction();
      builder.addInstruction(jumpToStartInstruction.target);

      body.addInstructions(builder);
      update?.addInstructions(builder);
      builder.addInstruction(jumpToStartInstruction);

      for (final continueTarget in continueTargets) {
        jumpToStartInstruction.target.insertAfter(continueTarget);
      }
    } else if (!condition.isConstant() || condition.constantValue() != 0) {
      final jumpToConditionInstruction = JumpInstruction();
      builder.addInstruction(jumpToConditionInstruction.target);
      condition.addInstructions(builder);

      final lastInstruction = builder.instructions.last;
      late final JumpInstructionBase jumpToEndInstruction;
      if (lastInstruction is OpcodeInstruction &&
          lastInstruction.opcode == ScriptOperatorOpcode.not) {
        builder.instructions.removeLast();
        jumpToEndInstruction = JumpIfNotZeroInstruction();
      } else {
        jumpToEndInstruction = JumpIfZeroInstruction();
      }
      builder.addInstruction(jumpToEndInstruction);
      body.addInstructions(builder);
      update?.addInstructions(builder);
      for (final continueTarget in continueTargets) {
        builder.addInstruction(continueTarget);
      }
      builder.addInstruction(jumpToConditionInstruction);
      builder.addInstruction(jumpToEndInstruction.target);
    }
    for (final endTarget in breakTargets) {
      builder.addInstruction(endTarget);
    }
    builder.continueTargets = originalContinueTargets;
    builder.breakTargets = originalBreakTargets;
  }
}

class DoWhileStatementAstNode extends AstNode {
  DoWhileStatementAstNode({
    required this.body,
    required this.condition,
  });

  final AstNode body;
  final AstNode condition;

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    body.mark(context);
    condition.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    // Layout is:
    //  start:
    //   body
    //   condition -> start

    final originalContinueTargets = builder.continueTargets;
    final originalBreakTargets = builder.breakTargets;
    final continueTargets = <NopInstruction>[];
    final breakTargets = <NopInstruction>[];
    builder.continueTargets = continueTargets;
    builder.breakTargets = breakTargets;

    final startMarker = NopInstruction();
    builder.addInstruction(startMarker);
    body.addInstructions(builder);
    builder.continueTargets = originalContinueTargets;
    builder.breakTargets = originalBreakTargets;

    for (final endTarget in continueTargets) {
      builder.addInstruction(endTarget);
    }

    condition.addInstructions(builder);

    final lastInstruction = builder.instructions.last;
    late final JumpInstructionBase jumpToEndInstruction;
    if (lastInstruction is OpcodeInstruction &&
        lastInstruction.opcode == ScriptOperatorOpcode.not) {
      builder.instructions.removeLast();
      jumpToEndInstruction = JumpIfZeroInstruction();
    } else {
      jumpToEndInstruction = JumpIfNotZeroInstruction();
    }
    builder.addInstruction(jumpToEndInstruction);
    startMarker.insertAfter(jumpToEndInstruction.target);

    for (final endTarget in breakTargets) {
      builder.addInstruction(endTarget);
    }
  }
}

class IfStatementAstNode extends AstNode {
  IfStatementAstNode({
    required this.condition,
    required this.whenTrue,
    this.whenFalse,
    this.isBooleanExpression = false,
  });

  @override
  bool isBoolean() => isBooleanExpression;

  @override
  bool isEmpty() {
    if (!condition.isConstant()) {
      return false;
    }
    if (condition.constantValue() != 0) {
      return whenTrue.isEmpty();
    } else {
      return whenFalse?.isEmpty() ?? true;
    }
  }

  @override
  bool isReturn() {
    if (!condition.isConstant()) {
      return false;
    }
    if (condition.constantValue() != 0) {
      return whenTrue.isReturn();
    } else {
      return whenFalse?.isReturn() ?? false;
    }
  }

  @override
  bool isConstant() => condition.isConstant()
      ? condition.constantValue() != 0
          ? whenTrue.isConstant()
          : (whenFalse?.isConstant() ?? false)
      : false;

  @override
  int constantValue() => condition.constantValue() != 0
      ? whenTrue.constantValue()
      : whenFalse!.constantValue();

  @override
  void mark(ScriptReachability context) {
    if (condition.isConstant()) {
      if (condition.constantValue() != 0) {
        whenTrue.mark(context);
      } else {
        whenFalse?.mark(context);
      }
    } else {
      condition.mark(context);
      whenTrue.mark(context);
      whenFalse?.mark(context);
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (condition.isConstant()) {
      if (condition.constantValue() != 0) {
        whenTrue.addInstructions(builder);
      } else {
        whenFalse?.addInstructions(builder);
      }
    } else {
      condition.addInstructions(builder);

      final lastInstruction = builder.instructions.last;
      late final JumpInstructionBase jumpInstruction;
      if (lastInstruction is OpcodeInstruction &&
          lastInstruction.opcode == ScriptOperatorOpcode.not) {
        builder.instructions.removeLast();
        jumpInstruction = JumpIfNotZeroInstruction();
      } else {
        jumpInstruction = JumpIfZeroInstruction();
      }
      final elseNop = jumpInstruction.target;
      builder.addInstruction(jumpInstruction);

      whenTrue.addInstructions(builder);
      NopInstruction? endNop;
      if (whenFalse != null) {
        final jumpInstruction = JumpInstruction();
        endNop = jumpInstruction.target;
        builder.addInstruction(jumpInstruction);
      }
      builder.addInstruction(elseNop);
      whenFalse?.addInstructions(builder);
      if (endNop != null) {
        builder.addInstruction(endNop);
      }
    }
  }

  final bool isBooleanExpression;
  final AstNode condition;
  final AstNode whenTrue;
  final AstNode? whenFalse;
}

class BreakStatementAstNode extends AstNode {
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final targets = builder.breakTargets;
    if (targets == null) {
      throw const FormatException('No target for break statement');
    }
    final jumpInstruction = JumpInstruction();
    builder.addInstruction(jumpInstruction);
    targets.add(jumpInstruction.target);
  }
}

class ContinueStatementAstNode extends AstNode {
  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final targets = builder.continueTargets;
    if (targets == null) {
      throw const FormatException('No target for continue statement');
    }
    final jumpInstruction = JumpInstruction();
    builder.addInstruction(jumpInstruction);
    targets.add(jumpInstruction.target);
  }
}

class StatementListAstNode extends AstNode {
  @override
  bool isEmpty() {
    for (final statement in statements) {
      if (!statement.isEmpty()) return false;
    }
    return true;
  }

  @override
  bool isReturn() {
    for (final statement in statements) {
      if (statement.isReturn()) return true;
      if (!statement.isEmpty()) return false;
    }
    return false;
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    for (final statement in statements) {
      statement.mark(context);
      if (statement.isReturn()) break;
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    for (final statement in statements) {
      statement.addInstructions(builder);
      if (statement.isReturn()) break;
    }
  }

  final statements = <AstNode>[];

  void add(AstNode statement) => statements.add(statement);
}

class LoadGlobalValueArrayAstNode extends AstNode {
  LoadGlobalValueArrayAstNode(this.global);

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    throw Exception('Global value array ${global.name} must be indexed');
  }

  final ScriptGlobal global;
}

mixin IndexedGlobalValueMixin {
  static int calculateIndexOffset(
    AstNode indexExpression,
    int globalValueIndex,
  ) {
    if (indexExpression.isConstant()) {
      // Special cased code generation
      return 0;
    }

    if (indexExpression is! TermsAstNode) {
      return 0;
    }

    var offset = indexExpression.constantValue();
    if (offset == 0) {
      return 0;
    }

    final index = globalValueIndex + offset;
    if (index < 0 || index > 255) {
      return 0;
    }

    indexExpression.terms.removeWhere((e) => e.statement.isConstant());
    return offset;
  }
}

class LoadIndexedGlobalValueAstNode extends AstNode
    with IndexedGlobalValueMixin {
  LoadIndexedGlobalValueAstNode(this.globalValue, this.indexExpression) {
    globalIndexOffset = IndexedGlobalValueMixin.calculateIndexOffset(
      indexExpression,
      globalValue.global.index,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    context.globals.add(globalValue.global.index);

    final pendingStatements =
        context.pendingGlobalStatements[globalValue.global.index];
    context.pendingGlobalStatements.remove(globalValue.global.index);
    if (pendingStatements != null) {
      for (final pendingStatement in pendingStatements) {
        pendingStatement.mark(context);
      }
    }

    indexExpression.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (indexExpression.isConstant()) {
      builder.addInstruction(
        LoadGlobalValueInstruction(
          globalValue.global.index + indexExpression.constantValue(),
        ),
      );
    } else {
      indexExpression.addInstructions(builder);
      builder.addInstruction(
        LoadIndexedGlobalValueInstruction(
          globalValue.global.index + globalIndexOffset,
        ),
      );
    }
  }

  int globalIndexOffset = 0;
  final LoadGlobalValueArrayAstNode globalValue;
  final AstNode indexExpression;
}

class LoadValueAstNode extends AstNode {
  LoadValueAstNode({
    required this.isGlobal,
    required this.index,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    if (isGlobal) {
      context.globals.add(index);

      final pendingStatements = context.pendingGlobalStatements[index];
      context.pendingGlobalStatements.remove(index);
      if (pendingStatements != null) {
        for (final pendingStatement in pendingStatements) {
          pendingStatement.mark(context);
        }
      }
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (isGlobal) {
      builder.addInstruction(LoadGlobalValueInstruction(index));
    } else {
      builder.addInstruction(LoadLocalValueInstruction(index));
    }
  }

  final bool isGlobal;
  final int index;
}

class CallFunctionAstNode extends AstNode {
  CallFunctionAstNode({
    required this.token,
    required this.usesValue,
    required this.name,
    required this.parameters,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    final definition = context.module.functions[name];
    if (definition is InBuiltScriptFunction) {
      for (final parameter in parameters) {
        parameter.mark(context);
      }
    } else if (definition is ScriptFunction) {
      if (definition.hasReturnValue ||
          (!definition.statements.isReturn() &&
              !definition.statements.isEmpty())) {
        for (final parameter in parameters) {
          parameter.mark(context);
        }

        context.functions.add(name);
        definition.mark(context);
      }
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final definition = builder.module.functions[name];
    if (definition == null) {
      throw FormatException('No such function $name ${token.location()}');
    }
    if (definition.numberOfParameters != parameters.length) {
      throw FormatException(
        '$name (${token.location()}) expects ${definition.numberOfParameters} '
        'parameters but ${parameters.length} provided',
      );
    }
    if (usesValue && !definition.hasReturnValue) {
      throw FormatException(
        '$name (${token.location()}) does not return a value',
      );
    }

    if (definition is InBuiltScriptFunction) {
      for (final parameter in parameters) {
        parameter.addInstructions(builder);
      }

      builder.addInstruction(
        CallInBuiltFunctionInstruction(definition),
      );
    } else if (definition is ScriptFunction) {
      if (definition.hasReturnValue ||
          (!definition.statements.isReturn() &&
              !definition.statements.isEmpty())) {
        for (final parameter in parameters) {
          parameter.addInstructions(builder);
        }

        builder.addInstruction(CallFunctionInstruction(name));
      }
    }

    if (!usesValue && definition.hasReturnValue) {
      builder.addInstruction(PopValueInstruction());
    }
  }

  final Token token;

  final bool usesValue;
  final String name;
  final List<AstNode> parameters;
}

class PushFunctionAddress extends AstNode {
  PushFunctionAddress({required this.token, required this.name});

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    context.functions.add(name);

    final function = context.module.functions[name] as ScriptFunction?;
    function?.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final definition = builder.module.functions[name];
    if (definition == null) {
      throw FormatException('No such function $name (${token.location()})');
    }
    builder.addInstruction(PushFunctionAddressInstruction(name));
  }

  final Token token;
  final String name;
}

class StoreValueAstNode extends AstNode {
  StoreValueAstNode({
    required this.isGlobal,
    required this.index,
    required this.expression,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    if (isGlobal) {
      if (context.globals.contains(index)) {
        expression.mark(context);
      } else {
        context.pendingGlobalStatements
            .putIfAbsent(index, () => [])
            .add(expression);
      }
    } else {
      expression.mark(context);
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (isGlobal && !builder.reachability.globals.contains(index)) {
      return;
    }

    expression.addInstructions(builder);
    if (isGlobal) {
      builder.addInstruction(StoreGlobalValueInstruction(index));
    } else {
      builder.addInstruction(StoreLocalValueInstruction(index));
    }
  }

  final bool isGlobal;
  final int index;
  final AstNode expression;
}

class StoreIndexedGlobalValueAstNode extends AstNode
    with IndexedGlobalValueMixin {
  StoreIndexedGlobalValueAstNode({
    required this.globalValueIndex,
    required this.indexExpression,
    required this.expression,
  }) {
    globalIndexOffset = IndexedGlobalValueMixin.calculateIndexOffset(
      indexExpression,
      globalValueIndex,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    if (context.globals.contains(globalValueIndex)) {
      indexExpression.mark(context);
      expression.mark(context);
    } else {
      // Storing does not mark the value as used.
      // Capture the expressions as pending evaluation.
      context.pendingGlobalStatements.putIfAbsent(globalValueIndex, () => [])
        ..add(indexExpression)
        ..add(expression);
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (builder.reachability.globals.contains(globalValueIndex)) {
      if (indexExpression.isConstant()) {
        expression.addInstructions(builder);
        builder.addInstruction(
          StoreGlobalValueInstruction(
            globalValueIndex + indexExpression.constantValue(),
          ),
        );
      } else {
        indexExpression.addInstructions(builder);
        expression.addInstructions(builder);
        builder.addInstruction(
          StoreIndexedGlobalValueInstruction(
            globalValueIndex + globalIndexOffset,
          ),
        );
      }
    }
  }

  int globalIndexOffset = 0;
  final int globalValueIndex;
  final AstNode indexExpression;
  final AstNode expression;
}

class ReturnAstNode extends AstNode {
  ReturnAstNode(this.expression);

  @override
  bool isReturn() => true;

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    expression?.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    expression?.addInstructions(builder);
    builder.addInstruction(ReturnInstruction());
  }

  AstNode? expression;
}

class CallValueAstNode extends AstNode {
  CallValueAstNode({required this.value, required this.parameters});

  @override
  bool isReturn() => false;

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  void mark(ScriptReachability context) {
    value.mark(context);
    for (final parameter in parameters) {
      parameter.mark(context);
    }
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    for (final parameter in parameters) {
      parameter.addInstructions(builder);
    }
    value.addInstructions(builder);
    builder.addInstruction(CallValueInstruction());
  }

  final AstNode value;
  final List<AstNode> parameters;
}
