export 'src/byte_code_builder.dart';
export 'src/module.dart';
export 'src/parser.dart';
export 'src/string_data.dart';

const latestScriptByteCodeVersion = 4;
bool isScriptByteCodeVersionSupported(int version) {
  return version == 3 || version == 4;
}
