import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/core/errors/app_exception.dart';
import 'package:vistora_mobile/features/auth/domain/auth_session.dart';

enum AuthStatus { initializing, unauthenticated, authenticating, authenticated }

class AuthState {
  const AuthState({required this.status, this.session, this.errorMessage});

  const AuthState.initializing() : this(status: AuthStatus.initializing);
  const AuthState.unauthenticated({String? message})
    : this(status: AuthStatus.unauthenticated, errorMessage: message);
  const AuthState.authenticating() : this(status: AuthStatus.authenticating);
  const AuthState.authenticated(AuthSession session)
    : this(status: AuthStatus.authenticated, session: session);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(apiClientProvider).onUnauthorized = expireSession;
    unawaited(_restore());
    return const AuthState.initializing();
  }

  Future<void> _restore() async {
    final repository = ref.read(authRepositoryProvider);
    if (!await repository.hasStoredToken()) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      state = AuthState.authenticated(await repository.restoreSession());
    } catch (error) {
      await ref.read(tokenStorageProvider).clear();
      state = AuthState.unauthenticated(message: _message(error));
    }
  }

  Future<bool> login({
    required String corpId,
    required String identity,
    required String password,
  }) async {
    state = const AuthState.authenticating();
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(corpId: corpId, identity: identity, password: password);
      state = AuthState.authenticated(session);
      return true;
    } catch (error) {
      state = AuthState.unauthenticated(message: _message(error));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  void expireSession() {
    state = const AuthState.unauthenticated(
      message: 'Your session has expired. Please sign in again.',
    );
  }

  String _message(Object error) => switch (error) {
    AppException exception => exception.message,
    FormatException exception => exception.message,
    _ => 'Unable to sign in. Please try again.',
  };
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
