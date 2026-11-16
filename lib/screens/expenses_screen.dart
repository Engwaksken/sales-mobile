import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../widgets/filter_bar.dart';
import 'expense_form_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final search = TextEditingController();
  Timer? debounce;
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
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void searchNow() {
    debounce?.cancel();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await context.read<ApiClient>().get(
        '/expenses',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text('Track and scan expense receipts', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => ExpenseFormScreen(onSaved: load)),
                  );
                  if (changed == true) load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          ),
        ),
        FilterBar(
          search: search,
          searchHint: 'Search expenses',
          onSearchChanged: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 450), load);
          },
          onSearchSubmitted: (_) => searchNow(),
          onSearchCleared: searchNow,
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
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
          else if (rows.isEmpty && search.text.trim().isNotEmpty)
            FilteredEmptyState(
              message: 'No expenses match your search',
              hint: 'Check the spelling or try other words.',
              clearLabel: 'Clear search',
              onClear: () {
                search.clear();
                searchNow();
              },
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No expenses found.', style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            ...rows.map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
              final payee = row['payee'] ?? row['vendor'] ?? row['description'] ?? 'Expense';
              final date = row['expense_date'] ?? row['created_at'] ?? '';

              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('$payee', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$date'),
                  trailing: Text(
                    'UGX ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
