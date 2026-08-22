import 'dart:io' as io;
import 'package:flutter/widgets.dart';

class const DropZone({
  super.key,
  required final Widget child,
  final void Function(List<io.File>?)? onDrop,
  final void Function()? onDragEnter,
  final void Function()? onDragExit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => child;
}
