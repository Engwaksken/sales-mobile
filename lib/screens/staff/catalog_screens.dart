import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/staff_lookups.dart';
import '../../widgets/staff_ui.dart';

enum FieldKind { text, email, phone, multiline, status, toggle, choice }

class CatalogField {
  const CatalogField(this.key, this.label, {this.kind = FieldKind.text, this.required = false, this.options = const []});

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;

  /// Values for [FieldKind.choice]; the first is the default.
  final List<String> options;
}

/// How one simple master-data module is listed and edited.
class CatalogConfig {
  const CatalogConfig({
    required this.resource,
    required this.singular,
    required this.plural,
    required this.icon,
    required this.fields,
    required this.title,
    required this.subtitle,
    this.status,
    this.refreshesLookups = false,
  });

  final String resource;
  final String singular;
  final String plural;
  final IconData icon;
  final List<CatalogField> fields;
  final String Function(Map<String, dynamic> row) title;
  final String Function(Map<String, dynamic> row) subtitle;
  final String? Function(Map<String, dynamic> row)? status;

  /// Categories, suppliers and expense categories appear in other forms' pick-lists.
  final bool refreshesLookups;

  static String _join(List<dynamic> parts) => parts.where((p) => p != null && '$p'.isNotEmpty).join(' · ');

  static final categories = CatalogConfig(
    resource: 'categories',
    singular: 'Category',
    plural: 'categories',
    icon: Icons.sell_outlined,
    refreshesLookups: true,
    fields: const [
      CatalogField('category_name', 'Name', required: true),
      CatalogField('description', 'Description', kind: FieldKind.multiline),
      CatalogField('status', 'Status', kind: FieldKind.status, required: true),
    ],
    title: (r) => '${r['category_name'] ?? r['name']}',
    subtitle: (r) => '${r['description'] ?? ''}',
    status: (r) => '${r['status']}',
  );

  static final customers = CatalogConfig(
    resource: 'customers',
    singular: 'Customer',
    plural: 'customers',
    icon: Icons.people_outline,
    fields: const [
      CatalogField('name', 'Name', required: true),
      CatalogField('phone', 'Phone', kind: FieldKind.phone),
      CatalogField('email', 'Email', kind: FieldKind.email),
      CatalogField('address', 'Address', kind: FieldKind.multiline),
    ],
    title: (r) => '${r['name'] ?? 'Customer #${r['id']}'}',
    subtitle: (r) => _join([r['phone'], r['email']]),
  );

  static final suppliers = CatalogConfig(
    resource: 'suppliers',
    singular: 'Supplier',
    plural: 'suppliers',
    icon: Icons.local_shipping_outlined,
    refreshesLookups: true,
    fields: const [
      CatalogField('name', 'Company name', required: true),
      CatalogField('contact_name', 'Contact person', required: true),
      CatalogField('phone', 'Phone', kind: FieldKind.phone),
      CatalogField('email', 'Email', kind: FieldKind.email),
      CatalogField('address', 'Address', kind: FieldKind.multiline),
      CatalogField('status', 'Status', kind: FieldKind.status, required: true),
    ],
    title: (r) => '${r['name']}',
    subtitle: (r) => _join([r['contact_name'], r['phone']]),
    status: (r) => '${r['status']}',
  );

  static final unitTypes = CatalogConfig(
    resource: 'unit-types',
    singular: 'Unit',
    plural: 'units',
    icon: Icons.straighten,
    refreshesLookups: true,
    fields: const [
      CatalogField('name', 'Name', required: true),
      CatalogField('abbreviation', 'Short name (shown on stock)', required: true),
      CatalogField('category', 'Group', kind: FieldKind.choice, options: ['Count', 'Weight', 'Volume', 'Length', 'Area', 'Other']),
      CatalogField('is_active', 'Show in stock forms', kind: FieldKind.toggle),
    ],
    title: (r) => '${r['name']} (${r['abbreviation']})',
    subtitle: (r) => '${r['category'] ?? ''}',
    status: (r) => r['is_active'] == true ? 'active' : 'inactive',
  );

  static final expenseCategories = CatalogConfig(
    resource: 'expense-categories',
    singular: 'Expense category',
    plural: 'expense categories',
    icon: Icons.category_outlined,
    refreshesLookups: true,
    fields: const [
      CatalogField('name', 'Name', required: true),
      CatalogField('status', 'Active', kind: FieldKind.toggle),
    ],
    title: (r) => '${r['name']}',
    subtitle: (r) => '',
    status: (r) => r['status'] == true ? 'active' : 'inactive',
  );
}

/// List + add/edit/delete for one [CatalogConfig].
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.config});

  final CatalogConfig config;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final list = PagedListController();

  Future<void> open([Map<String, dynamic>? row]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CatalogFormScreen(config: widget.config, record: row)),
    );
    if (saved == true) list.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-${c.resource}',
        onPressed: open,
        icon: const Icon(Icons.add),
        label: Text('Add ${c.singular.toLowerCase()}'),
      ),
      body: PagedList(
        path: '/staff/catalog/${c.resource}',
        controller: list,
        searchHint: 'Search ${c.plural}',
        emptyText: 'No ${c.plural} yet.',
        emptyIcon: c.icon,
        itemBuilder: (context, row) => RecordCard(
          leading: CircleAvatar(child: Icon(c.icon, size: 18)),
          title: c.title(row),
          subtitle: c.subtitle(row),
          status: c.status?.call(row),
          onTap: () => open(row),
        ),
      ),
    );
  }
}

class CatalogFormScreen extends StatefulWidget {
  const CatalogFormScreen({super.key, required this.config, this.record});

  final CatalogConfig config;
  final Map<String, dynamic>? record;

  @override
  State<CatalogFormScreen> createState() => _CatalogFormScreenState();
}

class _CatalogFormScreenState extends State<CatalogFormScreen> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> text = {
    for (final f in widget.config.fields)
      if (f.kind != FieldKind.status && f.kind != FieldKind.toggle && f.kind != FieldKind.choice)
        f.key: TextEditingController(text: '${widget.record?[f.key] ?? ''}'),
  };
  late final Map<String, dynamic> choice = {
    for (final f in widget.config.fields)
      if (f.kind == FieldKind.status) f.key: '${widget.record?[f.key] ?? 'active'}'
      else if (f.kind == FieldKind.toggle) f.key: widget.record?[f.key] ?? true
      else if (f.kind == FieldKind.choice)
        f.key: f.options.contains(widget.record?[f.key]) ? widget.record![f.key] : f.options.first,
  };
  bool saving = false;

  bool get editing => widget.record != null;

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final c = widget.config;
    final body = {
      for (final e in text.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      ...choice,
    };
    final path = '/staff/catalog/${c.resource}${editing ? '/${widget.record!['id']}' : ''}';
    final lookups = context.read<StaffLookups>();

    final result = await runApi(
      context,
      (api) => editing ? api.put(path, data: body) : api.post(path, data: body),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    if (c.refreshesLookups) lookups.load();
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Saved.'}');
    Navigator.pop(context, true);
  }

  Future<void> delete() async {
    final c = widget.config;
    if (!await confirmAction(context, title: 'Delete ${c.singular.toLowerCase()}?', message: 'This cannot be undone.', confirm: 'Delete', destructive: true)) {
      return;
    }
    if (!mounted) return;
    final lookups = context.read<StaffLookups>();
    final result = await runApi(
      context,
      (api) => api.delete('/staff/catalog/${c.resource}/${widget.record!['id']}'),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    if (c.refreshesLookups) lookups.load();
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Deleted.'}');
    Navigator.pop(context, true);
  }

  Widget field(CatalogField f) {
    switch (f.kind) {
      case FieldKind.status:
        return DropdownButtonFormField<String>(
          initialValue: choice[f.key] == 'inactive' ? 'inactive' : 'active',
          decoration: InputDecoration(labelText: f.label),
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
          ],
          onChanged: (v) => setState(() => choice[f.key] = v),
        );
      case FieldKind.choice:
        return DropdownButtonFormField<String>(
          initialValue: '${choice[f.key]}',
          decoration: InputDecoration(labelText: f.label),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => choice[f.key] = v),
        );
      case FieldKind.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: choice[f.key] == true,
          onChanged: (v) => setState(() => choice[f.key] = v),
        );
      default:
        return TextFormField(
          controller: text[f.key],
          maxLines: f.kind == FieldKind.multiline ? 3 : 1,
          keyboardType: switch (f.kind) {
            FieldKind.email => TextInputType.emailAddress,
            FieldKind.phone => TextInputType.phone,
            FieldKind.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(labelText: f.required ? '${f.label} *' : f.label),
          validator: (v) {
            if (f.required && (v == null || v.trim().isEmpty)) return 'Required';
            if (f.kind == FieldKind.email && v != null && v.trim().isNotEmpty && !v.contains('@')) return 'Enter a valid email';
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit ${c.singular.toLowerCase()}' : 'New ${c.singular.toLowerCase()}'),
        actions: [
          if (editing) IconButton(tooltip: 'Delete', onPressed: saving ? null : delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final f in c.fields) ...[field(f), const SizedBox(height: 14)],
            const SizedBox(height: 6),
            FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save')),
          ],
        ),
      ),
    );
  }
}

/// Products with photo, category and stock on hand.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final list = PagedListController();
  int? categoryId;

  @override
  void initState() {
    super.initState();
    context.read<StaffLookups>().ensureLoaded();
  }

  Future<void> open([Map<String, dynamic>? row]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: row)));
    if (saved == true) list.reload();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<StaffLookups>().categories;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-product',
        onPressed: open,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: PagedList(
        path: '/staff/catalog/products',
        controller: list,
        query: {'category_id': categoryId},
        searchHint: 'Name, SKU or barcode',
        emptyText: 'No products found.',
        emptyIcon: Icons.category_outlined,
        header: categories.isEmpty
            ? null
            : FilterChips(
                options: {for (final c in categories) '${c.id}': c.name},
                selected: categoryId?.toString(),
                onSelected: (v) => setState(() => categoryId = v == null ? null : int.parse(v)),
              ),
        itemBuilder: (context, row) => RecordCard(
          leading: _Thumb(url: row['image_url']?.toString()),
          title: '${row['name']}',
          subtitle: [row['category_name'], row['sku']].where((s) => s != null && '$s'.isNotEmpty).join(' · '),
          caption: '${formatNumber(row['stock_quantity'])} in stock',
          status: row['is_active'] == true ? 'active' : 'inactive',
          onTap: () => open(row),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        color: const Color(0xFFF1F5F9),
        child: url == null
            ? const Icon(Icons.image_outlined, color: kFaint)
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: kFaint)),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Map<String, dynamic>? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: '${widget.product?['name'] ?? ''}');
  late final sku = TextEditingController(text: '${widget.product?['sku'] ?? ''}');
  late final barcode = TextEditingController(text: '${widget.product?['barcode'] ?? ''}');
  late final description = TextEditingController(text: '${widget.product?['description'] ?? ''}');
  late int? categoryId = int.tryParse('${widget.product?['category_id']}');
  late bool active = widget.product?['is_active'] ?? true;
  XFile? photo;
  bool saving = false;

  bool get editing => widget.product != null;

  @override
  void dispose() {
    for (final c in [name, sku, barcode, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (picked != null) setState(() => photo = picked);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    // Multipart has no null: empty strings arrive in Laravel as null, which clears the field.
    final fields = <String, dynamic>{
      'name': name.text.trim(),
      'sku': sku.text.trim(),
      'barcode': barcode.text.trim(),
      'description': description.text.trim(),
      'category_id': categoryId?.toString() ?? '',
      'is_active': active ? '1' : '0',
    };
    if (photo != null) {
      fields['image'] = await MultipartFile.fromFile(photo!.path, filename: photo!.path.split(Platform.pathSeparator).last);
    }
    if (!mounted) return;

    // Multipart bodies always go as POST; the API accepts POST for updates too.
    final path = editing ? '/staff/catalog/products/${widget.product!['id']}' : '/staff/catalog/products';
    final result = await runApi(
      context,
      (api) => api.post(path, data: FormData.fromMap(fields)),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Saved.'}');
    Navigator.pop(context, true);
  }

  Future<void> delete() async {
    if (!await confirmAction(context, title: 'Delete product?', message: 'Products that have sales or stock cannot be deleted.', confirm: 'Delete', destructive: true)) {
      return;
    }
    if (!mounted) return;
    final result = await runApi(context, (api) => api.delete('/staff/catalog/products/${widget.product!['id']}'), busy: (b) => setState(() => saving = b));
    if (result == null || !mounted) return;
    showSuccess(context, 'Product deleted.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<StaffLookups>().categories;
    final imageUrl = widget.product?['image_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit product' : 'New product'),
        actions: [if (editing) IconButton(tooltip: 'Delete', onPressed: saving ? null : delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 140,
                  height: 140,
                  color: const Color(0xFFF1F5F9),
                  child: photo != null
                      ? Image.file(File(photo!.path), fit: BoxFit.cover)
                      : imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 40, color: kFaint))
                          : const Icon(Icons.image_outlined, size: 40, color: kFaint),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(onPressed: () => pickPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
                TextButton.icon(onPressed: () => pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextFormField(controller: sku, decoration: const InputDecoration(labelText: 'SKU'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode'))),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: categories.any((c) => c.id == categoryId) ? categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('No category')),
                for (final c in categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => categoryId = v),
            ),
            const SizedBox(height: 14),
            TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active (shown in the shop and POS)'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'Saving...' : 'Save product')),
          ],
        ),
      ),
    );
  }
}
