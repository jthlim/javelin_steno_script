import 'package:javelin_steno_script/javelin_steno_script.dart';
import 'package:javelin_steno_script/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group(Parser, () {
    test('should create expected constants', () {
      final result = ScriptModule();
      Parser(
        input: 'const A = 4; const B = A + 1; const C = B - 2;',
        filename: '',
        module: result,
      ).parse();

      expect(result.constants['A']!.constantValue(), 4);
      expect(result.constants['B']!.constantValue(), 5);
      expect(result.constants['C']!.constantValue(), 3);
    });

    test('should create correct multiply constants', () {
      final result = ScriptModule();
      Parser(
        input: 'const A = 3*4; const B = 2 * A;',
        filename: '',
        module: result,
      ).parse();

      expect(result.constants['A']!.constantValue(), 12);
      expect(result.constants['B']!.constantValue(), 24);
    });

    test('should create correct quotient constants', () {
      final result = ScriptModule();
      Parser(
        input: 'const A = 20 / 3; const B = -5 / 2;',
        filename: '',
        module: result,
      ).parse();

      expect(result.constants['A']!.constantValue(), 6);
      expect(result.constants['B']!.constantValue(), -2);
    });

    test('should create correct remainder constants', () {
      final result = ScriptModule();
      Parser(
        input: 'const A = 20 % 3; const B = -5 % 2;',
        filename: '',
        module: result,
      ).parse();

      expect(result.constants['A']!.constantValue(), 2);
      expect(result.constants['B']!.constantValue(), -1);
    });
  });
}
