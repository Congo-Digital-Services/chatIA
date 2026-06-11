import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_session.dart';

/// Interface du service d'authentification.
///
/// Sur le Web, [signInWithSso] retourne [null] car la session est créée
/// après le retour du navigateur depuis Keycloak, via [handleOAuthCallback].
abstract class AuthService {
  /// Restaure une session persistée.
  Future<AuthSession?> restoreSession();

  /// Lance le flux SSO.
  ///
  /// - Retourne une [AuthSession] en mode maquette ou mobile.
  /// - Retourne [null] sur le Web (redirection navigateur ou popup initiée).
  Future<AuthSession?> signInWithSso({bool usePopup = false});

  /// Traite le callback OAuth2 (échange code → tokens).
  ///
  /// Appelé depuis [OAuthCallbackPage] avec le `code` et le `state`
  /// extraits des paramètres de l'URL de retour.
  Future<AuthSession> handleOAuthCallback(String code, String state);

  /// Déconnecte l'utilisateur et efface la session stockée.
  Future<void> signOut({String? idTokenHint});
}

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be overridden in ProviderScope.');
});
