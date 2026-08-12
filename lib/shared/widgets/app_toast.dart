import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

OverlayEntry? _activeToastEntry;

void showAppToast(
  BuildContext context, {
  required String message,
  AppToastType type = AppToastType.info,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeToastEntry?.remove();
  _activeToastEntry = null;

  late final OverlayEntry entry;
  void dismiss() {
    if (!entry.mounted) return;
    entry.remove();
    if (identical(_activeToastEntry, entry)) {
      _activeToastEntry = null;
    }
  }

  entry = OverlayEntry(
    builder: (context) => _AppToast(
      message: message,
      type: type,
      onDismiss: dismiss,
    ),
  );
  _activeToastEntry = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final AppToastType type;
  final VoidCallback onDismiss;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    final duration = Duration(
      seconds: widget.type == AppToastType.error ? 4 : 3,
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _entrance.forward();
    _autoDismissTimer = Timer(duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _toastStyle(widget.type);
    final duration = Duration(
      seconds: widget.type == AppToastType.error ? 4 : 3,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppThemeColors.cardStrong,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: style.borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: style.iconBackground,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                style.icon,
                                color: style.iconColor,
                                size: 18,
                              ),
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
                                      color: style.iconColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.message,
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
                            IconButton(
                              onPressed: widget.onDismiss,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppThemeColors.textMuted,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: 'Fermer',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 3,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1, end: 0),
                          duration: duration,
                          curve: Curves.linear,
                          builder: (context, value, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: ColoredBox(color: style.iconColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _successColor = Color(0xFF2FB36B);
const _errorColor = Color(0xFFE5484D);
const _warningColor = Color(0xFFB7791F);
const _infoColor = Color(0xFF3B82F6);

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
        borderColor: _successColor.withValues(alpha: .35),
        iconBackground: _successColor.withValues(alpha: .14),
        iconColor: _successColor,
        icon: Icons.check_circle_rounded,
        title: 'Succès',
      );
    case AppToastType.error:
      return (
        borderColor: _errorColor.withValues(alpha: .35),
        iconBackground: _errorColor.withValues(alpha: .14),
        iconColor: _errorColor,
        icon: Icons.error_rounded,
        title: 'Erreur',
      );
    case AppToastType.warning:
      return (
        borderColor: _warningColor.withValues(alpha: .35),
        iconBackground: _warningColor.withValues(alpha: .14),
        iconColor: _warningColor,
        icon: Icons.priority_high_rounded,
        title: 'Attention',
      );
    case AppToastType.info:
      return (
        borderColor: _infoColor.withValues(alpha: .35),
        iconBackground: _infoColor.withValues(alpha: .14),
        iconColor: _infoColor,
        icon: Icons.info_rounded,
        title: 'Info',
      );
  }
}
