String formatStringData(String s) {
  final marker = s.codeUnitAt(0);
  if (marker == 0x53 /* 'S' */) {
    return '"${s.substring(1)}"';
  } else if (marker == 0x44 /* 'D' */) {
    final stringBuffer = StringBuffer();
    stringBuffer.write('[[');
    for (final byte in s.codeUnits.skip(1)) {
      stringBuffer.write(' ');
      stringBuffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    stringBuffer.write(' ]]');
    return stringBuffer.toString();
  } else {
    throw Exception('Internal error: Unhandled string marker');
  }
}
