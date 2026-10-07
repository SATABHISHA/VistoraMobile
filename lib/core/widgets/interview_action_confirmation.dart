import 'package:flutter/material.dart';

Future<bool> confirmInterviewAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.94, end: 1),
          duration: const Duration(milliseconds: 180),
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AlertDialog(
            scrollable: true,
            icon: Icon(
              Icons.fact_check_outlined,
              color: Theme.of(dialogContext).colorScheme.primary,
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
