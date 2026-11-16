import 'package:flutter/material.dart';

import '../core/format.dart';

import '../core/app_theme.dart';
/// The app's one filter pattern: a compact bar under the app bar (search,
/// quick filters and a "Filters" button with a badge), removable chips for
/// the filters in use, and a bottom sheet holding the full set.
///
/// Screens describe their filters with [FilterField]s and keep the chosen
/// values in a `Map<String, Object?>` keyed by [FilterField.id]; they turn
/// those values into API query parameters themselves.

/// Today's date. Tests replace it to get fixed date presets.
@visibleForTesting
DateTime Function() filterClock = DateTime.now;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [range] with the times dropped, so ranges compare by calendar day.
DateTimeRange dateOnlyRange(DateTimeRange range) => DateTimeRange(start: _day(range.start), end: _day(range.end));

/// Ready-made date ranges offered before "Custom".
enum DatePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year');

  const DatePreset(this.label);

  final String label;

  /// The range this preset stands for, ending today for the "This ..." ones.
  /// Weeks start on Monday.
  DateTimeRange range([DateTime? now]) {
    final t = _day(now ?? filterClock());
    return switch (this) {
      DatePreset.today => DateTimeRange(start: t, end: t),
      DatePreset.yesterday => DateTimeRange(
        start: DateTime(t.year, t.month, t.day - 1),
        end: DateTime(t.year, t.month, t.day - 1),
      ),
      DatePreset.thisWeek => DateTimeRange(start: DateTime(t.year, t.month, t.day - (t.weekday - 1)), end: t),
      DatePreset.thisMonth => DateTimeRange(start: DateTime(t.year, t.month), end: t),
      DatePreset.lastMonth => DateTimeRange(start: DateTime(t.year, t.month - 1), end: DateTime(t.year, t.month, 0)),
      DatePreset.thisYear => DateTimeRange(start: DateTime(t.year), end: t),
    };
  }

  /// The preset whose range is exactly [range], if any.
  static DatePreset? matching(DateTimeRange? range) {
    if (range == null) return null;
    final r = dateOnlyRange(range);
    return DatePreset.values.where((p) => p.range() == r).firstOrNull;
  }
}

/// One value of a [ChoiceFilter].
class FilterOption {
  const FilterOption(this.value, this.label);

  final String value;
  final String label;
}

/// One filter a screen offers.
sealed class FilterField {
  const FilterField({required this.id, required this.label, this.icon});

  /// Key of this filter's value in the values map.
  final String id;

  /// Section title in the sheet, e.g. "Branch".
  final String label;
  final IconData? icon;

  /// The value meaning "not filtering"; Reset and Clear all go back to it.
  Object? get defaultValue;

  bool isActive(Object? value) => value != defaultValue;

  /// Text for the active-filter chip, e.g. "Branch: Main".
  String describe(Object? value);
}

/// Pick one of [options], or none ("All"). Few options show as chips, many
/// ([searchable], or more than six) as a searchable list.
class ChoiceFilter extends FilterField {
  const ChoiceFilter({
    required super.id,
    required super.label,
    required this.options,
    super.icon,
    this.allLabel = 'All',
    this.searchable,
  });

  final List<FilterOption> options;
  final String allLabel;
  final bool? searchable;

  bool get usesPicker => searchable ?? options.length > 6;

  @override
  Object? get defaultValue => null;

  String optionLabel(Object? value) {
    if (value == null) return allLabel;
    return options.where((o) => o.value == value).map((o) => o.label).firstOrNull ?? titleCase('$value');
  }

  @override
  String describe(Object? value) => '$label: ${optionLabel(value)}';
}

/// An on/off filter such as "Low stock only".
class ToggleFilter extends FilterField {
  const ToggleFilter({required super.id, required super.label, super.icon, this.description});

  final String? description;

  @override
  Object? get defaultValue => false;

  @override
  bool isActive(Object? value) => value == true;

  @override
  String describe(Object? value) => label;
}

/// A from/to date range with presets. With an [initialRange] the filter always
/// has a range (Reset returns to it); without one, "Any time" means no range.
class DateRangeFilter extends FilterField {
  const DateRangeFilter({
    required super.id,
    required super.label,
    super.icon = Icons.event_outlined,
    this.initialRange,
    this.presets = DatePreset.values,
  });

  final DateTimeRange? initialRange;
  final List<DatePreset> presets;

  bool get clearable => initialRange == null;

  @override
  Object? get defaultValue => initialRange;

  @override
  bool isActive(Object? value) {
    final range = value as DateTimeRange?;
    final initial = initialRange;
    if (range == null || initial == null) return range != initial;
    return dateOnlyRange(range) != dateOnlyRange(initial);
  }

  @override
  String describe(Object? value) {
    final range = value as DateTimeRange?;
    if (range == null) return 'Any time';
    return DatePreset.matching(range)?.label ?? formatDateRange(range.start, range.end);
  }

  /// The dates written out, e.g. "1 Nov – 16 Nov 2026".
  String describeDates(Object? value) {
    final range = value as DateTimeRange?;
    return range == null ? 'Any time' : formatDateRange(range.start, range.end);
  }
}

/// How many of [filters] differ from their default in [values].
int activeFilterCount(List<FilterField> filters, Map<String, Object?> values) =>
    filters.where((f) => f.isActive(values[f.id])).length;

/// [values] with every one of [filters] back at its default.
Map<String, Object?> resetFilterValues(List<FilterField> filters, Map<String, Object?> values) => {
  ...values,
  for (final f in filters) f.id: f.defaultValue,
};

/// Opens the date range picker for a "Custom" range.
Future<DateTimeRange?> pickCustomDateRange(BuildContext context, DateRangeFilter filter, DateTimeRange? current) async {
  final today = _day(filterClock());
  var first = DateTime(today.year - 5);
  var last = today;
  if (current != null && current.start.isBefore(first)) first = _day(current.start);
  if (current != null && current.end.isAfter(last)) last = _day(current.end);
  final picked = await showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: current == null ? null : dateOnlyRange(current),
    helpText: filter.label,
    saveText: 'Done',
  );
  return picked == null ? null : dateOnlyRange(picked);
}

/// The bar under the app bar. Give it [search] when the screen can search.
/// [quickFilters] are ids of filters also shown as one-tap chips.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    this.filters = const [],
    this.values = const {},
    this.onChanged,
    this.quickFilters = const [],
    this.search,
    this.searchHint = 'Search',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchCleared,
  });

  final List<FilterField> filters;
  final Map<String, Object?> values;
  final ValueChanged<Map<String, Object?>>? onChanged;
  final List<String> quickFilters;
  final TextEditingController? search;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchCleared;

  void _set(String id, Object? value) => onChanged?.call({...values, id: value});

  Future<void> _openSheet(BuildContext context) async {
    final result = await showFilterSheet(context, filters: filters, values: values);
    if (result != null) onChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = search != null;
    if (!hasSearch && filters.isEmpty) return const SizedBox.shrink();

    final quick = [for (final id in quickFilters) ...filters.where((f) => f.id == id)];
    final active = [
      for (final f in filters)
        if (f.isActive(values[f.id])) f,
    ];
    // A quick filter's choice already shows as a selected pill, so only the
    // others get a removable chip. The badge still counts every filter.
    final removable = [
      for (final f in active)
        if (!quick.contains(f) || !_shownAsPill(f, values[f.id])) f,
    ];
    final button = filters.isEmpty ? null : _FiltersButton(count: active.length, onPressed: () => _openSheet(context));

    final rows = <Widget>[
      if (hasSearch)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: search!,
                  hint: searchHint,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  onCleared: onSearchCleared,
                ),
              ),
              if (button != null) ...[const SizedBox(width: 8), button],
            ],
          ),
        ),
      if (quick.isNotEmpty)
        hasSearch || button == null
            ? _QuickRow(filters: quick, values: values, onSet: _set)
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickRow(filters: quick, values: values, onSet: _set),
                    ),
                    Padding(padding: const EdgeInsets.only(left: 4, right: 16), child: button),
                  ],
                ),
              )
      else if (!hasSearch && button != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(alignment: Alignment.centerRight, child: button),
        ),
      if (removable.isNotEmpty)
        _ActiveRow(
          filters: removable,
          values: values,
          onRemove: (f) => _set(f.id, f.defaultValue),
          onClearAll: () => onChanged?.call(resetFilterValues(filters, values)),
          onOpen: () => _openSheet(context),
        ),
    ];
    // Chip rows carry their own breathing room (48px tap targets).
    final endsWithChips = removable.isNotEmpty || quick.isNotEmpty;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: endsWithChips ? 2 : 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      ),
    );
  }
}

/// Whether [value] is visible as a selected quick pill. Custom date ranges
/// and values missing from the options (lookups still loading) are not.
bool _shownAsPill(FilterField f, Object? value) => switch (f) {
  ChoiceFilter() => value == null || f.options.any((o) => o.value == value),
  ToggleFilter() => true,
  DateRangeFilter() => value == null || DatePreset.matching(value as DateTimeRange) != null,
};

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, this.onChanged, this.onSubmitted, this.onCleared});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 15, color: context.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 1,
          isDense: true,
          filled: true,
          fillColor: context.fieldFill,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          prefixIcon: Icon(Icons.search, color: context.muted, size: 22),
          border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close, size: 20, color: context.muted),
                  onPressed: () {
                    controller.clear();
                    onCleared?.call();
                  },
                ),
        ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = count > 0;
    return Semantics(
      button: true,
      label: active ? 'Filters, $count active' : 'Filters',
      excludeSemantics: true,
      child: OutlinedButton(
        key: const ValueKey('filter-bar-button'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: active ? colors.primary : context.ink,
          backgroundColor: active ? colors.primary.withValues(alpha: 0.08) : null,
          side: BorderSide(color: active ? colors.primary : context.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 20),
            const SizedBox(width: 6),
            const Text('Filters'),
            if (active) ...[const SizedBox(width: 6), _CountBadge(count: count)],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('filter-bar-badge'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$count',
        style: TextStyle(color: colors.onPrimary, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// A pill chip in the app's filter style.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onSelected, this.icon});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? colors.primary : context.muted),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: TextStyle(
        fontSize: 13.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? colors.primary : context.ink,
      ),
      backgroundColor: colors.surfaceContainerLowest,
      selectedColor: colors.primary.withValues(alpha: 0.12),
      side: BorderSide(color: selected ? colors.primary : context.hairline),
      shape: const StadiumBorder(),
    );
  }
}

/// Every choice of a [FilterField] as pills (used in the bar and the sheet).
List<Widget> _choicePills(BuildContext context, FilterField f, Object? value, void Function(Object? value) onSet) {
  switch (f) {
    case ChoiceFilter():
      return [
        FilterPill(label: f.allLabel, selected: value == null, onSelected: (_) => onSet(null)),
        for (final o in f.options)
          FilterPill(label: o.label, selected: value == o.value, onSelected: (_) => onSet(o.value)),
      ];
    case ToggleFilter():
      return [FilterPill(label: f.label, icon: f.icon, selected: value == true, onSelected: (on) => onSet(on))];
    case DateRangeFilter():
      final range = value as DateTimeRange?;
      final preset = DatePreset.matching(range);
      return [
        if (f.clearable) FilterPill(label: 'Any time', selected: range == null, onSelected: (_) => onSet(null)),
        for (final p in f.presets)
          FilterPill(label: p.label, selected: preset == p, onSelected: (_) => onSet(p.range())),
        FilterPill(
          label: 'Custom',
          icon: Icons.date_range,
          selected: range != null && preset == null,
          onSelected: (_) async {
            final picked = await pickCustomDateRange(context, f, range);
            if (picked != null) onSet(picked);
          },
        ),
      ];
  }
}

class _QuickRow extends StatefulWidget {
  const _QuickRow({required this.filters, required this.values, required this.onSet});

  final List<FilterField> filters;
  final Map<String, Object?> values;
  final void Function(String id, Object? value) onSet;

  @override
  State<_QuickRow> createState() => _QuickRowState();
}

class _QuickRowState extends State<_QuickRow> {
  final selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Starting filters (e.g. "Last month") may sit past the screen edge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = selectedKey.currentContext;
      if (mounted && target != null) Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var keyed = false;
    for (final f in widget.filters) {
      if (children.isNotEmpty) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: VerticalDivider(width: 1, color: context.hairline),
          ),
        );
      }
      for (final pill in _choicePills(context, f, widget.values[f.id], (v) => widget.onSet(f.id, v))) {
        final select = !keyed && pill is FilterPill && pill.selected;
        keyed = keyed || select;
        children.add(Padding(key: select ? selectedKey : null, padding: const EdgeInsets.only(right: 8), child: pill));
      }
    }
    return _FadeEnd(
      child: SizedBox(
        height: _rowHeight(context),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Row(children: children),
        ),
      ),
    );
  }
}

/// Fades the right edge of a horizontal chip row, hinting that it scrolls.
class _FadeEnd extends StatelessWidget {
  const _FadeEnd({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: [0, rect.width <= 28 ? 0 : 1 - 20 / rect.width, 1],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Room for one row of chips, growing with the text size.
double _rowHeight(BuildContext context) => 48 + 14 * (MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(0, 2);

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.filters,
    required this.values,
    required this.onRemove,
    required this.onClearAll,
    required this.onOpen,
  });

  final List<FilterField> filters;
  final Map<String, Object?> values;
  final ValueChanged<FilterField> onRemove;
  final VoidCallback onClearAll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep each chip's remove button on screen: the label gets what
              // is left after the padding, icon and remove button.
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final labelMax = (constraints.maxWidth - 28 - 96 * scale).clamp(64.0, 200.0);
              return _FadeEnd(
                child: SizedBox(
                  height: _rowHeight(context),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    children: [
                      for (final f in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            key: ValueKey('active-filter-${f.id}'),
                            avatar: f.icon == null ? null : Icon(f.icon, size: 16, color: colors.primary),
                            label: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: labelMax),
                              child: Text(f.describe(values[f.id]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary),
                            backgroundColor: colors.primary.withValues(alpha: 0.08),
                            side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
                            shape: const StadiumBorder(),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            deleteIconColor: colors.primary,
                            deleteButtonTooltipMessage: 'Remove ${f.label} filter',
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            onPressed: onOpen,
                            onDeleted: () => onRemove(f),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Clear all', style: TextStyle(fontWeight: FontWeight.w700), maxLines: 1),
          ),
        ),
      ],
    );
  }
}

/// Opens the full filter set. Returns the new values when the person taps
/// "Show results", or null when they dismiss the sheet.
Future<Map<String, Object?>?> showFilterSheet(
  BuildContext context, {
  required List<FilterField> filters,
  required Map<String, Object?> values,
  String title = 'Filters',
  String applyLabel = 'Show results',
}) {
  return showModalBottomSheet<Map<String, Object?>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (_) => FilterSheet(filters: filters, values: values, title: title, applyLabel: applyLabel),
  );
}

/// The body of [showFilterSheet]: edits a draft that only applies on the button.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.filters,
    required this.values,
    this.title = 'Filters',
    this.applyLabel = 'Show results',
  });

  final List<FilterField> filters;
  final Map<String, Object?> values;
  final String title;
  final String applyLabel;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Map<String, Object?> draft = {...widget.values};

  void _set(String id, Object? value) => setState(() => draft[id] = value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canReset = activeFilterCount(widget.filters, draft) > 0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: context.ink),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('filter-sheet-reset'),
                  onPressed: canReset ? () => setState(() => draft = resetFilterValues(widget.filters, draft)) : null,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.hairline),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [
                for (final f in widget.filters)
                  Padding(padding: const EdgeInsets.only(bottom: 22), child: _section(context, f)),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border(top: BorderSide(color: context.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  key: const ValueKey('filter-sheet-apply'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.pop(context, draft),
                  child: Text(widget.applyLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, FilterField f) {
    final value = draft[f.id];
    void set(Object? v) => _set(f.id, v);

    if (f is ToggleFilter) {
      return Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value == true,
          onChanged: set,
          title: Text(
            f.label,
            style: TextStyle(fontWeight: FontWeight.w700, color: context.ink),
          ),
          subtitle: f.description == null
              ? null
              : Text(f.description!, style: TextStyle(color: context.muted, fontSize: 13)),
        ),
      );
    }

    final Widget body;
    if (f is ChoiceFilter && f.usesPicker) {
      body = _PickerField(
        icon: f.icon ?? Icons.list,
        text: f.optionLabel(value),
        placeholder: value == null,
        semanticLabel: '${f.label}: ${f.optionLabel(value)}',
        onTap: () async {
          final picked = await _pickOption(context, f, value);
          if (picked != null) set(picked.value);
        },
      );
    } else if (f is DateRangeFilter) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 8, runSpacing: 2, children: _choicePills(context, f, value, set)),
          const SizedBox(height: 10),
          Semantics(
            label: 'Selected dates: ${f.describeDates(value)}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.event_note_outlined, size: 20, color: context.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.describeDates(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      body = Wrap(spacing: 8, runSpacing: 2, children: _choicePills(context, f, value, set));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          f.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.ink),
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}

/// A tappable field showing the chosen option; opens the searchable list.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.text,
    required this.placeholder,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final bool placeholder;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: context.fieldFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: context.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
                        color: placeholder ? context.muted : context.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: context.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The result of [_pickOption]; [value] null means "All".
class _Picked {
  const _Picked(this.value);

  final String? value;
}

Future<_Picked?> _pickOption(BuildContext context, ChoiceFilter f, Object? current) {
  return showModalBottomSheet<_Picked>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (_) => _OptionPicker(filter: f, current: current),
  );
}

class _OptionPicker extends StatefulWidget {
  const _OptionPicker({required this.filter, required this.current});

  final ChoiceFilter filter;
  final Object? current;

  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    final colors = Theme.of(context).colorScheme;
    final needle = search.text.trim().toLowerCase();
    final options = needle.isEmpty
        ? f.options
        : f.options.where((o) => o.label.toLowerCase().contains(needle)).toList();

    Widget tile(String label, String? value) {
      final selected = widget.current == value;
      return ListTile(
        minTileHeight: 52,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.primary : context.ink,
          ),
        ),
        trailing: selected ? Icon(Icons.check, color: colors.primary, semanticLabel: 'Selected') : null,
        onTap: () => Navigator.pop(context, _Picked(value)),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              f.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: context.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _SearchField(
              controller: search,
              hint: 'Search ${f.label.toLowerCase()}',
              onChanged: (_) => setState(() {}),
              onCleared: () => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (needle.isEmpty) tile(f.allLabel, null),
                for (final o in options) tile(o.label, o.value),
                if (options.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'No matches.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.muted),
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

/// Shown when a filtered list comes back empty.
class FilteredEmptyState extends StatelessWidget {
  const FilteredEmptyState({
    super.key,
    required this.onClear,
    this.message = 'No results match these filters',
    this.hint = 'Try changing or clearing them to see more.',
    this.clearLabel = 'Clear filters',
  });

  final VoidCallback onClear;
  final String message;
  final String hint;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: context.fieldFill, shape: BoxShape.circle),
            child: Icon(Icons.filter_alt_off_outlined, size: 30, color: context.faint),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.ink),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: Text(clearLabel),
          ),
        ],
      ),
    );
  }
}
