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
      if (instruction is NopScriptInstruction) {
        final reference = instruction.reference;
        if (reference is JumpScriptInstruction) {
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
      if (instruction is PushIntValueScriptInstruction) {
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
      if (instruction is JumpScriptInstruction) {
        instruction = instruction.target;
        continue;
      }
      if (instruction is NopScriptInstruction) {
        instruction = instruction.next;
        continue;
      }
      if (instruction is OpcodeScriptInstruction &&
          instruction.opcode == ScriptOperatorOpcode.not) {
        isNonZero = !isNonZero;
        instruction = instruction.next;
        continue;
      }
      if (instruction is JumpIfZeroScriptInstruction) {
        final jumpInstruction = JumpScriptInstruction();
        if (isNonZero) {
          instruction.insertAfter(jumpInstruction.target);
        } else {
          instruction.target.insertBefore(jumpInstruction.target);
        }
        return jumpInstruction;
      }
      if (instruction is JumpIfNotZeroScriptInstruction) {
        final jumpInstruction = JumpScriptInstruction();
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
      if (instruction is JumpScriptInstructionBase) {
        final target = instruction.target.nextNonNopInstruction;
        ScriptInstruction? replacement;
        if (target is ReturnScriptInstruction) {
          if (instruction is JumpScriptInstruction) {
            replacement = ReturnScriptInstruction();
          }
        } else if (target is JumpScriptInstructionBase) {
          replacement = replaceJumpPair(instruction, target);
        } else if (target is JumpFunctionScriptInstruction) {
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
        if (nextInstruction is ReturnScriptInstruction) {
          final jumpInstruction =
              JumpFunctionScriptInstruction(instruction.functionName);

          instruction.replaceWith(jumpInstruction);
          nextInstruction.unlink();

          instruction = jumpInstruction;
        } else if (nextInstruction is NopScriptInstruction) {
          final nextNonNop = nextInstruction.nextNonNopInstruction;
          if (nextNonNop is ReturnScriptInstruction) {
            final jumpInstruction =
                JumpFunctionScriptInstruction(instruction.functionName);

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
        if (instruction is JumpScriptInstructionBase &&
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
      if (instruction is! JumpScriptInstructionBase ||
          !instruction.isJumpToNext()) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.target.next;
      if (instruction is JumpScriptInstruction) {
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
      if (instruction is! JumpScriptInstructionBase ||
          !instruction.isJumpToNext()) {
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
      if (instruction is! JumpScriptInstructionBase ||
          !instruction.isConditional()) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.next!;
      if (next is! JumpScriptInstruction) {
        instruction = instruction.next;
        continue;
      }

      if (instruction.target != next.next) {
        instruction = instruction.next;
        continue;
      }

      final label2 = next.target;
      late final JumpScriptInstructionBase replacementInstruction;
      if (instruction is JumpIfZeroScriptInstruction) {
        replacementInstruction = JumpIfNotZeroScriptInstruction();
      } else if (instruction is JumpIfNotZeroScriptInstruction) {
        replacementInstruction = JumpIfZeroScriptInstruction();
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
      if (instruction is! OpcodeScriptInstruction ||
          instruction.opcode != ScriptOperatorOpcode.not) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.next;
      final previous = instruction.previous!;
      if (previous.isBooleanResult &&
          next is OpcodeScriptInstruction &&
          next.opcode == ScriptOperatorOpcode.not) {
        final nextNext = next.next;
        instruction.unlink();
        next.unlink();
        instruction = nextNext;
        continue;
      } else if (previous is OpcodeScriptInstruction &&
          previous.opcode.opposite != null) {
        final opposite = previous.opcode.opposite!;
        previous.replaceWith(OpcodeScriptInstruction(opposite));
        instruction.unlink();
      } else if (next is OpcodeScriptInstruction &&
          next.opcode == ScriptOperatorOpcode.not) {
        final nextNext = next.next;
        if (nextNext is OpcodeScriptInstruction &&
            nextNext.opcode == ScriptOperatorOpcode.not) {
          next.unlink();
          nextNext.unlink();
          continue;
        }
      } else if (next is JumpIfZeroScriptInstruction) {
        final replacement = JumpIfNotZeroScriptInstruction();
        next.target.insertAfter(replacement.target);
        next.replaceWith(replacement);
        instruction.unlink();
        instruction = previous;
        continue;
      } else if (next is JumpIfNotZeroScriptInstruction) {
        final replacement = JumpIfZeroScriptInstruction();
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
      JumpScriptInstructionBase first, JumpFunctionScriptInstruction second) {
    if (first is JumpScriptInstruction) {
      return JumpFunctionScriptInstruction(second.functionName);
    } else if (first is JumpIfZeroScriptInstruction) {
      return JumpIfZeroFunctionScriptInstruction(second.functionName);
    } else if (first is JumpIfNotZeroScriptInstruction) {
      return JumpIfNotZeroFunctionScriptInstruction(second.functionName);
    } else {
      throw Exception('Internal error: Unexpected jump type $first');
    }
  }

  static JumpScriptInstructionBase? replaceJumpPair(
      JumpScriptInstructionBase first, JumpScriptInstructionBase second) {
    if (first is JumpScriptInstruction) {
      if (second is JumpScriptInstruction) {
        final result = JumpScriptInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroScriptInstruction ||
          second is JumpIfNotZeroScriptInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else if (first is JumpIfZeroScriptInstruction) {
      if (second is JumpScriptInstruction) {
        final result = JumpIfZeroScriptInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroScriptInstruction ||
          second is JumpIfNotZeroScriptInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else if (first is JumpIfNotZeroScriptInstruction) {
      if (second is JumpScriptInstruction) {
        final result = JumpIfNotZeroScriptInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroScriptInstruction ||
          second is JumpIfNotZeroScriptInstruction) {
        return null;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else {
      throw Exception('Internal error: Unexpected jump type $first');
    }
  }
}
