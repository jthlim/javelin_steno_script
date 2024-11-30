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

  void optimize({required int byteCodeVersion}) {
    optimizeNot();
    optimizeTrueFalseJumps();
    optimizeRightFactor();
    optimizeJumpTarget(byteCodeVersion);
    optimizeRightFactor();
    optimizeJumpTarget(byteCodeVersion);
    optimizeCallReturn();
    optimizeDeadCode();
    optimizeJumpToNext();
    optimizeConditionalJumpOverJump();
    optimizeNot();
    optimizeConditionalJumpToNext();
    optimizeConsecutiveRet();
    optimizeStoreLoad();
    optimizeFunctionReference();
    optimizeEqualsAndNotEquals();
    if (byteCodeVersion >= 4) {
      optimizeJumpOverRet();
    }
    optimizeDeadFunctions();
  }

  void optimizeRightFactor() {
    if (instructions.isEmpty) {
      return;
    }

    // To avoid jumps being equivalent, do do a layout
    var offset = 0;
    for (final instruction in instructions) {
      offset += instruction.layoutFinalPass(offset);
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
          final jumpInstruction =
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

  // Replaces jump over rets with a single retz or retnz instruction:
  //
  //     jnz skip
  //     ret
  //   skip:
  //
  // with:
  //
  //     retz
  void optimizeJumpOverRet() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      final next = instruction.next;
      if (next is! ReturnInstruction) {
        instruction = next;
        continue;
      }
      if (instruction is JumpIfZeroInstruction) {
        final afterJump = instruction.target.next;
        instruction.replaceWith(ReturnIfNotZeroInstruction());
        next.unlink();
        instruction = afterJump;
      } else if (instruction is JumpIfNotZeroInstruction) {
        final afterJump = instruction.target.next;
        instruction.replaceWith(ReturnIfZeroInstruction());
        next.unlink();
        instruction = afterJump;
      } else {
        instruction = next;
      }
    }
  }

  // Replace jump to ret, jump to jump, and jump to function
  void optimizeJumpTarget(int byteCodeVersion) {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is JumpInstructionBase) {
        final target = instruction.target.firstNonNopInstruction;
        ScriptInstruction? replacement;
        if (target is ReturnInstruction) {
          if (instruction is JumpInstruction) {
            replacement = ReturnInstruction();
          } else if (byteCodeVersion >= 4) {
            if (instruction is JumpIfZeroInstruction) {
              replacement = ReturnIfZeroInstruction();
            } else if (instruction is JumpIfNotZeroInstruction) {
              replacement = ReturnIfNotZeroInstruction();
            }
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
          final nextNonNop = nextInstruction.firstNonNopInstruction;
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
          final nextNonNop = nextInstruction.firstNonNopInstruction;
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
      if (instruction.isConditional) {
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
      if (instruction is! JumpInstructionBase || !instruction.isConditional) {
        instruction = instruction.next;
        continue;
      }

      final next = instruction.next;
      if (next is JumpInstruction) {
        if (!instruction.target.isTarget(next.next)) {
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

        instruction.unlink();
        next.unlink();

        instruction = replacementInstruction;
      } else if (next is JumpFunctionInstruction) {
        if (!instruction.target.isTarget(next.next)) {
          instruction = instruction.next;
          continue;
        }

        late final JumpFunctionInstructionBase replacementInstruction;
        if (instruction is JumpIfZeroInstruction) {
          replacementInstruction =
              JumpIfNotZeroFunctionInstruction(next.functionName);
        } else if (instruction is JumpIfNotZeroInstruction) {
          replacementInstruction =
              JumpIfZeroFunctionInstruction(next.functionName);
        }
        instruction.insertAfter(replacementInstruction);

        instruction.unlink();
        next.unlink();

        instruction = replacementInstruction;
      } else {
        instruction = instruction.next;
      }
    }
  }

  void replaceWithSubtract(ScriptInstruction instruction) {
    final previous = instruction.previous;
    if (previous is PushIntValueInstruction) {
      if (previous.value == 1) {
        previous.unlink();
        instruction
            .replaceWith(OpcodeInstruction(ScriptOperatorOpcode.decrement));
        return;
      } else if (previous.value == -1) {
        previous.unlink();
        instruction
            .replaceWith(OpcodeInstruction(ScriptOperatorOpcode.increment));
        return;
      }
    }
    instruction.replaceWith(OpcodeInstruction(ScriptOperatorOpcode.subtract));
  }

  // Replaces equals and not equals with subtract when possible.
  //
  // Subtract is a faster operation than equals and not equals, and opens
  // up increment/decrement opportunities, which also reduces the number of
  // instructions.
  void optimizeEqualsAndNotEquals() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      if (instruction is! OpcodeInstruction) {
        instruction = instruction.next;
        continue;
      }

      switch (instruction.opcode) {
        case ScriptOperatorOpcode.notEquals:
          final next = instruction.next;
          if ((next is JumpInstructionBase && next.isConditional) ||
              (next is JumpFunctionInstructionBase && next.isConditional) ||
              next is ReturnIfZeroInstruction ||
              next is ReturnIfNotZeroInstruction) {
            replaceWithSubtract(instruction);
            instruction = next;
            continue;
          }
          break;

        case ScriptOperatorOpcode.equals:
          final next = instruction.next;
          if (next is JumpInstructionBase && next.isConditional) {
            final JumpInstructionBase replacement;
            if (next is JumpIfNotZeroInstruction) {
              replacement = JumpIfZeroInstruction();
            } else if (next is JumpIfZeroInstruction) {
              replacement = JumpIfNotZeroInstruction();
            } else {
              throw Exception('Internal error: Unexpected jump type $next');
            }
            replaceWithSubtract(instruction);
            next.target.insertAfter(replacement.target);
            next.replaceWith(replacement);
            instruction = replacement;
            continue;
          } else if (next is JumpFunctionInstructionBase &&
              next.isConditional) {
            final JumpFunctionInstructionBase replacement;
            if (next is JumpIfNotZeroFunctionInstruction) {
              replacement = JumpIfZeroFunctionInstruction(next.functionName);
            } else if (next is JumpIfZeroInstruction) {
              replacement = JumpIfNotZeroFunctionInstruction(next.functionName);
            } else {
              throw Exception('Internal error: Unexpected jump type $next');
            }
            replaceWithSubtract(instruction);
            next.replaceWith(replacement);
            instruction = replacement;
            continue;
          } else if (next is ReturnIfZeroInstruction) {
            replaceWithSubtract(instruction);
            final replacement = ReturnIfNotZeroInstruction();
            next.replaceWith(replacement);
            instruction = replacement;
            continue;
          } else if (next is ReturnIfNotZeroInstruction) {
            replaceWithSubtract(instruction);
            final replacement = ReturnIfZeroInstruction();
            next.replaceWith(replacement);
            instruction = replacement;
            continue;
          }
          break;

        default:
          break;
      }
      instruction = instruction.next;
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
      } else if (next is JumpIfZeroFunctionInstruction) {
        final replacement = JumpIfNotZeroFunctionInstruction(next.functionName);
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
      } else if (next is JumpIfNotZeroFunctionInstruction) {
        final replacement = JumpIfZeroFunctionInstruction(next.functionName);
        final previous = instruction.previous!;
        next.replaceWith(replacement);
        instruction.unlink();
        instruction = previous;
        continue;
      } else if (next is ReturnIfNotZeroInstruction) {
        next.replaceWith(ReturnIfZeroInstruction());
        instruction.unlink();
        instruction = previous;
        continue;
      } else if (next is ReturnIfZeroInstruction) {
        next.replaceWith(ReturnIfNotZeroInstruction());
        instruction.unlink();
        instruction = previous;
        continue;
      }
      instruction = next;
    }
  }

  static ScriptInstruction? replaceJumpToFunction(
    JumpInstructionBase first,
    JumpFunctionInstruction second,
  ) {
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
    JumpInstructionBase first,
    JumpInstructionBase second,
  ) {
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

  void optimizeConsecutiveRet() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      final nextInstruction = instruction.next;
      if (instruction is! ReturnInstruction) {
        instruction = nextInstruction;
        continue;
      }

      if (nextInstruction?.firstNonNopInstruction is! ReturnInstruction) {
        instruction = nextInstruction;
        continue;
      }

      instruction.unlink();
      instruction = nextInstruction;
    }
  }

  static bool hasLoadLocalIndex(ScriptInstruction? instruction, int index) {
    for (;;) {
      if (instruction == null) {
        return false;
      }
      if (instruction is StartFunctionInstruction) {
        return false;
      }
      if (instruction is LoadLocalValueInstruction &&
          instruction.index == index) {
        return true;
      }
      instruction = instruction.next;
    }
  }

  void optimizeStoreLoad() {
    if (instructions.isEmpty) {
      return;
    }

    ScriptInstruction? instruction = instructions.first;
    while (instruction != null) {
      final nextInstruction = instruction.next;
      if (instruction is! StoreLocalValueInstruction) {
        instruction = nextInstruction;
        continue;
      }

      if (nextInstruction is! LoadLocalValueInstruction) {
        instruction = nextInstruction;
        continue;
      }

      if (instruction.index != nextInstruction.index) {
        instruction = nextInstruction;
        continue;
      }

      // Check if there are any more loads
      final nextNextInstruction = nextInstruction.next;
      if (hasLoadLocalIndex(nextNextInstruction, instruction.index)) {
        instruction = nextInstruction;
        continue;
      }

      instruction.unlink();
      nextInstruction.unlink();
      instruction = nextNextInstruction;
    }
  }

  void optimizeFunctionReference() {
    if (instructions.isEmpty) {
      return;
    }

    // First build function name -> target Name map.
    final functionTargets = <String, String?>{};

    for (ScriptInstruction? instruction = instructions.first;
        instruction != null;
        instruction = instruction.next) {
      if (instruction is StartFunctionInstruction) {
        final firstInstruction = instruction.next;
        if (firstInstruction is JumpFunctionInstruction) {
          functionTargets[instruction.function.functionName] =
              firstInstruction.targetName;
        } else if (firstInstruction is ReturnInstruction) {
          functionTargets[instruction.function.functionName] = null;
        }
      }
    }

    for (ScriptInstruction? instruction = instructions.first;
        instruction != null;
        instruction = instruction.next) {
      if (instruction is FunctionReferenceScriptInstruction) {
        for (;;) {
          if (!functionTargets.containsKey(instruction.targetName)) {
            break;
          }

          instruction.targetName = functionTargets[instruction.targetName];
        }
      }
    }
  }

  void recurseMarkStartFunctions(
    Map<String, StartFunctionInstruction> startFunctionInstructions,
    Set<StartFunctionInstruction> requiredFunctions,
    String? name,
  ) {
    if (name == null) return;

    final startInstruction = startFunctionInstructions[name];
    if (startInstruction == null) return;

    if (requiredFunctions.contains(startInstruction)) return;

    requiredFunctions.add(startInstruction);

    for (ScriptInstruction? instruction = startInstruction;
        instruction != null;
        instruction = instruction.next) {
      if (instruction is FunctionReferenceScriptInstruction) {
        recurseMarkStartFunctions(
          startFunctionInstructions,
          requiredFunctions,
          instruction.targetName,
        );
      }
    }
  }

  void optimizeDeadFunctions() {
    // First build function name -> target Name map.
    final startFunctionInstructions = <String, StartFunctionInstruction>{};
    final requiredFunctions = <StartFunctionInstruction>{};

    for (ScriptInstruction? instruction = instructions.first;
        instruction != null;
        instruction = instruction.next) {
      if (instruction is StartFunctionInstruction) {
        startFunctionInstructions[instruction.function.functionName] =
            instruction;
      }
    }

    recurseMarkStartFunctions(
      startFunctionInstructions,
      requiredFunctions,
      '\$byteCodeRoot',
    );

    for (ScriptInstruction? instruction = instructions.first;
        instruction != null;
        instruction = instruction?.next) {
      while (instruction is StartFunctionInstruction) {
        if (requiredFunctions.contains(instruction)) break;

        do {
          final next = instruction!.next;
          instruction.unlink();
          instruction = next;
        } while (
            instruction != null && instruction is! StartFunctionInstruction);
      }
    }
  }
}
