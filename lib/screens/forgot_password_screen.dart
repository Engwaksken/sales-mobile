import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/branding.dart';
import '../core/auth_store.dart';
import '../widgets/auth_brand.dart';
import '../widgets/api_status_banner.dart';
import '../widgets/common.dart';
import 'password_reset_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty) {
      showFlash(context, 'Enter your email address.', error: true);
      return;
    }

    final error = await context.read<AuthStore>().requestPasswordReset(
          email.text,
        );

    if (!mounted) return;

    if (error != null) {
      showFlash(context, error, error: true);
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordResetOtpScreen(
          email: email.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AuthBrand(size: 76),
            const SizedBox(height: 14),
            const ApiStatusBanner(),
            const SizedBox(height: 4),
            const Text(
              'Reset your password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your account email and ${context.brandName} will send a 6-digit verification code.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: auth.loading ? null : submit,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(
                auth.loading ? 'Sending code...' : 'Send verification code',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
