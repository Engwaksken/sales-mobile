import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../widgets/staff_ui.dart';
import 'staff/module_router.dart';
import 'staff/order_screens.dart';
import 'staff/sales_screens.dart';

import '../core/app_theme.dart';
/// Staff dashboard: tappable statistic cards, charts and recent records.
/// What appears depends on the user's permissions (decided by the server).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  bool showAllStats = false;
  String? error;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = data.isEmpty;
      error = null;
    });
    try {
      final response = await api.get('/dashboard');
      if (mounted)
        setState(() => data = Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : [];

  static IconData iconFor(String? name) => switch (name) {
    'point_of_sale' => Icons.point_of_sale,
    'trending_up' => Icons.trending_up,
    'receipt_long' => Icons.receipt_long,
    'shopping_cart' => Icons.shopping_cart,
    'people' => Icons.people,
    'inventory_2' => Icons.inventory_2,
    'payments' => Icons.payments,
    'notifications' => Icons.notifications,
    'account_balance_wallet' => Icons.account_balance_wallet,
    'savings' => Icons.savings,
    'warning_amber' => Icons.warning_amber,
    'forum' => Icons.forum,
    _ => Icons.insights,
  };

  Future<void> openStat(Map<String, dynamic> stat) async {
    final filter = stat['filter'] is Map
        ? Map<String, dynamic>.from(stat['filter'] as Map)
        : <String, dynamic>{};
    await openStatTarget(
      context,
      '${stat['module']}',
      filter,
      '${stat['label']}',
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && data.isEmpty)
      return Center(
        child: ErrorState(message: error!, onRetry: load),
      );

    final stats = list(data['stats']);
    final charts = data['charts'] is Map
        ? Map<String, dynamic>.from(data['charts'] as Map)
        : <String, dynamic>{};
    final monthly = list(charts['monthly']);
    final daily = list(charts['daily']);
    final methods = list(charts['payment_methods']);
    final topProducts = list(charts['top_products']);
    final stages = list(charts['order_stages']);
    final salespeople = list(
      charts['top_salespeople'] ?? charts['salesperson_performance'],
    );
    final recentSales = list(data['recent_sales']);
    final recentOrders = list(data['recent_orders']);

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            data['branch_scoped'] == true
                ? 'Your branch, ${formatDate(DateTime.now().toIso8601String())}'
                : 'All branches, ${formatDate(DateTime.now().toIso8601String())}',
            style: TextStyle(color: context.muted),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final stat in (showAllStats ? stats : stats.take(6)))
                    SizedBox(
                      width: width,
                      child: StatCard(
                        label: '${stat['label']}',
                        value: stat['type'] == 'money'
                            ? compactMoney(stat['value'])
                            : formatNumber(stat['value']),
                        icon: iconFor('${stat['icon']}'),
                        onTap: () => openStat(stat),
                      ),
                    ),
                ],
              );
            },
          ),
          if (stats.length > 6)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => showAllStats = !showAllStats),
                icon: Icon(
                  showAllStats ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  showAllStats ? 'Show less' : 'See more (${stats.length - 6})',
                ),
              ),
            ),
          if (monthly.isNotEmpty) ...[
            const SizedBox(height: 18),
            _CollapsibleSection(
              title: monthly.any((m) => m['expenses'] != null)
                  ? 'Sales vs expenses'
                  : 'Monthly sales',
              subtitle: 'Last 7 months',
              child: _ChartCard(
                title: monthly.any((m) => m['expenses'] != null)
                    ? 'Sales vs expenses'
                    : 'Monthly sales',
                subtitle: 'Last 7 months',
                legend: [
                  _Legend(Theme.of(context).colorScheme.primary, 'Sales'),
                  if (monthly.any((m) => m['expenses'] != null))
                    const _Legend(Color(0xFFF59E0B), 'Expenses'),
                ],
                child: _MonthlyBars(rows: monthly),
              ),
            ),
          ],
          if (daily.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'Daily sales',
              subtitle: 'Last 14 days',
              child: _ChartCard(
                title: 'Daily sales',
                subtitle: 'Last 14 days',
                child: _DailyLine(rows: daily),
              ),
            ),
          ],
          if (methods.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'How customers paid',
              subtitle: 'This month',
              child: _ChartCard(
                title: 'How customers paid',
                subtitle: 'This month',
                child: _MethodsPie(rows: methods),
              ),
            ),
          ],
          if (topProducts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'Top products',
              subtitle: 'This month, by revenue',
              child: _ChartCard(
                title: 'Top products',
                subtitle: 'This month, by revenue',
                child: _TopProducts(rows: topProducts),
              ),
            ),
          ],
          if (salespeople.isNotEmpty)
            _CollapsibleSection(
              title: 'Top salesperson / staff',
              subtitle: 'This month',
              child: _ChartCard(
                title: 'Top salesperson / staff',
                subtitle: 'This month',
                child: _TopProducts(
                  rows: salespeople
                      .map(
                        (r) => {
                          ...r,
                          'revenue': r['revenue'] ?? r['sales'] ?? r['total'],
                          'quantity': r['quantity'] ?? r['sales_count'] ?? 0,
                        },
                      )
                      .toList(),
                ),
              ),
            ),
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'Orders by stage',
              subtitle: 'Tap a stage to open those orders',
              child: _ChartCard(
                title: 'Orders by stage',
                subtitle: 'Tap a stage to open those orders',
                child: _StageBars(
                  rows: stages,
                  onTap: (key, label) => openStatTarget(context, 'orders', {
                    'status': key,
                  }, label).then((_) => load()),
                ),
              ),
            ),
          ],
          if (recentSales.isNotEmpty) ...[
            const SizedBox(height: 18),
            _CollapsibleSection(
              title: 'Recent sales',
              subtitle: '${recentSales.length} latest',
              child: SectionCard(
                title: 'Recent sales',
                children: [
                  for (final s in recentSales)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const CircleAvatar(
                        child: Icon(Icons.point_of_sale, size: 17),
                      ),
                      title: Text(
                        '${s['invoice_no'] ?? 'Sale #${s['id']}'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${s['customer_name'] ?? 'Walk-in'} · ${formatDate(s['sale_date'])}',
                      ),
                      trailing: Text(
                        money(s['total_amount']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SaleDetailScreen(saleId: s['id'] as int),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (recentOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CollapsibleSection(
              title: 'Recent orders',
              subtitle: '${recentOrders.length} latest',
              child: SectionCard(
                title: 'Recent orders',
                children: [
                  for (final o in recentOrders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_shipping, size: 17),
                      ),
                      title: Text(
                        '${o['order_number'] ?? o['order_id'] ?? 'Order #${o['id']}'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${o['customer_name'] ?? ''} · ${o['status_label'] ?? ''}',
                      ),
                      trailing: Text(
                        money(o['total_amount']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(orderId: o['id'] as int),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Chart series colours; mid-tones that read on both light and dark backgrounds.
const _palette = [
  Color(0xFF0F766E),
  Color(0xFF2563EB),
  Color(0xFFF59E0B),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFF64748B),
];

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.muted, fontSize: 12),
      ),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: child),
      ],
    ),
  );
}

class _Legend {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.legend = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<_Legend> legend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            Text(subtitle, style: TextStyle(color: context.muted, fontSize: 12)),
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                children: [
                  for (final l in legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: l.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(l.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

String _axis(double v) =>
    v == 0 ? '0' : compactMoney(v).replaceFirst(RegExp(r'^[A-Z]{3} '), '');

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasExpenses = rows.any((r) => r['expenses'] != null);
    final maxY = rows.fold<double>(
      0,
      (m, r) => [
        m,
        toDouble(r['sales']),
        toDouble(r['expenses']),
      ].reduce((a, b) => a > b ? a : b),
    );

    return SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.15,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.hairline, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) => Text(
                  _axis(value),
                  style: TextStyle(fontSize: 10, color: context.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      i >= 0 && i < rows.length ? '${rows[i]['label']}' : '',
                      style: TextStyle(fontSize: 11, color: context.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rows[groupIndex]['label']} ${rodIndex == 0 ? 'sales' : 'expenses'}\n${money(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < rows.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: toDouble(rows[i]['sales']),
                    color: primary,
                    width: hasExpenses ? 9 : 16,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  if (hasExpenses)
                    BarChartRodData(
                      toY: toDouble(rows[i]['expenses']),
                      color: const Color(0xFFF59E0B),
                      width: 9,
                      borderRadius: BorderRadius.circular(3),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyLine extends StatelessWidget {
  const _DailyLine({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final maxY = rows.fold<double>(
      0,
      (m, r) => toDouble(r['value']) > m ? toDouble(r['value']) : m,
    );

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.hairline, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) => Text(
                  _axis(value),
                  style: TextStyle(fontSize: 10, color: context.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  // Every third day keeps the labels readable on a phone.
                  if (i < 0 ||
                      i >= rows.length ||
                      (rows.length - 1 - i) % 3 != 0)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${rows[i]['label']}',
                      style: TextStyle(fontSize: 10, color: context.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${rows[s.x.toInt()]['label']}\n${money(s.y)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < rows.length; i++)
                  FlSpot(i.toDouble(), toDouble(rows[i]['value'])),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodsPie extends StatelessWidget {
  const _MethodsPie({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + toDouble(r['value']));

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < rows.length; i++)
                  PieChartSectionData(
                    value: toDouble(rows[i]['value']),
                    color: _palette[i % _palette.length],
                    radius: 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${rows[i]['label']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total > 0
                            ? '${(toDouble(rows[i]['value']) / total * 100).round()}%'
                            : '',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  money(total),
                  style: TextStyle(color: context.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final top = rows.fold<double>(
      0,
      (m, r) => toDouble(r['revenue']) > m ? toDouble(r['revenue']) : m,
    );
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r['name']}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      money(r['revenue']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: top > 0 ? toDouble(r['revenue']) / top : 0,
                    minHeight: 8,
                    color: primary,
                    backgroundColor: primary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNumber(r['quantity'])} sold',
                  style: TextStyle(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StageBars extends StatelessWidget {
  const _StageBars({required this.rows, required this.onTap});

  final List<Map<String, dynamic>> rows;
  final void Function(String key, String label) onTap;

  @override
  Widget build(BuildContext context) {
    final top = rows.fold<double>(
      0,
      (m, r) => toDouble(r['value']) > m ? toDouble(r['value']) : m,
    );

    return Column(
      children: [
        for (final r in rows)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onTap('${r['key']}', '${r['label']}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      '${r['label']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: top > 0 ? toDouble(r['value']) / top : 0,
                        minHeight: 10,
                        color: StatusPill.colorsFor('${r['key']}', dark: context.isDark).$2,
                        backgroundColor: context.fieldFill,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      formatNumber(r['value']),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: context.faint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
