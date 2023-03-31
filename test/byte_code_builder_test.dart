import 'package:javelin_steno_script/src/byte_code_builder.dart';
import 'package:javelin_steno_script/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptByteCodeBuilder, () {
    test('should create expected function', () {
      final compiledCode = _compileScript('var a = -1;');
      expect(compiledCode, '''

init (0x8):
  push -1
  store g0
  ret

tick (0xc):
  ret
''');
    });
  });
}

String _compileScript(String script) {
  final result = Parser(
    input: script,
    filename: '',
  ).parse();
  final builder = ScriptByteCodeBuilder(result);
  builder.createByteCode(0);

  final buffer = StringBuffer();
  for (final instruction in builder.instructions) {
    buffer.write(instruction);
    buffer.write("\n");
  }
  return buffer.toString();
}
