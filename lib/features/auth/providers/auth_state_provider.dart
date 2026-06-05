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

  Future<void> signInWithSso() async {
    if (isLoading) {
      return;
    }

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
      session = await _service.signInWithSso();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut(idTokenHint: session?.idToken);
    session = null;
    errorMessage = null;
    notifyListeners();
  }
}
