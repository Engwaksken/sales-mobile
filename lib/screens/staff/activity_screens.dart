import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/staff_ui.dart';

const _red = Color(0xFFB91C1C);

/// The owner's audit trail: who created, changed or deleted what, with
/// suspicious edits (deleted sales, stock counts raised by hand...) flagged.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final list = PagedListController();
  Map<String, dynamic> summary = {};
  bool flaggedOnly = false;
  String? module;
  int? userId;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    try {
      final response = await context.read<ApiClient>().get('/staff/activity-logs/summary');
      if (mounted) setState(() => summary = Map<String, dynamic>.from(response.data as Map));
    } catch (_) {
      // The list shows its own error.
    }
  }

  List<Map<String, dynamic>> _list(String key) =>
      ((summary[key] as List?) ?? const []).map((m) => Map<String, dynamic>.from(m as Map)).toList();

  String userName(int? id) =>
      _list('users').where((u) => u['id'] == id).map((u) => '${u['name']}').firstOrNull ?? 'User #$id';

  @override
  Widget build(BuildContext context) {
    final flaggedCount = int.tryParse('${summary['flagged_this_week'] ?? 0}') ?? 0;
    final top = _list('top_flagged');
    final modules = {for (final m in _list('modules')) '${m['key']}': '${m['label']}'};
    final users = _list('users');

    return PagedList(
      path: '/staff/activity-logs',
      controller: list,
      query: {'flagged': flaggedOnly ? 1 : null, 'module': module, 'user_id': userId},
      searchHint: 'Invoice, product, person...',
      emptyText: flaggedOnly ? 'Nothing flagged for these filters.' : 'No activity for these filters.',
      emptyIcon: Icons.fact_check_outlined,
      bottomPadding: 24,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: flaggedCount > 0 ? const Color(0xFFFEF2F2) : null,
            child: InkWell(
              onTap: () => setState(() => flaggedOnly = !flaggedOnly),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, color: flaggedCount > 0 ? _red : kFaint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$flaggedCount flagged change${flaggedCount == 1 ? '' : 's'} in the last 7 days',
                            style: TextStyle(fontWeight: FontWeight.w800, color: flaggedCount > 0 ? _red : null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Flags mark deleted or edited sales, changed payments and stock counts changed by hand. Check each one is genuine.',
                      style: TextStyle(color: kMuted, fontSize: 12.5),
                    ),
                    if (top.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in top)
                            ActionChip(
                              avatar: const Icon(Icons.person_outline, size: 16),
                              label: Text('${t['user_name'] ?? 'User'} · ${t['total']}'),
                              onPressed: () => setState(() {
                                flaggedOnly = true;
                                userId = int.tryParse('${t['user_id']}');
                              }),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                avatar: Icon(Icons.flag, size: 16, color: flaggedOnly ? _red : kMuted),
                label: const Text('Flagged only'),
                selected: flaggedOnly,
                onSelected: (v) => setState(() => flaggedOnly = v),
              ),
              _PickerChip(
                icon: Icons.person_outline,
                label: userId == null ? 'Everyone' : userName(userId),
                active: userId != null,
                options: {for (final u in users) '${u['id']}': '${u['name']} (${titleCase('${u['role']}')})'},
                onSelected: (v) => setState(() => userId = v == null ? null : int.tryParse(v)),
              ),
              _PickerChip(
                icon: Icons.category_outlined,
                label: module == null ? 'All areas' : (modules[module] ?? module!),
                active: module != null,
                options: modules,
                onSelected: (v) => setState(() => module = v),
              ),
            ],
          ),
        ],
      ),
      itemBuilder: (context, row) => _LogCard(row: row),
    );
  }
}

/// A chip that opens a list to pick one value (or clear it).
class _PickerChip extends StatelessWidget {
  const _PickerChip({required this.icon, required this.label, required this.active, required this.options, required this.onSelected});

  final IconData icon;
  final String label;
  final bool active;
  final Map<String, String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: active,
      onDeleted: active ? () => onSelected(null) : null,
      onPressed: options.isEmpty
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (sheet) => SizedBox(
                  height: MediaQuery.of(sheet).size.height * 0.6,
                  child: ListView(
                    children: [
                      for (final e in options.entries)
                        ListTile(title: Text(e.value), onTap: () => Navigator.pop(sheet, e.key)),
                    ],
                  ),
                ),
              );
              if (picked != null) onSelected(picked);
            },
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.row});

  final Map<String, dynamic> row;

  static IconData iconFor(String? action) => switch (action) {
        'created' => Icons.add_circle_outline,
        'updated' => Icons.edit_outlined,
        'deleted' => Icons.delete_outline,
        'login' => Icons.login,
        'logout' => Icons.logout,
        'login_failed' => Icons.lock_outline,
        _ => Icons.history,
      };

  @override
  Widget build(BuildContext context) {
    final flagged = row['flagged'] == true;
    final who = [row['user_name'], titleCase('${row['user_role'] ?? ''}')].where((s) => s != null && '$s'.isNotEmpty).join(' · ');

    return Card(
      color: flagged ? const Color(0xFFFEF2F2) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _LogDetail(row: row),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconFor('${row['action']}'), color: flagged ? _red : kMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['description']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (flagged && row['flag_reason'] != null) ...[
                      const SizedBox(height: 3),
                      Text('${row['flag_reason']}', style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '$who · ${formatDate(row['created_at'], withTime: true)} · ${titleCase('${row['source'] ?? ''}')}',
                      style: const TextStyle(color: kFaint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  const _LogDetail({required this.row});

  final Map<String, dynamic> row;

  static String _value(dynamic v) {
    if (v == null || '$v'.isEmpty) return '—';
    if (v is num) return formatNumber(v);
    final n = num.tryParse('$v');
    return n != null ? formatNumber(n) : '$v';
  }

  @override
  Widget build(BuildContext context) {
    final changes = row['changes'] is Map ? Map<String, dynamic>.from(row['changes'] as Map) : <String, dynamic>{};
    final updated = row['action'] == 'updated';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${row['description']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if (row['flagged'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: _red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${row['flag_reason']}', style: const TextStyle(color: _red, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            InfoRow('Who', '${row['user_name'] ?? 'System'}'),
            InfoRow('Role', titleCase('${row['user_role'] ?? ''}')),
            InfoRow('When', formatDate(row['created_at'], withTime: true)),
            InfoRow('From', titleCase('${row['source'] ?? ''}')),
            InfoRow('IP address', row['ip_address']?.toString()),
            InfoRow('During', titleCase(row['context']?.toString())),
            if (changes.isNotEmpty) ...[
              const Divider(height: 24),
              Text(updated ? 'What changed' : (row['action'] == 'deleted' ? 'Record before deletion' : 'Details'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              for (final e in changes.entries)
                Builder(builder: (context) {
                  final pair = e.value is List ? e.value as List : [null, e.value];
                  final old = pair.isNotEmpty ? pair[0] : null;
                  final now = pair.length > 1 ? pair[1] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 120, child: Text(titleCase(e.key), style: const TextStyle(color: kMuted))),
                        Expanded(
                          child: updated
                              ? Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: _value(old), style: const TextStyle(color: _red, decoration: TextDecoration.lineThrough)),
                                    const TextSpan(text: '  →  '),
                                    TextSpan(text: _value(now), style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w800)),
                                  ]),
                                  textAlign: TextAlign.right,
                                )
                              : Text(_value(now ?? old), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
