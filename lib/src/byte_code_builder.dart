import 'dart:convert';
import 'dart:typed_data';

import 'instruction.dart';
import 'instruction_list.dart';
import 'module.dart';

class ScriptByteCodeBuilder {
  ScriptByteCodeBuilder(this.module);

  final ScriptModule module;

  final bytesBuilder = BytesBuilder();
  final instructions = InstructionList();
  final functions = <String, FunctionStartPlaceholderScriptInstruction>{};
  final stringTable = <String, int>{};

  Uint8List createByteCode(int buttonCount) {
    _createInstructionList();
    _measureByteCode(buttonCount);
    _createByteCode(buttonCount);

    return bytesBuilder.toBytes();
  }

  void _createInstructionList() {
    for (final function in module.functions.values) {
      if (function is! ScriptFunction) {
        continue;
      }
      if (function != module.functions[function.name]) {
        throw Exception('Internal error - inconsistent function name');
      }
      // Set up placeholder instruction.
      final functionStart =
          FunctionStartPlaceholderScriptInstruction(function.name);
      functions[function.name] = functionStart;
      addInstruction(functionStart);

      // Add instructions to store passed in parameters.
      if (function.numberOfParameters > 0) {
        addInstruction(StoreParamCountInstruction(function.numberOfParameters));
      }

      // Add function instructions
      function.statements.addInstructions(this);

      if (instructions.isEmpty ||
          instructions.last is! ReturnScriptInstruction) {
        // Add safety return.
        if (function.hasReturnValue) {
          addInstruction(PushIntValueScriptInstruction(0));
        }
        addInstruction(ReturnScriptInstruction());
      }
    }

    instructions.optimize();
  }

  void _measureByteCode(int buttonCount) {
    // Starting offset is:
    // magic + 2 (init) + buttonCount * 2 (press/release) * 2 (bytes per offset)
    final startingOffset = 4 + 2 + buttonCount * 4;
    var offset = startingOffset;
    for (final instruction in instructions) {
      offset += instruction.layoutFirstPass(offset);
    }
    offset = startingOffset;
    for (final instruction in instructions) {
      offset += instruction.layoutFinalPass(offset);
    }
    for (final string in stringTable.keys) {
      stringTable[string] = offset;
      offset += utf8.encode(string).length + 1;
    }
  }

  void _createByteCode(int buttonCount) {
    bytesBuilder.add('JSS0'.codeUnits);
    addFunctionOffset('init');

    for (var i = 0; i < buttonCount; ++i) {
      addFunctionOffset('onPress$i');
      addFunctionOffset('onRelease$i');
    }

    for (final instruction in instructions) {
      if (instruction.offset != bytesBuilder.length) {
        throw Exception(
          'Internal error: byte code offset (${instruction.offset} vs ${bytesBuilder.length}) mismatch at $instruction',
        );
      }
      instruction.addByteCode(this);
    }

    for (final string in stringTable.keys) {
      if (stringTable[string] != bytesBuilder.length) {
        throw Exception(
          'Internal error: byte code offset mismatch at string $string',
        );
      }
      bytesBuilder.add(utf8.encode(string));
      bytesBuilder.addByte(0);
    }
  }

  void addFunctionOffset(String name) {
    final function = functions[name];
    if (function == null) {
      throw FormatException('Missing $name definition');
    }
    final offset = function.offset;
    bytesBuilder.addByte(offset);
    bytesBuilder.addByte(offset >> 8);
  }

  void addInstruction(ScriptInstruction instruction) =>
      instructions.add(instruction);
}
