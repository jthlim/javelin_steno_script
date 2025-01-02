import 'dart:io' as io;
import 'package:flutter/widgets.dart';

class DropZone extends StatelessWidget {
  final Widget child;
  final void Function()? onDragEnter;
  final void Function()? onDragExit;

  final void Function(List<io.File>?)? onDrop;

  const DropZone({
    super.key,
    required this.child,
    this.onDrop,
    this.onDragEnter,
    this.onDragExit,
  });

  @override
  Widget build(BuildContext context) => child;
}
