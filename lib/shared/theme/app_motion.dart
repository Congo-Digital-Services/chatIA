import 'package:flutter/widgets.dart';

/// Courbes et durées communes des animations de l'app.
///
/// Règles : entrées et sorties en « ease-out » marqué (jamais d'ease-in, qui
/// retarde l'instant regardé), pas de rebond sur l'interface, durées sous
/// 300 ms. Si l'utilisateur a désactivé les animations dans son système,
/// les durées tombent à zéro via [AppMotion.duration].
class AppMotion {
  const AppMotion._();

  /// Ease-out marqué, pour les entrées/sorties d'éléments d'interface.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Ease-in-out marqué, pour un élément qui se déplace à l'écran.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration release = Duration(milliseconds: 160);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration enter = Duration(milliseconds: 220);

  /// L'utilisateur a demandé moins d'animations (réglage d'accessibilité).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [value], ou zéro si les animations sont désactivées dans le système.
  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;
}

/// Léger enfoncement au toucher (retour visuel d'un bouton).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.enabled && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener : n'intercepte pas le geste, le bouton garde son onTap.
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !AppMotion.reduced(context) ? 0.94 : 1,
        duration: _pressed ? AppMotion.press : AppMotion.release,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Apparition d'un élément : fondu et petite montée, jouée une seule fois.
class EnterOnce extends StatefulWidget {
  const EnterOnce({super.key, required this.child, required this.animate});

  final Widget child;
  final bool animate;

  @override
  State<EnterOnce> createState() => _EnterOnceState();
}

class _EnterOnceState extends State<EnterOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.easeOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value < 1 && !_controller.isAnimating) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _progress.value)),
          child: child,
        ),
      ),
    );
  }
}
