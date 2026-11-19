import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/document_sharing.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/staff_ui.dart';
import 'pos_screen.dart';
import 'tender_editor.dart';

import '../../core/app_theme.dart';
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

  static final filters = [
    ChoiceFilter(
      id: 'status',
      label: 'Status',
      options: [for (final e in saleStatuses.entries) FilterOption(e.key, e.value)],
    ),
    const DateRangeFilter(id: 'date', label: 'Sale date'),
  ];

  /// The range a dashboard card opened this list with.
  late final DateTimeRange? startRange = _startingRange(widget.from, widget.to);

  late Map<String, Object?> values = {
    'status': widget.initialStatus,
    'date': startRange,
  };

  /// A dashboard card's from/to, for display; a missing end shows as today.
  static DateTimeRange? _startingRange(String? from, String? to) {
    final start = DateTime.tryParse(from ?? '') ?? DateTime.tryParse(to ?? '');
    if (start == null) return null;
    final end = DateTime.tryParse(to ?? '') ?? DateTime.now();
    return dateOnlyRange(DateTimeRange(start: start, end: end.isBefore(start) ? start : end));
  }

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
    final range = values['date'] as DateTimeRange?;
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
        query: {
          'status': values['status'],
          // Until the dates are changed, send the card's own from/to unchanged.
          'from': range == null ? null : (range == startRange ? widget.from : isoDate(range.start)),
          'to': range == null ? null : (range == startRange ? widget.to : isoDate(range.end)),
        },
        filters: filters,
        filterValues: values,
        onFiltersChanged: (v) => setState(() => values = v),
        quickFilters: const ['status'],
        searchHint: 'Invoice, customer or product',
        emptyText: 'No sales found.',
        emptyIcon: Icons.point_of_sale,
        itemBuilder: (context, row) => RecordCard(
          title: '${row['invoice_no'] ?? 'Sale #${row['id']}'}',
          subtitle: '${row['product_names'] ?? ''}',
          caption: [
            row['customer_name'],
            formatDate(row['sale_date']),
          ].where((s) => s != null && '$s'.isNotEmpty).join(' | '),
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
              onPressed: () => shareSalesDocument(
                context,
                SalesDocument(
                  title: 'Invoice',
                  signer: sale['sold_by']?.toString(),
                  signerRole: sale['sold_by_role']?.toString(),
                  signature: bytesFromDataUri(sale['sold_by_signature']),
                  number: '${sale['invoice_no'] ?? ''}',
                  details: [
                    ('Billed to', '${sale['customer_name'] ?? 'Walk-in'}'),
                    ('Phone', sale['customer_phone']?.toString()),
                    ('Date', formatDate(sale['sale_date'])),
                    ('Status', saleStatuses[sale['payment_status']] ?? sale['payment_status']?.toString()),
                    ('Branch', sale['branch_name']?.toString()),
                    ('Served by', sale['sold_by']?.toString()),
                  ],
                  lines: [
                    for (final raw in items)
                      () {
                        final item = Map<String, dynamic>.from(raw as Map);
                        return DocumentLine(
                          name: '${item['name']}',
                          quantity: item['quantity'],
                          price: item['price'],
                          total: item['total'],
                        );
                      }(),
                  ],
                  totals: [
                    if (toDouble(sale['discount']) > 0) ('Discount', '- ${money(sale['discount'])}'),
                    if (toDouble(sale['vat']) > 0) ('VAT', money(sale['vat'])),
                    ('Total', money(sale['total_amount'])),
                    ('Paid', money(sale['paid_amount'])),
                    ('Balance due', money(sale['balance_amount'])),
                  ],
                ),
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
                  label: Text('Record payment (${money(balance)} due)'),
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
                            '${formatNumber(item['quantity'])} x ${money(item['price'])}',
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
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No payments yet.',
                        style: TextStyle(color: context.muted),
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
                              '${p['receipt_no'] ?? 'Receipt'} | ${p['method'] ?? ''}',
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
                                  onPressed: () => shareSalesDocument(
                                    context,
                                    SalesDocument(
                                      title: 'Payment receipt',
                                      signer: sale['sold_by']?.toString(),
                                      signerRole: sale['sold_by_role']?.toString(),
                                      signature: bytesFromDataUri(sale['sold_by_signature']),
                                      number: '${p['receipt_no'] ?? ''}',
                                      details: [
                                        ('Received from', '${sale['customer_name'] ?? 'Walk-in'}'),
                                        ('Invoice', '${sale['invoice_no'] ?? ''}'),
                                        ('Date', formatDate(p['created_at'], withTime: true)),
                                        ('Method', '${p['method'] ?? ''}'),
                                        ('Branch', sale['branch_name']?.toString()),
                                      ],
                                      highlight: ('Amount received', money(p['amount'])),
                                      totals: [
                                        ('Invoice total', money(sale['total_amount'])),
                                        ('Balance due', money(sale['balance_amount'])),
                                      ],
                                    ),
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
              '${widget.sale['invoice_no']} | balance ${money(balance)}',
              style: TextStyle(color: context.muted),
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
const paymentStatuses = {
  'successful': 'Successful',
  'pending': 'Pending',
  'failed': 'Failed',
};

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, this.initialStatus, this.from, this.to});

  /// Starting filters, e.g. from the "Collected This Month" dashboard card.
  final String? initialStatus;
  final String? from;
  final String? to;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final list = PagedListController();

  /// The range a dashboard card opened this list with.
  late final DateTimeRange? startRange = _SalesScreenState._startingRange(widget.from, widget.to);

  late Map<String, Object?> values = {
    'status': paymentStatuses.containsKey(widget.initialStatus) ? widget.initialStatus : null,
    'date': startRange,
  };

  @override
  void initState() {
    super.initState();
    context.read<StaffLookups>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final lookups = context.watch<StaffLookups>();
    final branchId = values['branch'] as String?;
    final paymentMethod = values['method'] as String?;
    final productId = values['product'] as String?;
    final range = values['date'] as DateTimeRange?;
    return PagedList(
      path: '/staff/payments',
      controller: list,
      query: {
        if (lookups.isAdmin && branchId != null) 'branch_id': int.parse(branchId),
        'payment_method': ?paymentMethod,
        if (productId != null) 'product_id': int.parse(productId),
        'status': values['status'],
        // Until the dates are changed, send the card's own from/to unchanged.
        'from': range == null ? null : (range == startRange ? widget.from : isoDate(range.start)),
        'to': range == null ? null : (range == startRange ? widget.to : isoDate(range.end)),
      },
      filters: [
        ChoiceFilter(
          id: 'method',
          label: 'Payment method',
          options: [for (final m in lookups.paymentMethods) FilterOption(m, m)],
          searchable: false,
        ),
        if (lookups.isAdmin)
          ChoiceFilter(
            id: 'branch',
            label: 'Branch',
            icon: Icons.store_outlined,
            allLabel: 'All branches',
            options: [for (final b in lookups.branches) FilterOption('${b.id}', b.name)],
            searchable: true,
          ),
        ChoiceFilter(
          id: 'product',
          label: 'Product',
          icon: Icons.inventory_2_outlined,
          allLabel: 'All products',
          options: [for (final p in lookups.products) FilterOption('${p.id}', p.name)],
          searchable: true,
        ),
        const DateRangeFilter(id: 'date', label: 'Payment date'),
        ChoiceFilter(
          id: 'status',
          label: 'Status',
          options: [for (final e in paymentStatuses.entries) FilterOption(e.key, e.value)],
        ),
      ],
      filterValues: values,
      onFiltersChanged: (v) => setState(() => values = v),
      quickFilters: const ['method'],
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
        ].where((s) => s != null).join(' | '),
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
