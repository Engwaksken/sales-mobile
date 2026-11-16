import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/branding.dart';
import 'api_status_banner.dart';
import 'auth_brand.dart';

/// Shared building blocks for the sign-in, sign-up and account recovery
/// screens: a branded header, form fields, the primary button, inline
/// banners, the password strength meter and the one-time code field.
///
/// Every colour comes from the admin's theme colour ([BrandingStore.primary])
/// or the current [ColorScheme], so the screens follow the branding and work
/// in light and dark themes.

const double kAuthMaxWidth = 440;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + .05;
  final lb = b.computeLuminance() + .05;
  return math.max(la, lb) / math.min(la, lb);
}

/// Text/icon colour for content drawn on the brand colour.
Color onBrandColor(Color brand) {
  const dark = Color(0xFF0F172A);
  return _contrast(Colors.white, brand) >= _contrast(dark, brand)
      ? Colors.white
      : dark;
}

/// The brand colour, darkened or lightened until it is readable on [background]
/// (WCAG 4.5:1), for links, focus rings and labels on the form surface.
Color readableBrand(Color brand, Color background, {double minContrast = 4.5}) {
  final target =
      background.computeLuminance() > .4 ? Colors.black : Colors.white;
  var color = brand;
  for (var i = 0; i < 12 && _contrast(color, background) < minContrast; i++) {
    color = Color.lerp(color, target, .12)!;
  }
  return color;
}

extension AuthColors on BuildContext {
  Color get authBrand => watch<BrandingStore>().primary;

  /// Brand colour that stays readable on the form surface.
  Color get authAccent => readableBrand(
        authBrand,
        Theme.of(this).colorScheme.surfaceContainerLowest,
      );
}

/// Friendly, client-side checks that mirror the server's rules.
class AuthValidators {
  AuthValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(text)) {
      return 'Enter a valid email address, like name@example.com.';
    }
    return null;
  }

  static String? password(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? name(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter your full name.' : null;

  /// Matches the server: at least 8 characters, mixed case and a number.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Create a password.';
    final check = PasswordCheck(text);
    if (!check.longEnough) return 'Use at least 8 characters.';
    if (!check.mixedCase) return 'Include both upper and lowercase letters.';
    if (!check.hasNumber) return 'Include at least one number.';
    return null;
  }

  static FormFieldValidator<String> confirmPassword(
    TextEditingController original,
  ) {
    return (value) {
      if ((value ?? '').isEmpty) return 'Confirm your password.';
      if (value != original.text) return "The passwords don't match.";
      return null;
    };
  }

  static String? otp(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the 6-digit code.';
    if (text.length != 6) return 'The code has 6 digits.';
    return null;
  }
}

/// Page frame for every auth screen: a branded header (logo, system name,
/// one-line subtitle) over a clean form surface. Scrolls when the keyboard
/// opens, and centres the content at [kAuthMaxWidth] on tablets.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.helper,
    required this.children,
    this.subtitle = 'Sales, orders, stock and payments in one place',
    this.step,
    this.showApiStatus = false,
    this.footer,
  });

  /// Screen title, e.g. "Sign in to your account".
  final String title;

  /// One short line under the title.
  final String helper;

  /// One-line subtitle under the system name in the header.
  final String subtitle;

  /// Optional progress label, e.g. "Step 2 of 3".
  final String? step;

  /// Shows the server availability warning above the form.
  final bool showApiStatus;

  final List<Widget> children;

  /// Secondary action pinned under the form, e.g. "Create an account".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brand = context.authBrand;
    final onBrand = onBrandColor(brand);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onBrand == Colors.white
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _AuthHeader(subtitle: subtitle)),
            SliverToBoxAdapter(
              child: _Centered(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (step != null) ...[
                        Text(
                          step!.toUpperCase(),
                          style: text.labelMedium?.copyWith(
                            color: context.authAccent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: text.headlineSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        helper,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (showApiStatus) const ApiStatusBanner(),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _Centered(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomInset),
                    child: footer ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kAuthMaxWidth),
        child: child,
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final brand = context.authBrand;
    final onBrand = onBrandColor(brand);
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, Color.lerp(brand, Colors.black, .22)!],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(4, topInset + 4, 4, 28),
      child: _Centered(
        child: Column(
          children: [
            SizedBox(
              height: canPop ? 48 : 20,
              child: canPop
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(color: onBrand),
                    )
                  : null,
            ),
            const AuthBrand(size: 64),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    context.brandName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(
                      color: onBrand,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: onBrand.withValues(alpha: .86),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Material 3 text field with the auth styling: label, prefix icon, rounded
/// outline, brand-coloured focus and an optional show/hide password toggle.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.focusNode,
    this.nextFocus,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.isPassword = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.style,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final FocusNode? focusNode;

  /// Field that "Next" on the keyboard moves to.
  final FocusNode? nextFocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool isPassword;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.authAccent;
    final radius = BorderRadius.circular(12);

    Color stateColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.error)) return scheme.error;
      if (states.contains(WidgetState.focused)) return accent;
      return scheme.onSurfaceVariant;
    }

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.isPassword
          ? TextInputType.visiblePassword
          : widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.isPassword && _obscure,
      enableSuggestions: !widget.isPassword,
      autocorrect: false,
      textAlign: widget.textAlign,
      style: (widget.style ?? Theme.of(context).textTheme.bodyLarge)
          ?.copyWith(color: scheme.onSurface),
      cursorColor: accent,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onEditingComplete: widget.nextFocus == null
          ? null
          : () => widget.nextFocus!.requestFocus(),
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorMaxLines: 3,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: stateColor(states),
            fontWeight: FontWeight.w600,
          ),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
        ),
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        prefixIconColor: WidgetStateColor.resolveWith(stateColor),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
        suffixIconColor: scheme.onSurfaceVariant,
        border: outline(scheme.outline.withValues(alpha: .7)),
        enabledBorder: outline(scheme.outline.withValues(alpha: .7)),
        focusedBorder: outline(accent, 2),
        errorBorder: outline(scheme.error),
        focusedErrorBorder: outline(scheme.error, 2),
      ),
    );
  }
}

/// Six-digit one-time code entry: numeric keyboard, SMS/email code autofill,
/// and [onCompleted] fires as soon as the sixth digit is entered.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final VoidCallback? onCompleted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: controller,
      label: 'Verification code',
      hint: '6-digit code',
      icon: Icons.pin_outlined,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
      validator: AuthValidators.otp,
      onChanged: (value) {
        if (value.length == 6) onCompleted?.call();
      },
      onSubmitted: (_) => onCompleted?.call(),
    );
  }
}

/// Full-width, 52px primary action. While [busy] it shows a spinner and
/// ignores taps so a request cannot be sent twice.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final String? busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.authBrand;
    final onBrand = onBrandColor(brand);

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: onBrand,
        disabledBackgroundColor: brand.withValues(alpha: .7),
        disabledForegroundColor: onBrand,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: onBrand,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    busyLabel ?? label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Brand-coloured text link with a 48px tap target.
class AuthLinkButton extends StatelessWidget {
  const AuthLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.authAccent,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// "Prompt? Action" line at the bottom of the screen.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        AuthLinkButton(label: action, onPressed: onPressed),
      ],
    );
  }
}

/// Checkbox with its label, tappable as a whole (at least 48px tall).
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.authAccent;

    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: accent,
                checkColor: onBrandColor(accent),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline message box for server errors (from `messageFromError`) and
/// confirmations such as "We sent a new code".
class AuthBanner extends StatelessWidget {
  const AuthBanner.error(this.message, {super.key, this.onDismiss})
      : success = false;

  const AuthBanner.success(this.message, {super.key, this.onDismiss})
      : success = true;

  final String message;
  final bool success;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color background;
    final Color foreground;
    if (success) {
      background = dark ? const Color(0xFF0B3B2E) : const Color(0xFFECFDF5);
      foreground = dark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46);
    } else {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: success ? 'Notice' : 'Error',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.fromLTRB(14, 12, onDismiss == null ? 14 : 0, 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: foreground.withValues(alpha: .22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (onDismiss != null)
              Transform.translate(
                offset: const Offset(0, -12),
                child: IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 18, color: foreground),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a password meets, against the server's rules (8+ characters,
/// upper and lowercase letters and a number).
class PasswordCheck {
  PasswordCheck(String value)
      : longEnough = value.length >= 8,
        mixedCase = value.contains(RegExp('[a-z]')) &&
            value.contains(RegExp('[A-Z]')),
        hasNumber = value.contains(RegExp(r'\d')),
        extra = value.length >= 12 || value.contains(RegExp(r'[^A-Za-z0-9]')),
        isEmpty = value.isEmpty;

  final bool longEnough;
  final bool mixedCase;
  final bool hasNumber;
  final bool extra;
  final bool isEmpty;

  bool get meetsRules => longEnough && mixedCase && hasNumber;

  /// 0 to 4.
  int get score {
    if (isEmpty) return 0;
    final met = [longEnough, mixedCase, hasNumber].where((ok) => ok).length;
    return math.max(1, meetsRules && extra ? 4 : met);
  }

  String get label => const ['', 'Weak', 'Fair', 'Good', 'Strong'][score];
}

/// Strength bar plus the rule checklist, updating as the user types.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.controller});

  final TextEditingController controller;

  static const _levelColors = [
    Color(0xFFDC2626),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF16A34A),
    Color(0xFF15803D),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final okColor = dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final check = PasswordCheck(value.text);
        final level = _levelColors[check.score];

        Widget rule(bool ok, String text) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: ok ? okColor : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: ok ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var i = 1; i <= 4; i++) ...[
                            if (i > 1) const SizedBox(width: 4),
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: i <= check.score
                                      ? level
                                      : scheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!check.isEmpty) ...[
                    const SizedBox(width: 10),
                    Text(
                      check.label,
                      semanticsLabel: 'Password strength: ${check.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: dark ? Color.lerp(level, Colors.white, .3) : level,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              rule(check.longEnough, 'At least 8 characters'),
              rule(check.mixedCase, 'Upper and lowercase letters'),
              rule(check.hasNumber, 'At least one number'),
            ],
          ),
        );
      },
    );
  }
}

/// "Didn't get a code? Resend code" with a sending state and a 30 second
/// cooldown after each successful resend.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.cooldown = const Duration(seconds: 30),
  });

  /// Sends a new code; returns an error message, or null on success.
  final Future<String?> Function() onResend;
  final Duration cooldown;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  bool _sending = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final error = await widget.onResend();
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) return;

    setState(() => _secondsLeft = widget.cooldown.inSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiting = _secondsLeft > 0;
    final label = _sending
        ? 'Sending...'
        : waiting
            ? 'Resend in ${_secondsLeft}s'
            : 'Resend code';

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Didn't get a code?",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        AuthLinkButton(
          label: label,
          onPressed: _sending || waiting ? null : _resend,
        ),
      ],
    );
  }
}
