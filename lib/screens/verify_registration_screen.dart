import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_ui.dart';

/// Confirms a new account with the 6-digit code emailed at sign-up (or when
/// an unverified account tries to sign in).
class VerifyRegistrationScreen extends StatefulWidget {
  const VerifyRegistrationScreen({
    super.key,
    required this.email,
    required this.rememberMe,
  });

  final String email;
  final bool rememberMe;

  @override
  State<VerifyRegistrationScreen> createState() =>
      _VerifyRegistrationScreenState();
}

class _VerifyRegistrationScreenState extends State<VerifyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final otp = TextEditingController();

  bool _busy = false;
  bool _attempted = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (_busy) return;
    setState(() {
      _attempted = true;
      _error = null;
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final error = await context.read<AuthStore>().verifyRegistration(
          email: widget.email,
          otp: otp.text,
          rememberMe: widget.rememberMe,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<String?> resend() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    final error = await context.read<AuthStore>().resendRegistrationOtp(
          widget.email,
        );

    if (mounted) {
      setState(() {
        _error = error;
        _notice = error == null ? 'We sent a new code to ${widget.email}.' : null;
      });
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      helper: 'Enter the 6-digit code we sent to ${widget.email}.',
      subtitle: 'One last step to finish setting up',
      footer: AuthFooterLink(
        prompt: 'Wrong email?',
        action: 'Back to sign in',
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      children: [
        if (_error != null)
          AuthBanner.error(
            _error!,
            onDismiss: () => setState(() => _error = null),
          ),
        if (_notice != null)
          AuthBanner.success(
            _notice!,
            onDismiss: () => setState(() => _notice = null),
          ),
        Form(
          key: _formKey,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: OtpCodeField(controller: otp, onCompleted: verify),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Verify and continue',
          busyLabel: 'Verifying...',
          busy: _busy,
          onPressed: verify,
        ),
        const SizedBox(height: 8),
        ResendCodeButton(onResend: resend),
      ],
    );
  }
}
