import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chatia/core/services/live_transcriber.dart';
import 'package:flutter_test/flutter_test.dart';

const _rate = 16000;

/// Bloc PCM 16 bits de [ms] millisecondes : sinusoïde (« parole ») ou zéros.
Uint8List _bloc(int ms, {bool voix = true}) {
  final n = _rate * ms ~/ 1000;
  final data = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    final v = voix
        ? (8000 * math.sin(2 * math.pi * 220 * i / _rate)).round()
        : 0;
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Alimente le segmenteur par blocs de 100 ms et collecte les segments rendus.
List<Uint8List> _alimenter(SpeechSegmenter seg, List<(int, bool)> plan) {
  final sortis = <Uint8List>[];
  for (final (ms, voix) in plan) {
    for (var t = 0; t < ms; t += 100) {
      final s = seg.add(_bloc(100, voix: voix));
      if (s != null) sortis.add(s);
    }
  }
  return sortis;
}

void main() {
  test('coupe un segment à la pause qui suit la parole', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(1500, true), (1000, false)]);

    expect(sortis, hasLength(1));
    // 1,5 s de parole + 0,25 s de fin : le reste de la pause n'est pas envoyé.
    final ms = sortis.single.length / 2 / _rate * 1000;
    expect(ms, inInclusiveRange(1700, 1800));
  });

  test('deux phrases séparées par une pause donnent deux segments', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [
      (1200, true),
      (900, false),
      (1200, true),
      (900, false),
    ]);
    expect(sortis, hasLength(2));
  });

  test('le silence seul n’est jamais envoyé', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(6000, false)]);
    expect(sortis, isEmpty);
    expect(seg.flush(), isNull);
  });

  test('une parole sans aucune pause est coupée avant 25 s', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(26000, true)]);
    expect(sortis, hasLength(1));
    expect(sortis.single.length / 2 / _rate, inInclusiveRange(23, 25));
  });

  test('au-delà de 25 s, la coupe tombe sur le passage le plus calme', () {
    final seg = SpeechSegmenter();
    // Un creux de 100 ms, trop court même pour une respiration (250 ms),
    // puis de la voix jusqu'à la limite.
    final sortis = _alimenter(seg, [(23900, true), (100, false), (2000, true)]);
    expect(sortis, hasLength(1));
    // Coupe dans le creux, vers 24 s, pas en plein mot à 25 s.
    expect(sortis.single.length / 2 / _rate, closeTo(24, 0.15));
  });

  test('passé 10 s, une respiration suffit à couper', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(11000, true), (300, false), (500, true)]);
    expect(sortis, hasLength(1));
    expect(sortis.single.length / 2 / _rate, closeTo(11.25, 0.1));
  });

  test('avant 10 s, une respiration ne coupe pas la phrase', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(3000, true), (300, false), (3000, true)]);
    expect(sortis, isEmpty);
    expect(seg.flush(), isNotNull);
  });

  test('le silence de début n’est pas envoyé', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [
      (3000, false),
      (1000, true),
      (1000, false),
    ]);
    expect(sortis, hasLength(1));
    // 0,3 s d'amorce + 1 s de parole + 0,25 s de fin.
    expect(sortis.single.length / 2 / _rate, closeTo(1.55, 0.1));
  });

  test('un bruit bref (sous la parole minimale) est ignoré', () {
    final seg = SpeechSegmenter();
    final sortis = _alimenter(seg, [(200, true), (1500, false)]);
    expect(sortis, isEmpty);
  });

  test('flush rend la fin de phrase en cours à l’arrêt', () {
    final seg = SpeechSegmenter();
    _alimenter(seg, [(1000, true)]);
    expect(seg.flush(), isNotNull);
  });

  test('le niveau suit la voix', () {
    final seg = SpeechSegmenter();
    seg.add(_bloc(100));
    expect(seg.level, greaterThan(0.5));
    seg.add(_bloc(100, voix: false));
    expect(seg.level, 0);
  });

  test('l’en-tête WAV est valide', () {
    final pcm = _bloc(500);
    final wav = SpeechSegmenter.wav(pcm);
    final d = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(d.getUint32(24, Endian.little), _rate);
    expect(d.getUint16(34, Endian.little), 16);
    expect(d.getUint32(40, Endian.little), pcm.length);
    expect(wav.length, pcm.length + 44);
  });
}
