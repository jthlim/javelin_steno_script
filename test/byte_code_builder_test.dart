import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptByteCodeBuilder, () {
    test('should create expected function', () {
      final compiledCode = _compileScript('var a = -1;');
      expect(compiledCode, '''

\$byteCodeRoot (0x0):
  ((set2 offset 6 -> null (init)))
  ((set2 offset 8 -> null (tick)))
  data [[4a 53 53 34 0a 00 00 00 00 00]]
''');
    });

    test('should inline calculation', () {
      final compiledCode = _compileScript('''
func tick() {
  printValue("Test", calculate(provide3(7), 4));
}

func calculate(a, b) var {
  return "0123456789"[2 * a + b / 4] - '0';
}

func provide3(x) var {
  return x % 4;
}

''');
      expect(compiledCode, '''

\$byteCodeRoot (0x0):
  ((set2 offset 6 -> null (init)))
  ((set2 offset 8 -> tick))
  data [[4a 53 53 34 18 00 00 00 0a 00]]

tick (0xa):
  push offset-of "Test"
  push 7
  call in-built-87 (printValue)
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
    requiredFunctions: ScriptByteCodeBuilder.createScriptFunctionList(0, 0),
  );
  builder.createByteCode();

  final buffer = StringBuffer();
  for (final instruction in builder.instructions) {
    buffer.write(instruction);
    buffer.write('\n');
  }
  return buffer.toString();
}
