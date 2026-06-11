/// Conditional export for URL strategy helper.
///
/// Automatically uses the web implementation when compiled for Web,
/// and a no-op stub on mobile or desktop platforms.
export 'url_strategy_helper_stub.dart'
    if (dart.library.html) 'url_strategy_helper_web.dart';
