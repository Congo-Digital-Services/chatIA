// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

/// Web implementation of configureUrlStrategy.
///
/// 1. Configures the Flutter application to use Path URL Strategy (no `#` in URL).
/// 2. Redirects from 127.0.0.1 to localhost to prevent session storage loss
///    and match Keycloak's client configurations.
void configureUrlStrategy() {
  usePathUrlStrategy();

  if (html.window.location.hostname == '127.0.0.1') {
    final newUrl = html.window.location.href.replaceFirst(
      '://127.0.0.1',
      '://localhost',
    );
    html.window.location.replace(newUrl);
  }
}
