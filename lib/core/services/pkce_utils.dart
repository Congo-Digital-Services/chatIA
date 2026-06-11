import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilitaires PKCE (Proof Key for Code Exchange) — RFC 7636.
///
/// Utilisés pour sécuriser le flux Authorization Code dans le service Keycloak.
class PkceUtils {
  const PkceUtils._();

  // ── Génère un code_verifier aléatoire (base64url, 96 octets → ~128 chars) ──
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(96, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  // ── Génère le code_challenge = BASE64URL(SHA256(verifier)) ──────────────────
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // ── Génère un state aléatoire anti-CSRF (16 octets → ~22 chars) ─────────────
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
