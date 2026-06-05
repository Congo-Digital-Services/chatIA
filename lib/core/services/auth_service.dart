import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_session.dart';

abstract class AuthService {
  Future<AuthSession?> restoreSession();
  Future<AuthSession> signInWithSso();
  Future<void> signOut({String? idTokenHint});
}

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be overridden.');
});
