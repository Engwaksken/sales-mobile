/// Reads the role and permissions the server returns in the user payload
/// (`/login`, `/register/verify-otp` and `/me`).
class UserAccess {
  const UserAccess(this.user);

  final Map<String, dynamic>? user;

  String get role => (user?['role']?.toString() ?? 'customer').toLowerCase();

  bool get isCustomer => role == 'customer';

  bool get isAdmin => role == 'admin';

  String get name => user?['name']?.toString() ?? 'User';

  String get email => user?['email']?.toString() ?? '';

  String get roleLabel {
    final words = role.replaceAll('_', ' ').split(' ');
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  List<String> get permissions {
    final raw = user?['permissions'];
    if (raw is List) return raw.map((p) => p.toString()).toList();
    return const [];
  }

  /// Admins (or a `*` grant) can do everything; others need the exact key.
  bool can(String permission) {
    if (isAdmin) return true;
    final granted = permissions;
    return granted.contains('*') || granted.contains(permission);
  }
}
