import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/common.dart';
import 'reset_password_screen.dart';

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
  final otp = TextEditingController();
  bool resending = false;

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (otp.text.trim().length != 6) {
      showFlash(context, 'Enter the 6-digit OTP.', error: true);
      return;
    }

    final result = await context.read<AuthStore>().verifyPasswordResetOtp(
          email: widget.email,
          otp: otp.text,
        );

    if (!mounted) return;

    if (result.error != null || result.resetToken == null) {
      showFlash(
        context,
        result.error ?? 'The OTP could not be verified.',
        error: true,
      );
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

  Future<void> resend() async {
    setState(() => resending = true);

    final error = await context.read<AuthStore>().resendPasswordResetOtp(
          widget.email,
        );

    if (!mounted) return;
    setState(() => resending = false);

    showFlash(
      context,
      error ?? 'A new password reset OTP has been sent.',
      error: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.password,
            size: 64,
            color: Color(0xFF0F766E),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter verification code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a code to ${widget.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              labelText: '6-digit OTP',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: auth.loading ? null : verify,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(auth.loading ? 'Checking...' : 'Verify OTP'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          TextButton(
            onPressed: resending ? null : resend,
            child: Text(resending ? 'Sending...' : 'Resend OTP'),
          ),
        ],
      ),
    );
  }
}
