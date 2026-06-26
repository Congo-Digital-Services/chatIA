import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChatiaLogo extends StatelessWidget {
  const ChatiaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/icons/congo_logo.png',
          width: 54,
          height: 54,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ChatIA', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              'Assistant IA sécurisé',
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
