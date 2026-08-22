import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javelin_steno_script/javelin_script_syntax_highlight.dart';

class JavelinScriptText(
  final String text, {
  super.key,
  TextStyle? style,
  final Brightness? brightness,
  final TextOverflow? overflow,
}) extends StatefulWidget {
  final TextStyle? style = font.merge(style);

  static final font = GoogleFonts.robotoMono();

  @override
  State<JavelinScriptText> createState() => _JavelinScriptTextState();
}

class _JavelinScriptTextState extends State<JavelinScriptText> {
  Brightness? _brightness;
  late InlineSpan _span;

  void updateSpan(Brightness brightness) {
    _brightness = brightness;
    _span = SyntaxHighlightingRule.buildSpans(
      text: widget.text,
      brightness: brightness,
      style: widget.style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness ?? Theme.brightnessOf(context);
    if (brightness != _brightness) {
      updateSpan(brightness);
    }

    return Text.rich(
      _span,
      style: widget.style,
      textAlign: .start,
      overflow: widget.overflow,
    );
  }
}
