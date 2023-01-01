import 'instruction.dart';
import 'byte_code_builder.dart';
import 'module.dart';

abstract class AstNode {
  bool isConstant();
  int constantValue();
  void addInstructions(ScriptByteCodeBuilder builder);

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
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    builder.stringTable[value] = 0;
    builder.addInstruction(PushStringValueScriptInstruction(value));
  }

  final String value;
}

class IntValueAstNode extends AstNode {
  IntValueAstNode(this.value);

  @override
  bool isConstant() => true;

  @override
  int constantValue() => value;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    builder.addInstruction(PushIntValueScriptInstruction(value));
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
  void addInstructions(ScriptByteCodeBuilder builder) {
    statement.addInstructions(builder);
    builder.addInstruction(OpcodeScriptInstruction(opcode));
  }

  ScriptOpCode get opcode;

  final AstNode statement;
}

class NotAstNode extends UnaryOperatorAstNode {
  NotAstNode(super.statement);

  @override
  int constantValue() => statement.constantValue() == 0 ? 1 : 0;

  @override
  ScriptOpCode get opcode => ScriptOpCode.not;
}

class NegateAstNode extends UnaryOperatorAstNode {
  NegateAstNode(super.statement);

  @override
  int constantValue() => -statement.constantValue();

  @override
  ScriptOpCode get opcode => ScriptOpCode.negative;
}

abstract class BinaryOperatorAstNode extends AstNode {
  BinaryOperatorAstNode(this.statementA, this.statementB);

  @override
  bool isConstant() => statementA.isConstant() && statementB.isConstant();

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    statementA.addInstructions(builder);
    statementB.addInstructions(builder);
    builder.addInstruction(OpcodeScriptInstruction(opcode));
  }

  ScriptOpCode get opcode;

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
  int constantValue() {
    var result = 0;
    for (final term in terms) {
      int value = term.statement.constantValue();
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
    bool isFirst = true;
    for (final term in terms) {
      term.statement.addInstructions(builder);
      if (isFirst) {
        isFirst = false;
      } else {
        switch (term.mode) {
          case TermMode.add:
            builder.addInstruction(OpcodeScriptInstruction(ScriptOpCode.add));
            break;
          case TermMode.subtract:
            builder
                .addInstruction(OpcodeScriptInstruction(ScriptOpCode.subtract));
            break;
        }
      }
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
  ScriptOpCode get opcode => ScriptOpCode.multiply;
}

class QuotientAstNode extends BinaryOperatorAstNode {
  QuotientAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ~/ statementB.constantValue();

  @override
  ScriptOpCode get opcode => ScriptOpCode.quotient;
}

class RemainderAstNode extends BinaryOperatorAstNode {
  RemainderAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue().remainder(statementB.constantValue());

  @override
  ScriptOpCode get opcode => ScriptOpCode.remainder;
}

class BitwiseAndAstNode extends BinaryOperatorAstNode {
  BitwiseAndAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() & statementB.constantValue();

  @override
  ScriptOpCode get opcode => ScriptOpCode.bitwiseAnd;
}

class BitwiseOrAstNode extends BinaryOperatorAstNode {
  BitwiseOrAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() | statementB.constantValue();

  @override
  ScriptOpCode get opcode => ScriptOpCode.bitwiseOr;
}

class BitwiseXorAstNode extends BinaryOperatorAstNode {
  BitwiseXorAstNode(super.statementA, super.statementB);

  @override
  int constantValue() =>
      statementA.constantValue() ^ statementB.constantValue();

  @override
  ScriptOpCode get opcode => ScriptOpCode.bitwiseXor;
}

class LogicalAndAstNode extends BinaryOperatorAstNode {
  LogicalAndAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() != 0 && statementB.constantValue() != 0) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.logicalAnd;
}

class LogicalOrAstNode extends BinaryOperatorAstNode {
  LogicalOrAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() != 0 || statementB.constantValue() != 0) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.logicalOr;
}

class EqualsAstNode extends BinaryOperatorAstNode {
  EqualsAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() == statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (statementA.isConstant() && statementA.constantValue() == 0) {
      statementB.addInstructions(builder);
      builder.addInstruction(OpcodeScriptInstruction(ScriptOpCode.not));
    } else if (statementB.isConstant() && statementB.constantValue() == 0) {
      statementA.addInstructions(builder);
      builder.addInstruction(OpcodeScriptInstruction(ScriptOpCode.not));
    } else {
      super.addInstructions(builder);
    }
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.equals;
}

class NotEqualsAstNode extends BinaryOperatorAstNode {
  NotEqualsAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() != statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.notEquals;
}

class LessThanAstNode extends BinaryOperatorAstNode {
  LessThanAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() < statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.lessThan;
}

class LessThanOrEqualToAstNode extends BinaryOperatorAstNode {
  LessThanOrEqualToAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() <= statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.lessThanOrEqualTo;
}

class GreaterThanAstNode extends BinaryOperatorAstNode {
  GreaterThanAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() > statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.greaterThan;
}

class GreaterThanOrEqualToAstNode extends BinaryOperatorAstNode {
  GreaterThanOrEqualToAstNode(super.statementA, super.statementB);

  @override
  int constantValue() {
    if (statementA.constantValue() >= statementB.constantValue()) {
      return 1;
    }
    return 0;
  }

  @override
  ScriptOpCode get opcode => ScriptOpCode.greaterThanOrEqualTo;
}

class NopAstNode extends AstNode {
  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {}
}

class IfStatementAstNode extends AstNode {
  IfStatementAstNode({
    required this.condition,
    required this.whenTrue,
    this.whenFalse,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    if (condition.isConstant()) {
      if (condition.constantValue() != 0) {
        whenTrue.addInstructions(builder);
      } else {
        whenFalse?.addInstructions(builder);
      }
    } else {
      final endNop = NopScriptInstruction();
      final elseNop = NopScriptInstruction();
      condition.addInstructions(builder);

      final lastInstruction = builder.instructions.last;
      if (lastInstruction is OpcodeScriptInstruction &&
          lastInstruction.opcode == ScriptOpCode.not) {
        builder.instructions.removeLast();
        builder.addInstruction(JumpIfNotZeroScriptInstruction(elseNop));
      } else {
        builder.addInstruction(JumpIfZeroScriptInstruction(elseNop));
      }

      whenTrue.addInstructions(builder);
      if (whenFalse != null) {
        builder.addInstruction(JumpScriptInstruction(endNop));
      }
      builder.addInstruction(elseNop);
      whenFalse?.addInstructions(builder);
      if (whenFalse != null) {
        builder.addInstruction(endNop);
      }
    }
  }

  final AstNode condition;
  final AstNode whenTrue;
  final AstNode? whenFalse;
}

class StatementListAstNode extends AstNode {
  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    for (final statement in statements) {
      statement.addInstructions(builder);
    }
  }

  final statements = <AstNode>[];

  void add(AstNode statement) => statements.add(statement);
}

class LoadParamAstNode extends AstNode {
  LoadParamAstNode({
    required this.index,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    builder.addInstruction(LoadParamInstruction(index));
  }

  final int index;
}

class LoadValueAstNode extends AstNode {
  LoadValueAstNode({
    required this.isGlobal,
    required this.index,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

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
    required this.usesValue,
    required this.name,
    required this.parameters,
  });

  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    final definition = builder.module.functions[name];
    if (definition == null) {
      throw FormatException('No such function $name');
    }
    if (definition.numberOfParameters != parameters.length) {
      throw FormatException(
        '$name expects ${definition.numberOfParameters} parameters '
        'but ${parameters.length} provided',
      );
    }
    if (usesValue && !definition.hasReturnValue) {
      throw FormatException('$name does not return a value');
    }

    for (final parameter in parameters) {
      parameter.addInstructions(builder);
    }

    if (definition is InBuiltScriptFunction) {
      builder.addInstruction(
        CallInBuiltFunctionInstruction(definition.functionIndex),
      );
    } else {
      builder.addInstruction(CallFunctionInstruction(name));
    }
  }

  final bool usesValue;
  final String name;
  final List<AstNode> parameters;
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
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
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

class ReturnAstNode extends AstNode {
  ReturnAstNode(this.expression);

  @override
  bool isConstant() => false;

  @override
  int constantValue() => 0;

  @override
  void addInstructions(ScriptByteCodeBuilder builder) {
    expression?.addInstructions(builder);
    builder.addInstruction(ReturnScriptInstruction());
  }

  AstNode? expression;
}
