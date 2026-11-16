import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/format.dart';
import 'package:nsales_native/widgets/filter_bar.dart';

const filters = <FilterField>[
  ChoiceFilter(
    id: 'status',
    label: 'Status',
    options: [FilterOption('paid', 'Paid'), FilterOption('pending', 'Credit')],
  ),
  ChoiceFilter(
    id: 'branch',
    label: 'Branch',
    icon: Icons.store_outlined,
    allLabel: 'All branches',
    options: [FilterOption('1', 'Main Street'), FilterOption('2', 'Kampala Road Wholesale and Retail Branch')],
    searchable: true,
  ),
  DateRangeFilter(id: 'date', label: 'Sale date'),
];

/// Hosts a [FilterBar] and remembers the values it applies.
class Host extends StatefulWidget {
  const Host({super.key, required this.initial, this.withSearch = true});

  final Map<String, Object?> initial;
  final bool withSearch;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late Map<String, Object?> values = widget.initial;
  int applied = 0;
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: Column(
        children: [
          FilterBar(
            filters: filters,
            values: values,
            quickFilters: const ['status'],
            search: widget.withSearch ? search : null,
            searchHint: 'Invoice, customer or product',
            onChanged: (v) => setState(() {
              values = v;
              applied++;
            }),
          ),
        ],
      ),
    );
  }
}

Future<HostState> pumpHost(WidgetTester tester, Map<String, Object?> initial, {double textScale = 1}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(720, 1280);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(MaterialApp(home: Host(initial: initial)));
  await tester.pumpAndSettle();
  return tester.state<HostState>(find.byType(Host));
}

String badge(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: find.byKey(const ValueKey('filter-bar-badge')), matching: find.byType(Text)))
    .data!;

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('filter-bar-button')));
  await tester.pumpAndSettle();
}

Future<void> apply(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('filter-sheet-apply')));
  await tester.pumpAndSettle();
}

Finder inSheet(Finder finder) => find.descendant(of: find.byType(FilterSheet), matching: finder);

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => filterClock = () => DateTime(2026, 11, 16, 9)); // a Monday
  tearDown(() => filterClock = DateTime.now);

  group('date presets', () {
    test('cover the expected days, weeks starting on Monday', () {
      final wed = DateTime(2026, 11, 18, 15);
      DateTimeRange r(int y, int m, int d, int y2, int m2, int d2) =>
          DateTimeRange(start: DateTime(y, m, d), end: DateTime(y2, m2, d2));
      expect(DatePreset.today.range(wed), r(2026, 11, 18, 2026, 11, 18));
      expect(DatePreset.yesterday.range(wed), r(2026, 11, 17, 2026, 11, 17));
      expect(DatePreset.thisWeek.range(wed), r(2026, 11, 16, 2026, 11, 18));
      expect(DatePreset.thisMonth.range(wed), r(2026, 11, 1, 2026, 11, 18));
      expect(DatePreset.lastMonth.range(wed), r(2026, 10, 1, 2026, 10, 31));
      expect(DatePreset.thisYear.range(wed), r(2026, 1, 1, 2026, 11, 18));
      expect(DatePreset.lastMonth.range(DateTime(2027, 1, 5)), r(2026, 12, 1, 2026, 12, 31));
      expect(DatePreset.yesterday.range(DateTime(2026, 3, 1)), r(2026, 2, 28, 2026, 2, 28));
    });

    test('ranges read naturally', () {
      expect(formatDateRange(DateTime(2026, 11, 16), DateTime(2026, 11, 16)), '16 Nov 2026');
      expect(formatDateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 15)), '1 Nov – 15 Nov 2026');
      expect(formatDateRange(DateTime(2025, 12, 20), DateTime(2026, 1, 5)), '20 Dec 2025 – 5 Jan 2026');
      const date = DateRangeFilter(id: 'date', label: 'Date');
      expect(date.describe(DatePreset.thisMonth.range()), 'This month');
      expect(date.describe(DateTimeRange(start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 9))), '2 Nov – 9 Nov 2026');
    });
  });

  testWidgets('badge counts every active filter; chips remove one, Clear all removes all', (tester) async {
    final host = await pumpHost(tester, {'status': 'paid', 'branch': '2', 'date': DatePreset.thisMonth.range()});

    expect(badge(tester), '3');
    expect(find.bySemanticsLabel('Filters, 3 active'), findsOneWidget);
    // The quick filter shows as a selected pill, the others as removable chips.
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Paid')).selected, isTrue);
    expect(find.byKey(const ValueKey('active-filter-status')), findsNothing);
    expect(find.text('Branch: Kampala Road Wholesale and Retail Branch'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('active-filter-branch')), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(host.values['branch'], isNull);
    expect(host.values['status'], 'paid');
    expect(badge(tester), '2');
    expect(find.byKey(const ValueKey('active-filter-branch')), findsNothing);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(host.values, {'status': null, 'branch': null, 'date': null});
    expect(find.byKey(const ValueKey('filter-bar-badge')), findsNothing);
    expect(find.text('Clear all'), findsNothing);
    expect(find.bySemanticsLabel('Filters'), findsOneWidget);
  });

  testWidgets('quick filters apply at once', (tester) async {
    final host = await pumpHost(tester, {});
    expect(find.text('Clear all'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Credit'));
    await tester.pumpAndSettle();
    expect(host.values['status'], 'pending');
    expect(badge(tester), '1');

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(host.values['status'], isNull);
  });

  testWidgets('the sheet edits a draft that applies only on Show results', (tester) async {
    final host = await pumpHost(tester, {'status': 'paid'});

    await openSheet(tester);
    expect(inSheet(find.text('Filters')), findsOneWidget);
    expect(inSheet(find.text('Status')), findsOneWidget);
    expect(inSheet(find.text('Branch')), findsOneWidget);
    expect(inSheet(find.text('Sale date')), findsOneWidget);

    await tester.tap(inSheet(find.text('Credit')));
    await tester.pumpAndSettle();
    expect(host.values['status'], 'paid', reason: 'nothing applies before the button');

    // Dismissing throws the draft away.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(FilterSheet), findsNothing);
    expect(host.applied, 0);

    await openSheet(tester);
    await tapVisible(tester, inSheet(find.text('Credit')));
    await tapVisible(tester, inSheet(find.text('Last month')));
    expect(inSheet(find.text('1 Oct – 31 Oct 2026')), findsOneWidget);

    // A searchable picker for the many-valued filter.
    await tapVisible(tester, inSheet(find.text('All branches')));
    await tester.enterText(find.widgetWithText(TextField, 'Search branch'), 'kam');
    await tester.pumpAndSettle();
    expect(find.text('Main Street'), findsNothing);
    await tester.tap(find.text('Kampala Road Wholesale and Retail Branch'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Kampala Road Wholesale and Retail Branch')), findsOneWidget);

    await apply(tester);
    expect(find.byType(FilterSheet), findsNothing);
    expect(host.applied, 1);
    expect(host.values['status'], 'pending');
    expect(host.values['branch'], '2');
    expect(host.values['date'], DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31)));
    expect(badge(tester), '3');
    expect(find.text('Last month'), findsOneWidget);
  });

  testWidgets('Reset clears the draft, keeping it until applied', (tester) async {
    final host = await pumpHost(tester, {'status': 'paid', 'branch': '1'});

    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('filter-sheet-reset')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('All branches')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('filter-sheet-reset'))).onPressed, isNull);
    expect(host.values['status'], 'paid');

    await apply(tester);
    expect(host.values, {'status': null, 'branch': null, 'date': null});
  });

  testWidgets('a range with a default only counts once changed, and resets to it', (tester) async {
    final thisMonth = DatePreset.thisMonth.range();
    Map<String, Object?> values = {'period': thisMonth};
    late StateSetter update;
    final period = DateRangeFilter(id: 'period', label: 'Period', initialRange: thisMonth);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return FilterBar(
            filters: [period],
            values: values,
            quickFilters: const ['period'],
            onChanged: (v) => update(() => values = v),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Any time'), findsNothing, reason: 'a report always has a period');
    expect(find.byKey(const ValueKey('filter-bar-badge')), findsNothing);
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Today'));
    expect(badge(tester), '1');

    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('filter-sheet-reset')));
    await apply(tester);
    expect(values['period'], thisMonth);
  });

  testWidgets('nothing overflows at 360 x 640 with text scale 1.3', (tester) async {
    await pumpHost(tester, {'status': 'pending', 'branch': '2', 'date': DateTimeRange(start: DateTime(2025, 12, 20), end: DateTime(2026, 1, 5))},
        textScale: 1.3);
    expect(tester.takeException(), isNull);

    await openSheet(tester);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, inSheet(find.text('Kampala Road Wholesale and Retail Branch')));
    expect(tester.takeException(), isNull);
    expect(find.text('Search branch'), findsOneWidget);

    // Tap targets stay at least 48px.
    expect(tester.getSize(find.byKey(const ValueKey('filter-bar-button'))).height, greaterThanOrEqualTo(48));
  });
}
