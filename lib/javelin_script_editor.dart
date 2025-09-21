import 'package:flutter/material.dart';
import 'package:image/image.dart' show Pixel;
import 'package:javelin_steno_script/image_convert.dart';
import 'package:javelin_steno_script/javelin_script_text.dart';

import 'drop_zone.dart';
import 'file_helper.dart';
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
    required this.autofocus,
    required this.script,
    this.padding = EdgeInsets.zero,
    required this.onChanged,
    this.maxLines,
    this.hintText,
    this.brightness,
  });

  final bool autofocus;
  final String script;
  final EdgeInsetsGeometry padding;
  final void Function(String s) onChanged;
  final int? maxLines;
  final String? hintText;
  final Brightness? brightness;

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
    _textEditingController.brightnessOverride = widget.brightness;
    _textEditingController.value = TextEditingValue(
      text: widget.script,
      selection: const TextSelection(baseOffset: 0, extentOffset: 0),
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static bool isOn(Pixel pixel) =>
      pixel.r < 128 && pixel.g < 128 && pixel.b < 128;

  Future<String> stringForDroppedFile(File file) async {
    final filename = file.name;
    final bytes = await file.bytes;
    if (bytes == null) {
      return '/* Unable to read file data. */';
    }

    final image = ImageConvert.decodeImage(bytes);
    if (image == null) {
      return '/* Unable to decode image. */';
    }

    final imageDataBytes = ImageConvert.convertBitmapImage(image);
    if (imageDataBytes == null) {
      return '/* Invalid image width or height. */';
    }

    final buffer = StringBuffer();
    buffer.write('/* $filename */ [[');
    for (var i = 0; i < imageDataBytes.length; ++i) {
      if (i % 16 == 0) buffer.write('\n ');
      buffer.write(' ${imageDataBytes[i].toRadixString(16).padLeft(2, '0')}');
    }
    buffer.write('\n]]\n');

    return buffer.toString();
  }

  void _handleDrop(File obj) async {
    final code = await stringForDroppedFile(obj);
    final textEditingValue = _textEditingController.value;
    _textEditingController.value =
        textEditingValue.replaced(textEditingValue.selection, code);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: _borderColor == null
            ? null
            : Border.all(color: _borderColor!, width: 2),
      ),
      child: DropZone(
        onDragEnter: () {
          if (_borderColor == null) {
            setState(() => _borderColor = Colors.green);
          }
        },
        onDragExit: () => setState(() => _borderColor = null),
        onDrop: (files) {
          setState(() => _borderColor = null);
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
              autofocus: widget.autofocus,
              maxLines: widget.maxLines,
              expands: widget.maxLines == null,
              style: JavelinScriptText.font,
              decoration: InputDecoration(
                contentPadding: widget.padding,
                border: InputBorder.none,
                hintText: widget.hintText,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ),
    );
  }
}
