import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/backend_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/librechat_session_service.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../shared/models/auth_session.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final service = ref.watch(authServiceProvider);
  final storage = ref.watch(tokenStorageServiceProvider);
  final libreChatSession = ref.watch(libreChatSessionServiceProvider);
  return AuthController(service, storage, libreChatSession)..restore();
});

class AuthController extends ChangeNotifier {
  AuthController(this._service, this._storage, this._libreChatSession);

  static const _resetAuthOnStart = bool.fromEnvironment(
    'RESET_AUTH_ON_START',
    defaultValue: false,
  );

  final AuthService _service;
  final TokenStorageService _storage;
  final LibreChatSessionService _libreChatSession;
  AuthSession? session;
  bool isLoading = false;
  bool isRestoring = true;
  String? errorMessage;

  bool get isAuthenticated => session != null;

  // ── Restauration de session au démarrage ──────────────────────────────────
  Future<void> restore() async {
    try {
      isRestoring = true;
      errorMessage = null;
      notifyListeners();

      if (kDebugMode && _resetAuthOnStart) {
        await _storage.clear();
        session = null;
        _libreChatSession.hydrateSession(null);
        return;
      }

      final restoredSession = await _service.restoreSession();
      if (restoredSession == null) {
        session = null;
        _libreChatSession.hydrateSession(null);
        return;
      }

      if (restoredSession.isMock) {
        await _storage.clear();
        session = null;
        _libreChatSession.hydrateSession(null);
        return;
      }

      if (restoredSession.isExpired) {
        if (!restoredSession.supportsAutomaticRefresh) {
          await _storage.clear();
          session = null;
          _libreChatSession.hydrateSession(null);
          return;
        }

        session = restoredSession;
        _libreChatSession.hydrateSession(restoredSession);
        try {
          session = await _libreChatSession.refreshSession(
            restoredSession,
            persist: true,
          );
        } catch (_) {
          session = null;
          _libreChatSession.hydrateSession(null);
        }
        return;
      }

      session = restoredSession;
      _libreChatSession.hydrateSession(restoredSession);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  // ── Lancement du flux SSO ─────────────────────────────────────────────────
  /// Sur le Web, cette méthode redirige le navigateur et retourne sans session.
  /// La session sera définie via [handleOAuthCallback] après le retour.
  Future<void> signInWithSso() async {
    if (isLoading) return;

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Le flux par redirection complète est plus robuste que la popup:
      // pas de blocage navigateur et pas de dépendance au postMessage.
      final result = await _service.signInWithSso(usePopup: false);
      if (result != null) {
        session = result;
        _libreChatSession.hydrateSession(result);
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setErrorMessage(String message) {
    errorMessage = message;
    notifyListeners();
  }

  // ── Traitement du callback OAuth2 ─────────────────────────────────────────
  /// Appelé par [OAuthCallbackPage] après le retour depuis Keycloak.
  Future<void> handleOAuthCallback(String code, String state) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      session = await _service.handleOAuthCallback(code, state);
      _libreChatSession.hydrateSession(session);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSession(AuthSession newSession) async {
    session = newSession;
    errorMessage = null;
    _libreChatSession.hydrateSession(newSession);
    await _storage.saveSession(newSession);
    notifyListeners();
  }

  Future<void> clearSession() async {
    session = null;
    _libreChatSession.hydrateSession(null);
    await _storage.clear();
    notifyListeners();
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    final currentSession = session;
    final currentErrorMessage = errorMessage;

    isLoading = true;
    session = null;
    errorMessage = null;
    _libreChatSession.hydrateSession(null);
    notifyListeners();

    try {
      if (currentSession != null && !currentSession.isMock) {
        await _signOutFromLibreChatBackend(currentSession.accessToken);
      }
    } catch (_) {
      // Le logout OIDC doit quand même continuer même si LibreChat refuse.
    } finally {
      try {
        await _service.signOut(idTokenHint: currentSession?.idToken);
      } catch (_) {
        errorMessage = currentErrorMessage;
      } finally {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> _signOutFromLibreChatBackend(String accessToken) async {
    final response = await http.post(
      Uri.parse('${BackendConfig.baseUrl}/api/auth/logout'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        if (!kIsWeb) 'User-Agent': BackendConfig.userAgent,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de fermer la session LibreChat : ${response.statusCode}',
      );
    }
  }
}
