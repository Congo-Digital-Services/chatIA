import 'package:chatia/core/services/auth_service.dart';
import 'package:chatia/main.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ChatIAApp builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_FakeAuthService())],
        child: const ChatIAApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _FakeAuthService implements AuthService {
  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    return AuthSession.mock();
  }

  @override
  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return 'Please check your email to verify your email address.';
  }

  @override
  Future<void> signOut({String? idTokenHint}) async {}
}
