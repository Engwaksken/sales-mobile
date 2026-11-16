import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import 'filter_bar.dart';

import '../core/app_theme.dart';

// Colours come from the theme (light or dark): see AppColors in core/app_theme.dart.

/// Lets a parent screen reload a [PagedList] (after creating or editing a record).
class PagedListController {
  VoidCallback? _reload;

  void reload() => _reload?.call();
}

/// A searchable, pull-to-refresh, load-more list backed by a paginated API
/// endpoint that returns `{data: [...], meta: {current_page, last_page}}`.
///
/// Search and [filters] sit in a [FilterBar] pinned above the list. The
/// screen keeps [filterValues] and maps them into [query] itself.
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.path,
    required this.itemBuilder,
    this.query = const {},
    this.controller,
    this.searchHint = 'Search...',
    this.header,
    this.emptyText = 'Nothing here yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.searchable = true,
    this.bottomPadding = 88,
    this.filters = const [],
    this.filterValues = const {},
    this.onFiltersChanged,
    this.quickFilters = const [],
  });

  final String path;
  final Map<String, dynamic> query;
  final Widget Function(BuildContext context, Map<String, dynamic> row) itemBuilder;
  final PagedListController? controller;
  final String searchHint;
  final Widget? header;
  final String emptyText;
  final IconData emptyIcon;
  final bool searchable;

  /// Room left under the last row for a floating action button.
  final double bottomPadding;

  final List<FilterField> filters;
  final Map<String, Object?> filterValues;
  final ValueChanged<Map<String, Object?>>? onFiltersChanged;

  /// Ids of [filters] also offered as one-tap chips in the bar.
  final List<String> quickFilters;

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final search = TextEditingController();
  final scroll = ScrollController();
  Timer? debounce;
  List<Map<String, dynamic>> rows = [];
  int page = 1;
  int lastPage = 1;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._reload = load;
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 300) loadMore();
    });
    load();
  }

  @override
  void didUpdateWidget(covariant PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._reload = load;
    if (oldWidget.path != widget.path || !_sameQuery(oldWidget.query, widget.query)) load();
  }

  bool _sameQuery(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> _params(int pageNo) => {
        for (final entry in widget.query.entries)
          if (entry.value != null && '${entry.value}'.isNotEmpty) entry.key: entry.value,
        if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
        'page': pageNo,
      };

  Future<void> load() async {
    final api = context.read<ApiClient>();
    final mine = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get(widget.path, query: _params(1));
      if (!mounted || mine != generation) return;
      final data = response.data as Map;
      setState(() {
        rows = _rows(data['data']);
        page = 1;
        lastPage = int.tryParse('${(data['meta'] as Map?)?['last_page'] ?? 1}') ?? 1;
      });
    } catch (e) {
      if (!mounted || mine != generation) return;
      setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted && mine == generation) setState(() => loading = false);
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || page >= lastPage) return;
    final api = context.read<ApiClient>();
    final mine = generation;
    setState(() => loadingMore = true);
    try {
      final response = await api.get(widget.path, query: _params(page + 1));
      if (!mounted || mine != generation) return;
      setState(() {
        rows.addAll(_rows((response.data as Map)['data']));
        page++;
      });
    } catch (_) {
      // Scrolling again retries.
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic raw) =>
      raw is List ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];

  void onSearchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 450), load);
  }

  bool get _filtered =>
      search.text.trim().isNotEmpty || activeFilterCount(widget.filters, widget.filterValues) > 0;

  void clearFilters() {
    debounce?.cancel();
    final hadFilters = activeFilterCount(widget.filters, widget.filterValues) > 0;
    search.clear();
    if (hadFilters && widget.onFiltersChanged != null) {
      // The new query reloads the list (see didUpdateWidget).
      widget.onFiltersChanged!(resetFilterValues(widget.filters, widget.filterValues));
    } else {
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = RefreshIndicator(
      onRefresh: load,
      child: ListView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
        children: [
          if (widget.header != null) ...[widget.header!, const SizedBox(height: 10)],
          if (loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            ErrorState(message: error!, onRetry: load)
          else if (rows.isEmpty)
            _filtered
                ? FilteredEmptyState(onClear: clearFilters)
                : EmptyState(text: widget.emptyText, icon: widget.emptyIcon)
          else ...[
            for (final row in rows)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.itemBuilder(context, row)),
            if (loadingMore)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ],
      ),
    );

    if (!widget.searchable && widget.filters.isEmpty) return list;
    return Column(
      children: [
        FilterBar(
          filters: widget.filters,
          values: widget.filterValues,
          onChanged: widget.onFiltersChanged,
          quickFilters: widget.quickFilters,
          search: widget.searchable ? search : null,
          searchHint: widget.searchHint,
          onSearchChanged: onSearchChanged,
          onSearchSubmitted: (_) {
            debounce?.cancel();
            load();
          },
          onSearchCleared: () {
            debounce?.cancel();
            load();
          },
        ),
        Expanded(child: list),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.inbox_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: context.faint),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 44, color: context.faint),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Loads one JSON object and shows loading / error states around [builder].
class AsyncBody extends StatelessWidget {
  const AsyncBody({super.key, required this.loading, required this.error, required this.onRetry, required this.builder});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: ErrorState(message: error!, onRetry: onRetry));
    return builder(context);
  }
}

/// Coloured pill for statuses: paid, pending, completed, closed...
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});

  final String? status;
  final String? label;

  /// Background and text colours for [status]; softer, darker fills in dark mode.
  static (Color, Color) colorsFor(String? status, {bool dark = false}) {
    switch ((status ?? '').toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'successful':
      case 'active':
      case 'delivered':
      case 'open':
        return dark ? (const Color(0xFF12301F), const Color(0xFF86EFAC)) : (const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'partial':
      case 'processing':
      case 'confirmed':
      case 'ready_for_pickup':
      case 'ready_for_delivery':
      case 'out_for_delivery':
        return dark ? (const Color(0xFF172A4D), const Color(0xFF93C5FD)) : (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
      case 'pending':
      case 'credit':
        return dark ? (const Color(0xFF3A2A0C), const Color(0xFFFCD34D)) : (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case 'cancelled':
      case 'failed':
      case 'inactive':
      case 'closed':
        return dark ? (const Color(0xFF1E2B44), const Color(0xFF94A3B8)) : (const Color(0xFFF1F5F9), const Color(0xFF475569));
      default:
        return dark ? (const Color(0xFF1E2B44), const Color(0xFFCBD5E1)) : (const Color(0xFFF1F5F9), const Color(0xFF334155));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status, dark: context.isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label ?? titleCase(status),
        style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// A tappable list card: title, subtitle lines, optional trailing amount and pill.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.title,
    this.subtitle,
    this.caption,
    this.amount,
    this.status,
    this.statusLabel,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? caption;
  final String? amount;
  final String? status;
  final String? statusLabel;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 13)),
                    ],
                    if (caption != null && caption!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.faint, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (amount != null || status != null) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (amount != null) Text(amount!, style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (status != null) ...[const SizedBox(height: 6), StatusPill(status, label: statusLabel)],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Titled card used on detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Label on the left, value on the right; hidden when the value is empty.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String? value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: context.muted))),
          Expanded(
            child: Text(
              value!,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: context.ink),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmAction(BuildContext context, {required String title, required String message, String confirm = 'Confirm', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result == true;
}

/// Bottom sheet that searches an API list and returns the chosen row.
Future<Map<String, dynamic>?> pickRecord(
  BuildContext context, {
  required String title,
  required String path,
  required String Function(Map<String, dynamic> row) label,
  String Function(Map<String, dynamic> row)? sublabel,
  Map<String, dynamic> query = const {},
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ),
          Expanded(
            child: PagedList(
              path: path,
              query: query,
              bottomPadding: 24,
              searchHint: 'Search...',
              itemBuilder: (context, row) => RecordCard(
                title: label(row),
                subtitle: sublabel?.call(row),
                onTap: () => Navigator.pop(sheetContext, row),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Runs an API action with a spinner-safe flag, showing the server's message.
Future<T?> runApi<T>(BuildContext context, Future<T> Function(ApiClient api) action, {void Function(bool busy)? busy}) async {
  final api = context.read<ApiClient>();
  final messenger = ScaffoldMessenger.of(context);
  busy?.call(true);
  try {
    return await action(api);
  } catch (e) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(api.messageFromError(e)),
        // Solid red/green with white text reads well in both themes.
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
      ));
    return null;
  } finally {
    busy?.call(false);
  }
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF047857),
      behavior: SnackBarBehavior.floating,
    ));
}
