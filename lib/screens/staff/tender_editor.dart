import 'package:flutter/material.dart';

import '../../core/format.dart';

import '../../core/app_theme.dart';
/// One way the customer pays: method + amount.
class Tender {
  Tender(this.method, double amount) : amount = TextEditingController(text: amount > 0 ? _plain(amount) : '');

  String method;
  final TextEditingController amount;

  double get value => toDouble(amount.text.replaceAll(',', ''));

  Map<String, dynamic> toJson() => {'method': method, 'amount': value};

  static String _plain(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// Edits a list of tenders (split payments). The caller owns the list.
class TenderEditor extends StatefulWidget {
  const TenderEditor({super.key, required this.tenders, required this.methods, required this.onChanged, this.suggested = 0});

  final List<Tender> tenders;
  final List<String> methods;
  final VoidCallback onChanged;

  /// Amount offered when a split row is added (what is still owed).
  final double suggested;

  @override
  State<TenderEditor> createState() => _TenderEditorState();
}

class _TenderEditorState extends State<TenderEditor> {
  @override
  Widget build(BuildContext context) {
    final paid = widget.tenders.fold<double>(0, (sum, t) => sum + t.value);
    final remaining = widget.suggested - paid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.tenders.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.methods.contains(widget.tenders[i].method) ? widget.tenders[i].method : widget.methods.first,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Method', isDense: true),
                    items: [for (final m in widget.methods) DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))],
                    onChanged: (value) {
                      setState(() => widget.tenders[i].method = value ?? widget.methods.first);
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: widget.tenders[i].amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', isDense: true),
                    onChanged: (_) {
                      setState(() {});
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.tenders.length > 1)
                  IconButton(
                    tooltip: 'Remove',
                    icon: Icon(Icons.remove_circle_outline, color: context.danger),
                    onPressed: () {
                      // Not disposed here: the field may still be in this frame's tree.
                      setState(() => widget.tenders.removeAt(i));
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: widget.tenders.length >= 10
                  ? null
                  : () {
                      final used = widget.tenders.map((t) => t.method).toSet();
                      final next = widget.methods.firstWhere((m) => !used.contains(m), orElse: () => widget.methods.first);
                      setState(() => widget.tenders.add(Tender(next, remaining > 0 ? remaining : 0)));
                      widget.onChanged();
                    },
              icon: const Icon(Icons.call_split),
              label: const Text('Split payment'),
            ),
            const Spacer(),
            if (widget.suggested > 0)
              Text(
                remaining > 0.005
                    ? 'Owing ${money(remaining)}'
                    : remaining < -0.005
                        ? 'Over by ${money(-remaining)}'
                        : 'Fully paid',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: remaining < -0.005 ? context.danger : context.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
