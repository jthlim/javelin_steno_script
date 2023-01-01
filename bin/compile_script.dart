// ignore_for_file: avoid_print

import 'dart:io';

import 'package:javelin_steno_script/javelin_steno_script.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    print('Usage: compile_script <button_count> script_file_name');
    return;
  }

  final buttonCount = int.tryParse(arguments[0]);
  if (buttonCount == null) {
    print('Usage: compile_script <button_count> script_file_name');
    return;
  }

  final filename = arguments[1];

  final source = File(filename).readAsStringSync();

  final result = Parser(input: source, filename: filename).parse();

  final builder = ScriptByteCodeBuilder(result);
  final byteCode = builder.createByteCode(buttonCount);

  print('Opcodes');
  print('-------');
  for (final instruction in builder.instructions) {
    print(instruction);
  }

  if (builder.stringTable.isNotEmpty) {
    print('\n\nString table');
    print('------------');
    builder.stringTable.forEach((key, value) {
      print('${value.toRadixString(16).padLeft(4, '0')}: "$key"');
    });
  }

  print('\n\nBytecode');
  print('--------');
  final buffer = StringBuffer();
  for (var i = 0; i < byteCode.length; ++i) {
    if (i % 16 == 0) {
      buffer.write('\n${i.toRadixString(16).padLeft(4, '0')}: ');
    }
    buffer.write(' 0x${byteCode[i].toRadixString(16).padLeft(2, '0')},');
  }
  buffer.write('\n');
  print(buffer.toString());
}
