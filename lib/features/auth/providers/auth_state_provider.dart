import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../shared/models/auth_session.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthController(service)..restore();
});

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;
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
      session = await _service.restoreSession();
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

      // Sur le Web : utilise une popup OAuth.
      // En maquette ou mobile : retourne directement une AuthSession.
      final result = await _service.signInWithSso(usePopup: kIsWeb);
      if (result != null) {
        session = result;
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
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _service.signOut(idTokenHint: session?.idToken);
    session = null;
    errorMessage = null;
    notifyListeners();
  }
}
