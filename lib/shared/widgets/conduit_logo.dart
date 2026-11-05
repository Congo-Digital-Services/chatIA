import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'maloba_glyph.dart';

class ConduitLogo extends StatelessWidget {
  const ConduitLogo({super.key});

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
            Text('Conduit', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              'OpenWebUI mobile inspired',
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
