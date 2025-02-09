import 'package:flutter/material.dart';

import 'javelin_script_syntax_highlight.dart';

class JavelinScriptTextEditingController extends TextEditingController {
  TextSpan? cache;
  var lastText = '';
  TextStyle? lastStyle;
  var lastBrightness = Brightness.light;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final brightness = Theme.of(context).brightness;

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
