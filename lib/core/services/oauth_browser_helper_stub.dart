/// Stub — plateformes non-web (mobile, desktop).
///
/// Les méthodes sont des no-ops ou lèvent [UnsupportedError] selon le contexte.
class OAuthBrowserHelper {
  const OAuthBrowserHelper._();

  static void saveToSession(String key, String value) {
    // Pas de sessionStorage hors du Web.
  }

  static String? readFromSession(String key) => null;

  static void removeFromSession(String key) {
    // No-op.
  }

  static void redirectTo(String url) {
    throw UnsupportedError(
      'La redirection navigateur n\'est pas disponible sur cette plateforme.',
    );
  }

  static void openPopup(String url) {
    throw UnsupportedError(
      'La popup OAuth n\'est pas disponible sur cette plateforme.',
    );
  }

  static void addPopupMessageListener(
    void Function(Map<String, dynamic> message) callback,
  ) {
    // No-op hors du Web.
  }

  static void removePopupMessageListener() {
    // No-op hors du Web.
  }

  static bool hasOpener() => false;

  static void postMessageToOpener(Map<String, dynamic> message) {
    // No-op hors du Web.
  }

  static void closeWindow() {
    // No-op hors du Web.
  }
}
