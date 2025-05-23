export 'script_compile_result.dart';
export 'src/byte_code_builder.dart';
export 'src/functions.dart';
export 'src/module.dart';
export 'src/parser.dart';
export 'src/string_data.dart';

const latestScriptByteCodeVersion = 4;
bool isScriptByteCodeVersionSupported(int version) {
  return version == 3 || version == 4;
}
