import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as html;

typedef File = html.File;

extension HtmlFileBytes on html.File {
  Future<Uint8List?> get bytes async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(this);
    await reader.onLoadEnd.first;

    final data = reader.result;
    if (data == null) {
      return null;
    }

    final bytes = data as JSArrayBuffer;
    return bytes.toDart.asUint8List();
  }
}
