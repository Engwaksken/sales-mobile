import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';

class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({
    super.key,
    required this.resource,
    required this.title,
    required this.icon,
    this.showHeader = true,
  });

  final String resource;
  final String title;
  final IconData icon;

  /// False when the screen sits under an AppBar that already shows the title.
  final bool showHeader;

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  final search = TextEditingController();
  bool loading = true;
  String? error;
  List<dynamic> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await context.read<ApiClient>().get(
        '/resources/${widget.resource}',
        query: {'q': search.text.trim()},
      );

      if (!mounted) return;
      setState(() => rows = List<dynamic>.from(response.data['data'] ?? []));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = context.read<ApiClient>().messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String first(Map<String, dynamic> row, List<String> keys, [String fallback = 'Record']) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Icon(widget.icon, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: search,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              hintText: 'Search ${widget.title.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.arrow_forward)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No records found.', style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            ...rows.map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final isSale = widget.resource == 'sales';
              final title = isSale
                  ? first(row, ['product_names', 'invoice_no'], 'Sale')
                  : first(row, ['name', 'title', 'invoice_no', 'order_number', 'receipt_number', 'receipt_no', 'customer_name', 'sku']);
              final subtitle = isSale
                  ? [
                      if (row['invoice_no'] != null) 'Invoice: ${row['invoice_no']}',
                      if (row['customer_name'] != null) '${row['customer_name']}',
                      if (row['payment_status'] != null) '${row['payment_status']}',
                    ].join(', ')
                  : first(row, ['description', 'status', 'payment_status', 'email', 'phone', 'created_at'], '');

              return Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(child: Icon(widget.icon, size: 18)),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: (row['amount'] ?? row['total_amount']) != null
                      ? Text('${row['amount'] ?? row['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w800))
                      : null,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: row.entries.map((entry) {
                            if (entry.value == null || entry.value is Map || entry.value is List) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 125,
                                    child: Text(
                                      entry.key.replaceAll('_', ' '),
                                      style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(child: Text('${entry.value}')),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
