import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_ui.dart';
import 'verify_registration_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool rememberMe = true;
  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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

    final error = await context.read<AuthStore>().register(
          name: name.text,
          email: email.text,
          password: password.text,
          passwordConfirmation: confirm.text,
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
        builder: (_) => VerifyRegistrationScreen(
          email: email.text.trim(),
          rememberMe: rememberMe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      helper: "We'll email you a 6-digit code to verify your address.",
      showApiStatus: true,
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Sign in',
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
                  controller: name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  nextFocus: _emailFocus,
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: email,
                  focusNode: _emailFocus,
                  label: 'Email address',
                  hint: 'name@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  nextFocus: _passwordFocus,
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: password,
                  focusNode: _passwordFocus,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
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
                  label: 'Confirm password',
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
        const SizedBox(height: 4),
        AuthCheckbox(
          value: rememberMe,
          label: 'Keep me signed in after verification',
          onChanged: (value) => setState(() => rememberMe = value),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: 'Create account',
          busyLabel: 'Creating account...',
          busy: _busy,
          onPressed: submit,
        ),
      ],
    );
  }
}
