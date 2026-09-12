import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/app/app.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/core/storage/login_identity_storage.dart';
import 'package:vistora_mobile/core/storage/token_storage.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

class _MemoryLoginIdentityStorage implements LoginIdentityStorage {
  _MemoryLoginIdentityStorage([this.remembered]);

  RememberedLogin? remembered;

  @override
  Future<RememberedLogin?> read() async => remembered;

  @override
  Future<void> write({required String corpId, required String identity}) async {
    remembered = RememberedLogin(corpId: corpId, identity: identity);
  }

  @override
  Future<void> clear() async => remembered = null;
}

void main() {
  testWidgets('unauthenticated app opens the Vistora login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
          loginIdentityStorageProvider.overrideWithValue(
            _MemoryLoginIdentityStorage(),
          ),
        ],
        child: const VistoraApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VISTORA'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Corporate ID'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
  });

  testWidgets('login form restores remembered company and identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
          loginIdentityStorageProvider.overrideWithValue(
            _MemoryLoginIdentityStorage(
              const RememberedLogin(
                corpId: 'AHN001',
                identity: 'person@example.com',
              ),
            ),
          ),
        ],
        child: const VistoraApp(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    final corpIdField = fields.first;
    final identityField = fields.elementAt(1);
    expect(corpIdField.controller?.text, 'AHN001');
    expect(identityField.controller?.text, 'person@example.com');
  });
}
