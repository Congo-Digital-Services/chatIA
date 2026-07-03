import 'package:flutter/material.dart';

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
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        duration: Duration(seconds: type == AppToastType.error ? 4 : 3),
        content: Container(
          decoration: BoxDecoration(
            color: style.backgroundColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(style.icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

({Color backgroundColor, IconData icon}) _toastStyle(AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return (
        backgroundColor: const Color(0xFF0F7B6C),
        icon: Icons.check_circle_outline_rounded,
      );
    case AppToastType.error:
      return (
        backgroundColor: const Color(0xFF8E2424),
        icon: Icons.error_outline_rounded,
      );
    case AppToastType.warning:
      return (
        backgroundColor: const Color(0xFF9A5C0A),
        icon: Icons.warning_amber_rounded,
      );
    case AppToastType.info:
      return (
        backgroundColor: const Color(0xFF24538E),
        icon: Icons.info_outline_rounded,
      );
  }
}
