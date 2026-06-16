import 'dart:convert';

class JwtDebugInfo {
  const JwtDebugInfo({
    required this.alg,
    required this.typ,
    required this.kid,
    required this.iss,
    required this.aud,
    required this.azp,
    required this.tokenLength,
    required this.tokenPreview,
  });

  final String alg;
  final String typ;
  final String kid;
  final String iss;
  final String aud;
  final String azp;
  final int tokenLength;
  final String tokenPreview;

  @override
  String toString() {
    return 'alg=$alg typ=$typ kid=$kid iss=$iss aud=$aud azp=$azp '
        'len=$tokenLength preview=$tokenPreview';
  }
}

class JwtDebugHelper {
  const JwtDebugHelper._();

  static JwtDebugInfo? inspect(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    final parts = token.split('.');
    if (parts.length < 2) {
      return JwtDebugInfo(
        alg: 'n/a',
        typ: 'n/a',
        kid: 'n/a',
        iss: 'n/a',
        aud: 'n/a',
        azp: 'n/a',
        tokenLength: token.length,
        tokenPreview: _preview(token),
      );
    }

    final header = _decodePart(parts[0]);
    final payload = _decodePart(parts[1]);

    return JwtDebugInfo(
      alg: header['alg']?.toString() ?? 'n/a',
      typ: header['typ']?.toString() ?? 'n/a',
      kid: header['kid']?.toString() ?? 'n/a',
      iss: payload['iss']?.toString() ?? 'n/a',
      aud: _audToString(payload['aud']),
      azp: payload['azp']?.toString() ?? 'n/a',
      tokenLength: token.length,
      tokenPreview: _preview(token),
    );
  }

  static Map<String, dynamic> _decodePart(String raw) {
    try {
      var normalized = raw.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final decoded = utf8.decode(base64Decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _audToString(dynamic aud) {
    if (aud is List) {
      return aud.map((item) => item.toString()).join(',');
    }
    return aud?.toString() ?? 'n/a';
  }

  static String _preview(String token) {
    if (token.length <= 16) {
      return token;
    }
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }
}
