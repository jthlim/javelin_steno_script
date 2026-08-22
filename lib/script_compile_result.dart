import 'dart:typed_data';

import 'package:crclib/catalog.dart';
import 'package:javelin_steno_script/button_script_bindings.dart';
import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:javelin_steno_script/unicode_script_bindings.dart';

class const ScriptCompileResult({
  required final bool success,
  required final String message,
  required final int size,
  final Uint8List? data,
  final ScriptByteCodeBuilder? builder,
}) {
  factory ScriptCompileResult.buttonScript({
    required String script,
    required String scriptHeader,
    required int buttonCount,
    required int analogInputCount,
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
        ButtonScriptBindings.constants,
        if (scriptHeader.isNotEmpty) scriptHeader,
        script,
      ],
      inBuiltFunctions: ButtonScriptBindings.functions,
      requiredFunctions: ButtonScriptBindings.createRootFunctionList(
        buttonCount: buttonCount,
        analogDataCount: analogInputCount,
        encoderCount: encoderCount,
        pointerCount: pointerCount,
      ),
      maximumScriptByteCodeSize: maximumByteCodeSize,
      byteCodeVersion: byteCodeVersion,
    );
  }

  factory ScriptCompileResult.unicodeScript({
    required String script,
    required int maximumByteCodeSize,
    int byteCodeVersion = latestScriptByteCodeVersion,
  }) {
    if (script.isEmpty) {
      return const ScriptCompileResult.empty();
    }

    return ScriptCompileResult.scripts(
      scripts: [script],
      inBuiltFunctions: UnicodeScriptBindings.functions,
      requiredFunctions: UnicodeScriptBindings.createRootFunctionList(),
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
    bool forceGlobalWrites = false,
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
      forceGlobalWrites: forceGlobalWrites,
    );
  }

  factory ScriptCompileResult.scripts({
    required List<String> scripts,
    required List<InBuiltScriptFunction> inBuiltFunctions,
    required List<String> requiredFunctions,
    int byteCodeVersion = latestScriptByteCodeVersion,
    required int maximumScriptByteCodeSize,
    bool forceGlobalWrites = false,
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
        forceGlobalWrites: forceGlobalWrites,
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

  const new ok(
    int size,
    Uint8List data,
    ScriptByteCodeBuilder builder,
  ) : this(
        success: true,
        message: 'OK, $size bytes',
        size: size,
        data: data,
        builder: builder,
      );

  const new failed(String message)
    : this(
        success: false,
        message: message,
        size: 0,
      );

  const new empty()
    : this(
        success: false,
        message: 'No script',
        size: 0,
      );

  ScriptCompileResult copyWith({
    bool? success,
    String? message,
    int? size,
    Uint8List? data,
    ScriptByteCodeBuilder? builder,
  }) {
    return ScriptCompileResult(
      success: success ?? this.success,
      message: message ?? this.message,
      size: size ?? this.size,
      data: data ?? this.data,
      builder: builder ?? this.builder,
    );
  }

  int get crc => Crc32().convert(data ?? []).toBigInt().toInt();
}
