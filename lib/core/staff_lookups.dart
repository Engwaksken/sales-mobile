import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// An id/name pair from a pick-list.
class Option {
  const Option(this.id, this.name);

  final int id;
  final String name;

  static List<Option> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Option(int.tryParse('${m['id']}') ?? 0, '${m['name'] ?? ''}'))
        .toList();
  }
}

/// A key/label pair (order stages, stock issue types).
class KeyLabel {
  const KeyLabel(this.key, this.label);

  final String key;
  final String label;

  static List<KeyLabel> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => KeyLabel('${m['key']}', '${m['label']}')).toList();
  }
}

/// A unit stock can be counted in; [value] is what stock rows store (e.g. "pcs").
class UnitOption {
  const UnitOption(this.value, this.label, this.category);

  final String value;
  final String label;
  final String category;

  static List<UnitOption> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => UnitOption('${m['value']}', '${m['label']}', '${m['category'] ?? 'Other'}'))
        .toList();
  }
}

/// Branches, categories, suppliers, payment methods and stage names for staff forms.
/// Loaded once per sign-in from /staff/lookups and refreshed after catalog edits.
class StaffLookups extends ChangeNotifier {
  StaffLookups(this.api);

  final ApiClient api;

  bool loaded = false;
  bool isAdmin = false;
  int? branchId;
  List<Option> branches = const [];
  List<Option> categories = const [];
  List<Option> suppliers = const [];
  List<Option> expenseCategories = const [];
  List<UnitOption> unitTypes = const [];
  List<String> paymentMethods = const ['Cash', 'Mobile Money', 'Card', 'Bank Transfer', 'Cheque'];
  List<KeyLabel> orderStages = const [];
  List<KeyLabel> stockIssueTypes = const [];

  Future<void> load() async {
    try {
      final response = await api.get('/staff/lookups');
      final data = Map<String, dynamic>.from(response.data as Map);
      isAdmin = data['is_admin'] == true;
      branchId = int.tryParse('${data['branch_id']}');
      branches = Option.listFrom(data['branches']);
      categories = Option.listFrom(data['categories']);
      suppliers = Option.listFrom(data['suppliers']);
      expenseCategories = Option.listFrom(data['expense_categories']);
      unitTypes = UnitOption.listFrom(data['unit_types']);
      if (data['payment_methods'] is List) {
        paymentMethods = (data['payment_methods'] as List).map((m) => '$m').toList();
      }
      orderStages = KeyLabel.listFrom(data['order_stages']);
      stockIssueTypes = KeyLabel.listFrom(data['stock_issue_types']);
      loaded = true;
      notifyListeners();
    } catch (_) {
      // Forms fall back to sensible defaults; the next screen retries.
    }
  }

  Future<void> ensureLoaded() async {
    if (!loaded) await load();
  }

  String branchName(int? id) =>
      branches.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? '';

  String stageLabel(String? key) =>
      orderStages.where((s) => s.key == key).map((s) => s.label).firstOrNull ?? (key ?? '');
}
