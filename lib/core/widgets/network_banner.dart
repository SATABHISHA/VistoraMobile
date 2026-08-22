import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vistora_mobile/core/network/connectivity_provider.dart';

class NetworkBanner extends ConsumerWidget {
  const NetworkBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectivityProvider).value ?? true;
    return Column(
      children: [
        if (!connected)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: const SizedBox(
                width: double.infinity,
                height: 34,
                child: Center(child: Text('No internet connection')),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
