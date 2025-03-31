import 'dart:typed_data';

import 'package:crclib/catalog.dart';
import 'package:javelin_steno_script/button_script_in_built_functions.dart';
import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:javelin_steno_script/src/functions.dart';

class ScriptCompileResult {
  factory ScriptCompileResult.buttonScript({
    required String script,
    required String scriptHeader,
    required int buttonCount,
    required int encoderCount,
    required int pointerCount,
    required int maximumByteCodeSize,
    int byteCodeVersion = latestScriptByteCodeVersion,
  }) {
    if (script.isEmpty) {
      return const ScriptCompileResult.empty();
    }

    return ScriptCompileResult.scripts(
      scripts: [
        if (scriptHeader.isNotEmpty) scriptHeader,
        script,
      ],
      inBuiltFunctions: ButtonScriptInBuiltFunctions.functions,
      requiredFunctions: ScriptByteCodeBuilder.createScriptFunctionList(
        buttonCount: buttonCount,
        encoderCount: encoderCount,
        pointerCount: pointerCount,
      ),
      maximumScriptByteCodeSize: maximumByteCodeSize,
      byteCodeVersion: byteCodeVersion,
    );
  }

  factory ScriptCompileResult.script({
    required String script,
    required List<InBuiltScriptFunction> inBuiltFunctions,
    required List<String> requiredFunctions,
    int byteCodeVersion = latestScriptByteCodeVersion,
    required int maximumScriptByteCodeSize,
  }) {
    if (script.isEmpty) {
      return const ScriptCompileResult.empty();
    }

    return ScriptCompileResult.scripts(
      scripts: [script],
      inBuiltFunctions: inBuiltFunctions,
      requiredFunctions: requiredFunctions,
      byteCodeVersion: byteCodeVersion,
      maximumScriptByteCodeSize: maximumScriptByteCodeSize,
    );
  }

  factory ScriptCompileResult.scripts({
    required List<String> scripts,
    required List<InBuiltScriptFunction> inBuiltFunctions,
    required List<String> requiredFunctions,
    int byteCodeVersion = latestScriptByteCodeVersion,
    required int maximumScriptByteCodeSize,
  }) {
    if (scripts.isEmpty) {
      return const ScriptCompileResult.empty();
    }

    final module = ScriptModule(inBuiltFunctions);
    try {
      for (final script in scripts) {
        Parser(input: script, filename: '', module: module).parse();
      }
      final builder = ScriptByteCodeBuilder(
        module: module,
        byteCodeVersion: byteCodeVersion,
        requiredFunctions: requiredFunctions,
      );
      final byteCode = builder.createByteCode();
      if (byteCode.length > maximumScriptByteCodeSize) {
        return ScriptCompileResult.failed(
          'Script requires ${byteCode.length} bytes, exceeding limit of '
          '$maximumScriptByteCodeSize bytes by '
          '${byteCode.length - maximumScriptByteCodeSize}',
        );
      }

      return ScriptCompileResult.ok(byteCode.length, byteCode, builder);
    } on Object catch (e) {
      return ScriptCompileResult.failed(e.toString());
    }
  }

  ScriptCompileResult.ok(
    this.size,
    Uint8List this.data,
    ScriptByteCodeBuilder this.builder,
  )   : success = true,
        message = 'OK, $size bytes';

  const ScriptCompileResult.failed(this.message)
      : success = false,
        size = 0,
        builder = null,
        data = null;

  const ScriptCompileResult.empty()
      : success = false,
        size = 0,
        message = 'No script',
        builder = null,
        data = null;

  final bool success;
  final String message;
  final int size;
  final Uint8List? data;
  final ScriptByteCodeBuilder? builder;

  int get crc => Crc32().convert(data ?? []).toBigInt().toInt();
}
