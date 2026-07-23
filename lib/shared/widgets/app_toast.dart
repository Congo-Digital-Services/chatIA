import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

void showAppToast(
  BuildContext context, {
  required String message,
  AppToastType type = AppToastType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final style = _toastStyle(type);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: Duration(seconds: type == AppToastType.error ? 4 : 3),
        content: Container(
          decoration: BoxDecoration(
            color: AppThemeColors.cardStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: style.borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: style.iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, color: style.iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.title,
                      style: TextStyle(
                        color: AppThemeColors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: AppThemeColors.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

({
  Color borderColor,
  Color iconBackground,
  Color iconColor,
  IconData icon,
  String title,
})
_toastStyle(AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return (
        borderColor: AppThemeColors.strokeStrong,
        iconBackground: AppThemeColors.pill,
        iconColor: AppThemeColors.success,
        icon: Icons.check_rounded,
        title: 'Info',
      );
    case AppToastType.error:
      return (
        borderColor: AppThemeColors.strokeStrong,
        iconBackground: AppThemeColors.pill,
        iconColor: AppThemeColors.danger,
        icon: Icons.close_rounded,
        title: 'Erreur',
      );
    case AppToastType.warning:
      return (
        borderColor: AppThemeColors.strokeStrong,
        iconBackground: AppThemeColors.pill,
        iconColor: AppThemeColors.warning,
        icon: Icons.priority_high_rounded,
        title: 'Info',
      );
    case AppToastType.info:
      return (
        borderColor: AppThemeColors.strokeStrong,
        iconBackground: AppThemeColors.pill,
        iconColor: AppThemeColors.info,
        icon: Icons.auto_awesome_rounded,
        title: 'Info',
      );
  }
}
