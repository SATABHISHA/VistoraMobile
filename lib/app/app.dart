import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/app/routing/app_router.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';
import 'package:vistora_mobile/core/update/app_update_gate.dart';

class VistoraApp extends ConsumerWidget {
  const VistoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Vistora HRMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          AppUpdateGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
