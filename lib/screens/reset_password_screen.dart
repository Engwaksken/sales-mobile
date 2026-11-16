import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_ui.dart';
import '../widgets/common.dart';

/// Step 3 of 3 of password recovery: choose the new password.
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
  final _formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    _confirmFocus.dispose();
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

    final error = await context.read<AuthStore>().resetPassword(
          email: widget.email,
          resetToken: widget.resetToken,
          password: password.text,
          passwordConfirmation: confirm.text,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    showFlash(context, 'Password changed. You can now sign in.');

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      step: 'Step 3 of 3',
      title: 'Set a new password',
      helper: 'Choose a strong password for ${widget.email}.',
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
        Form(
          key: _formKey,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: password,
                  label: 'New password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  nextFocus: _confirmFocus,
                  validator: AuthValidators.newPassword,
                ),
                PasswordStrengthMeter(controller: password),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: confirm,
                  focusNode: _confirmFocus,
                  label: 'Confirm new password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.confirmPassword(password),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Update password',
          busyLabel: 'Updating...',
          busy: _busy,
          onPressed: submit,
        ),
      ],
    );
  }
}
