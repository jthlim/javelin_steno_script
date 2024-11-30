import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

void main(List<String> arguments) {
  for (final argument in arguments) {
    final file = File(argument);
    final bytes = file.readAsBytesSync();

    final image = decodePng(bytes)!;
    final width = image.width;
    final height = image.height;

    print('Read image: ${width}x$height');

    final imageData = BytesBuilder();
    imageData.addByte(width);
    imageData.addByte(height);

    final black = ColorUint32.rgb(0, 0, 0);
    final white = ColorUint32.rgb(255, 255, 255);

    for (var x = 0; x < width; ++x) {
      for (var yy = 0; yy < height; yy += 8) {
        var data = 0;
        for (var y = 0; y < 8; ++y) {
          if (yy + y >= height) {
            break;
          }
          if (isOn(image.getPixel(x, yy + y))) {
            data |= 1 << y;
            image.setPixel(x, yy + y, black);
          } else {
            image.setPixel(x, yy + y, white);
          }
        }
        imageData.addByte(data);
      }
    }

    file.writeAsBytesSync(encodePng(image));

    writeUint8List(imageData.toBytes());
  }
}

bool isDivider(Pixel pixel) => pixel.r >= 128 && pixel.g < 128 && pixel.b < 128;

// Inverse - white is off.
bool isOn(Pixel pixel) => pixel.r < 128 && pixel.g < 128 && pixel.b < 128;

int calculateGlyphWidth(Image image, int startX) {
  var x = startX;
  for (; x < image.width; ++x) {
    if (isDivider(image.getPixel(x, 0))) {
      return x - startX;
    }
  }
  return image.width - startX;
}

void writeUint8List(Uint8List data) {
  stdout.write('[[');
  for (var i = 0; i < data.length; ++i) {
    if (i % 16 == 0) stdout.write('\n ');
    stdout.write(' ${data[i].toRadixString(16).padLeft(2, '0')}');
  }
  stdout.write('\n]];\n');
}
