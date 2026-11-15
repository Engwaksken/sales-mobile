import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_brand.dart';
import '../widgets/common.dart';

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
  final otp = TextEditingController();
  bool resending = false;

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (otp.text.trim().length != 6) {
      showFlash(context, 'Enter the 6-digit verification code.', error: true);
      return;
    }

    final error = await context.read<AuthStore>().verifyRegistration(
          email: widget.email,
          otp: otp.text,
          rememberMe: widget.rememberMe,
        );

    if (!mounted) return;

    if (error != null) {
      showFlash(context, error, error: true);
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> resend() async {
    setState(() => resending = true);

    final error = await context.read<AuthStore>().resendRegistrationOtp(
          widget.email,
        );

    if (!mounted) return;
    setState(() => resending = false);

    showFlash(
      context,
      error ?? 'A new verification code has been sent.',
      error: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AuthBrand(size: 76),
            const SizedBox(height: 18),
            const Text(
              'Email Verification',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit OTP sent to\n${widget.email}',
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
                labelText: 'Verification code',
                counterText: '',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: auth.loading ? null : verify,
              icon: const Icon(Icons.verified),
              label: Text(auth.loading ? 'Verifying...' : 'Verify & Continue'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            TextButton(
              onPressed: resending ? null : resend,
              child: Text(
                resending ? 'Sending...' : 'Resend OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
