import 'dart:html' as html;
import 'dart:typed_data';

import 'package:drop_zone/drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' show Pixel, decodePng;

import 'javelin_script_text_editing_controller.dart';

class HideScrollbarBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class JavelinScriptEditor extends StatefulWidget {
  const JavelinScriptEditor({
    super.key,
    required this.script,
    required this.padding,
    required this.onChanged,
  });

  final String script;
  final EdgeInsetsGeometry padding;
  final void Function(String s) onChanged;

  @override
  State<StatefulWidget> createState() => JavelinScriptEditorState();
}

class JavelinScriptEditorState extends State<JavelinScriptEditor> {
  final _textEditingController = JavelinScriptTextEditingController();
  final _scrollController = ScrollController();
  Color? _borderColor;

  @override
  void initState() {
    super.initState();
    _textEditingController.value = TextEditingValue(
      text: widget.script,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: 0,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
    _scrollController.dispose();
    //  _dropZoneController = null;
  }

  static bool isOn(Pixel pixel) =>
      pixel.r < 128 && pixel.g < 128 && pixel.b < 128;

  Future<String> stringForDroppedFile(html.File file) async {
    final filename = file.name;
    if (file.type != 'image/png') {
      return '/* Unable to convert: Only PNG files supported. */';
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final data = reader.result as Uint8List?;
    if (data == null) {
      return '/* Unable to read file data. */';
    }

    final image = decodePng(data);
    if (image == null) {
      return '/* Unable to decode PNG. */';
    }
    final width = image.width;
    final height = image.height;

    if (width == 0 || height == 0 || width >= 256 || height >= 256) {
      return '/* PNG width & height must be less than 256. */';
    }

    final imageData = BytesBuilder();
    imageData.addByte(width);
    imageData.addByte(height);

    for (var x = 0; x < width; ++x) {
      for (int yy = 0; yy < height; yy += 8) {
        int data = 0;
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

    final buffer = StringBuffer();
    final imageDataBytes = imageData.toBytes();
    buffer.write('/* $filename */ [[');
    for (var i = 0; i < imageDataBytes.length; ++i) {
      if (i % 16 == 0) buffer.write('\n ');
      buffer.write(' ${imageDataBytes[i].toRadixString(16).padLeft(2, '0')}');
    }
    buffer.write('\n]]\n');

    return buffer.toString();
  }

  void _handleDrop(html.File obj) async {
    setState(() => _borderColor = null);
    final code = await stringForDroppedFile(obj);
    final textEditingValue = _textEditingController.value;
    _textEditingController.value =
        textEditingValue.replaced(textEditingValue.selection, code);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DropZone(
          onDragEnter: () {
            if (_borderColor == null) {
              setState(() => _borderColor = Colors.green);
            }
          },
          onDragExit: () => setState(() => _borderColor = null),
          onDrop: (files) {
            if (files == null) return;
            for (final file in files) {
              _handleDrop(file);
            }
          },
          child: Scrollbar(
            controller: _scrollController,
            child: ScrollConfiguration(
              behavior: HideScrollbarBehavior(),
              child: TextField(
                controller: _textEditingController,
                scrollController: _scrollController,
                autofocus: true,
                maxLines: null,
                expands: true,
                style: GoogleFonts.robotoMono(),
                decoration: InputDecoration(
                  contentPadding: widget.padding,
                  border: InputBorder.none,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
        if (_borderColor != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor!, width: 2),
            ),
            child: const SizedBox.expand(),
          ),
      ],
    );
  }
}
