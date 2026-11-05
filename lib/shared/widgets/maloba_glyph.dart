import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// Glyphe MALOBA : quatre barres d'onde arrondies, repris à l'identique du
/// site maloba.congo-digital.com (components/icons.tsx, `Glyphe`, viewBox 27×24).
class MalobaGlyph extends StatelessWidget {
  const MalobaGlyph({super.key, this.size = 24});

  /// Largeur du glyphe ; la hauteur suit la proportion d'origine (24/27).
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 24 / 27,
      child: const CustomPaint(painter: _GlyphPainter()),
    );
  }
}

/// Les quatre couleurs du glyphe, dans l'ordre des barres.
///
/// Déclarées ici parce que c'est ici qu'elles viennent du SVG source : tout
/// ce qui doit reprendre les couleurs du logo les lit à cet endroit, et une
/// retouche de la charte n'a donc qu'un seul endroit à toucher.
const malobaColors = <Color>[_bleu, _orange, _vert, _bleuClair];

const _bleu = Color(0xFF2864AA);
const _orange = Color(0xFFD26E46);
const _vert = Color(0xFF2E7D52);
const _bleuClair = Color(0xFF5C93D0);

// x, y, largeur, hauteur, couleur — valeurs du SVG source. (Un indice de
// liste n'est pas une constante en Dart : d'où les couleurs nommées.)
const _bars = <(double, double, double, double, Color)>[
  (3, 10, 3.4, 8, _bleu),
  (8.9, 4, 3.4, 17, _orange),
  (14.8, 7, 3.4, 12, _vert),
  (20.7, 11, 3.4, 5.5, _bleuClair),
];

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 27;
    for (final (x, y, w, h, color) in _bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale),
          Radius.circular(1.7 * scale),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) => false;
}

/// Indicateur de chargement de l'app : les quatre barres du glyphe MALOBA
/// montent et descendent comme une onde sonore, chacune décalée.
///
/// [color] rend les barres d'une seule couleur (dans un bouton, sur un fond
/// coloré) ; sans [color], les couleurs du logo sont gardées. Si le système
/// demande moins d'animations, les barres restent immobiles et seule leur
/// opacité pulse doucement.
class MalobaLoader extends StatefulWidget {
  const MalobaLoader({
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  /// Largeur du loader ; la hauteur suit la proportion du glyphe.
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  State<MalobaLoader> createState() => _MalobaLoaderState();
}

class _MalobaLoaderState extends State<MalobaLoader>
    with SingleTickerProviderStateMixin {
  // Mouvement continu : cycle linéaire, la forme vient du sinus.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? 'Chargement',
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size * 24 / 27,
          child: CustomPaint(
            painter: _LoaderPainter(
              progress: _controller,
              color: widget.color,
              reduced: AppMotion.reduced(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({
    required this.progress,
    required this.color,
    required this.reduced,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color? color;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 27;
    final middle = size.height / 2;
    final t = progress.value * 2 * math.pi;
    for (var i = 0; i < _bars.length; i++) {
      final (x, _, w, h, barColor) = _bars[i];
      // Onde : chaque barre est décalée d'un quart de cycle sur la précédente.
      final wave = (math.sin(t - i * math.pi / 2) + 1) / 2; // 0 → 1
      // Animé : hauteur entre 35 % et 100 % de la plus grande barre (17).
      // Réduit : hauteurs du logo, seule l'opacité varie.
      final height = (reduced ? h : 17 * (0.35 + 0.65 * wave)) * scale;
      final opacity = reduced ? 0.45 + 0.55 * wave : 1.0;
      final paint = Paint()
        ..color = (color ?? barColor).withValues(alpha: opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset((x + w / 2) * scale, middle),
            width: w * scale,
            height: height,
          ),
          Radius.circular(1.7 * scale),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.reduced != reduced;
}

/// Texte d'attente qui change de mot et de couleur, à la façon d'un terminal
/// qui dit ce qu'il est en train de faire.
///
/// Le mot change toutes les [every] ; la couleur suit celles du glyphe
/// ([malobaColors]), dans l'ordre, pour que l'attente reste visiblement de la
/// même famille que le logo. La transition est un fondu : un changement sec
/// attire l'œil plus que le contenu ne le mérite.
///
/// Si le système demande moins d'animations, le mot et la couleur sont fixes.
/// Une personne qui a désactivé les animations l'a fait pour une raison, et
/// un texte qui clignote est exactement ce qu'elle voulait éviter.
class MalobaThinkingText extends StatefulWidget {
  const MalobaThinkingText({
    super.key,
    this.words = defaultWords,
    this.every = const Duration(milliseconds: 2200),
    this.style,
  });

  /// Les mots défilent dans l'ordre, puis recommencent.
  final List<String> words;
  final Duration every;
  final TextStyle? style;

  /// Verbes à la première personne du pluriel : l'app travaille AVEC la
  /// personne, pas pour elle. « Malobalisons » est le mot-valise du projet.
  static const defaultWords = <String>[
    'Malobalisons',
    'Lingalisons',
    'Réfléchissons',
    'Accordons les tons',
    'Tissons les mots',
    'Cherchons la nuance',
    'Pesons les syllabes',
    'Assemblons',
  ];

  @override
  State<MalobaThinkingText> createState() => _MalobaThinkingTextState();
}

class _MalobaThinkingTextState extends State<MalobaThinkingText> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final step = reduced ? 0 : _index;
    final word = widget.words[step % widget.words.length];
    // Les deux cycles ont des longueurs différentes (8 mots, 4 couleurs), donc
    // un même mot ne revient pas toujours dans la même couleur. C'est voulu :
    // la répétition se remarque moins.
    final color = malobaColors[step % malobaColors.length];
    final style = (widget.style ?? const TextStyle())
        .copyWith(color: color, fontWeight: FontWeight.w600);

    final text = Text('$word…', key: ValueKey(step), style: style);
    if (reduced) return text;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: text,
    );
  }
}
