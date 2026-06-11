// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

/// Implémentation Web de [OAuthBrowserHelper].
///
/// Utilise [html.window.sessionStorage] pour persister le verifier PKCE et le
/// state OAuth2 entre la redirection vers Keycloak et le retour sur le callback.
class OAuthBrowserHelper {
  const OAuthBrowserHelper._();

  static void saveToSession(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  static String? readFromSession(String key) {
    return html.window.sessionStorage[key];
  }

  static void removeFromSession(String key) {
    html.window.sessionStorage.remove(key);
  }

  /// Redirige le navigateur vers [url].
  ///
  /// Provoque le rechargement complet de la page (flux de redirection OAuth2).
  static void redirectTo(String url) {
    html.window.location.href = url;
  }

  /// Ouvre une popup pour le flux OAuth.
  static void openPopup(String url) {
    const width = 520;
    const height = 700;
    final left = ((html.window.screen?.width ?? 0) - width) ~/ 2;
    final top = ((html.window.screen?.height ?? 0) - height) ~/ 2;
    final features = [
      'toolbar=0',
      'menubar=0',
      'width=$width',
      'height=$height',
      'top=$top',
      'left=$left',
      'resizable=1',
      'scrollbars=1',
    ].join(',');

    html.window.open(url, 'chatia_oauth_popup', features);
  }

  static StreamSubscription<html.MessageEvent>? _popupMessageSubscription;

  static void addPopupMessageListener(
    void Function(Map<String, dynamic> message) callback,
  ) {
    removePopupMessageListener();

    _popupMessageSubscription = html.window.onMessage.listen((event) {
      if (event.origin != html.window.location.origin) return;
      final data = event.data;
      if (data is Map<String, dynamic> && data['type'] == 'oauth_popup_result') {
        callback(data);
      }
    });
  }

  static void removePopupMessageListener() {
    _popupMessageSubscription?.cancel();
    _popupMessageSubscription = null;
  }

  static bool hasOpener() => html.window.opener != null;

  static void postMessageToOpener(Map<String, dynamic> message) {
    final opener = html.window.opener;
    if (opener != null) {
      opener.postMessage(message, html.window.location.origin);
    }
  }

  static void closeWindow() {
    html.window.close();
  }
}
