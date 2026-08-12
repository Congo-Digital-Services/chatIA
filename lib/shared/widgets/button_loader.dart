import 'package:flutter/material.dart';

class ButtonLoader extends StatelessWidget {
  const ButtonLoader({
    super.key,
    this.size = 18,
    this.strokeWidth = 2.5,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        color: color ?? Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
