// ignore_for_file: avoid_print

import 'dart:io';

import 'package:javelin_steno_script/button_script_in_built_functions.dart';
import 'package:javelin_steno_script/javelin_steno_script.dart';

void main(List<String> arguments) {
  if (arguments.length < 4) {
    print(
      'Usage: compile_script <button_count> <encoder_count> <pointer_count> script_file_name1 ...',
    );
    return;
  }

  final buttonCount = int.tryParse(arguments[0]);
  if (buttonCount == null) {
    print('Unable to parse button count');
    return;
  }

  final encoderCount = int.tryParse(arguments[1]);
  if (encoderCount == null) {
    print('Unable to parse encoder count');
    return;
  }

  final pointerCount = int.tryParse(arguments[2]);
  if (pointerCount == null) {
    print('Unable to parse pointer count');
    return;
  }

  final module = ScriptModule(ButtonScriptInBuiltFunctions.functions);

  for (var i = 3; i < arguments.length; ++i) {
    final filename = arguments[i];
    final source = File(filename).readAsStringSync();
    Parser(input: source, filename: filename, module: module).parse();
  }

  final builder = ScriptByteCodeBuilder(
    module: module,
    byteCodeVersion: latestScriptByteCodeVersion,
    requiredFunctions: ScriptByteCodeBuilder.createScriptFunctionList(
      buttonCount: buttonCount,
      encoderCount: encoderCount,
      pointerCount: pointerCount,
    ),
  );
  final byteCode = builder.createByteCode();
  print(builder.disassemble(byteCode));
}
