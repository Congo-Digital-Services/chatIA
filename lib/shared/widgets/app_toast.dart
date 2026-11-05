import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

OverlayEntry? _activeToastEntry;

/// Notification brève en haut de l'écran : une pastille discrète (icône de
/// couleur + texte court), qui se ferme seule ou au toucher.
///
/// [iconOnly] n'affiche que l'icône dans sa couleur — pour une confirmation
/// évidente (fin de transcription, copie). [message] reste lu par les lecteurs
/// d'écran.
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastType type = AppToastType.info,
  bool iconOnly = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeToastEntry?.remove();
  _activeToastEntry = null;

  late final OverlayEntry entry;
  void remove() {
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
      iconOnly: iconOnly,
      onRemove: remove,
    ),
  );
  _activeToastEntry = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.type,
    required this.iconOnly,
    required this.onRemove,
  });

  final String message;
  final AppToastType type;
  final bool iconOnly;
  final VoidCallback onRemove;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
    reverseDuration: AppMotion.fast,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _motion,
    curve: AppMotion.easeOut,
    reverseCurve: AppMotion.easeOut.flipped,
  );
  Timer? _timer;
  bool _closing = false;

  Duration get _visibleFor => switch (widget.type) {
    AppToastType.success => Duration(
      milliseconds: widget.iconOnly ? 1400 : 2000,
    ),
    AppToastType.info => const Duration(milliseconds: 2600),
    AppToastType.warning => const Duration(milliseconds: 3200),
    AppToastType.error => const Duration(milliseconds: 4000),
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer(_visibleFor, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _motion.value = 1;
    } else if (_motion.value == 0) {
      _motion.forward();
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted && !AppMotion.reduced(context)) {
      await _motion.reverse();
    }
    widget.onRemove();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _toastStyle(widget.type);
    final pill = widget.iconOnly
        ? Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: style.color.withValues(alpha: .28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(style.icon, size: 22, color: Colors.white),
          )
        : Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
            decoration: BoxDecoration(
              color: AppThemeColors.cardStrong,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppThemeColors.stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, size: 18, color: style.color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.textSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(_curve),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(_curve),
                child: Semantics(
                  liveRegion: true,
                  label: widget.message,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    onVerticalDragEnd: (_) => _close(),
                    child: Material(
                      type: MaterialType.transparency,
                      child: pill,
                    ),
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

({Color color, IconData icon}) _toastStyle(AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return (color: _successColor, icon: Icons.check_rounded);
    case AppToastType.error:
      return (color: _errorColor, icon: Icons.error_outline_rounded);
    case AppToastType.warning:
      return (color: _warningColor, icon: Icons.warning_amber_rounded);
    case AppToastType.info:
      return (color: _infoColor, icon: Icons.info_outline_rounded);
  }
}
