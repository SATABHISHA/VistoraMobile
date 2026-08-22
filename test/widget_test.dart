import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistora_mobile/app/app.dart';
import 'package:vistora_mobile/app/providers.dart';
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

void main() {
  testWidgets('unauthenticated app opens the Vistora login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        ],
        child: const VistoraApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VISTORA'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Corporate ID'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
