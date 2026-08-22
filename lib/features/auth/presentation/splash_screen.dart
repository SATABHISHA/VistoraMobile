import 'package:flutter/material.dart';
import 'package:vistora_mobile/core/widgets/vistora_brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VistoraBrand(),
              SizedBox(height: 28),
              SizedBox(width: 160, child: LinearProgressIndicator()),
              SizedBox(height: 14),
              Text('Preparing your workspace...'),
            ],
          ),
        ),
      ),
    );
  }
}
