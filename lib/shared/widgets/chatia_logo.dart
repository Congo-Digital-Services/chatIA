import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'maloba_glyph.dart';

class ChatiaLogo extends StatelessWidget {
  const ChatiaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 54,
          height: 54,
          child: Center(child: MalobaGlyph(size: 44)),
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
