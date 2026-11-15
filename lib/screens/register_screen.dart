import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_brand.dart';
import '../widgets/api_status_banner.dart';
import '../widgets/common.dart';
import 'verify_registration_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool obscure = true;
  bool obscureConfirm = true;
  bool rememberMe = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty ||
        confirm.text.isEmpty) {
      showFlash(context, 'Complete all required fields.', error: true);
      return;
    }

    if (password.text != confirm.text) {
      showFlash(context, 'The passwords do not match.', error: true);
      return;
    }

    final error = await context.read<AuthStore>().register(
          name: name.text,
          email: email.text,
          password: password.text,
          passwordConfirmation: confirm.text,
        );

    if (!mounted) return;

    if (error != null) {
      showFlash(context, error, error: true);
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyRegistrationScreen(
          email: email.text.trim(),
          rememberMe: rememberMe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AuthBrand(size: 76),
            const SizedBox(height: 14),
            const ApiStatusBanner(),
            const SizedBox(height: 4),
            const Text(
              'Create your NSales account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'We will verify your email using a 6-digit OTP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters with upper/lowercase and a number.',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => obscureConfirm = !obscureConfirm);
                  },
                  icon: Icon(
                    obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: rememberMe,
              title: const Text('Remember me after verification'),
              onChanged: (value) {
                setState(() => rememberMe = value ?? false);
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: auth.loading ? null : submit,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(
                auth.loading ? 'Creating account...' : 'Create account',
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
