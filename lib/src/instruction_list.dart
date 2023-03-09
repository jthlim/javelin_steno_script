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
    optimizeJumpTarget();
    optimizeRightFactor();
    optimizeCallReturn();
    optimizeDeadCode();
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
      final next = instruction.next;
      if (!instruction.hasReference) {
        instruction.unlink();
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
      if (second is JumpScriptInstruction ||
          second is JumpIfZeroScriptInstruction) {
        final result = JumpIfZeroScriptInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfNotZeroScriptInstruction) {
        final result = JumpIfZeroScriptInstruction();
        second.target.nextNonNopInstruction.insertAfter(result.target);
        return result;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else if (first is JumpIfNotZeroScriptInstruction) {
      if (second is JumpScriptInstruction ||
          second is JumpIfNotZeroScriptInstruction) {
        final result = JumpIfNotZeroScriptInstruction();
        second.target.insertAfter(result.target);
        return result;
      } else if (second is JumpIfZeroScriptInstruction) {
        final result = JumpIfNotZeroScriptInstruction();
        second.target.nextNonNopInstruction.insertAfter(result.target);
        return result;
      } else {
        throw Exception('Internal error: Unexpected jump type $second');
      }
    } else {
      throw Exception('Internal error: Unexpected jump type $first');
    }
  }
}
