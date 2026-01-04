import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javelin_steno_script/javelin_script_syntax_highlight.dart';

class JavelinScriptText extends StatefulWidget {
  JavelinScriptText(
    this.text, {
    super.key,
    TextStyle? style,
    this.brightness,
    this.overflow,
  }) : style = font.merge(style);

  final String text;
  final TextStyle? style;
  final Brightness? brightness;
  final TextOverflow? overflow;

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
    final brightness = widget.brightness ?? Theme.of(context).brightness;
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
