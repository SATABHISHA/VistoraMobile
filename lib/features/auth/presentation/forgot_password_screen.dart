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
  String? _successMessage;

  @override
  void dispose() {
    _corp.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
      _successMessage = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .forgotPassword(
            corpId: _corp.text.trim().toUpperCase(),
            email: _email.text.trim(),
          );
      if (response['success'] != true) {
        throw AppException(
          message:
              response['message']?.toString() ??
              'We could not send the reset link. Please try again.',
        );
      }
      if (mounted) {
        setState(() {
          _successMessage =
              'We sent a secure reset link to your registered email. It expires in 30 minutes.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is AppException
              ? error.message
              : 'Unable to request a password reset. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _successMessage ?? _message;
    final isSuccess = _successMessage != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.9, -0.9),
            radius: 1.7,
            colors: [Color(0xFF25172B), Color(0xFF07091A), Color(0xFF10122B)],
          ),
        ),
        child: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 520,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Back to sign in',
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF171D38), Color(0xFF0D1226)],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Form(
                      key: _key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6A00),
                                      Color(0xFFFF2D78),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44FF5A36),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Colors.white,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 13),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VISTORA',
                                    style: TextStyle(
                                      color: Color(0xFFFFAD35),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.1,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'HRMS PLATFORM',
                                    style: TextStyle(
                                      color: Color(0xFF91A2C8),
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'ACCOUNT RECOVERY',
                            style: TextStyle(
                              color: Color(0xFF79DDFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Forgot your password?',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your Corporate ID and registered email. We’ll send you a secure link to choose a new password.',
                            style: TextStyle(
                              color: Color(0xFF9AA9CA),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _corp,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Corporate ID',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your Corporate ID.'
                                : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Registered email',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(value.trim())
                                ? 'Enter a valid email address.'
                                : null,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                ),
                            child: status == null
                                ? const SizedBox(key: ValueKey('empty'))
                                : Container(
                                    key: ValueKey('$isSuccess:$status'),
                                    margin: const EdgeInsets.only(top: 18),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: isSuccess
                                          ? const Color(0x2210B981)
                                          : const Color(0x22F43F5E),
                                      border: Border.all(
                                        color: isSuccess
                                            ? const Color(0x5534D399)
                                            : const Color(0x55FB7185),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isSuccess
                                              ? Icons.mark_email_read_rounded
                                              : Icons.info_outline_rounded,
                                          color: isSuccess
                                              ? const Color(0xFF6EE7B7)
                                              : colors.error,
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: isSuccess
                                                  ? const Color(0xFFB7F7DC)
                                                  : const Color(0xFFFFC0C8),
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox.square(
                                    dimension: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _loading
                                  ? 'Sending securely…'
                                  : 'Send reset link',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/login'),
                            child: const Text('Back to sign in'),
                          ),
                          const SizedBox(height: 6),
                          const Divider(),
                          const SizedBox(height: 10),
                          const Text(
                            'Ahanova AI Technologies Private Limited',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFD7DFF3),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              Text(
                                'ahanova.in',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'wecare@ahanova.in',
                                style: TextStyle(
                                  color: Color(0xFFFFAD35),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
