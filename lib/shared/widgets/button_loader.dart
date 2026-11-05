import 'package:flutter/material.dart';

import 'maloba_glyph.dart';

/// Loader des boutons : le glyphe MALOBA animé, d'une seule couleur.
class ButtonLoader extends StatelessWidget {
  const ButtonLoader({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: MalobaLoader(
          size: size,
          color: color ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
