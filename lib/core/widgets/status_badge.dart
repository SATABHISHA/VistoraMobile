import 'package:flutter/material.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'present' ||
      'approved' ||
      'released' ||
      'completed' => VistoraColors.green,
      'pending' || 'half_day' || 'leave' || 'on_hold' => VistoraColors.amber,
      'rejected' || 'absent' || 'cancelled' => const Color(0xFFFF6B7A),
      _ => VistoraColors.cyan,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
