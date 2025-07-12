import 'dart:typed_data';

import 'package:javelin_steno_script/src/byte_code_builder.dart';
import 'package:javelin_steno_script/src/module.dart';

import 'src/functions.dart';

class UnicodeScriptBindings {
  static const functions = <InBuiltScriptFunction>[
    InBuiltScriptFunction('pressKey', 1, ReturnType.none, 0),
    InBuiltScriptFunction('releaseKey', 1, ReturnType.none, 1),
    InBuiltScriptFunction('tapKey', 1, ReturnType.none, 2),
    InBuiltScriptFunction('emitKeyCode', 1, ReturnType.none, 3),
    InBuiltScriptFunction('flush', 0, ReturnType.none, 4),
    InBuiltScriptFunction('getLedStatus', 1, ReturnType.boolean, 5),
    InBuiltScriptFunction('releaseModifiers', 0, ReturnType.none, 6),
  ];

  static List<String> createRootFunctionList() {
    return const [
      'init',
      'begin',
      'emit',
      'end',
    ];
  }
}

extension UnicodeScriptModule on ScriptModule {
  Uint8List createByteCode({
    required int scriptByteCodeVersion,
  }) =>
      ScriptByteCodeBuilder(
        module: this,
        byteCodeVersion: scriptByteCodeVersion,
        requiredFunctions: UnicodeScriptBindings.createRootFunctionList(),
      ).createByteCode();
}
