import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';

class CustomerProfileEditScreen extends StatefulWidget {
  const CustomerProfileEditScreen({super.key});

  @override
  State<CustomerProfileEditScreen> createState() =>
      _CustomerProfileEditScreenState();
}

class _CustomerProfileEditScreenState
    extends State<CustomerProfileEditScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  bool loading = true;
  bool saving = false;

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final profile = await customerApi.profile();
    if (!mounted) return;

    name.text = '${profile['name'] ?? ''}';
    phone.text = '${profile['phone'] ?? ''}';
    address.text = '${profile['address'] ?? ''}';

    setState(() => loading = false);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      await customerApi.updateProfile(
        name: name.text.trim(),
        phone: phone.text.trim(),
        address: address.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: name,
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: address,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
