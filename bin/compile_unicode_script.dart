// ignore_for_file: avoid_print

import 'dart:io';

import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:javelin_steno_script/unicode_script_bindings.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: compile_script script_file_name1 ...');
    return;
  }

  final module = ScriptModule(UnicodeScriptBindings.functions);

  for (var i = 0; i < arguments.length; ++i) {
    final filename = arguments[i];
    final source = File(filename).readAsStringSync();
    Parser(input: source, filename: filename, module: module).parse();
  }

  final builder = ScriptByteCodeBuilder(
    module: module,
    byteCodeVersion: latestScriptByteCodeVersion,
    requiredFunctions: UnicodeScriptBindings.createRootFunctionList(),
  );
  final byteCode = builder.createByteCode();
  print(builder.disassemble(byteCode));
}
