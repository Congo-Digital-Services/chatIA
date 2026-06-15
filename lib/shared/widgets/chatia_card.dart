import 'package:flutter/material.dart';

class ChatiaCard extends StatelessWidget {
  const ChatiaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}
