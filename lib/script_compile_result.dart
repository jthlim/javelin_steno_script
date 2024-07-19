import 'dart:typed_data';

import 'package:crclib/catalog.dart';

import 'src/byte_code_builder.dart';
import 'src/module.dart';
import 'src/parser.dart';

class ScriptCompileResult {
  factory ScriptCompileResult(
    int scriptButtonCount,
    int maximumScriptByteCodeSize,
    String scriptHeader,
    String script,
  ) {
    if (script.isEmpty) {
      return ScriptCompileResult.failed('No script');
    }

    try {
      final module = ScriptModule();
      if (scriptHeader.isNotEmpty) {
        Parser(input: scriptHeader, filename: '', module: module).parse();
      }
      Parser(input: script, filename: '', module: module).parse();
      final builder = ScriptByteCodeBuilder(module);
      final byteCode = builder.createByteCode(scriptButtonCount);

      if (byteCode.length > maximumScriptByteCodeSize) {
        return ScriptCompileResult.failed(
          'Script requires ${byteCode.length} bytes, exceeding limit of '
          '$maximumScriptByteCodeSize bytes by '
          '${byteCode.length - maximumScriptByteCodeSize}',
        );
      }

      return ScriptCompileResult.ok(byteCode.length, byteCode, script);
    } on Exception catch (e) {
      return ScriptCompileResult.failed(e.toString());
    }
  }

  ScriptCompileResult.ok(this.size, Uint8List this.data, String this.script)
      : success = true,
        message = 'OK, $size bytes';
  ScriptCompileResult.failed(this.message)
      : success = false,
        size = 0;

  bool success;
  String message;
  int size;
  Uint8List? data;
  String? script;

  int get crc => Crc32().convert(data ?? []).toBigInt().toInt();
}
