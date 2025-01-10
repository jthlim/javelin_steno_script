import 'dart:typed_data';

import 'byte_code_builder.dart';
import 'executor.dart';
import 'functions.dart';
import 'instruction.dart';
import 'module.dart';
import 'token.dart';

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

  bool isPure();
  ExecutionValue? evaluate(ExecutionContext context) =>
      throw UnsupportedError('Should not be invoked');

  int constantValue();
  void addInstructions(ScriptByteCodeBuilder builder);

  void mark(ScriptReachability context) {}

  Uint8List getData() => throw UnsupportedError('Internal error');

  bool canUseAsPureParameter(ExecutionContext context) => isConstant();

  AstNode simplify() {
    if (isConstant()) {
      return IntValueAstNode(constantValue());
    }
    return this;
  }

  static const maximumEvaluationLoopCount = 32;
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
  bool isPure() => true;

  @override
  bool canUseAsPureParameter(ExecutionContext context) => true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) =>
      ExecutionValue.string(value);

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
  bool isPure() => false;

  @override
  ExecutionValue? evaluate(ExecutionContext context) =>
      throw UnsupportedError('Should not be invoked');

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
  bool isPure() => byteValue.isPure() && index.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final byteValue = this.byteValue.evaluate(context);
    if (byteValue == null || !byteValue.isString()) {
      context.state = ExecutionState.error;
      return null;
    }

    final index = this.index.evaluate(context);
    if (index == null || !index.isInt()) {
      context.state = ExecutionState.error;
      return null;
    }

    if (index.intValue < 0 ||
        index.intValue >= byteValue.stringValue!.length - 1) {
      return ExecutionValue.zero;
    }

    return ExecutionValue.int(
      byteValue.stringValue!.codeUnitAt(index.intValue + 1),
    );
  }

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
  bool isPure() => false;

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
  bool isPure() => true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    return ExecutionValue.int(value);
  }

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
  bool isPure() => statement.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final value = statement.evaluate(context);
    if (value == null) {
      context.state = ExecutionState.error;
      return null;
    }

    return evaluateUnaryOp(value);
  }

  ExecutionValue? evaluateUnaryOp(ExecutionValue a);

  @override
  int constantValue() => -statement.constantValue();

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
  ExecutionValue? evaluateUnaryOp(ExecutionValue a) {
    if (!a.isInt()) return null;
    return ExecutionValue.int(a.intValue == 0 ? 1 : 0);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.not;
}

class NegateAstNode extends UnaryOperatorAstNode {
  NegateAstNode(super.statement);

  @override
  int constantValue() => -statement.constantValue();

  @override
  ExecutionValue? evaluateUnaryOp(ExecutionValue a) {
    if (!a.isInt()) return null;
    return ExecutionValue.int(-a.intValue);
  }

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
  bool isPure() => expression.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final value = expression.evaluate(context);
    if (value == null || !value.isInt()) {
      context.state = ExecutionState.error;
      return null;
    }

    return ExecutionValue.int(~value.intValue);
  }

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
  bool isPure() => statementA.isPure() && statementB.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final a = statementA.evaluate(context);
    if (a == null) {
      context.state = ExecutionState.error;
      return null;
    }

    final b = statementB.evaluate(context);
    if (b == null) {
      context.state = ExecutionState.error;
      return null;
    }
    return evaluateBinaryOp(a, b);
  }

  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b);

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
  bool isPure() => terms.every((e) => e.statement.isPure());

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    ExecutionValue? result = ExecutionValue.zero;
    for (final term in terms) {
      final value = term.statement.evaluate(context);
      if (value == null ||
          result == null ||
          context.state != ExecutionState.running) {
        context.state = ExecutionState.error;
        return null;
      }
      switch (term.mode) {
        case TermMode.add:
          result = result + value;
          break;
        case TermMode.subtract:
          result = result - value;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue * b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.multiply;
}

class QuotientAstNode extends BinaryOperatorAstNode {
  QuotientAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ~/ statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue ~/ b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.quotient;
}

class RemainderAstNode extends BinaryOperatorAstNode {
  RemainderAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue().remainder(statementB.constantValue());

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue.remainder(b.intValue));
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.remainder;
}

class BitwiseAndAstNode extends BinaryOperatorAstNode {
  BitwiseAndAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() & statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue & b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseAnd;
}

class BitwiseOrAstNode extends BinaryOperatorAstNode {
  BitwiseOrAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() | statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue | b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseOr;
}

class BitwiseXorAstNode extends BinaryOperatorAstNode {
  BitwiseXorAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ^ statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue ^ b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.bitwiseXor;
}

class BitShiftLeftAstNode extends BinaryOperatorAstNode {
  BitShiftLeftAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() << statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue << b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.shiftLeft;
}

class ArithmeticBitShiftRightAstNode extends BinaryOperatorAstNode {
  ArithmeticBitShiftRightAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() >> statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue >> b.intValue);
  }

  @override
  ScriptOperatorOpcode get opcode => ScriptOperatorOpcode.arithmeticShiftRight;
}

class LogicalBitShiftRightAstNode extends BinaryOperatorAstNode {
  LogicalBitShiftRightAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() >>> statementB.constantValue();

  @override
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return ExecutionValue.int(a.intValue >>> b.intValue);
  }

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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    // OK to do full evaluation here if there are no side effects.
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue != 0 && b.intValue != 0
        ? ExecutionValue.one
        : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    // OK to do full evaluation here if there are no side effects.
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue != 0 || b.intValue != 0
        ? ExecutionValue.one
        : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue == b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue != b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue < b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue <= b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue > b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  ExecutionValue? evaluateBinaryOp(ExecutionValue a, ExecutionValue b) {
    if (!a.isInt() || !b.isInt()) {
      return null;
    }
    return a.intValue >= b.intValue ? ExecutionValue.one : ExecutionValue.zero;
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
  bool isPure() => true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    return null;
  }

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
  bool isPure() =>
      (initialization?.isPure() ?? true) &&
      (condition?.isPure() ?? true) &&
      (update?.isPure() ?? true) & body.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    initialization?.evaluate(context);
    if (context.state != ExecutionState.running) {
      return null;
    }
    for (var loopCount = 0;
        loopCount < AstNode.maximumEvaluationLoopCount;
        ++loopCount) {
      final condition = this.condition;
      if (condition != null) {
        final conditionValue = condition.evaluate(context);
        if (conditionValue == null) {
          context.state = ExecutionState.error;
          return null;
        }
        if (conditionValue.isFalse()) {
          return null;
        }
      }

      final value = body.evaluate(context);
      if (value != null) {
        throw UnsupportedError('Internal error');
      }
      switch (context.state) {
        case ExecutionState.running:
          break;
        case ExecutionState.finished:
          return null;
        case ExecutionState.timeout:
          return null;
        case ExecutionState.error:
          return null;
        case ExecutionState.doBreak:
          context.state = ExecutionState.running;
          return null;
        case ExecutionState.doContinue:
          context.state = ExecutionState.running;
          break;
      }

      final updateValue = update?.evaluate(context);
      if (updateValue != null) {
        context.state = ExecutionState.error;
        return null;
      }
    }

    context.state = ExecutionState.timeout;
    return null;
  }

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

    if (condition != null &&
        condition.isConstant() &&
        condition.constantValue() == 0) {
      return;
    }

    final originalContinueTargets = builder.continueTargets;
    final originalBreakTargets = builder.breakTargets;
    final continueTargets = <NopInstruction>[];
    final breakTargets = <NopInstruction>[];
    builder.continueTargets = continueTargets;
    builder.breakTargets = breakTargets;

    final jumpToConditionInstruction = JumpInstruction();
    builder.addInstruction(jumpToConditionInstruction.target);

    if (condition != null &&
        !(condition.isConstant() && condition.constantValue() != 0)) {
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
      breakTargets.add(jumpToEndInstruction.target);
    }

    body.addInstructions(builder);
    for (final continueTarget in continueTargets) {
      builder.addInstruction(continueTarget);
    }
    update?.addInstructions(builder);
    builder.addInstruction(jumpToConditionInstruction);
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
  bool isPure() => body.isPure() && condition.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    if (context.state != ExecutionState.running) {
      return null;
    }
    for (var loopCount = 0;
        loopCount < AstNode.maximumEvaluationLoopCount;
        ++loopCount) {
      final value = body.evaluate(context);
      if (value != null) {
        throw UnsupportedError('Internal error');
      }
      switch (context.state) {
        case ExecutionState.running:
          break;
        case ExecutionState.finished:
          return null;
        case ExecutionState.timeout:
          return null;
        case ExecutionState.error:
          return null;
        case ExecutionState.doBreak:
          context.state = ExecutionState.running;
          return null;
        case ExecutionState.doContinue:
          context.state = ExecutionState.running;
          break;
      }

      final conditionValue = condition.evaluate(context);
      if (conditionValue == null) {
        context.state = ExecutionState.error;
        return null;
      }
      if (conditionValue.isFalse()) {
        return null;
      }
    }

    context.state = ExecutionState.timeout;
    return null;
  }

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
  bool isPure() {
    if (condition.isConstant()) {
      final value = condition.constantValue();
      if (value != 0) return whenTrue.isPure();
      return whenFalse?.isPure() ?? true;
    }

    return condition.isPure() &&
        whenTrue.isPure() &&
        (whenFalse?.isPure() ?? true);
  }

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final conditionValue = condition.evaluate(context);
    if (conditionValue == null) {
      context.state = ExecutionState.error;
      return null;
    }
    if (conditionValue.isTrue()) {
      return whenTrue.evaluate(context);
    } else {
      return whenFalse?.evaluate(context);
    }
  }

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
  bool isPure() => true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    context.state = ExecutionState.doBreak;
    return null;
  }

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
  bool isPure() => true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    context.state = ExecutionState.doContinue;
    return null;
  }

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
  bool isPure() => statements.every((e) => e.isPure());

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    for (final statement in statements) {
      final value = statement.evaluate(context);
      if (value != null) {
        throw UnsupportedError('Internal error');
      }
      if (context.state != ExecutionState.running) {
        return null;
      }
    }
    return null;
  }

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
  bool isPure() => false;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    throw Exception('Global value array ${global.name} must be indexed');
  }

  final ScriptGlobal global;
}

class LoadLocalValueArrayAstNode extends AstNode {
  LoadLocalValueArrayAstNode(this.local);

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => throw UnsupportedError('Should not be invoked');

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    return ExecutionValue.int(local.index);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    throw Exception('Local value array ${local.name} must be indexed');
  }

  final ScriptLocalVariable local;
}

mixin IndexedValueMixin {
  static int calculateIndexOffset(
    AstNode indexExpression,
    int valueIndex,
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

    final index = valueIndex + offset;
    if (index < 0 || index > 255) {
      return 0;
    }

    indexExpression.terms.removeWhere((e) => e.statement.isConstant());
    return offset;
  }
}

class LoadIndexedGlobalValueAstNode extends AstNode with IndexedValueMixin {
  LoadIndexedGlobalValueAstNode(this.globalValue, this.indexExpression) {
    globalIndexOffset = IndexedValueMixin.calculateIndexOffset(
      indexExpression,
      globalValue.global.index,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => false;

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

class LoadIndexedLocalValueAstNode extends AstNode with IndexedValueMixin {
  LoadIndexedLocalValueAstNode(this.localValue, this.indexExpression) {
    localIndexOffset = IndexedValueMixin.calculateIndexOffset(
      indexExpression,
      localValue.local.index,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => indexExpression.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final index = indexExpression.evaluate(context);
    if (index == null || !index.isInt()) {
      context.state = ExecutionState.error;
      return null;
    }
    return context.locals[localValue.local.index + index.intValue];
  }

  @override
  void mark(ScriptReachability context) {
    indexExpression.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (indexExpression.isConstant()) {
      builder.addInstruction(
        LoadLocalValueInstruction(
          localValue.local.index + indexExpression.constantValue(),
        ),
      );
    } else {
      indexExpression.addInstructions(builder);
      builder.addInstruction(
        LoadIndexedLocalValueInstruction(
          localValue.local.index + localIndexOffset,
        ),
      );
    }
  }

  int localIndexOffset = 0;
  final LoadLocalValueArrayAstNode localValue;
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
  bool isPure() => !isGlobal;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    return context.locals[index];
  }

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
  bool isPure() => false;

  @override
  bool canUseAsPureParameter(ExecutionContext context) {
    updateEvaluation(context);
    return evaluationResult?.isInt() ?? false;
  }

  @override
  ExecutionValue? evaluate(ExecutionContext context) => evaluationResult;

  void updateEvaluation(ExecutionContext context) {
    if (hasEvaluated) return;
    hasEvaluated = true;

    if (context.scriptCallDepth > ExecutionContext.maxScriptCallDepth) {
      return;
    }

    final definition = context.module.functions[name];
    if (definition is! ScriptFunction) return;
    if (!definition.isPure()) return;
    if (!definition.hasReturnValue || !usesValue) return;

    context.scriptCallDepth++;

    if (parameters.every((e) => e.canUseAsPureParameter(context))) {
      var offset = 0;
      final localContext =
          ExecutionContext(definition.numberOfLocals, context.module);
      localContext.scriptCallDepth = context.scriptCallDepth;
      for (final parameter in parameters) {
        localContext.locals[offset++] = parameter.evaluate(localContext)!;
      }
      evaluationResult = definition.evaluate(localContext);
    }

    context.scriptCallDepth--;
  }

  @override
  void mark(ScriptReachability context) {
    final definition = context.module.functions[name];
    if (definition is InBuiltScriptFunction) {
      for (final parameter in parameters) {
        parameter.mark(context);
      }
    } else if (definition is ScriptFunction) {
      updateEvaluation(ExecutionContext(0, context.module));
      if (evaluationResult?.isInt() ?? false) {
        return;
      }

      for (final parameter in parameters) {
        parameter.mark(context);
      }

      context.functions.add(name);
      definition.mark(context);
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
      if (definition.isPure()) {
        if (!definition.hasReturnValue || !usesValue) return;

        if (evaluationResult?.isInt() ?? false) {
          builder.addInstruction(
            PushIntValueInstruction(evaluationResult!.intValue),
          );
          return;
        }
      }
      for (final parameter in parameters) {
        parameter.addInstructions(builder);
      }

      builder.addInstruction(CallFunctionInstruction(name));
    }

    if (!usesValue && definition.hasReturnValue) {
      builder.addInstruction(PopValueInstruction());
    }
  }

  final Token token;

  final bool usesValue;
  final String name;
  final List<AstNode> parameters;

  var hasEvaluated = false;
  ExecutionValue? evaluationResult;
}

class PushFunctionAddress extends AstNode {
  PushFunctionAddress({required this.token, required this.name});

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => false;

  @override
  void mark(ScriptReachability context) {
    context.functions.add(name);

    final function = context.module.functions[name];
    if (function == null) return;
    if (function is! ScriptFunction) {
      throw FormatException(
        'Cannot use address of inbuilt function ${function.functionName} '
        'near $token',
      );
    }
    function.mark(context);
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
  bool isPure() => !isGlobal && expression.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    assert(!isGlobal);
    final value = expression.evaluate(context);
    if (value == null) {
      context.state = ExecutionState.error;
      return null;
    }
    context.locals[index] = value;
    return null;
  }

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

class StoreIndexedGlobalValueAstNode extends AstNode with IndexedValueMixin {
  StoreIndexedGlobalValueAstNode({
    required this.globalValueIndex,
    required this.indexExpression,
    required this.expression,
  }) {
    globalIndexOffset = IndexedValueMixin.calculateIndexOffset(
      indexExpression,
      globalValueIndex,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => false;

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

class StoreIndexedLocalValueAstNode extends AstNode with IndexedValueMixin {
  StoreIndexedLocalValueAstNode({
    required this.localValueIndex,
    required this.indexExpression,
    required this.expression,
  }) {
    localIndexOffset = IndexedValueMixin.calculateIndexOffset(
      indexExpression,
      localValueIndex,
    );
  }

  @override
  bool isConstant() => false;

  @override
  int constantValue() => throw UnsupportedError('Should not be invoked');

  @override
  bool isPure() => indexExpression.isPure() && expression.isPure();

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final index = indexExpression.evaluate(context);
    if (index == null || !index.isInt()) {
      context.state = ExecutionState.error;
      return null;
    }
    final value = expression.evaluate(context);
    if (value == null) {
      context.state = ExecutionState.error;
      return null;
    }
    context.locals[localValueIndex + index.intValue] = value;
    return null;
  }

  @override
  void mark(ScriptReachability context) {
    indexExpression.mark(context);
    expression.mark(context);
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (indexExpression.isConstant()) {
      expression.addInstructions(builder);
      builder.addInstruction(
        StoreLocalValueInstruction(
          localValueIndex + indexExpression.constantValue(),
        ),
      );
    } else {
      indexExpression.addInstructions(builder);
      expression.addInstructions(builder);
      builder.addInstruction(
        StoreIndexedLocalValueInstruction(
          localValueIndex + localIndexOffset,
        ),
      );
    }
  }

  int localIndexOffset = 0;
  final int localValueIndex;
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
  bool isPure() => expression?.isPure() ?? true;

  @override
  ExecutionValue? evaluate(ExecutionContext context) {
    final expression = this.expression;
    if (expression == null) {
      context.state = ExecutionState.finished;
      return null;
    }

    final value = expression.evaluate(context);
    if (value == null) {
      context.state = ExecutionState.error;
      return null;
    }
    context.returnValue = value;
    context.state = ExecutionState.finished;
    return null;
  }

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
  bool isPure() => false;

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
