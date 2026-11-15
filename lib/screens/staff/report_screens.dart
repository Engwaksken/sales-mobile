import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/staff_ui.dart';

/// Reports the signed-in user may open.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> types = [];
  bool loading = true;
  String? error;

  static const icons = {
    'overview': Icons.dashboard_outlined,
    'sales': Icons.point_of_sale,
    'salesperson_performance': Icons.emoji_events_outlined,
    'expenses': Icons.receipt_long_outlined,
    'stock': Icons.inventory_2_outlined,
    'expiry': Icons.event_busy_outlined,
    'products': Icons.category_outlined,
    'customers': Icons.people_outline,
    'suppliers': Icons.local_shipping_outlined,
    'purchases': Icons.shopping_bag_outlined,
    'profit': Icons.trending_up,
    'income_statement': Icons.account_balance_outlined,
    'trial_balance': Icons.balance_outlined,
  };

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
      final response = await api.get('/staff/reports');
      if (!mounted) return;
      setState(
        () => types = ((response.data as Map)['data'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList(),
      );
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      loading: loading,
      error: error,
      onRetry: load,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordCard(
                leading: CircleAvatar(
                  child: Icon(icons[t['type']] ?? Icons.insights, size: 18),
                ),
                title: '${t['label']}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportViewScreen(
                      type: '${t['type']}',
                      label: '${t['label']}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One report as cards (one card per row), with a date range.
class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({super.key, required this.type, required this.label});

  final String type;
  final String label;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  late DateTimeRange range;
  Map<String, dynamic> report = {};
  bool loading = true;
  String? error;
  int? branchId;
  String? paymentMethod;
  int? productId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(start: DateTime(now.year, now.month), end: now);
    load();
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final lookups = context.read<StaffLookups>();
      final response = await api.get(
        '/staff/reports/${widget.type}',
        query: {
          'from': isoDate(range.start),
          'to': isoDate(range.end),
          if (lookups.isAdmin && branchId != null) 'branch_id': branchId,
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (productId != null) 'product_id': productId,
        },
      );
      if (mounted) {
        setState(
          () => report = Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: range,
    );
    if (picked != null) {
      setState(() => range = picked);
      load();
    }
  }

  String cell(String key, dynamic value, List money_) {
    if (value == null) return '';
    if (money_.contains(key)) return money(value);
    if (value is num) return formatNumber(value);
    if (value is bool) return value ? 'Yes' : 'No';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final lookups = context.watch<StaffLookups>();
    final headers = ((report['headers'] as List?) ?? const [])
        .map((h) => '$h')
        .toList();
    final keys = ((report['keys'] as List?) ?? const [])
        .map((k) => '$k')
        .toList();
    final moneyCols = (report['money_columns'] as List?) ?? const [];
    final rows = (report['rows'] as List?) ?? const [];
    final total = int.tryParse('${report['total_rows']}') ?? rows.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.label)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${formatDate(range.start.toIso8601String())} – ${formatDate(range.end.toIso8601String())}',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (lookups.isAdmin)
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey('report-branch-$branchId'),
                          initialValue: branchId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All branches'),
                            ),
                            for (final option in lookups.branches)
                              DropdownMenuItem<int?>(
                                value: option.id,
                                child: Text(
                                  option.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => branchId = value);
                            load();
                          },
                        ),
                      ),
                    if ([
                      'overview',
                      'sales',
                      'salesperson_performance',
                      'purchases',
                      'profit',
                      'expenses',
                    ].contains(widget.type))
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('report-method-$paymentMethod'),
                          initialValue: paymentMethod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All methods'),
                            ),
                            for (final method in lookups.paymentMethods)
                              DropdownMenuItem<String?>(
                                value: method,
                                child: Text(method),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => paymentMethod = value);
                            load();
                          },
                        ),
                      ),
                    if ([
                      'overview',
                      'sales',
                      'salesperson_performance',
                      'purchases',
                      'profit',
                      'products',
                    ].contains(widget.type))
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey('report-product-$productId'),
                          initialValue: productId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Product',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All products'),
                            ),
                            for (final option in lookups.products)
                              DropdownMenuItem<int?>(
                                value: option.id,
                                child: Text(
                                  option.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => productId = value);
                            load();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              loading: loading,
              error: error,
              onRetry: load,
              builder: (context) => rows.isEmpty
                  ? const EmptyState(
                      text: 'No data for this period.',
                      icon: Icons.insights,
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (total > rows.length)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Showing the first ${rows.length} of $total rows. Export the full report from the website.',
                                style: const TextStyle(color: kMuted),
                              ),
                            ),
                          for (final raw in rows)
                            Builder(
                              builder: (context) {
                                final row = Map<String, dynamic>.from(
                                  raw as Map,
                                );
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      10,
                                    ),
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < keys.length; i++)
                                          if (i == 0)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 2,
                                                ),
                                                child: Text(
                                                  keys.length == 2
                                                      ? '${row[keys[0]] ?? ''}'
                                                      : cell(
                                                          keys[0],
                                                          row[keys[0]],
                                                          moneyCols,
                                                        ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            InfoRow(
                                              i < headers.length
                                                  ? headers[i]
                                                  : titleCase(keys[i]),
                                              cell(
                                                keys[i],
                                                row[keys[i]],
                                                moneyCols,
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
