import 'dart:convert';
import 'dart:typed_data';

import 'package:crclib/catalog.dart';

import 'ast.dart';
import 'instruction.dart';
import 'instruction_list.dart';
import 'module.dart';
import 'string_data.dart';

class ScriptByteCodeBuilder {
  ScriptByteCodeBuilder({
    required this.module,
    required this.byteCodeVersion,
    required this.requiredFunctions,
  }) : reachability = ScriptReachability(module);

  final ScriptModule module;
  final int byteCodeVersion;
  final List<String> requiredFunctions;

  final _bytesBuilder = BytesBuilder();
  final instructions = InstructionList();
  final functions = <String, StartFunctionInstruction>{};
  final strings = <String>{};
  late final List<String> sortedStrings;
  final stringTable = <String, int>{};
  var stringHashTableOffset = 0;
  final data = <AstNode, int>{};
  final ScriptReachability reachability;
  List<NopInstruction>? continueTargets;
  List<NopInstruction>? breakTargets;
  late Uint8List _headerBytes;

  Uint8List createByteCode() {
    _mark();

    module.prepareAutogeneratedCode(reachability);

    _createInstructionList();
    sortedStrings = reachability.strings.toList()..sort();
    _measureByteCode();
    _createByteCode();

    return _bytesBuilder.toBytes();
  }

  void _mark() {
    for (final function in requiredFunctions) {
      _markFunction(function);
    }
  }

  void _createInstructionList() {
    // Add header and root element. This name is used by InstructionList.
    addInstruction(
      StartFunctionInstruction(ScriptFunction('\$byteCodeRoot'), true, false),
    );
    _headerBytes = Uint8List(6 + 2 * requiredFunctions.length);
    _headerBytes.setRange(0, 4, 'JSS$byteCodeVersion'.codeUnits);
    for (var i = 0; i < requiredFunctions.length; ++i) {
      addInstruction(
        SetHalfWordFunctionDataValueInstruction(
          functionName: requiredFunctions[i],
          value: _headerBytes,
          valueOffset: 6 + i * 2,
        ),
      );
    }
    addInstruction(DataInstruction(_headerBytes));

    for (final function in module.functions.values) {
      if (function is! ScriptFunction) continue;
      if (!reachability.functions.contains(function.functionName)) continue;

      if (function != module.functions[function.functionName]) {
        throw Exception('Internal error - inconsistent function name');
      }
      // Set up placeholder instruction.
      final functionStart = StartFunctionInstruction(
        function,
        function.isLocked,
        function.isPure(),
      );
      functions[function.functionName] = functionStart;
      addInstruction(functionStart);

      // Add function instructions
      function.statements.addInstructions(this);

      if (instructions.isEmpty || instructions.last is! ReturnInstruction) {
        // Add safety return.
        if (function.hasReturnValue) {
          addInstruction(PushIntValueInstruction(0));
        }
        addInstruction(ReturnInstruction());
      }
    }

    instructions.optimize(byteCodeVersion: byteCodeVersion);
  }

  void _measureByteCode() {
    var offset = 0;
    for (final instruction in instructions) {
      offset += instruction.layoutFirstPass(offset);
    }
    offset = 0;
    for (final instruction in instructions) {
      offset += instruction.layoutFinalPass(offset);
    }

    // Align data section to word boundaries.
    offset = (offset + 1) & -2;

    for (final e in reachability.data.entries) {
      data[e.key] = offset;
      offset += e.value;
    }
    for (final string in sortedStrings) {
      stringTable[string] = offset;

      // Strings either start with 'S' (string) or 'D' (data).
      final marker = string.codeUnitAt(0);

      if (marker == 0x53 /* 'S' */) {
        offset += utf8.encode(string.substring(1)).length + 1;
      } else if (marker == 0x44 /* 'D' */) {
        offset += string.length - 1;
      } else {
        throw Exception('Internal error: Unhandled string marker');
      }
    }

    // Align hash table to word boundaries.
    offset = (offset + 1) & -2;

    stringHashTableOffset = offset;
  }

  void _createByteCode() {
    // Set HashTableOffset
    _headerBytes[4] = stringHashTableOffset & 0xff;
    _headerBytes[5] = stringHashTableOffset >> 8;

    for (final instruction in instructions) {
      if (instruction.offset != _bytesBuilder.length) {
        throw Exception(
          'Internal error: byte code offset (${instruction.offset} vs ${_bytesBuilder.length}) mismatch at $instruction',
        );
      }
      instruction.addByteCode(this);
    }

    // Align data to half word boundaries.
    if ((_bytesBuilder.length & 1) != 0) {
      _bytesBuilder.addByte(0);
    }

    for (final e in data.entries) {
      _bytesBuilder.add(e.key.getData());
    }

    for (final string in sortedStrings) {
      if (stringTable[string] != _bytesBuilder.length) {
        throw Exception(
          'Internal error: byte code offset mismatch at string $string',
        );
      }

      // Strings either start with 'S' (string) or 'D' (data).
      final marker = string.codeUnitAt(0);
      if (marker == 0x53 /* 'S' */) {
        _bytesBuilder.add(utf8.encode(string.substring(1)));
        _bytesBuilder.addByte(0);
      } else if (marker == 0x44 /* 'D' */) {
        for (final byte in string.codeUnits.skip(1)) {
          _bytesBuilder.addByte(byte);
        }
      } else {
        throw Exception('Internal error: Unhandled string marker');
      }
    }

    // Align hash table to half word boundaries.
    if ((_bytesBuilder.length & 1) != 0) {
      _bytesBuilder.addByte(0);
    }

    writeStringHashTable();
  }

  void _markFunction(String name) {
    final function = module.functions[name] as ScriptFunction?;
    function?.mark(reachability);
    function?.isLocked = true;

    reachability.functions.add(name);
  }

  void addInstruction(ScriptInstruction instruction) =>
      instructions.add(instruction);

  void add16BitValue(int value) {
    _bytesBuilder.addByte(value);
    _bytesBuilder.addByte(value >> 8);
  }

  void add(List<int> bytes) {
    _bytesBuilder.add(bytes);
  }

  void addByte(int byte) {
    _bytesBuilder.addByte(byte);
  }

  void addOpcode(ScriptOpcode opcode) {
    _bytesBuilder.addByte(opcode.value);
  }

  void addOperatorOpcode(ScriptOperatorOpcode operatorOpcode) {
    _bytesBuilder.addByte(operatorOpcode.value);
  }

  void writeStringHashTable() {
    final strings = sortedStrings.where((element) => element.startsWith('S'));

    // Target duty cycle of 66%.
    var hashMapSize = 4;
    if (strings.length < 2) {
      hashMapSize = [0, 2][strings.length];
    } else {
      final minimumHashMapSize = strings.length + (strings.length >> 1);
      while (hashMapSize < minimumHashMapSize) {
        hashMapSize <<= 1;
      }
    }

    add16BitValue(hashMapSize);

    // Build hashmap, index -> stroke index
    final hashMap = List<int>.filled(hashMapSize, 0);
    for (final string in strings) {
      final hashValue = string.substring(1).crc32Hash();
      var index = hashValue % hashMapSize;
      while (hashMap[index] != 0) {
        index = (index + 1) % hashMapSize;
      }
      hashMap[index] = stringTable[string]!;
    }

    for (final e in hashMap) {
      add16BitValue(e);
    }
  }
}

extension Crc32StringExtension on String {
  int crc32Hash() {
    final buffer = utf8.encode(this);

    return Crc32().convert(buffer).toBigInt().toInt();
  }
}

extension ByteCodeScriptExtension on ScriptByteCodeBuilder {
  String disassemble(Uint8List byteCode) {
    final buffer = StringBuffer();

    if (module.globals.isNotEmpty) {
      buffer.write('Globals\n');
      buffer.write('-------\n');
      module.globals.forEach((globalName, global) {
        if (reachability.globals.contains(global.index)) {
          if (global.arraySize != null) {
            buffer
                .write('g${global.index}[${global.arraySize}]: $globalName\n');
          } else {
            buffer.write('g${global.index}: $globalName\n');
          }
        }
      });
      buffer.write('\n');
    }

    buffer.write('Opcodes\n');
    buffer.write('-------\n');
    ScriptInstruction? lastInstruction;
    for (final instruction in instructions) {
      if (instruction is! NopInstruction ||
          lastInstruction is! NopInstruction) {
        buffer.write('$instruction\n');
      }

      lastInstruction = instruction;
    }

    if (stringTable.isNotEmpty) {
      buffer.write('\n\nData\n');
      buffer.write('----\n');
      stringTable.forEach((key, value) {
        buffer.write(
          '${value.toRadixString(16).padLeft(4, '0')}: '
          '${formatStringData(key)}\n',
        );
      });
    }

    buffer.write('\n\nBytecode\n');
    buffer.write('--------\n');
    for (var i = 0; i < byteCode.length; ++i) {
      if (i % 16 == 0) {
        buffer.write('\n${i.toRadixString(16).padLeft(4, '0')}: ');
      }
      buffer.write(' 0x${byteCode[i].toRadixString(16).padLeft(2, '0')},');
    }
    buffer.write('\n\n');
    buffer.write('Bytecode length: ${byteCode.length}\n');
    buffer.write('Globals used: ${module.globalsUsedCount}\n');

    return buffer.toString();
  }
}
