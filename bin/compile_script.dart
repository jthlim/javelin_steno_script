// ignore_for_file: avoid_print

import 'dart:io';

import 'package:javelin_steno_script/javelin_steno_script.dart';

void main(List<String> arguments) {
  if (arguments.length < 2) {
    print('Usage: compile_script <button_count> script_file_name1 ...');
    return;
  }

  final buttonCount = int.tryParse(arguments[0]);
  if (buttonCount == null) {
    print('Usage: compile_script <button_count> script_file_name1 ...');
    return;
  }

  final module = ScriptModule();

  for (var i = 1; i < arguments.length; ++i) {
    final filename = arguments[i];
    final source = File(filename).readAsStringSync();
    Parser(input: source, filename: filename, module: module).parse();
  }

  final builder = ScriptByteCodeBuilder(
    module: module,
    byteCodeVersion: latestScriptByteCodeVersion,
    requiredFunctions:
        ScriptByteCodeBuilder.createScriptFunctionList(buttonCount),
  );
  final byteCode = builder.createByteCode();
  print(builder.disassemble(byteCode));
}
