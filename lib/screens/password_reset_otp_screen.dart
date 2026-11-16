import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_ui.dart';
import 'reset_password_screen.dart';

/// Step 2 of 3 of password recovery: enter the emailed 6-digit code.
class PasswordResetOtpScreen extends StatefulWidget {
  const PasswordResetOtpScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<PasswordResetOtpScreen> createState() =>
      _PasswordResetOtpScreenState();
}

class _PasswordResetOtpScreenState extends State<PasswordResetOtpScreen> {
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

    final result = await context.read<AuthStore>().verifyPasswordResetOtp(
          email: widget.email,
          otp: otp.text,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.error != null || result.resetToken == null) {
      setState(() => _error = result.error ?? 'The code could not be verified.');
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          email: widget.email,
          resetToken: result.resetToken!,
        ),
      ),
    );
  }

  Future<String?> resend() async {
    setState(() {
      _error = null;
      _notice = null;
    });

    final error = await context.read<AuthStore>().resendPasswordResetOtp(
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
      step: 'Step 2 of 3',
      title: 'Check your email',
      helper: 'Enter the 6-digit code we sent to ${widget.email}.',
      subtitle: 'Secure account recovery',
      footer: AuthFooterLink(
        prompt: 'Changed your mind?',
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
          label: 'Verify code',
          busyLabel: 'Checking...',
          busy: _busy,
          onPressed: verify,
        ),
        const SizedBox(height: 8),
        ResendCodeButton(onResend: resend),
      ],
    );
  }
}
