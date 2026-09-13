import 'package:flutter/material.dart';
import 'package:vistora_mobile/app/routing/app_router.dart';

import 'app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  final _service = AppUpdateService();
  AppUpdateState? _state;
  bool _dialogOpen = false;
  bool _checking = false;
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking || !mounted) return;
    final now = DateTime.now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < const Duration(seconds: 30)) {
      return;
    }
    _checking = true;
    _lastCheckAt = now;
    try {
      final state = await _service.check();
      if (!mounted) return;
      setState(() => _state = state);
      if (state.hasUpdate) await _showUpdateDialog();
    } catch (_) {
      // Update checks must never prevent the app from opening.
    } finally {
      _checking = false;
    }
  }

  Future<void> _showUpdateDialog() async {
    if (_dialogOpen || !mounted) return;
    final dialogContext = appRootNavigatorKey.currentState?.overlay?.context;
    if (dialogContext == null) return;
    _dialogOpen = true;
    final isMandatory = _state?.isRequired ?? false;
    try {
      await showDialog<void>(
        context: dialogContext,
        barrierDismissible: !isMandatory,
        useRootNavigator: true,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF101329),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
          title: Text(isMandatory ? 'Update required' : 'Update Vistora'),
          content: Text(
            _state?.manifest?.message ??
                'A newer version of Vistora is ready. Update now for the latest improvements.',
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final started = await _service.tryAndroidPlayUpdate();
                if (!started) await _service.openStore(_state?.manifest);
                if (!isMandatory && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: const Text('Update now'),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
