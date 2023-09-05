import 'dart:collection';

import 'instruction.dart';

class InstructionList extends Iterable<ScriptInstruction> {
  final instructions = LinkedList<ScriptInstruction>();

  void add(ScriptInstruction instruction) {
    instructions.add(instruction);
  }

  void removeLast() {
    instructions.last.unlink();
  }

  @override
  Iterator<ScriptInstruction> get iterator => instructions.iterator;

  void optimize() {
    optimizeNot();
    optimizeTrueFalseJumps();
    optimizeRightFactor();
    optimizeJumpTarget();
    optimizeRightFactor();
    optimizeCallReturn();
    optimizeDeadCode();
    optimizeJumpToNext();
    optimizeConditionalJumpOverJump();
    optimizeNot();
    optimizeConditionalJumpToNext();
  }

  void optimizeRightFactor() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is NopInstruction) {
        final reference = instruction.reference;
        if (reference is JumpInstruction) {
          final previousInstruction =
              instruction.previous?.previousNonNopInstruction;
          final previousReferenceInstruction = reference.previous;

          if (previousInstruction != null &&
              previousInstruction.implicitNext &&
              previousReferenceInstruction != null &&
              previousInstruction == previousReferenceInstruction) {
            reference.unlink();
            previousInstruction.insertBefore(instruction);
            previousReferenceInstruction.insertBefore(reference);
            continue;
          }
        }
      }
      instruction = instruction.next;
    }
  }

  void optimizeTrueFalseJumps() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is PushIntValueInstruction) {
        final value = instruction.value;
        if (value == 0 || value == 1) {
          ScriptInstruction? jumpInstruction =
              findFixedJumpTarget(instruction.next, value != 0);
          if (jumpInstruction != null) {
            instruction.replaceWith(jumpInstruction);
            instruction = jumpInstruction;
          }
        }
      }

      instruction = instruction.next;
    }
  }

  // Resolves true/false followed by conditional jump.
  static ScriptInstruction? findFixedJumpTarget(
    ScriptInstruction? instruction,
    bool isNonZero,
  ) {
    for (;;) {
      if (instruction is JumpInstruction) {
        instruction = instruction.target;
        continue;
      }
      if (instruction is NopInstruction) {
        instruction = instruction.next;
        continue;
      }
      if (instruction is OpcodeInstruction &&
          instruction.opcode == ScriptOperatorOpcode.not) {
        isNonZero = !isNonZero;
        instruction = instruction.next;
        continue;
      }
      if (instruction is JumpIfZeroInstruction) {
        final jumpInstruction = JumpInstruction();
        if (isNonZero) {
          instruction.insertAfter(jumpInstruction.target);
        } else {
          instruction.target.insertBefore(jumpInstruction.target);
        }
        return jumpInstruction;
      }
      if (instruction is JumpIfNotZeroInstruction) {
        final jumpInstruction = JumpInstruction();
        if (isNonZero) {
          instruction.target.insertBefore(jumpInstruction.target);
        } else {
          instruction.insertAfter(jumpInstruction.target);
        }
        return jumpInstruction;
      }
      return null;
    }
  }

  void optimizeJumpTarget() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is JumpInstructionBase) {
        final target = instruction.target.nextNonNopInstruction;
        ScriptInstruction? replacement;
        if (target is ReturnInstruction) {
          if (instruction is JumpInstruction) {
            replacement = ReturnInstruction();
          }
        } else if (target is JumpInstructionBase) {
          replacement = replaceJumpPair(instruction, target);
        } else if (target is JumpFunctionInstruction) {
          replacement = replaceJumpToFunction(instruction, target);
        }

        if (replacement != null) {
          instruction.replaceWith(replacement);
          instruction = replacement;
        }
      }
      instruction = instruction.next;
    }
  }

  void optimizeCallReturn() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is CallFunctionInstruction) {
        final nextInstruction = instruction.next;
        if (nextInstruction is ReturnInstruction) {
          final jumpInstruction =
              JumpFunctionInstruction(instruction.functionName);

          instruction.replaceWith(jumpInstruction);
          nextInstruction.unlink();

          instruction = jumpInstruction;
        } else if (nextInstruction is NopInstruction) {
          final nextNonNop = nextInstruction.nextNonNopInstruction;
          if (nextNonNop is ReturnInstruction) {
            final jumpInstruction =
                JumpFunctionInstruction(instruction.functionName);

            instruction.replaceWith(jumpInstruction);
            instruction = jumpInstruction;
          }
        }
      } else if (instruction is CallValueInstruction) {
        final nextInstruction = instruction.next;
        if (nextInstruction is ReturnInstruction) {
          final jumpInstruction = JumpValueInstruction();

          instruction.replaceWith(jumpInstruction);
          nextInstruction.unlink();

          instruction = jumpInstruction;
        } else if (nextInstruction is NopInstruction) {
          final nextNonNop = nextInstruction.nextNonNopInstruction;
          if (nextNonNop is ReturnInstruction) {
            final jumpInstruction = JumpValueInstruction();

            instruction.replaceWith(jumpInstruction);
            instruction = jumpInstruction;
          }
        }
      }

      instruction = instruction.next;
    }
  }

  void optimizeDeadCode() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      var next = instruction.next;
      if (!instruction.hasReference) {
        if (instruction is JumpInstructionBase &&
            identical(instruction.next, instruction.target)) {
          next = instruction.target.next;
        }
        instruction.unlink();
      }
      instruction = next;
    }
  }

  void optimizeJumpToNext() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is! JumpInstructionBase || !instruction.isJumpToNext()) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.target.next;
      if (instruction is JumpInstruction) {
        instruction.unlink();
      }
      instruction = next;
    }
  }

  void optimizeConditionalJumpToNext() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is! JumpInstructionBase || !instruction.isJumpToNext()) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.target.next;
      if (instruction.isConditional()) {
        instruction.insertAfter(PopValueInstruction());
        instruction.unlink();
      }
      instruction = next;
    }
  }

  void optimizeConditionalJumpOverJump() {
    // Optimizes the sequence:
    //    jnz <label1>
    //    jmp <label2>
    //  label1:
    //
    // To:
    //    jz <label2>
    //
    // And vice versa for jz.

    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is! JumpInstructionBase || !instruction.isConditional()) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.next;
      if (next is! JumpInstruction) {
        instruction = instruction.next;
        continue;
      }

      if (!identical(instruction.target, next.next)) {
        instruction = instruction.next;
        continue;
      }

      final label2 = next.target;
      late final JumpInstructionBase replacementInstruction;
      if (instruction is JumpIfZeroInstruction) {
        replacementInstruction = JumpIfNotZeroInstruction();
      } else if (instruction is JumpIfNotZeroInstruction) {
        replacementInstruction = JumpIfZeroInstruction();
      }
      label2.insertAfter(replacementInstruction.target);
      instruction.insertAfter(replacementInstruction);

      final nextInstructionToProcess = instruction.target.next;

      instruction.unlink();
      next.unlink();

      instruction = nextInstructionToProcess;
    }
  }

  void optimizeNot() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is! OpcodeInstruction ||
          instruction.opcode != ScriptOperatorOpcode.not) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.next;
      final previous = instruction.previous!;
      if (previous.isBooleanResult &&
          next is OpcodeInstruction &&
          next.opcode == ScriptOperatorOpcode.not) {
        final nextNext = next.next;
        instruction.unlink();
        next.unlink();
        instruction = nextNext;
        continue;
      } else if (previous is OpcodeInstruction &&
          previous.opcode.opposite != null) {
        final opposite = previous.opcode.opposite!;
        previous.replaceWith(OpcodeInstruction(opposite));
        instruction.unlink();
      } else if (next is OpcodeInstruction &&
          next.opcode == ScriptOperatorOpcode.not) {
        final nextNext = next.next;
        if (nextNext is OpcodeInstruction &&
            nextNext.opcode == ScriptOperatorOpcode.not) {
          next.unlink();
          nextNext.unlink();
          continue;
        }
      } else if (next is JumpIfZeroInstruction) {
        final replacement = JumpIfNotZeroInstruction();
        next.target.insertAfter(replacement.target);
        next.replaceWith(replacement);
        instruction.unlink();
        instruction = previous;
        continue;
      } else if (next is JumpIfNotZeroInstruction) {
        final replacement = JumpIfZeroInstruction();
        final previous = instruction.previous!;
        next.target.insertAfter(replacement.target);
        next.replaceWith(replacement);
        instruction.unlink();
        instruction = previous;
        continue;
      }
      instruction = next;
    }
  }

  static ScriptInstruction? replaceJumpToFunction(
      JumpInstructionBase first, JumpFunctionInstruction second) {
    if (first is JumpInstruction) {
      return JumpFunctionInstruction(second.functionName);
    } else if (first is JumpIfZeroInstruction) {
      return JumpIfZeroFunctionInstruction(second.functionName);
    } else if (first is JumpIfNotZeroInstruction) {
      return JumpIfNotZeroFunctionInstruction(second.functionName);
    } else {
      throw Exception('Internal error: Unexpected jump type $first');
    }
  }

  static JumpInstructionBase? replaceJumpPair(
      JumpInstructionBase first, JumpInstructionBase second) {
    if (first is JumpInstruction) {
      if (second is JumpInstruction) {
        final result = JumpInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroInstruction ||
          second is JumpIfNotZeroInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else if (first is JumpIfZeroInstruction) {
      if (second is JumpInstruction) {
        final result = JumpIfZeroInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroInstruction ||
          second is JumpIfNotZeroInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else if (first is JumpIfNotZeroInstruction) {
      if (second is JumpInstruction) {
        final result = JumpIfNotZeroInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroInstruction ||
          second is JumpIfNotZeroInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else {
      throw Exception('Internal error: Unexpected jump type $first');
    }
  }
}
