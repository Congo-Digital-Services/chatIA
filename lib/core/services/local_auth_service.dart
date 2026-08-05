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

  void _logAuthDebug(String context, String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[Auth][$context] $message');
  }

  @override
  Future<AuthSession?> restoreSession() => storage.readSession();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final client = clientFactory();
    final uri = Uri.parse('${BackendConfig.baseUrl}/api/auth/login');
    try {
      _logAuthDebug('signIn', 'url=$uri');
      _logAuthDebug('signIn', 'email=$email');
      final response = await client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (!kIsWeb) 'User-Agent': BackendConfig.userAgent,
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      _logAuthDebug('signIn', 'status=${response.statusCode}');
      _logAuthDebug('signIn', 'body=${response.body}');

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
      _logAuthDebug(
        'signIn',
        'login success user=${session.userName} email=${session.email}',
      );
      return session;
    } catch (error, stackTrace) {
      _logAuthDebug('signIn', 'error=$error');
      _logAuthDebug('signIn', 'stackTrace=$stackTrace');
      rethrow;
    } finally {
      client.close();
    }
  }

  String _buildSignInErrorMessage(http.Response response) {
    final responseMessage = _responseMessage(response);
    if (response.statusCode == 422 &&
        responseMessage.toLowerCase().contains('email not verified')) {
      return 'Votre e-mail n’est pas vérifié. Consultez votre boîte de réception ou demandez un nouvel e-mail.';
    }
    switch (response.statusCode) {
      case 404:
      case 401:
      case 403:
        return 'E-mail ou mot de passe incorrect. Vérifiez vos identifiants.';
      default:
        return 'Connexion impossible. Veuillez réessayer.';
    }
  }

  String _responseMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? ''
          : '';
    } catch (_) {
      return '';
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
      final uri = Uri.parse('${BackendConfig.baseUrl}/api/auth/register');
      _logAuthDebug('register', 'url=$uri');
      _logAuthDebug(
        'register',
        'email=$email passwordLength=${password.length} '
            'confirmationMatches=${password == confirmPassword}',
      );
      final response = await client.post(
        uri,
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

      _logAuthDebug('register', 'status=${response.statusCode}');
      _logAuthDebug('register', 'body=${response.body}');

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
    } catch (error, stackTrace) {
      _logAuthDebug('register', 'error=$error');
      _logAuthDebug('register', 'stackTrace=$stackTrace');
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<String> verifyEmail({required String email, required String token}) =>
      _postMessage('/api/user/verify', {'email': email, 'token': token});

  @override
  Future<String> resendVerificationEmail({required String email}) =>
      _postMessage('/api/user/verify/resend', {'email': email});

  @override
  Future<String> requestPasswordReset({required String email}) =>
      _postMessage('/api/auth/requestPasswordReset', {'email': email});

  @override
  Future<String> resetPassword({
    required String userId,
    required String token,
    required String password,
  }) => _postMessage('/api/auth/resetPassword', {
    'userId': userId,
    'token': token,
    'password': password,
  });

  Future<String> _postMessage(String path, Map<String, String> payload) async {
    final client = clientFactory();
    try {
      final response = await client.post(
        Uri.parse('${BackendConfig.baseUrl}$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (!kIsWeb) 'User-Agent': BackendConfig.userAgent,
        },
        body: jsonEncode(payload),
      );
      final decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(message ?? 'Opération impossible. Veuillez réessayer.');
      }
      return message ?? 'Opération effectuée avec succès.';
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
