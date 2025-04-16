import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart';
import 'package:javelin_extensions/javelin_extensions.dart';

class ImageConvert {
  static bool isOn(Pixel pixel) =>
      pixel.r < 128 && pixel.g < 128 && pixel.b < 128;

  static Uint8List? convertBitmapImage(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    if (width > 255 || height > 255) {
      imageData.addByte(0);
      imageData.addByte(0);
      imageData.addUint16(0);
      imageData.addUint16(width);
      imageData.addUint16(height);
    } else {
      imageData.addByte(width);
      imageData.addByte(height);
    }

    for (var x = 0; x < width; ++x) {
      for (var yy = 0; yy < height; yy += 8) {
        var data = 0;
        for (var y = 0; y < 8; ++y) {
          if (yy + y >= height) {
            break;
          }
          if (isOn(image.getPixel(x, yy + y))) {
            data |= 1 << y;
          }
        }
        imageData.addByte(data);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertLuminanceImage(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(1); // Indicating luminance.
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final luminance = image.getPixel(x, y).luminance.toInt();
        imageData.addByte(luminance);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertRgb332Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(2); // Indicating Rgb332
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt() >> 5;
        final g = pixel.g.toInt() >> 5;
        final b = pixel.b.toInt() >> 6;
        final byte = (r << 5) | (g << 2) | b;
        imageData.addByte(byte);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertRgb565Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(3); // Indicating Rgb565
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt() >> 3;
        final g = pixel.g.toInt() >> 2;
        final b = pixel.b.toInt() >> 3;
        final value = (r << 11) | (g << 5) | b;
        imageData.addUint16(value);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertRgb888Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(4); // Indicating Rgb888
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final pixel = image.getPixel(x, y);
        imageData.addByte(pixel.r.toInt());
        imageData.addByte(pixel.g.toInt());
        imageData.addByte(pixel.b.toInt());
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertAlpha8Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(5); // Indicating alpha8
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final luminance = 255 - image.getPixel(x, y).luminance.toInt();
        imageData.addByte(luminance);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertArgb1555Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(6); // Indicating Argb1555
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a.toInt() >> 7;
        final r = pixel.r.toInt() >> 3;
        final g = pixel.g.toInt() >> 3;
        final b = pixel.b.toInt() >> 3;
        final value = (a << 15) | (r << 10) | (g << 5) | b;
        imageData.addUint16(value);
      }
    }

    return imageData.toBytes();
  }

  static Uint8List? convertRgba8888Image(Image image) {
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0) {
      return null;
    }

    final imageData = BytesBuilder();
    imageData.addByte(0);
    imageData.addByte(7); // Indicating Rgba8888
    imageData.addUint16(0);
    imageData.addUint16(width);
    imageData.addUint16(height);

    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final pixel = image.getPixel(x, y);
        imageData.addByte(pixel.r.toInt());
        imageData.addByte(pixel.g.toInt());
        imageData.addByte(pixel.b.toInt());
        imageData.addByte(pixel.a.toInt());
      }
    }

    return imageData.toBytes();
  }

  static Decoder? _getDecoder(Uint8List bytes) {
    final png = PngDecoder();
    if (png.isValidFile(bytes)) {
      return png;
    }

    final jpg = JpegDecoder();
    if (jpg.isValidFile(bytes)) {
      return jpg;
    }

    final bmp = BmpDecoder();
    if (bmp.isValidFile(bytes)) {
      return bmp;
    }

    final gif = GifDecoder();
    if (gif.isValidFile(bytes)) {
      return gif;
    }

    return null;
  }

  static bool canDecodeImage(Uint8List bytes) => _getDecoder(bytes) != null;

  static Image? decodeImage(Uint8List bytes) =>
      _getDecoder(bytes)?.decode(bytes);

  static Future<ui.Image> _createImage(
    int width,
    int height,
    Uint8List pixels, [
    ui.FilterQuality filter = ui.FilterQuality.high,
  ]) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  static Future<ui.Image> createBitmapImage(
    int width,
    int height,
    Uint8List bytes,
    int baseOffset,
  ) {
    final pixels = Uint8List(width * height * 4);
    var destinationOffset = 0;
    final bytesPerColumn = (height + 7) >> 3;
    for (var y = 0; y < height; ++y) {
      for (var x = 0; x < width; ++x) {
        final byteOffset = baseOffset + x * bytesPerColumn + (y >> 3);
        final v = ((bytes[byteOffset] >> (y & 7)) & 1) == 0 ? 0xff : 0;

        pixels[destinationOffset++] = v;
        pixels[destinationOffset++] = v;
        pixels[destinationOffset++] = v;
        pixels[destinationOffset++] = 0xff;
      }
    }

    return _createImage(width, height, pixels, ui.FilterQuality.none);
  }

  static Future<ui.Image> createLuminanceImage(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final v = bytes[sourceOffset++];

      pixels[destinationOffset] = v;
      pixels[destinationOffset + 1] = v;
      pixels[destinationOffset + 2] = v;
      pixels[destinationOffset + 3] = 0xff;

      destinationOffset += 4;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image> createRgb332Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final v = bytes[sourceOffset++];

      final r = (v >> 5) & 7;
      final g = (v >> 2) & 7;
      final b = v & 3;
      pixels[destinationOffset] = r << 5;
      pixels[destinationOffset + 1] = g << 5;
      pixels[destinationOffset + 2] = b << 6;
      pixels[destinationOffset + 3] = 0xff;

      destinationOffset += 4;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image> createRgb565Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final v = bytes.getUint16(sourceOffset);
      sourceOffset += 2;

      final r = (v >> 11) & 0x1f;
      final g = (v >> 5) & 0x3f;
      final b = v & 0x1f;
      pixels[destinationOffset] = r << 3;
      pixels[destinationOffset + 1] = g << 2;
      pixels[destinationOffset + 2] = b << 3;
      pixels[destinationOffset + 3] = 0xff;

      destinationOffset += 4;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image> createRgb888Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      pixels[destinationOffset++] = bytes[sourceOffset++];
      pixels[destinationOffset++] = bytes[sourceOffset++];
      pixels[destinationOffset++] = bytes[sourceOffset++];
      pixels[destinationOffset++] = 0xff;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image> createAlpha8Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final v = 255 - bytes[sourceOffset++];

      pixels[destinationOffset] = v;
      pixels[destinationOffset + 1] = v;
      pixels[destinationOffset + 2] = v;
      pixels[destinationOffset + 3] = 0xff;

      destinationOffset += 4;
    }

    return _createImage(width, height, pixels, ui.FilterQuality.none);
  }

  static Future<ui.Image> createArgb1555Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final v = bytes.getUint16(sourceOffset);
      sourceOffset += 2;

      final a = (v >> 15);
      final r = (v >> 10) & 0x1f;
      final g = (v >> 5) & 0x1f;
      final b = v & 0x1f;
      pixels[destinationOffset] = (r << 3) * a;
      pixels[destinationOffset + 1] = (g << 3) * a;
      pixels[destinationOffset + 2] = (b << 3) * a;
      pixels[destinationOffset + 3] = 255;

      destinationOffset += 4;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image> createRgba8888Image(
    int width,
    int height,
    Uint8List bytes,
  ) {
    final pixels = Uint8List(width * height * 4);
    var sourceOffset = 8;
    var destinationOffset = 0;
    for (var p = 0; p < width * height; ++p) {
      final r = bytes[sourceOffset++];
      final g = bytes[sourceOffset++];
      final b = bytes[sourceOffset++];
      final a = bytes[sourceOffset++];
      pixels[destinationOffset++] = r * a ~/ 255;
      pixels[destinationOffset++] = g * a ~/ 255;
      pixels[destinationOffset++] = b * a ~/ 255;
      pixels[destinationOffset++] = 255;
    }

    return _createImage(width, height, pixels);
  }

  static Future<ui.Image?> fromBytes(Uint8List bytes) async {
    if (bytes.length > 8 && bytes[0] == 0 && bytes[2] == 0 && bytes[3] == 0) {
      final format = bytes[1];
      final width = bytes.getUint16(4);
      final height = bytes.getUint16(6);
      switch (format) {
        case 0:
          // Bitmap
          final bytesPerColumn = (height + 7) >> 3;
          if (bytes.length != bytesPerColumn * width + 8) break;
          return createBitmapImage(width, height, bytes, 8);
        case 1:
          // Luminance
          if (bytes.length != width * height + 8) break;
          return createLuminanceImage(width, height, bytes);
        case 2:
          // Rgb332
          if (bytes.length != width * height + 8) break;
          return createRgb332Image(width, height, bytes);
        case 3:
          // Rgb565
          if (bytes.length != 2 * width * height + 8) break;
          return createRgb565Image(width, height, bytes);
        case 4:
          // Rgb888
          if (bytes.length != 3 * width * height + 8) break;
          return createRgb888Image(width, height, bytes);
        case 5:
          // Alpha8
          if (bytes.length != width * height + 8) break;
          return createAlpha8Image(width, height, bytes);
        case 6:
          // Argb1555
          if (bytes.length != 2 * width * height + 8) break;
          return createArgb1555Image(width, height, bytes);
        case 7:
          // Rgba8888
          if (bytes.length != 4 * width * height + 8) break;
          return createRgba8888Image(width, height, bytes);
      }
    } else {
      final width = bytes[0];
      final height = bytes[1];
      final bytesPerColumn = (height + 7) >> 3;
      if (bytes.length == bytesPerColumn * width + 2) {
        return createBitmapImage(width, height, bytes, 2);
      }
    }

    return null;
  }
}
