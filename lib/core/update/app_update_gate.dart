import 'package:flutter/material.dart';

import 'app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  final _service = AppUpdateService();
  AppUpdateState? _state;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final state = await _service.check();
    if (!mounted) return;
    setState(() {
      _state = state;
    });
    if (state.isRequired) await _showUpdateDialog();
  }

  Future<void> _showUpdateDialog() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101329),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF7A00), Color(0xFFE94E75)],
            ),
          ),
          child: const Center(
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        title: const Text('Update Vistora'),
        content: Text(
          _state?.manifest?.message ??
              'Please install the latest version to continue using Vistora.',
        ),
        actions: [
          if (_state?.manifest?.forceUpdate == false)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton.icon(
            onPressed: () async {
              final started = await _service.tryAndroidPlayUpdate();
              if (!started) await _service.openStore(_state?.manifest);
              if (context.mounted) Navigator.of(context).pop();
              if (_state?.manifest?.forceUpdate != false) {
                _dialogOpen = false;
                await _checkForUpdate();
              }
            },
            icon: const Icon(Icons.system_update_alt_rounded),
            label: const Text('Update now'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
