import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/staff_ui.dart';
import 'tender_editor.dart';

import '../../core/app_theme.dart';
class CartLine {
  CartLine(this.product, this.quantity);

  final Map<String, dynamic> product;
  int quantity;

  int get id => product['product_id'] as int;
  double get price => toDouble(product['price']);
  double get available => toDouble(product['available']);
  double get total => price * quantity;
}

/// Point of sale: pick a branch (admins), add products, then check out.
/// Pops with the new sale's id.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final search = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> products = [];
  final Map<int, CartLine> cart = {};
  int? branchId;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final lookups = context.read<StaffLookups>();
    lookups.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() => branchId = lookups.isAdmin
          ? (lookups.branches.isNotEmpty ? lookups.branches.first.id : null)
          : lookups.branchId);
      load();
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/staff/pos/products', query: {
        if (branchId != null) 'branch_id': branchId,
        if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
      });
      if (!mounted) return;
      setState(() => products = ((response.data as Map)['data'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void add(Map<String, dynamic> product) {
    final id = product['product_id'] as int;
    final line = cart[id];
    final available = toDouble(product['available']);
    if (line != null && line.quantity + 1 > available) {
      showFlashError('Only ${formatNumber(available)} in stock.');
      return;
    }
    setState(() => line == null ? cart[id] = CartLine(product, 1) : line.quantity++);
  }

  void showFlashError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  double get subtotal => cart.values.fold(0, (sum, line) => sum + line.total);
  int get itemCount => cart.values.fold(0, (sum, line) => sum + line.quantity);

  Future<void> changeBranch(int? id) async {
    if (id == branchId) return;
    if (cart.isNotEmpty &&
        !await confirmAction(context, title: 'Change branch?', message: 'The cart will be emptied because stock differs per branch.', confirm: 'Change')) {
      return;
    }
    setState(() {
      branchId = id;
      cart.clear();
    });
    load();
  }

  Future<void> checkout() async {
    final saleId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(lines: cart.values.toList(), branchId: branchId, subtotal: subtotal),
    );
    if (saleId != null && mounted) Navigator.pop(context, saleId);
  }

  @override
  Widget build(BuildContext context) {
    final lookups = context.watch<StaffLookups>();

    return Scaffold(
      appBar: AppBar(title: const Text('New sale')),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: checkout,
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_checkout),
                      const SizedBox(width: 10),
                      Text('Checkout ($itemCount item${itemCount == 1 ? '' : 's'})'),
                      const Spacer(),
                      Text(money(subtotal)),
                    ],
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                if (lookups.isAdmin && lookups.branches.length > 1) ...[
                  DropdownButtonFormField<int>(
                    initialValue: branchId,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Branch', prefixIcon: Icon(Icons.store_outlined)),
                    items: [for (final b in lookups.branches) DropdownMenuItem(value: b.id, child: Text(b.name))],
                    onChanged: changeBranch,
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) {
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 400), load);
                  },
                  onSubmitted: (_) => load(),
                  decoration: const InputDecoration(hintText: 'Search product, SKU or barcode', prefixIcon: Icon(Icons.search), isDense: true),
                ),
              ],
            ),
          ),
          if (cart.isNotEmpty) _CartStrip(cart: cart, onChanged: () => setState(() {})),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: ErrorState(message: error!, onRetry: load))
                    : products.isEmpty
                        ? const EmptyState(text: 'No products with stock and a selling price at this branch.', icon: Icons.inventory_2_outlined)
                        : RefreshIndicator(
                            onRefresh: load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: products.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final p = products[i];
                                final inCart = cart[p['product_id']]?.quantity ?? 0;
                                return RecordCard(
                                  title: '${p['name']}',
                                  subtitle: '${formatNumber(p['available'])} in stock${p['sku'] != null ? ' | ${p['sku']}' : ''}',
                                  amount: money(p['price']),
                                  leading: CircleAvatar(
                                    backgroundColor: inCart > 0 ? Theme.of(context).colorScheme.primary : null,
                                    foregroundColor: inCart > 0 ? Theme.of(context).colorScheme.onPrimary : null,
                                    child: inCart > 0 ? Text('$inCart', style: const TextStyle(fontWeight: FontWeight.w900)) : const Icon(Icons.add),
                                  ),
                                  onTap: () => add(p),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _CartStrip extends StatelessWidget {
  const _CartStrip({required this.cart, required this.onChanged});

  final Map<int, CartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final line in cart.values.toList())
            ListTile(
              dense: true,
              title: Text('${line.product['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(money(line.total)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(line.quantity == 1 ? Icons.delete_outline : Icons.remove_circle_outline),
                    onPressed: () {
                      line.quantity == 1 ? cart.remove(line.id) : line.quantity--;
                      onChanged();
                    },
                  ),
                  Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: line.quantity + 1 > line.available
                        ? null
                        : () {
                            line.quantity++;
                            onChanged();
                          },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Customer, discount/VAT and tenders; submits the sale and pops with its id.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key, required this.lines, required this.branchId, required this.subtotal});

  final List<CartLine> lines;
  final int? branchId;
  final double subtotal;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final discount = TextEditingController();
  final vat = TextEditingController();
  late final List<Tender> tenders;
  Map<String, dynamic>? customer;
  bool credit = false;
  bool saving = false;

  double get total {
    final value = widget.subtotal - toDouble(discount.text) + toDouble(vat.text);
    return value < 0 ? 0 : value;
  }

  double get tendered => tenders.fold(0, (sum, t) => sum + t.value);

  @override
  void initState() {
    super.initState();
    tenders = [Tender(context.read<StaffLookups>().paymentMethods.first, widget.subtotal)];
  }

  @override
  void dispose() {
    discount.dispose();
    vat.dispose();
    for (final t in tenders) {
      t.amount.dispose();
    }
    super.dispose();
  }

  /// Keeps a single untouched tender equal to the total when discount/VAT change.
  void totalsChanged() {
    if (tenders.length == 1) {
      tenders.first.amount.text = total.truncateToDouble() == total ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> pickCustomer() async {
    final row = await pickRecord(
      context,
      title: 'Choose customer',
      path: '/staff/pos/customers',
      query: {if (widget.branchId != null) 'branch_id': widget.branchId},
      label: (r) => '${r['name'] ?? 'Customer #${r['id']}'}',
      sublabel: (r) => [r['phone'], r['email']].where((s) => s != null && '$s'.isNotEmpty).join(' | '),
    );
    if (row != null) setState(() => customer = row);
  }

  String? get problem {
    final paid = credit ? 0 : tendered;
    if (paid > total + 0.005) return 'Payments are more than the total.';
    if (paid < total - 0.005 && customer == null) {
      return 'Walk-in sales must be paid in full. Choose a customer to sell on credit.';
    }
    return null;
  }

  Future<void> submit() async {
    final result = await runApi(
      context,
      (api) => api.post('/staff/sales', data: {
        if (widget.branchId != null) 'branch_id': widget.branchId,
        if (customer != null) 'customer_id': customer!['id'],
        'discount': toDouble(discount.text),
        'vat': toDouble(vat.text),
        'items': [for (final l in widget.lines) {'product_id': l.id, 'quantity': l.quantity}],
        'payments': credit ? [] : tenders.where((t) => t.value > 0).map((t) => t.toJson()).toList(),
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    final data = result.data as Map;
    showSuccess(context, '${data['message'] ?? 'Sale recorded.'}');
    Navigator.pop(context, (data['data'] as Map)['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    final methods = context.watch<StaffLookups>().paymentMethods;
    final issue = problem;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickCustomer,
              icon: const Icon(Icons.person_search),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(customer == null ? 'Walk-in customer (tap to choose)' : '${customer!['name']}', overflow: TextOverflow.ellipsis),
              ),
            ),
            if (customer != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() {
                  customer = null;
                  credit = false;
                }), child: const Text('Remove customer')),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: discount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount', isDense: true),
                    onChanged: (_) => totalsChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: vat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'VAT', isDense: true),
                    onChanged: (_) => totalsChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InfoRow('Subtotal', money(widget.subtotal)),
            InfoRow('Total', money(total), bold: true),
            const Divider(height: 24),
            if (customer != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: credit,
                onChanged: (v) => setState(() => credit = v),
                title: const Text('Sell on credit (no payment now)'),
              ),
            if (!credit) TenderEditor(tenders: tenders, methods: methods, suggested: total, onChanged: () => setState(() {})),
            if (issue != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(issue, style: TextStyle(color: context.danger, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving || issue != null ? null : submit,
              icon: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text('Complete sale (${money(total)})'),
            ),
          ],
        ),
      ),
    );
  }
}
