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
  bool useBiometrics = true;
  bool _busy = false;
  bool _bioBusy = false;
  bool _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint prompt straight away, once per app launch.
    final auth = context.read<AuthStore>();
    if (auth.biometricEnabled && auth.biometricAvailable && !auth.biometricAutoPromptUsed) {
      auth.biometricAutoPromptUsed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) signInWithBiometrics();
      });
    }
  }

  Future<void> signInWithBiometrics() async {
    if (_busy || _bioBusy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _bioBusy = true;
      _error = null;
    });
    final error = await context.read<AuthStore>().signInWithBiometrics();
    // On success the app swaps this screen for the home screen.
    if (!mounted) return;
    setState(() {
      _bioBusy = false;
      _error = error;
    });
  }

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

    final auth = context.read<AuthStore>();
    // The app-wide messenger outlives this screen, so the note about
    // biometric sign-in still shows once the home screen replaces it.
    final messenger = ScaffoldMessenger.of(context);
    final result = await auth.login(
          email.text,
          password.text,
          rememberMe: rememberMe,
          enableBiometrics: _offerBiometrics(auth) && useBiometrics,
        );

    if (result.biometricNotice != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.biometricNotice!)));
    }

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

  /// Biometric sign-in can be turned on here when the phone supports it and
  /// it is not already on.
  bool _offerBiometrics(AuthStore auth) => auth.biometricAvailable && !auth.biometricEnabled;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final bioLabel = auth.biometricLabel;
    final showBioButton = auth.biometricEnabled && auth.biometricAvailable;

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
            if (_offerBiometrics(auth))
              AuthCheckbox(
                value: useBiometrics,
                label: 'Use $bioLabel next time',
                onChanged: (value) => setState(() => useBiometrics = value),
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
        if (showBioButton) ...[
          const SizedBox(height: 12),
          _BiometricButton(
            label: bioLabel,
            name: auth.biometricName,
            busy: _bioBusy,
            onPressed: _busy ? null : signInWithBiometrics,
          ),
        ],
      ],
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.label, required this.name, required this.busy, required this.onPressed});

  final String label;
  final String? name;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.authBrand;
    final who = (name ?? '').trim();
    final text = who.isEmpty ? 'Sign in with $label' : 'Sign in as ${who.split(' ').first} with $label';

    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: brand))
          : Icon(label == 'face' ? Icons.face_outlined : Icons.fingerprint, size: 24),
      label: Text(text, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        side: BorderSide(color: brand, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
