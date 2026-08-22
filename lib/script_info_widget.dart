import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class const ScriptInfoWidget({super.key, final double size = 16})
    extends StatelessWidget {

  static const url =
      'https://github.com/jthlim/javelin-steno/blob/main/script.md';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Script Reference',
      child: GestureDetector(
        onTap: () {
          url_launcher.launchUrl(Uri.parse(url));
        },
        child: Icon(Icons.info, size: size),
      ),
    );
  }
}
