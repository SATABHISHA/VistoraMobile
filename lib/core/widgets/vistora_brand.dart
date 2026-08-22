import 'package:flutter/material.dart';
import 'package:vistora_mobile/app/theme/app_theme.dart';

class VistoraBrand extends StatelessWidget {
  const VistoraBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vistora HRMS',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 42 : 54,
            height: compact ? 42 : 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 13 : 17),
              gradient: const LinearGradient(
                colors: [VistoraColors.orange, VistoraColors.pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x55FF2D78), blurRadius: 24),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 21 : 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [VistoraColors.orange, VistoraColors.amber],
            ).createShader(bounds),
            child: Text(
              'VISTORA',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
