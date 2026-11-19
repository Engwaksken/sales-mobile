import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

enum BiometricOutcome { success, cancelled, lockedOut, unavailable, failed }

/// Thin wrapper over the phone's fingerprint / face check, so screens and
/// tests never talk to the platform plugin directly.
class BiometricAuth {
  BiometricAuth([LocalAuthentication? plugin]) : _plugin = plugin ?? LocalAuthentication();

  final LocalAuthentication _plugin;

  /// True when the phone has biometric hardware and at least one fingerprint
  /// or face enrolled. Any plugin error counts as "not available".
  Future<bool> isAvailable() async {
    try {
      if (!await _plugin.isDeviceSupported()) return false;
      return (await _plugin.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// "face" when face is the only enrolled method, otherwise "fingerprint",
  /// which is what almost every Android phone uses.
  Future<String> label() async {
    try {
      final types = await _plugin.getAvailableBiometrics();
      final faceOnly = types.contains(BiometricType.face) && !types.contains(BiometricType.fingerprint);
      return faceOnly ? 'face' : 'fingerprint';
    } catch (_) {
      return 'fingerprint';
    }
  }

  Future<BiometricOutcome> authenticate(String reason) async {
    try {
      final ok = await _plugin.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: const [
          AndroidAuthMessages(signInTitle: 'Confirm it is you', cancelButton: 'Cancel'),
        ],
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          BiometricOutcome.cancelled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          BiometricOutcome.lockedOut,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricOutcome.unavailable,
        _ => BiometricOutcome.failed,
      };
    } on PlatformException {
      return BiometricOutcome.failed;
    } on MissingPluginException {
      return BiometricOutcome.unavailable;
    }
  }

  /// A short message for anything other than success, or null to say nothing
  /// (the person cancelled on purpose).
  static String? messageFor(BiometricOutcome outcome, String label) => switch (outcome) {
        BiometricOutcome.success || BiometricOutcome.cancelled => null,
        BiometricOutcome.lockedOut =>
          'Too many tries. Unlock your phone with its PIN or pattern first, or sign in with your password.',
        BiometricOutcome.unavailable =>
          'No $label is set up on this phone. Add one in your phone settings, or sign in with your password.',
        BiometricOutcome.failed => "We couldn't check your $label. Sign in with your password instead.",
      };
}
