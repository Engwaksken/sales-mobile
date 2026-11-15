import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/common.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  final String email;
  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool obscure = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (password.text.isEmpty || confirm.text.isEmpty) {
      showFlash(context, 'Enter and confirm your new password.', error: true);
      return;
    }

    if (password.text != confirm.text) {
      showFlash(context, 'The passwords do not match.', error: true);
      return;
    }

    final error = await context.read<AuthStore>().resetPassword(
          email: widget.email,
          resetToken: widget.resetToken,
          password: password.text,
          passwordConfirmation: confirm.text,
        );

    if (!mounted) return;

    if (error != null) {
      showFlash(context, error, error: true);
      return;
    }

    showFlash(context, 'Password changed. You can now sign in.');

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('New Password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.lock_reset,
            size: 64,
            color: Color(0xFF0F766E),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create a new password',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: password,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'New password',
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
              labelText: 'Confirm new password',
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
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: auth.loading ? null : submit,
            icon: const Icon(Icons.save),
            label: Text(
              auth.loading ? 'Updating...' : 'Change password',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
