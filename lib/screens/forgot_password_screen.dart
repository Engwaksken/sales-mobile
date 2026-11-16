import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../core/branding.dart';
import '../widgets/auth_ui.dart';
import 'password_reset_otp_screen.dart';

/// Step 1 of 3 of password recovery: ask for the account email, then the
/// server emails a 6-digit code ([PasswordResetOtpScreen] is step 2 and
/// `ResetPasswordScreen` step 3).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();

  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (_busy) return;
    setState(() {
      _attempted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final error = await context.read<AuthStore>().requestPasswordReset(
          email.text,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      setState(() => _error = error);
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
    return AuthScaffold(
      step: 'Step 1 of 3',
      title: 'Reset your password',
      helper: 'Enter the email you use for ${context.brandName} and '
          "we'll send you a 6-digit code.",
      subtitle: 'Secure account recovery',
      showApiStatus: true,
      footer: AuthFooterLink(
        prompt: 'Remembered it?',
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
        Form(
          key: _formKey,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: AuthTextField(
              controller: email,
              label: 'Email address',
              hint: 'name@example.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              onSubmitted: (_) => submit(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Send reset code',
          busyLabel: 'Sending code...',
          busy: _busy,
          onPressed: submit,
        ),
      ],
    );
  }
}
