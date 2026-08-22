import 'package:flutter/material.dart';

import 'javelin_script_syntax_highlight.dart';

class JavelinScriptTextEditingController({super.text})
    extends TextEditingController {
  TextSpan? cache;
  var lastText = '';
  TextStyle? lastStyle;
  var lastBrightness = Brightness.light;
  Brightness? brightnessOverride;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final brightness = brightnessOverride ?? Theme.brightnessOf(context);

    if (cache == null ||
        brightness != lastBrightness ||
        !identical(style, lastStyle) ||
        !identical(text, lastText)) {
      lastBrightness = brightness;
      lastStyle = style;
      lastText = text;

      cache = SyntaxHighlightingRule.buildSpans(
        text: text,
        brightness: brightness,
        style: style,
      );
    }

    return cache!;
  }
}
