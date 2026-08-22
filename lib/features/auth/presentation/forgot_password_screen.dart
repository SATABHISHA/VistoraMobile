import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vistora_mobile/app/providers.dart';
import 'package:vistora_mobile/core/errors/app_exception.dart';
import 'package:vistora_mobile/core/widgets/responsive_center.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _corp = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _corp.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(
            corpId: _corp.text.trim().toUpperCase(),
            email: _email.text.trim(),
          );
      if (mounted) {
        setState(() {
          _success = true;
          _message = 'If the account exists, reset instructions will be sent.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _success = false;
          _message = error is AppException
              ? error.message
              : 'Unable to request a password reset.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: ResponsiveCenter(
        maxWidth: 520,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Reset password',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your company and registered email address.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _corp,
                    decoration: const InputDecoration(
                      labelText: 'Corporate ID',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Corporate ID is required.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Registered email',
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email.'
                        : null,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _success
                            ? Colors.greenAccent
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Send reset instructions'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
