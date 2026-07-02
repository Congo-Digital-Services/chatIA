import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/auth_session.dart';
import '../constants/backend_config.dart';
import 'auth_service.dart';
import 'token_storage_service.dart';

class LocalAuthService implements AuthService {
  LocalAuthService({required this.storage, required this.clientFactory});

  final TokenStorageService storage;
  final http.Client Function() clientFactory;

  @override
  Future<AuthSession?> restoreSession() => storage.readSession();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final client = clientFactory();
    try {
      final response = await client.post(
        Uri.parse('${BackendConfig.baseUrl}/api/auth/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (!kIsWeb) 'User-Agent': BackendConfig.userAgent,
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_buildSignInErrorMessage(response));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse de login invalide.');
      }

      final token = decoded['token']?.toString();
      final user = decoded['user'] as Map<String, dynamic>? ?? const {};
      if (token == null || token.isEmpty) {
        throw const FormatException('Token de connexion absent.');
      }

      final refreshToken =
          _extractCookieValue(response.headers['set-cookie'], 'refreshToken') ??
          (kIsWeb ? 'cookie' : null);
      final id = _extractCookieValue(response.headers['set-cookie'], 'token');

      final session = AuthSession(
        accessToken: token,
        refreshToken: refreshToken,
        idToken: id,
        userName:
            user['username']?.toString() ??
            user['name']?.toString() ??
            'Utilisateur',
        email: user['email']?.toString() ?? email,
        expiresAt: _readTokenExpiry(token),
        isMock: false,
        provider: AuthSessionProvider.local,
      );

      await storage.saveSession(session);
      return session;
    } finally {
      client.close();
    }
  }

  String _buildSignInErrorMessage(http.Response response) {
    switch (response.statusCode) {
      case 404:
        return 'Aucun compte n\'existe avec cette adresse e-mail.';
      case 401:
      case 403:
        return 'Identifiants incorrects. Vérifiez votre e-mail et votre mot de passe.';
      default:
        return 'Connexion impossible. Veuillez réessayer.';
    }
  }

  @override
  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final client = clientFactory();
    try {
      final response = await client.post(
        Uri.parse('${BackendConfig.baseUrl}/api/auth/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (!kIsWeb) 'User-Agent': BackendConfig.userAgent,
        },
        body: jsonEncode({
          'name': name,
          'username': username,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Inscription impossible : ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse d’inscription invalide.');
      }

      return decoded['message']?.toString() ??
          'Inscription réussie. Vérifiez votre adresse e-mail.';
    } finally {
      client.close();
    }
  }

  @override
  Future<void> signOut({String? idTokenHint}) async {
    await storage.clear();
  }

  String? _extractCookieValue(String? raw, String name) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final match = RegExp('$name=([^;,\\s]+)').firstMatch(raw);
    return match?.group(1);
  }

  DateTime _readTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return DateTime.now().add(const Duration(minutes: 15));
      }

      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);
      if (json is! Map<String, dynamic>) {
        return DateTime.now().add(const Duration(minutes: 15));
      }

      final exp = json['exp'];
      final seconds = exp is int ? exp : int.tryParse(exp?.toString() ?? '');
      if (seconds == null) {
        return DateTime.now().add(const Duration(minutes: 15));
      }

      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return DateTime.now().add(const Duration(minutes: 15));
    }
  }
}
