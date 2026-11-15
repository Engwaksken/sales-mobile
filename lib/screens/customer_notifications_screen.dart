import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  bool loading = true;
  List<dynamic> rows = [];

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  Future<void> load() async {
    final result = await customerApi.notifications();
    if (!mounted) return;

    setState(() {
      rows = result;
      loading = false;
    });
  }

  Future<void> openNotification(Map<String, dynamic> row) async {
    if (row['is_read'] != true) {
      await customerApi.readNotification(int.parse('${row['id']}'));
      row['is_read'] = true;
      if (mounted) setState(() {});
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${row['title'] ?? 'Notification'}'),
        content: Text('${row['message'] ?? ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> readAll() async {
    await customerApi.readAllNotifications();
    for (final raw in rows) {
      (raw as Map)['is_read'] = true;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: rows.any((e) => (e as Map)['is_read'] != true)
                ? readAll
                : null,
            child: const Text('Read all'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: rows.isEmpty
                    ? const [
                        SizedBox(height: 160),
                        Center(child: Text('No notifications yet.')),
                      ]
                    : rows.map((raw) {
                        final row =
                            Map<String, dynamic>.from(raw as Map);
                        final unread = row['is_read'] != true;

                        return Card(
                          elevation: 0,
                          color: unread
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .35)
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                unread
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none,
                              ),
                            ),
                            title: Text(
                              '${row['title'] ?? 'Notification'}',
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${row['message'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: unread
                                ? const Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: Colors.red,
                                  )
                                : null,
                            onTap: () => openNotification(row),
                          ),
                        );
                      }).toList(),
              ),
            ),
    );
  }
}
