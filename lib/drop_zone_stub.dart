import 'dart:io' as io;
import 'package:flutter/widgets.dart';

class DropZone extends StatelessWidget {
  final Widget child;
  final void Function()? onDragEnter;
  final void Function()? onDragExit;

  final void Function(List<io.File>?)? onDrop;

  const DropZone({
    required this.child,
    Key? key,
    this.onDrop,
    this.onDragEnter,
    this.onDragExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => child;
}
