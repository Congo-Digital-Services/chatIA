import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChatiaLogo extends StatelessWidget {
  const ChatiaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Icon(Icons.graphic_eq_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ChatIA', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              'Assistant IA securise',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppThemeColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
