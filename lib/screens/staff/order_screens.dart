import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/staff_ui.dart';
import 'sales_screens.dart';

import '../../core/app_theme.dart';
/// Online orders with a stage filter.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final list = PagedListController();
  late String? status = widget.initialStatus;

  @override
  void initState() {
    super.initState();
    context.read<StaffLookups>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final stages = context.watch<StaffLookups>().orderStages;

    return PagedList(
      path: '/staff/orders',
      controller: list,
      query: {'status': status},
      searchHint: 'Order number, customer or phone',
      emptyText: 'No orders found.',
      emptyIcon: Icons.local_shipping_outlined,
      bottomPadding: 24,
      filters: [
        ChoiceFilter(
          id: 'status',
          label: 'Stage',
          options: [for (final s in stages) FilterOption(s.key, s.label)],
          searchable: false,
        ),
      ],
      filterValues: {'status': status},
      onFiltersChanged: (v) => setState(() => status = v['status'] as String?),
      quickFilters: const ['status'],
      itemBuilder: (context, row) => RecordCard(
        title: '${row['order_number'] ?? 'Order #${row['id']}'}',
        subtitle: [row['customer_name'], row['phone']].where((s) => s != null && '$s'.isNotEmpty).join(' | '),
        caption: '${formatDate(row['created_at'], withTime: true)} | ${titleCase('${row['payment_status'] ?? ''}')}',
        amount: money(row['total_amount']),
        status: '${row['status']}',
        statusLabel: '${row['status_label'] ?? ''}',
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: row['id'] as int)));
          list.reload();
        },
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic> order = {};
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/staff/orders/${widget.orderId}');
      if (!mounted) return;
      setState(() => order = Map<String, dynamic>.from((response.data as Map)['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeStage() async {
    final stages = context.read<StaffLookups>().orderStages;
    final note = TextEditingController();
    String selected = '${order['status']}';

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Move order to', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) => setSheet(() => selected = v ?? selected),
                  child: Column(
                    children: [
                      for (final s in stages)
                        RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, value: s.key, title: Text(s.label)),
                    ],
                  ),
                ),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(sheetContext, selected), child: const Text('Update stage')),
              ],
            ),
          ),
        ),
      ),
    );

    final noteText = note.text.trim();
    note.dispose();
    if (chosen == null || chosen == order['status'] || !mounted) return;

    final result = await runApi(
      context,
      (api) => api.patch('/staff/orders/${widget.orderId}/status', data: {'status': chosen, if (noteText.isNotEmpty) 'note': noteText}),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    final data = result.data as Map;
    showSuccess(context, '${data['message']}');
    setState(() => order = Map<String, dynamic>.from(data['data'] as Map));
  }

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List?) ?? const [];
    final logs = (order['logs'] as List?) ?? const [];
    final receipts = (order['receipts'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text('${order['order_number'] ?? 'Order'}')),
      bottomNavigationBar: loading || error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: saving ? null : changeStage,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('Change stage (${order['status_label'] ?? ''})'),
                ),
              ),
            ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Customer',
                trailing: StatusPill('${order['status']}', label: '${order['status_label']}'),
                children: [
                  InfoRow('Name', '${order['customer_name'] ?? ''}'),
                  InfoRow('Phone', order['phone']?.toString()),
                  InfoRow('Email', order['email']?.toString()),
                  InfoRow('Delivery to', order['delivery_location']?.toString()),
                  InfoRow('Zone', order['delivery_zone']?.toString()),
                  InfoRow('Address', order['address']?.toString()),
                  InfoRow('Branch', order['branch_name']?.toString()),
                  InfoRow('Placed', formatDate(order['created_at'], withTime: true)),
                  InfoRow('Notes', order['notes']?.toString()),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Items',
                children: [
                  for (final raw in items)
                    Builder(builder: (context) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${formatNumber(item['quantity'])} x ${money(item['price'])}'),
                        trailing: Text(money(item['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
                      );
                    }),
                  const Divider(),
                  InfoRow('Subtotal', money(order['subtotal'])),
                  if (toDouble(order['delivery_fee']) > 0) InfoRow('Delivery', money(order['delivery_fee'])),
                  if (toDouble(order['discount']) > 0) InfoRow('Discount', '- ${money(order['discount'])}'),
                  InfoRow('Total', money(order['total_amount']), bold: true),
                  InfoRow('Paid', money(order['amount_paid'])),
                  InfoRow('Balance', money(order['balance_amount'])),
                  InfoRow('Payment', '${titleCase('${order['payment_method'] ?? ''}')} | ${titleCase('${order['payment_status'] ?? ''}')}'),
                  if (order['sale_id'] != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.point_of_sale),
                        label: const Text('Open POS sale'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: order['sale_id'] as int))),
                      ),
                    ),
                ],
              ),
              if (receipts.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Payment receipts',
                  children: [
                    for (final raw in receipts)
                      Builder(builder: (context) {
                        final r = Map<String, dynamic>.from(raw as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.receipt_long),
                          title: Text('${r['receipt_number'] ?? 'Receipt'} | ${r['payment_method'] ?? ''}'),
                          subtitle: Text(formatDate(r['created_at'], withTime: true)),
                          trailing: Text(money(r['amount_paid']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        );
                      }),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                title: 'History',
                children: [
                  if (logs.isEmpty) Text('No history yet.', style: TextStyle(color: context.muted)),
                  for (final raw in logs)
                    Builder(builder: (context) {
                      final log = Map<String, dynamic>.from(raw as Map);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 9, color: context.faint)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${log['description'] ?? titleCase('${log['action']}')}'),
                                  Text(formatDate(log['created_at'], withTime: true), style: TextStyle(color: context.faint, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
