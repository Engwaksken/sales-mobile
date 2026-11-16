import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../widgets/auth_ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool rememberMe = true;
  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    _passwordFocus.dispose();
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

    final result = await context.read<AuthStore>().login(
          email.text,
          password.text,
          rememberMe: rememberMe,
        );

    // On success the app swaps this screen for the home screen.
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.requiresVerification) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyRegistrationScreen(
            email: result.email ?? email.text.trim(),
            rememberMe: rememberMe,
          ),
        ),
      );
      return;
    }

    if (result.error != null) {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in to your account',
      helper: 'Welcome back. Enter your details to continue.',
      showApiStatus: true,
      footer: AuthFooterLink(
        prompt: "Don't have an account?",
        action: 'Create an account',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        ),
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
                  controller: email,
                  label: 'Email address',
                  hint: 'name@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: AuthValidators.password,
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Wraps onto two lines with very large text instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AuthCheckbox(
              value: rememberMe,
              label: 'Remember me',
              onChanged: (value) => setState(() => rememberMe = value),
            ),
            AuthLinkButton(
              label: 'Forgot password?',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: 'Sign in',
          busyLabel: 'Signing in...',
          busy: _busy,
          onPressed: submit,
        ),
      ],
    );
  }
}
