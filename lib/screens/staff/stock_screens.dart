import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/staff_ui.dart';

/// Stock levels and stock issues (damages, gratis, staff consumption).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  final levels = PagedListController();
  final issues = PagedListController();
  bool lowOnly = false;

  @override
  void initState() {
    super.initState();
    context.read<StaffLookups>().ensureLoaded();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> openForm(Widget form, PagedListController list) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => form));
    if (saved == true) {
      levels.reload();
      list.reload();
    }
  }

  Future<void> editStock(Map<String, dynamic> row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StockEditSheet(stock: row),
    );
    if (saved == true) levels.reload();
  }

  @override
  Widget build(BuildContext context) {
    final onIssues = tabs.index == 1;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stock-action',
        onPressed: () => onIssues ? openForm(const StockIssueFormScreen(), issues) : openForm(const ReceiveStockScreen(), levels),
        icon: Icon(onIssues ? Icons.report_gmailerrorred : Icons.add_box_outlined),
        label: Text(onIssues ? 'Record issue' : 'Receive stock'),
      ),
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(controller: tabs, tabs: const [Tab(text: 'Stock levels'), Tab(text: 'Stock issues')]),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                PagedList(
                  path: '/staff/stock',
                  controller: levels,
                  query: {'low': lowOnly ? 1 : null},
                  searchHint: 'Product, SKU or barcode',
                  emptyText: lowOnly ? 'Nothing is running low.' : 'No stock recorded yet.',
                  emptyIcon: Icons.inventory_2_outlined,
                  header: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Low stock (5 or fewer)'),
                      selected: lowOnly,
                      onSelected: (v) => setState(() => lowOnly = v),
                    ),
                  ),
                  itemBuilder: (context, row) {
                    final qty = toDouble(row['quantity']);
                    final price = row['selling_price'];
                    return RecordCard(
                      title: '${row['product_name'] ?? 'Product #${row['product_id']}'}',
                      subtitle: [row['branch_name'], row['supplier_name']].where((s) => s != null && '$s'.isNotEmpty).join(' · '),
                      caption: [
                        price == null ? 'No selling price' : 'Sells at ${money(price)}',
                        if (row['expiry_date'] != null) 'Expires ${formatDate(row['expiry_date'])}',
                      ].join(' · '),
                      amount: '${formatNumber(qty)} ${row['unit_type'] ?? ''}'.trim(),
                      status: qty <= 0 ? 'cancelled' : (qty <= 5 ? 'pending' : 'active'),
                      statusLabel: qty <= 0 ? 'Out' : (qty <= 5 ? 'Low' : 'In stock'),
                      onTap: () => editStock(row),
                    );
                  },
                ),
                PagedList(
                  path: '/staff/stock-issues',
                  controller: issues,
                  searchable: false,
                  emptyText: 'No stock issues recorded.',
                  emptyIcon: Icons.report_gmailerrorred,
                  itemBuilder: (context, row) => RecordCard(
                    title: '${row['product_name'] ?? 'Product'}',
                    subtitle: [row['branch_name'], row['reason']].where((s) => s != null && '$s'.isNotEmpty).join(' · '),
                    caption: '${formatDate(row['created_at'], withTime: true)}${row['recorded_by'] != null ? ' · ${row['recorded_by']}' : ''}',
                    amount: '-${formatNumber(row['quantity'])}',
                    status: 'pending',
                    statusLabel: '${row['type_label'] ?? row['type']}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks a product for stock forms (needs only manage_stock).
Future<Map<String, dynamic>?> pickStockProduct(BuildContext context) => pickRecord(
      context,
      title: 'Choose product',
      path: '/staff/stock/products',
      label: (r) => '${r['name']}',
      sublabel: (r) => [r['sku'], r['barcode']].where((s) => s != null && '$s'.isNotEmpty).join(' · '),
    );

class _ProductField extends StatelessWidget {
  const _ProductField({required this.product, required this.onChanged});

  final Map<String, dynamic>? product;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
      onPressed: () async {
        final row = await pickStockProduct(context);
        if (row != null) onChanged(row);
      },
      icon: const Icon(Icons.inventory_2_outlined),
      label: Text(product == null ? 'Choose product *' : '${product!['name']}', overflow: TextOverflow.ellipsis),
    );
  }
}

/// Branch selector shown to admins only; others always use their own branch.
class BranchChooser extends StatelessWidget {
  const BranchChooser({super.key, required this.selected, required this.onChanged, this.multiple = false});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final lookups = context.watch<StaffLookups>();
    if (!lookups.isAdmin) {
      return InfoRow('Branch', lookups.branchName(lookups.branchId).isEmpty ? 'Your branch' : lookups.branchName(lookups.branchId));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(multiple ? 'Branches *' : 'Branch *', style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final b in lookups.branches)
              FilterChip(
                label: Text(b.name),
                selected: selected.contains(b.id),
                onSelected: (on) {
                  final next = multiple ? {...selected} : <int>{};
                  on ? next.add(b.id) : next.remove(b.id);
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController();
  final unit = TextEditingController();
  final cost = TextEditingController();
  final selling = TextEditingController();
  Map<String, dynamic>? product;
  int? supplierId;
  DateTime? expiry;
  Set<int> branches = {};
  bool saving = false;

  @override
  void dispose() {
    for (final c in [quantity, unit, cost, selling]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final lookups = context.read<StaffLookups>();
    if (!form.currentState!.validate()) return;
    if (product == null) return showSnack('Choose a product.');
    if (lookups.isAdmin && branches.isEmpty) return showSnack('Choose at least one branch.');

    final result = await runApi(
      context,
      (api) => api.post('/staff/stock', data: {
        'product_id': product!['id'],
        if (supplierId != null) 'supplier_id': supplierId,
        if (lookups.isAdmin) 'branch_ids': branches.toList(),
        'quantity': toDouble(quantity.text),
        if (unit.text.trim().isNotEmpty) 'unit_type': unit.text.trim(),
        if (cost.text.trim().isNotEmpty) 'cost_price': toDouble(cost.text),
        if (selling.text.trim().isNotEmpty) 'selling_price': toDouble(selling.text),
        if (expiry != null) 'expiry_date': isoDate(expiry!),
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Stock saved.'}');
    Navigator.pop(context, true);
  }

  void showSnack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<StaffLookups>().suppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive stock')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProductField(product: product, onChanged: (p) => setState(() => product = p)),
            const SizedBox(height: 14),
            BranchChooser(selected: branches, multiple: true, onChanged: (s) => setState(() => branches = s)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                    validator: (v) => toDouble(v) > 0 ? null : 'Enter a quantity',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (pcs, kg...)'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cost price'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: selling,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Selling price'),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Stock without a selling price cannot be sold until one is set.', style: TextStyle(color: kMuted, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Supplier'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('No supplier')),
                for (final s in suppliers) DropdownMenuItem<int?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => supplierId = v),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.event),
              label: Text(expiry == null ? 'Expiry date (optional)' : 'Expires ${formatDate(expiry!.toIso8601String())}'),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, firstDate: now.subtract(const Duration(days: 365)), lastDate: DateTime(now.year + 10), initialDate: expiry ?? now);
                if (picked != null) setState(() => expiry = picked);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.save),
              label: Text(saving ? 'Saving...' : 'Save stock'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit prices, quantity, unit and expiry of one stock row.
class StockEditSheet extends StatefulWidget {
  const StockEditSheet({super.key, required this.stock});

  final Map<String, dynamic> stock;

  @override
  State<StockEditSheet> createState() => _StockEditSheetState();
}

class _StockEditSheetState extends State<StockEditSheet> {
  late final quantity = TextEditingController(text: _text(widget.stock['quantity']));
  late final cost = TextEditingController(text: _text(widget.stock['cost_price']));
  late final selling = TextEditingController(text: _text(widget.stock['selling_price']));
  late final unit = TextEditingController(text: '${widget.stock['unit_type'] ?? ''}');
  bool saving = false;

  static String _text(dynamic v) {
    if (v == null) return '';
    final d = toDouble(v);
    return d.truncateToDouble() == d ? d.toStringAsFixed(0) : d.toString();
  }

  @override
  void dispose() {
    for (final c in [quantity, cost, selling, unit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final result = await runApi(
      context,
      (api) => api.put('/staff/stock/${widget.stock['id']}', data: {
        'quantity': toDouble(quantity.text),
        'unit_type': unit.text.trim().isEmpty ? null : unit.text.trim(),
        'cost_price': cost.text.trim().isEmpty ? null : toDouble(cost.text),
        'selling_price': selling.text.trim().isEmpty ? null : toDouble(selling.text),
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, 'Stock updated.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.stock['product_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${widget.stock['branch_name'] ?? ''}', style: const TextStyle(color: kMuted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost price'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: selling, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling price'))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('To take stock out for damages or gratis, use Stock issues so it is recorded.', style: TextStyle(color: kMuted, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}

class StockIssueFormScreen extends StatefulWidget {
  const StockIssueFormScreen({super.key});

  @override
  State<StockIssueFormScreen> createState() => _StockIssueFormScreenState();
}

class _StockIssueFormScreenState extends State<StockIssueFormScreen> {
  final quantity = TextEditingController();
  final reason = TextEditingController();
  Map<String, dynamic>? product;
  String? type;
  Set<int> branch = {};
  bool saving = false;

  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final lookups = context.read<StaffLookups>();
    String? problem;
    if (product == null) problem = 'Choose a product.';
    if (type == null) problem ??= 'Choose the type of issue.';
    if ((int.tryParse(quantity.text.trim()) ?? 0) < 1) problem ??= 'Enter a whole quantity of at least 1.';
    if (lookups.isAdmin && branch.isEmpty) problem ??= 'Choose a branch.';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem), behavior: SnackBarBehavior.floating));
      return;
    }

    final result = await runApi(
      context,
      (api) => api.post('/staff/stock-issues', data: {
        'product_id': product!['id'],
        if (lookups.isAdmin) 'branch_id': branch.first,
        'type': type,
        'quantity': int.parse(quantity.text.trim()),
        if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Stock issue recorded.'}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final types = context.watch<StaffLookups>().stockIssueTypes;

    return Scaffold(
      appBar: AppBar(title: const Text('Record stock issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Takes stock out without a sale or cash entry.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 14),
          _ProductField(product: product, onChanged: (p) => setState(() => product = p)),
          const SizedBox(height: 14),
          BranchChooser(selected: branch, onChanged: (s) => setState(() => branch = s)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type *'),
            items: [for (final t in types) DropdownMenuItem(value: t.key, child: Text(t.label))],
            onChanged: (v) => setState(() => type = v),
          ),
          const SizedBox(height: 14),
          TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity *')),
          const SizedBox(height: 14),
          TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Record issue')),
        ],
      ),
    );
  }
}
