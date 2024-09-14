import 'dart:io' as io;
import 'dart:typed_data';

typedef File = io.File;

extension IoFileBytes on io.File {
  String get name => path;
  String get type => '';

  Future<Uint8List?> get bytes => readAsBytes();
}
