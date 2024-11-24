import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptByteCodeBuilder, () {
    test('should create expected function', () {
      final compiledCode = _compileScript('var a = -1;');
      expect(compiledCode, '''

init (0xa):
  push -1
  store g0
  ret

tick (0xe):
  ret
''');
    });
  });
}

String _compileScript(String script) {
  final module = ScriptModule();
  Parser(input: script, filename: '', module: module).parse();
  final builder = ScriptByteCodeBuilder(
    module: module,
    byteCodeVersion: latestScriptByteCodeVersion,
    requiredFunctions: ScriptByteCodeBuilder.createScriptFunctionList(0),
  );
  builder.createByteCode();

  final buffer = StringBuffer();
  for (final instruction in builder.instructions) {
    buffer.write(instruction);
    buffer.write('\n');
  }
  return buffer.toString();
}
