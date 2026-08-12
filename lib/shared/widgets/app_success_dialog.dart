import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<void> showAppSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onDone,
  String actionLabel = 'Compris',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: AppThemeColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 30,
                    color: AppThemeColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.textSoft,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onDone();
                  },
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
