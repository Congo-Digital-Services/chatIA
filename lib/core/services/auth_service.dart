import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_session.dart';

abstract class AuthService {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> signIn({required String email, required String password});

  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  });

  Future<String> verifyEmail({required String email, required String token});

  Future<String> resendVerificationEmail({required String email});

  Future<String> requestPasswordReset({required String email});

  Future<String> resetPassword({
    required String userId,
    required String token,
    required String password,
  });

  Future<void> signOut({String? idTokenHint});
}

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be overridden in ProviderScope.');
});
