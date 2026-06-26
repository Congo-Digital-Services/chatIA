import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ConduitLogo extends StatelessWidget {
  const ConduitLogo({super.key});

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
            Text(
              'Conduit',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'OpenWebUI mobile inspired',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppThemeColors.textMuted,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
