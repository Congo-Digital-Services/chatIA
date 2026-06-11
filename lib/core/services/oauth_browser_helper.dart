/// Point d'entrée pour [OAuthBrowserHelper] avec import conditionnel.
///
/// Sur le Web  : utilise [oauth_browser_helper_web.dart]  (dart:html).
/// Sur mobile  : utilise [oauth_browser_helper_stub.dart] (no-op / erreurs).
export 'oauth_browser_helper_stub.dart'
    if (dart.library.html) 'oauth_browser_helper_web.dart';
