import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../widgets/staff_ui.dart';

import '../core/app_theme.dart';
/// Lets the signed-in user choose which notifications they get. The server
/// decides which options apply to their role; changes save straight away.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  List<Map<String, dynamic>> options = [];
  int? threshold;
  bool loading = true;
  bool saving = false;
  String? error;
  Timer? thresholdDebounce;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    thresholdDebounce?.cancel();
    super.dispose();
  }

  void apply(Map data) {
    options = ((data['options'] as List?) ?? const []).map((o) => Map<String, dynamic>.from(o as Map)).toList();
    threshold = int.tryParse('${data['low_stock_threshold']}');
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/notification-preferences');
      if (mounted) setState(() => apply((response.data as Map)['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final result = await runApi(
      context,
      (api) => api.put('/notification-preferences', data: {
        'preferences': {for (final o in options) '${o['key']}': o['enabled'] == true},
        if (threshold != null) 'low_stock_threshold': threshold,
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null) {
      // Show the saved state again if the change did not go through.
      if (mounted) load();
      return;
    }
    if (mounted) setState(() => apply((result.data as Map)['data'] as Map));
  }

  void toggle(Map<String, dynamic> option, bool value) {
    setState(() => option['enabled'] = value);
    save();
  }

  void changeThreshold(int value) {
    setState(() => threshold = value.clamp(0, 100000));
    thresholdDebounce?.cancel();
    thresholdDebounce = Timer(const Duration(milliseconds: 700), save);
  }

  static IconData iconFor(String key) => switch (key) {
        'announcements' => Icons.campaign_outlined,
        'order_updates' || 'new_orders' => Icons.local_shipping_outlined,
        'chat_replies' || 'customer_chats' => Icons.forum_outlined,
        'email_receipts' => Icons.mark_email_read_outlined,
        'low_stock' => Icons.inventory_2_outlined,
        'flagged_activity' => Icons.flag_outlined,
        _ => Icons.notifications_outlined,
      };

  Widget section(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: context.muted)),
        ),
        Card(
          child: Column(
            children: [
              for (final o in items) ...[
                SwitchListTile(
                  secondary: Icon(iconFor('${o['key']}')),
                  title: Text('${o['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${o['description']}'),
                  value: o['enabled'] == true,
                  onChanged: (v) => toggle(o, v),
                ),
                if (o['key'] == 'low_stock' && o['enabled'] == true && threshold != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(child: Text('Alert me at', style: TextStyle(color: context.muted))),
                        IconButton.outlined(
                          visualDensity: VisualDensity.compact,
                          onPressed: threshold! > 0 ? () => changeThreshold(threshold! - 1) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text('$threshold', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                        IconButton.outlined(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => changeThreshold(threshold! + 1),
                          icon: const Icon(Icons.add),
                        ),
                        const SizedBox(width: 6),
                        Text('or fewer', style: TextStyle(color: context.muted)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inApp = options.where((o) => o['channel'] != 'email').toList();
    final email = options.where((o) => o['channel'] == 'email').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification settings'),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                'Choose what you want to be told about. Changes save straight away and also apply on the website.',
                style: TextStyle(color: context.muted),
              ),
            ),
            if (inApp.isNotEmpty) section('In the app', inApp),
            if (email.isNotEmpty) section('By email', email),
          ],
        ),
      ),
    );
  }
}
