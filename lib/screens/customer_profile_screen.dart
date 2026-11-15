import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_store.dart';
import '../core/config.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final rawPhoto = user?['photo_url']?.toString() ?? '';
    final parsedPhoto = Uri.tryParse(rawPhoto);
    final photoUrl = rawPhoto.isEmpty
        ? null
        : (parsedPhoto?.hasScheme == true
              ? rawPhoto
              : Uri.parse(AppConfig.apiOrigin)
                    .resolve(rawPhoto.startsWith('/') ? rawPhoto : '/$rawPhoto')
                    .toString());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'My Profile',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Center(
          child: CircleAvatar(
            radius: 48,
            foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            onForegroundImageError: photoUrl == null ? null : (_, _) {},
            child: Text(
              '${user?['name'] ?? 'C'}'.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                subtitle: Text('${user?['name'] ?? 'Customer'}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text('${user?['email'] ?? ''}'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Account type'),
                subtitle: Text('Customer'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.read<AuthStore>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
