import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/document_sharing.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/staff_ui.dart';
import 'pos_screen.dart';
import 'tender_editor.dart';

const saleStatuses = {
  'paid': 'Paid',
  'partial': 'Part paid',
  'pending': 'Credit',
  'outstanding': 'Owing',
};

/// Sales list with status filter and a "New sale" button that opens the POS.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.initialStatus, this.from, this.to});

  /// Starting filters, e.g. from a dashboard card.
  final String? initialStatus;
  final String? from;
  final String? to;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final list = PagedListController();
  late String? status = widget.initialStatus;
  late String? from = widget.from;
  late String? to = widget.to;

  Future<void> newSale() async {
    final saleId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    );
    if (saleId == null || !mounted) return;
    list.reload();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: saleId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-sale',
        onPressed: newSale,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New sale'),
      ),
      body: PagedList(
        path: '/staff/sales',
        controller: list,
        query: {'status': status, 'from': from, 'to': to},
        searchHint: 'Invoice, customer or product',
        emptyText: 'No sales found.',
        emptyIcon: Icons.point_of_sale,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterChips(
              options: saleStatuses,
              selected: status,
              onSelected: (v) => setState(() => status = v),
            ),
            if (from != null || to != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InputChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    from == to
                        ? formatDate(from)
                        : '${formatDate(from)} – ${formatDate(to)}',
                  ),
                  onDeleted: () => setState(() {
                    from = null;
                    to = null;
                  }),
                ),
              ),
          ],
        ),
        itemBuilder: (context, row) => RecordCard(
          title: '${row['invoice_no'] ?? 'Sale #${row['id']}'}',
          subtitle: '${row['product_names'] ?? ''}',
          caption: [
            row['customer_name'],
            formatDate(row['sale_date']),
          ].where((s) => s != null && '$s'.isNotEmpty).join(' · '),
          amount: money(row['total_amount']),
          status: '${row['payment_status']}',
          statusLabel: saleStatuses[row['payment_status']],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SaleDetailScreen(saleId: row['id'] as int),
              ),
            );
            list.reload();
          },
        ),
      ),
    );
  }
}

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Map<String, dynamic> sale = {};
  bool loading = true;
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
      final response = await api.get('/staff/sales/${widget.saleId}');
      if (!mounted) return;
      setState(
        () => sale = Map<String, dynamic>.from(
          (response.data as Map)['data'] as Map,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recordPayment() async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecordPaymentSheet(sale: sale),
    );
    if (updated != null && mounted) setState(() => sale = updated);
  }

  @override
  Widget build(BuildContext context) {
    final balance = toDouble(sale['balance_amount']);
    final items = (sale['items'] as List?) ?? const [];
    final payments = (sale['payments'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${sale['invoice_no'] ?? 'Sale'}'),
        actions: [
          if (!loading && error == null)
            IconButton(
              tooltip: 'Share invoice',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareDocument(
                'Invoice ${sale['invoice_no'] ?? ''}',
                [
                  'INVOICE ${sale['invoice_no'] ?? ''}',
                  'Customer: ${sale['customer_name'] ?? 'Walk-in'}',
                  'Date: ${formatDate(sale['sale_date'])}',
                  '',
                  for (final raw in items)
                    () {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return '${item['name']} — ${formatNumber(item['quantity'])} × ${money(item['price'])} = ${money(item['total'])}';
                    }(),
                  '',
                  if (toDouble(sale['discount']) > 0)
                    'Discount: -${money(sale['discount'])}',
                  if (toDouble(sale['vat']) > 0) 'VAT: ${money(sale['vat'])}',
                  'Total: ${money(sale['total_amount'])}',
                  'Paid: ${money(sale['paid_amount'])}',
                  'Balance: ${money(sale['balance_amount'])}',
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: !loading && error == null && balance > 0.005
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: recordPayment,
                  icon: const Icon(Icons.payments),
                  label: Text('Record payment · ${money(balance)} due'),
                ),
              ),
            )
          : null,
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
                title: 'Summary',
                trailing: StatusPill(
                  '${sale['payment_status']}',
                  label: saleStatuses[sale['payment_status']],
                ),
                children: [
                  InfoRow('Customer', '${sale['customer_name'] ?? ''}'),
                  InfoRow('Phone', sale['customer_phone']?.toString()),
                  InfoRow('Date', formatDate(sale['sale_date'])),
                  InfoRow('Branch', sale['branch_name']?.toString()),
                  InfoRow('Sold by', sale['sold_by']?.toString()),
                  InfoRow('Method', sale['payment_method']?.toString()),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Items',
                children: [
                  for (final raw in items)
                    Builder(
                      builder: (context) {
                        final item = Map<String, dynamic>.from(raw as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${item['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${formatNumber(item['quantity'])} × ${money(item['price'])}',
                          ),
                          trailing: Text(
                            money(item['total']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
                  const Divider(),
                  if (toDouble(sale['discount']) > 0)
                    InfoRow('Discount', '- ${money(sale['discount'])}'),
                  if (toDouble(sale['vat']) > 0)
                    InfoRow('VAT', money(sale['vat'])),
                  InfoRow('Total', money(sale['total_amount']), bold: true),
                  InfoRow('Paid', money(sale['paid_amount'])),
                  InfoRow(
                    'Balance',
                    money(sale['balance_amount']),
                    bold: balance > 0,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Payments',
                children: [
                  if (payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No payments yet.',
                        style: TextStyle(color: kMuted),
                      ),
                    )
                  else
                    for (final raw in payments)
                      Builder(
                        builder: (context) {
                          final p = Map<String, dynamic>.from(raw as Map);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.receipt_long),
                            title: Text(
                              '${p['receipt_no'] ?? 'Receipt'} · ${p['method'] ?? ''}',
                            ),
                            subtitle: Text(
                              formatDate(p['created_at'], withTime: true),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  money(p['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Share receipt',
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () => shareDocument(
                                    'Payment receipt ${p['receipt_no'] ?? ''}',
                                    [
                                      'PAYMENT RECEIPT ${p['receipt_no'] ?? ''}',
                                      'Invoice: ${sale['invoice_no'] ?? ''}',
                                      'Customer: ${sale['customer_name'] ?? 'Walk-in'}',
                                      'Amount: ${money(p['amount'])}',
                                      'Method: ${p['method'] ?? ''}',
                                      'Date: ${formatDate(p['created_at'], withTime: true)}',
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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

/// Collects one or more tenders towards a sale's balance. Pops with the updated sale.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key, required this.sale});

  final Map<String, dynamic> sale;

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final List<Tender> tenders;
  bool saving = false;

  double get balance => toDouble(widget.sale['balance_amount']);

  @override
  void initState() {
    super.initState();
    final methods = context.read<StaffLookups>().paymentMethods;
    tenders = [Tender(methods.first, balance)];
  }

  @override
  void dispose() {
    for (final t in tenders) {
      t.amount.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final result = await runApi(
      context,
      (api) => api.post(
        '/staff/sales/${widget.sale['id']}/payments',
        data: {
          'payments': tenders
              .where((t) => t.value > 0)
              .map((t) => t.toJson())
              .toList(),
        },
      ),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    final data = result.data as Map;
    showSuccess(context, '${data['message'] ?? 'Payment recorded.'}');
    Navigator.pop(context, Map<String, dynamic>.from(data['data'] as Map));
  }

  @override
  Widget build(BuildContext context) {
    final methods = context.watch<StaffLookups>().paymentMethods;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              '${widget.sale['invoice_no']} · balance ${money(balance)}',
              style: const TextStyle(color: kMuted),
            ),
            const SizedBox(height: 14),
            TenderEditor(
              tenders: tenders,
              methods: methods,
              suggested: balance,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every receipt issued against sales.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedList(
      path: '/staff/payments',
      searchHint: 'Receipt, invoice or customer',
      emptyText: 'No payments found.',
      emptyIcon: Icons.payments_outlined,
      bottomPadding: 24,
      itemBuilder: (context, row) => RecordCard(
        title: '${row['receipt_no'] ?? 'Receipt #${row['id']}'}',
        subtitle: [
          row['invoice_no'],
          row['customer_name'] ?? 'Walk-in',
          row['method'],
        ].where((s) => s != null).join(' · '),
        caption: formatDate(row['created_at'], withTime: true),
        amount: money(row['amount']),
        status: '${row['status']}',
        onTap: row['sale_id'] == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SaleDetailScreen(saleId: row['sale_id'] as int),
                ),
              ),
      ),
    );
  }
}
