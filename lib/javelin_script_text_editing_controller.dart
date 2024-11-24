import 'package:flutter/material.dart';

class SyntaxHighlightingRule {
  SyntaxHighlightingRule(this.pattern, this.lightMode, this.darkMode,
      [this.nestedRules]);

  final RegExp pattern;
  final TextStyle lightMode;
  final TextStyle darkMode;
  final List<SyntaxHighlightingRule>? nestedRules;

  TextStyle textStyle(Brightness brightness) =>
      brightness == Brightness.light ? lightMode : darkMode;

  static final rules = <SyntaxHighlightingRule>[
    // Data literals.
    SyntaxHighlightingRule(
      RegExp(r'(?<!\[)\[\[(?!\[).*?\]\]', unicode: true, dotAll: true),
      const TextStyle(color: Color(0xFF4527A0)), // purple800
      const TextStyle(color: Color(0xFFB39DDB)), // purple200
      [
        SyntaxHighlightingRule(
          RegExp(r'//.*|/\*.*?\*/', unicode: true),
          const TextStyle(color: Colors.green),
          const TextStyle(color: Colors.green),
        ),
      ],
    ),

    // Comments
    SyntaxHighlightingRule(
      RegExp(r'//.*|/\*.*?\*/', unicode: true),
      const TextStyle(color: Colors.green),
      const TextStyle(color: Colors.green),
    ),

    // String literals.
    SyntaxHighlightingRule(
      RegExp(r'"(?:\\.|[^\\"])*"?', unicode: true),
      const TextStyle(color: Color(0xFF4527A0)), // purple800
      const TextStyle(color: Color(0xFFB39DDB)), // purple200
    ),

    // Keywords
    SyntaxHighlightingRule(
      RegExp(r'\b(?:func|for|const|var|return|if|else|while|do)\b',
          unicode: true),
      const TextStyle(color: Color(0xFFAD1457)), // pink800
      const TextStyle(color: Color(0xFFF48FB1)), // pink200
    ),

    // Operator
    SyntaxHighlightingRule(
      RegExp(r'[!@*/%+=^&|?:;<>\[\],-]+', unicode: true),
      const TextStyle(color: Colors.blueGrey),
      const TextStyle(color: Color(0xFF80DEEA)), // Colors.cyan[200],
    ),

    // Brackets
    SyntaxHighlightingRule(
      RegExp(r'[{}()]+', unicode: true),
      const TextStyle(color: Colors.brown),
      const TextStyle(color: Color(0xFFFBC02D)), // Colors.yellow[700]
    ),

    // Numbers
    SyntaxHighlightingRule(
      RegExp(r'\b(?:0x[0-9a-f]+|[0-9]+)\b', unicode: true),
      const TextStyle(color: Color(0xFFAA00FF)), // purpleAccent700
      const TextStyle(color: Color(0xFFEA80FC)), // purpleAccent100
    ),
  ];
}

class JavelinScriptTextEditingController extends TextEditingController {
  static Iterable<TextSpan> colorSpanWithRules({
    required String text,
    required List<SyntaxHighlightingRule> rules,
    required int index,
    required Brightness brightness,
    TextStyle? style,
  }) sync* {
    if (index >= rules.length) {
      yield TextSpan(text: text, style: style);
      return;
    }

    var offset = 0;
    final rule = rules[index];
    for (final match in rule.pattern.allMatches(text)) {
      if (match.start != offset) {
        yield* colorSpanWithRules(
          text: text.substring(offset, match.start),
          rules: rules,
          index: index + 1,
          brightness: brightness,
          style: style,
        );
      }
      final nestedRules = rule.nestedRules;
      if (nestedRules != null) {
        yield* colorSpanWithRules(
          text: match.group(0)!,
          rules: nestedRules,
          index: 0,
          brightness: brightness,
          style: rule.textStyle(brightness),
        );
      } else {
        yield TextSpan(
          text: match.group(0),
          style: rule.textStyle(brightness),
        );
      }

      offset = match.end;
    }
    if (offset != text.length) {
      yield* colorSpanWithRules(
        text: text.substring(offset),
        rules: rules,
        index: index + 1,
        brightness: brightness,
        style: style,
      );
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final brightness = Theme.of(context).brightness;
    return TextSpan(
      style: style,
      children: colorSpanWithRules(
        brightness: brightness,
        text: text,
        rules: SyntaxHighlightingRule.rules,
        index: 0,
      ).toList(),
    );
  }
}
