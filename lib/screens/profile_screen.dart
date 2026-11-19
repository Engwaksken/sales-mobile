import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/auth_store.dart';
import '../core/format.dart';
import '../widgets/signature_pad.dart';
import '../widgets/staff_ui.dart';

import '../core/app_theme.dart';
/// The signed-in user's own profile: photo, name, password, and for customers
/// their phone and delivery address.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  Map<String, dynamic> profile = {};
  XFile? photo;
  bool removePhoto = false;
  bool loading = true;
  bool saving = false;
  String? error;

  bool get isCustomer => profile['is_customer'] == true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [name, phone, address]) {
      c.dispose();
    }
    super.dispose();
  }

  void apply(Map data) {
    profile = Map<String, dynamic>.from(data);
    name.text = '${profile['name'] ?? ''}';
    phone.text = '${profile['phone'] ?? ''}';
    address.text = '${profile['address'] ?? ''}';
    photo = null;
    removePhoto = false;
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/profile');
      if (mounted) setState(() => apply((response.data as Map)['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choosePhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (profile['photo_url'] != null || photo != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: context.danger,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: context.danger),
                ),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (source == 'remove') {
      setState(() {
        photo = null;
        removePhoto = true;
      });
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        photo = picked;
        removePhoto = false;
      });
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final fields = <String, dynamic>{
      'name': name.text.trim(),
      if (removePhoto) 'remove_photo': '1',
      if (isCustomer) 'phone': phone.text.trim(),
      if (isCustomer) 'address': address.text.trim(),
    };
    if (photo != null) {
      fields['photo'] = await MultipartFile.fromFile(
        photo!.path,
        filename: photo!.path.split(Platform.pathSeparator).last,
      );
    }
    if (!mounted) return;
    final auth = context.read<AuthStore>();

    final result = await runApi(
      context,
      (api) => api.post('/profile', data: FormData.fromMap(fields)),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    final data = Map<String, dynamic>.from((result.data as Map)['data'] as Map);
    setState(() => apply(data));
    auth.updateUser({
      'name': data['name'],
      'photo_url': data['photo_url'],
      if (isCustomer) 'phone': data['phone'],
    });
    showSuccess(context, 'Profile saved.');
  }

  bool signatureBusy = false;

  Future<void> saveSignature(Object body) async {
    final result = await runApi(
      context,
      (api) => api.post('/profile/signature', data: body),
      busy: (b) => setState(() => signatureBusy = b),
    );
    if (result == null || !mounted) return;
    setState(() => profile['signature'] = ((result.data as Map)['data'] as Map)['signature']);
    showSuccess(context, 'Signature saved. It will appear on your invoices and receipts.');
  }

  Future<void> drawSignature() async {
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SignaturePadScreen()),
    );
    if (bytes != null) await saveSignature({'signature_data': pngDataUri(bytes)});
  }

  Future<void> uploadSignature() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 90);
    if (picked == null) return;
    await saveSignature(FormData.fromMap({
      'signature': await MultipartFile.fromFile(picked.path, filename: picked.path.split(Platform.pathSeparator).last),
    }));
  }

  Future<void> removeSignature() async {
    final result = await runApi(
      context,
      (api) => api.delete('/profile/signature'),
      busy: (b) => setState(() => signatureBusy = b),
    );
    if (result == null || !mounted) return;
    setState(() => profile['signature'] = null);
    showSuccess(context, 'Signature removed.');
  }

  Widget signatureCard() {
    final bytes = bytesFromDataUri(profile['signature']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.draw_outlined),
                const SizedBox(width: 12),
                const Expanded(child: Text('My signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                if (signatureBusy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Added automatically to invoices and receipts of the sales you make.',
              style: TextStyle(color: context.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.hairline),
              ),
              child: bytes == null
                  ? Text('No signature yet', style: TextStyle(color: context.faint))
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.memory(bytes, fit: BoxFit.contain, semanticLabel: 'Your signature'),
                    ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (bytes != null)
                  TextButton.icon(
                    onPressed: signatureBusy ? null : removeSignature,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  ),
                TextButton.icon(
                  onPressed: signatureBusy ? null : uploadSignature,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload'),
                ),
                TextButton.icon(
                  onPressed: signatureBusy ? null : drawSignature,
                  icon: const Icon(Icons.gesture),
                  label: Text(bytes == null ? 'Draw' : 'Redraw'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> changePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (changed == true && mounted)
      showSuccess(
        context,
        'Password changed. Other devices have been signed out.',
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photoUrl = removePhoto ? null : profile['photo_url']?.toString();
    final initial = name.text.trim().isEmpty
        ? '?'
        : name.text.trim()[0].toUpperCase();

    ImageProvider? image;
    if (photo != null) {
      image = FileImage(File(photo!.path));
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      final parsed = Uri.tryParse(photoUrl);
      image = NetworkImage(
        parsed?.hasScheme == true
            ? photoUrl
            : Uri.parse(AppConfig.apiOrigin)
                  .resolve(photoUrl.startsWith('/') ? photoUrl : '/$photoUrl')
                  .toString(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: scheme.primaryContainer,
                      foregroundImage: image,
                      onForegroundImageError: image == null ? null : (_, _) {},
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Change photo',
                        onPressed: choosePhoto,
                        icon: const Icon(Icons.photo_camera, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    StatusPill(
                      'active',
                      label:
                          '${profile['role_label'] ?? titleCase('${profile['role']}')}',
                    ),
                    if (profile['branch_name'] != null)
                      StatusPill(null, label: '${profile['branch_name']}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: '${profile['email'] ?? ''}',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                  helperText: 'Ask an admin to change your email.',
                ),
              ),
              if (isCustomer) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save profile'),
              ),
              if (!isCustomer) ...[
                const SizedBox(height: 18),
                signatureCard(),
              ],
              const SizedBox(height: 18),
              const _AppearanceCard(),
              const _BiometricCard(),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: changePassword,
                    ),
                    if (profile['member_since'] != null)
                      ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('Member since'),
                        trailing: Text(
                          formatDate(profile['member_since']),
                          style: TextStyle(color: context.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;
  bool show = false;

  @override
  void dispose() {
    for (final c in [current, next, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final result = await runApi(
      context,
      (api) => api.put(
        '/profile/password',
        data: {
          'current_password': current.text,
          'password': next.text,
          'password_confirmation': confirm.text,
        },
      ),
      busy: (b) => setState(() => saving = b),
    );
    if (result != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: Icon(
        show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: () => setState(() => show = !show),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Change password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: current,
                obscureText: !show,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: toggle,
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: !show,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters',
                ),
                validator: (v) => v == null || v.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirm,
                obscureText: !show,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) =>
                    v != next.text ? 'The passwords do not match' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : 'Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// System / Light / Dark, remembered on this phone.
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ThemeModeStore>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.dark_mode_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {store.mode},
              onSelectionChanged: (value) => store.set(value.first),
            ),
            const SizedBox(height: 8),
            Text(
              store.mode == ThemeMode.system ? "Follows your phone's light or dark setting." : 'Applies on this phone only.',
              style: TextStyle(color: context.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns biometric sign-in on or off for this phone. Hidden on phones with no
/// fingerprint or face enrolled.
class _BiometricCard extends StatefulWidget {
  const _BiometricCard();

  @override
  State<_BiometricCard> createState() => _BiometricCardState();
}

class _BiometricCardState extends State<_BiometricCard> {
  bool busy = false;

  String? get _email => context.read<AuthStore>().user?['email']?.toString();

  Future<void> toggle(bool on) async {
    final auth = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);
    final label = auth.biometricLabel;

    if (!on) {
      setState(() => busy = true);
      await auth.disableBiometrics();
      if (!mounted) return;
      setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('${_cap(label)} sign-in is off on this phone.')));
      return;
    }

    final email = _email;
    if (email == null || email.isEmpty) return;
    final password = await showDialog<String>(context: context, builder: (_) => _ConfirmPasswordDialog(label: label));
    if (password == null || !mounted) return;

    setState(() => busy = true);
    final error = await auth.enableBiometrics(email: email, password: password);
    if (!mounted) return;
    setState(() => busy = false);
    if (error == null) {
      messenger.showSnackBar(SnackBar(content: Text('${_cap(label)} sign-in is on. Use it next time you sign in.')));
    } else if (error.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.biometricAvailable) return const SizedBox.shrink();
    final label = auth.biometricLabel;
    final email = auth.user?['email']?.toString();
    final onForMe = auth.biometricEnabled && auth.biometricEmail == email;
    final onForOther = auth.biometricEnabled && !onForMe;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Card(
        child: SwitchListTile(
          secondary: Icon(label == 'face' ? Icons.face_outlined : Icons.fingerprint),
          title: Text('Sign in with $label'),
          subtitle: Text(
            onForOther
                ? 'On for ${auth.biometricEmail}. Turning it on here switches it to your account.'
                : onForMe
                    ? 'On for this phone. Signing out keeps it ready for next time.'
                    : 'Skip typing your password on this phone.',
            style: TextStyle(color: context.muted, fontSize: 12.5),
          ),
          value: onForMe,
          onChanged: busy ? null : toggle,
        ),
      ),
    );
  }
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({required this.label});

  final String label;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final password = TextEditingController();
  bool show = false;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (password.text.isEmpty) return;
    Navigator.pop(context, password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Turn on ${widget.label} sign-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter your password to confirm it is you.'),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            autofocus: true,
            obscureText: !show,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => show = !show),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: submit, child: const Text('Continue')),
      ],
    );
  }
}
