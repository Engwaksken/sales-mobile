import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/branding.dart';
import '../../core/format.dart';
import '../../widgets/staff_ui.dart';

/// One of the website's admin modules (users, branches, gateways, EFRIS...), managed
/// in the app with the same rules: list and search, add, edit and delete.
class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key, required this.resource, required this.label, this.readOnly = false});

  final String resource;
  final String label;
  final bool readOnly;

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final list = PagedListController();

  Future<void> open([int? id]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRecordScreen(resource: widget.resource, label: widget.label, id: id, readOnly: widget.readOnly),
      ),
    );
    if (changed == true) list.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              heroTag: 'admin-add-${widget.resource}',
              onPressed: () => open(),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
      body: PagedList(
        path: '/staff/admin/${widget.resource}',
        controller: list,
        searchHint: 'Search ${widget.label.toLowerCase()}',
        emptyText: 'No ${widget.label.toLowerCase()} yet.',
        bottomPadding: widget.readOnly ? 24 : 96,
        itemBuilder: (context, row) => RecordCard(
          title: '${row['title'] ?? ''}',
          subtitle: '${row['subtitle'] ?? ''}'.trim().isEmpty ? null : '${row['subtitle']}',
          status: row['active'] == null ? null : (row['active'] == true ? 'active' : 'inactive'),
          onTap: () => open(row['id'] as int),
        ),
      ),
    );
  }
}

/// A field of an admin form, as the server describes it.
class AdminField {
  AdminField(Map<String, dynamic> json)
      : name = '${json['name']}',
        type = '${json['type']}',
        label = '${json['label']}',
        required = json['required'] == true,
        requiredOnEdit = json['required_on_edit'] == true,
        help = json['help']?.toString(),
        defaultValue = json['default'],
        multiline = json['multiline'] == true,
        allowCustom = json['allow_custom'] == true,
        emptyLabel = json['empty_label']?.toString(),
        options = [
          for (final o in (json['options'] as List? ?? const []))
            (value: '${(o as Map)['value']}', label: '${o['label']}'),
        ];

  final String name;
  final String type;
  final String label;
  final bool required;
  final bool requiredOnEdit;
  final String? help;
  final Object? defaultValue;
  final bool multiline;
  final bool allowCustom;
  final String? emptyLabel;
  final List<({String value, String label})> options;

  bool get isSecret => type == 'secret' || type == 'password';
}

class AdminRecordScreen extends StatefulWidget {
  const AdminRecordScreen({super.key, required this.resource, required this.label, this.id, this.readOnly = false});

  final String resource;
  final String label;
  final int? id;
  final bool readOnly;

  @override
  State<AdminRecordScreen> createState() => _AdminRecordScreenState();
}

class _AdminRecordScreenState extends State<AdminRecordScreen> {
  final form = GlobalKey<FormState>();
  List<AdminField> fields = [];
  final values = <String, Object?>{};
  final controllers = <String, TextEditingController>{};
  final secretSet = <String, bool>{};
  List<Map<String, dynamic>> details = [];
  String title = '';
  bool loading = true;
  bool saving = false;
  String? error;

  bool get isNew => widget.id == null;
  String get singular => widget.label.endsWith('ies')
      ? '${widget.label.substring(0, widget.label.length - 3)}y'
      : (widget.label.endsWith('s') ? widget.label.substring(0, widget.label.length - 1) : widget.label);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final base = '/staff/admin/${widget.resource}';
      final schema = await api.get('$base/schema');
      final record = isNew ? null : await api.get('$base/${widget.id}');
      if (!mounted) return;
      final data = record == null ? null : Map<String, dynamic>.from((record.data as Map)['data'] as Map);
      final current = Map<String, dynamic>.from((data?['values'] as Map?) ?? const {});
      setState(() {
        fields = [for (final f in ((schema.data as Map)['data'] as Map)['fields'] as List) AdminField(Map<String, dynamic>.from(f as Map))];
        title = '${data?['title'] ?? 'New ${singular.toLowerCase()}'}';
        details = [for (final d in (data?['details'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)];
        for (final f in fields) {
          final value = isNew ? f.defaultValue : current[f.name];
          values[f.name] = f.type == 'bool' ? value == true || value == 1 || value == '1' : value;
          secretSet[f.name] = current['${f.name}__set'] == true;
          if (!['bool', 'select', 'relation', 'date', 'datetime'].contains(f.type)) {
            controllers[f.name] = TextEditingController(text: f.isSecret || value == null ? '' : '$value');
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> body() => {
        for (final f in fields)
          f.name: controllers.containsKey(f.name)
              ? (controllers[f.name]!.text.trim().isEmpty ? null : controllers[f.name]!.text.trim())
              : values[f.name],
      };

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final base = '/staff/admin/${widget.resource}';
    final result = await runApi(
      context,
      (api) => isNew ? api.post(base, data: body()) : api.put('$base/${widget.id}', data: body()),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Saved.'}');
    Navigator.pop(context, true);
  }

  Future<void> delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${singular.toLowerCase()}?',
      message: '"$title" will be removed. This cannot be undone.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final result = await runApi(
      context,
      (api) => api.delete('/staff/admin/${widget.resource}/${widget.id}'),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    showSuccess(context, '${(result.data as Map)['message'] ?? 'Deleted.'}');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editable = !widget.readOnly && fields.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New ${singular.toLowerCase()}' : title, overflow: TextOverflow.ellipsis),
        actions: [
          if (!isNew && editable)
            IconButton(tooltip: 'Delete', onPressed: saving ? null : delete, icon: Icon(Icons.delete_outline, color: context.danger)),
        ],
      ),
      bottomNavigationBar: editable && !loading && error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : const Icon(Icons.check),
                  label: Text(isNew ? 'Create ${singular.toLowerCase()}' : 'Save changes'),
                ),
              ),
            )
          : null,
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (editable)
                for (final f in fields) ...[
                  _field(f),
                  const SizedBox(height: 14),
                ],
              if (details.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Card(
                    child: ExpansionTile(
                      initiallyExpanded: !editable,
                      leading: const Icon(Icons.info_outline),
                      title: const Text('All details', style: TextStyle(fontWeight: FontWeight.w800)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [for (final d in details) InfoRow('${d['label']}', '${d['value'] ?? ''}')],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _validator(AdminField f) {
    final needed = isNew ? f.required : f.requiredOnEdit && !f.isSecret;
    return (v) {
      final text = (v ?? '').trim();
      if (needed && text.isEmpty) return 'Enter ${f.label.toLowerCase()}';
      if (text.isEmpty) return null;
      if (f.type == 'email' && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email address';
      if ((f.type == 'number' || f.type == 'money') && double.tryParse(text.replaceAll(',', '')) == null) return 'Enter a number';
      if (f.type == 'color' && !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)) return 'Use a colour like #1d2b72';
      if (f.type == 'password' && text.length < 8) return 'Use at least 8 characters';
      return null;
    };
  }

  Widget _field(AdminField f) {
    final label = '${f.label}${(isNew ? f.required : f.requiredOnEdit) && !f.isSecret ? ' *' : ''}';
    final helper = f.isSecret && !isNew && secretSet[f.name] == true ? 'Saved. ${f.help ?? 'Leave blank to keep it.'}' : f.help;

    switch (f.type) {
      case 'bool':
        return Card(
          child: SwitchListTile(
            title: Text(f.label),
            value: values[f.name] == true,
            onChanged: (v) => setState(() => values[f.name] = v),
          ),
        );
      case 'select':
      case 'relation':
        return _ChoiceField(
          field: f,
          label: label,
          value: values[f.name]?.toString(),
          required: isNew ? f.required : f.requiredOnEdit,
          onChanged: (v) => setState(() => values[f.name] = v),
        );
      case 'date':
      case 'datetime':
        return _DateField(
          label: label,
          withTime: f.type == 'datetime',
          value: values[f.name]?.toString(),
          required: isNew ? f.required : f.requiredOnEdit,
          onChanged: (v) => setState(() => values[f.name] = v),
        );
      default:
        final controller = controllers[f.name]!;
        final multiline = f.type == 'textarea' || f.multiline;
        return TextFormField(
          controller: controller,
          obscureText: f.isSecret && !multiline,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 1,
          keyboardType: switch (f.type) {
            'email' => TextInputType.emailAddress,
            'number' || 'money' => const TextInputType.numberWithOptions(decimal: true),
            'url' => TextInputType.url,
            _ => multiline ? TextInputType.multiline : TextInputType.text,
          },
          autofillHints: f.type == 'email' ? const [AutofillHints.email] : (f.type == 'password' ? const [AutofillHints.newPassword] : null),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 3,
            prefixIcon: Icon(_icon(f)),
            suffixIcon: f.type == 'color' ? _ColorDot(controller: controller) : null,
            alignLabelWithHint: multiline,
          ),
          validator: _validator(f),
          onChanged: f.type == 'color' ? (_) => setState(() {}) : null,
        );
    }
  }

  IconData _icon(AdminField f) => switch (f.type) {
        'email' => Icons.mail_outline,
        'password' || 'secret' => Icons.lock_outline,
        'money' => Icons.payments_outlined,
        'number' => Icons.tag,
        'url' => Icons.link,
        'color' => Icons.palette_outlined,
        'textarea' => Icons.notes,
        _ => Icons.edit_outlined,
      };
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final hex = controller.text.trim().replaceFirst('#', '');
    final color = RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex) ? Color(int.parse('FF$hex', radix: 16)) : null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: context.hairline)),
      ),
    );
  }
}

/// A fixed list of choices or a related record; searchable when the list is long.
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({required this.field, required this.label, required this.value, required this.required, required this.onChanged});

  final AdminField field;
  final String label;
  final String? value;
  final bool required;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [...field.options];
    if (value != null && value!.isNotEmpty && options.every((o) => o.value != value)) {
      options.add((value: value!, label: value!));
    }
    final selected = options.where((o) => o.value == value).firstOrNull;
    return FormField<String>(
      initialValue: value,
      validator: (_) => required && (value == null || value!.isEmpty) ? 'Choose ${field.label.toLowerCase()}' : null,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await _pick(context, options);
          if (picked == null) return;
          final next = picked == '\u0000' ? null : picked;
          onChanged(next);
          state.didChange(next);
        },
        child: InputDecorator(
          isEmpty: selected == null,
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            prefixIcon: Icon(field.type == 'relation' ? Icons.link : Icons.list_alt),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(selected?.label ?? (field.emptyLabel ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  /// Returns the chosen value, '\u0000' for "none", or null when dismissed.
  Future<String?> _pick(BuildContext context, List<({String value, String label})> options) async {
    String? custom;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        var query = '';
        return StatefulBuilder(
          builder: (sheet, setSheet) {
            final shown = options.where((o) => o.label.toLowerCase().contains(query.toLowerCase())).toList();
            return SizedBox(
              height: MediaQuery.of(sheet).size.height * .75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(field.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  if (options.length > 8 || field.allowCustom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        autofocus: options.length > 8,
                        decoration: InputDecoration(
                          hintText: field.allowCustom ? 'Search or type a new value' : 'Search',
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) => setSheet(() {
                          query = v;
                          custom = v.trim();
                        }),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        if (!required)
                          ListTile(
                            leading: const Icon(Icons.block),
                            title: Text(field.emptyLabel ?? 'None'),
                            onTap: () => Navigator.pop(sheet, '\u0000'),
                          ),
                        if (field.allowCustom && (custom ?? '').isNotEmpty && shown.every((o) => o.label.toLowerCase() != custom!.toLowerCase()))
                          ListTile(
                            leading: const Icon(Icons.add),
                            title: Text('Use "$custom"'),
                            onTap: () => Navigator.pop(sheet, custom),
                          ),
                        for (final o in shown)
                          ListTile(
                            title: Text(o.label),
                            trailing: o.value == value ? Icon(Icons.check, color: Theme.of(sheet).colorScheme.primary) : null,
                            onTap: () => Navigator.pop(sheet, o.value),
                          ),
                        if (shown.isEmpty && !field.allowCustom)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text('Nothing matches.', style: TextStyle(color: context.muted))),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.withTime, required this.value, required this.required, required this.onChanged});

  final String label;
  final bool withTime;
  final String? value;
  final bool required;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(value ?? '');
    return FormField<String>(
      initialValue: value,
      validator: (_) => required && parsed == null ? 'Choose a date' : null,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = DateTime.now();
          final date = await showDatePicker(context: context, initialDate: parsed ?? now, firstDate: DateTime(2000), lastDate: DateTime(now.year + 10));
          if (date == null || !context.mounted) return;
          var result = date;
          if (withTime) {
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(parsed ?? now));
            if (time != null) result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          }
          final text = withTime
              ? '${isoDate(result)} ${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}:00'
              : isoDate(result);
          onChanged(text);
          state.didChange(text);
        },
        child: InputDecorator(
          isEmpty: parsed == null,
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            prefixIcon: const Icon(Icons.event_outlined),
            suffixIcon: parsed != null && !required
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      onChanged(null);
                      state.didChange(null);
                    },
                  )
                : null,
          ),
          child: Text(parsed == null ? '' : formatDate(value, withTime: withTime)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The website's System Settings page: name, branding, business details, sales and storefront options.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final form = GlobalKey<FormState>();
  final text = <String, TextEditingController>{};
  final switches = <String, bool>{};
  Map<String, dynamic> values = {};
  List<({String value, String label})> branches = [];
  List<String> fonts = [];
  String? branchId;
  String font = 'Lato';
  XFile? logo;
  XFile? favicon;
  bool loading = true;
  bool saving = false;
  String? error;

  static const textKeys = [
    'site_name', 'currency', 'timezone', 'business_email', 'business_phone', 'business_address',
    'tax_rate', 'invoice_prefix', 'order_prefix', 'low_stock_threshold', 'receipt_footer_note', 'font_size',
    'theme_primary', 'theme_secondary', 'theme_accent', 'theme_sidebar', 'theme_sidebar_text', 'theme_background', 'theme_surface',
  ];
  static const switchKeys = ['enable_guest_checkout', 'enable_mobile_money', 'accessibility_widget_enabled'];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void apply(Map data) {
    values = Map<String, dynamic>.from(data['values'] as Map);
    branches = [for (final b in (data['branches'] as List? ?? const [])) (value: '${(b as Map)['value']}', label: '${b['label']}')];
    fonts = [for (final f in (data['fonts'] as List? ?? const [])) '$f'];
    for (final k in textKeys) {
      (text[k] ??= TextEditingController()).text = '${values[k] ?? ''}';
    }
    for (final k in switchKeys) {
      switches[k] = '${values[k]}' == '1' || values[k] == true;
    }
    branchId = '${values['default_branch_id'] ?? ''}'.isEmpty ? null : '${values['default_branch_id']}';
    font = '${values['font_family'] ?? 'Lato'}';
    logo = null;
    favicon = null;
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/staff/admin/settings');
      if (mounted) setState(() => apply((response.data as Map)['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pick(bool isLogo) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file != null) setState(() => isLogo ? logo = file : favicon = file);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final branding = context.read<BrandingStore>();
    final fields = <String, dynamic>{
      for (final k in textKeys) k: text[k]!.text.trim(),
      for (final k in switchKeys) k: switches[k]! ? '1' : '0',
      'default_branch_id': branchId ?? '',
      'font_family': font,
      if (logo != null) 'system_logo': await MultipartFile.fromFile(logo!.path, filename: logo!.path.split(Platform.pathSeparator).last),
      if (favicon != null) 'system_favicon': await MultipartFile.fromFile(favicon!.path, filename: favicon!.path.split(Platform.pathSeparator).last),
    };
    if (!mounted) return;
    final result = await runApi(
      context,
      (api) => api.post('/staff/admin/settings', data: FormData.fromMap(fields)),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    setState(() => apply(((result.data as Map)['data']) as Map));
    branding.refresh();
    showSuccess(context, 'System settings saved.');
  }

  Widget input(String key, String label, {IconData icon = Icons.edit_outlined, TextInputType? keyboard, bool required = false, int lines = 1, String? Function(String)? check}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: text[key],
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        decoration: InputDecoration(labelText: '$label${required ? ' *' : ''}', prefixIcon: Icon(icon), alignLabelWithHint: lines > 1),
        validator: (v) {
          final t = (v ?? '').trim();
          if (required && t.isEmpty) return 'Enter ${label.toLowerCase()}';
          return t.isEmpty ? null : check?.call(t);
        },
      ),
    );
  }

  Widget colour(String key, String label) {
    final c = text[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: '$label *', prefixIcon: const Icon(Icons.palette_outlined), suffixIcon: _ColorDot(controller: c)),
        inputFormatters: [LengthLimitingTextInputFormatter(7)],
        onChanged: (_) => setState(() {}),
        validator: (v) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch((v ?? '').trim()) ? null : 'Use a colour like #1d2b72',
      ),
    );
  }

  Widget image(String label, bool isLogo) {
    final file = isLogo ? logo : favicon;
    final url = values[isLogo ? 'system_logo_url' : 'system_favicon_url'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.hairline)),
            child: file != null
                ? Image.file(File(file.path), fit: BoxFit.contain)
                : (url != null ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => Icon(Icons.image_outlined, color: context.faint)) : Icon(Icons.image_outlined, color: context.faint)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: () => pick(isLogo), icon: const Icon(Icons.upload_outlined), label: Text(file != null || url != null ? 'Change' : 'Upload')),
        ],
      ),
    );
  }

  String? number(String t) => double.tryParse(t) == null ? 'Enter a number' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: !loading && error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : const Icon(Icons.check),
                  label: const Text('Save settings'),
                ),
              ),
            )
          : null,
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SectionCard(title: 'General', children: [
                input('site_name', 'System name', icon: Icons.badge_outlined, required: true),
                input('currency', 'Currency', icon: Icons.payments_outlined, required: true),
                input('timezone', 'Timezone', icon: Icons.schedule, required: true),
                DropdownButtonFormField<String?>(
                  initialValue: branchId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Default branch', prefixIcon: Icon(Icons.store_outlined)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final b in branches) DropdownMenuItem(value: b.value, child: Text(b.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => branchId = v),
                ),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Branding', children: [
                image('Logo', true),
                image('Favicon (app icon)', false),
                colour('theme_primary', 'Primary colour'),
                colour('theme_secondary', 'Secondary colour'),
                colour('theme_accent', 'Accent colour'),
                colour('theme_sidebar', 'Sidebar colour'),
                colour('theme_sidebar_text', 'Sidebar text colour'),
                colour('theme_background', 'Background colour'),
                colour('theme_surface', 'Surface colour'),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Typography', children: [
                DropdownButtonFormField<String>(
                  initialValue: fonts.contains(font) ? font : null,
                  decoration: const InputDecoration(labelText: 'Font *', prefixIcon: Icon(Icons.font_download_outlined)),
                  items: [for (final f in fonts) DropdownMenuItem(value: f, child: Text(f))],
                  onChanged: (v) => setState(() => font = v ?? font),
                ),
                const SizedBox(height: 12),
                input('font_size', 'Font size (12-20)', icon: Icons.format_size, keyboard: TextInputType.number, required: true,
                    check: (t) => (int.tryParse(t) ?? 0) < 12 || (int.tryParse(t) ?? 0) > 20 ? 'Choose a size from 12 to 20' : null),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Business details', children: [
                input('business_email', 'Email', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress,
                    check: (t) => t.contains('@') ? null : 'Enter a valid email address'),
                input('business_phone', 'Phone', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
                input('business_address', 'Address', icon: Icons.location_on_outlined, lines: 2),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Sales', children: [
                input('tax_rate', 'Tax rate (%)', icon: Icons.percent, keyboard: const TextInputType.numberWithOptions(decimal: true), required: true, check: number),
                input('invoice_prefix', 'Invoice prefix', icon: Icons.receipt_long_outlined, required: true),
                input('order_prefix', 'Order prefix', icon: Icons.shopping_bag_outlined, required: true),
                input('low_stock_threshold', 'Low stock alert at', icon: Icons.inventory_2_outlined, keyboard: TextInputType.number, required: true, check: number),
                input('receipt_footer_note', 'Receipt footer note', icon: Icons.notes, lines: 2),
              ]),
              const SizedBox(height: 12),
              SectionCard(title: 'Storefront and accessibility', children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Guest checkout'),
                  subtitle: const Text('Shoppers can order without an account.'),
                  value: switches['enable_guest_checkout'] ?? false,
                  onChanged: (v) => setState(() => switches['enable_guest_checkout'] = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mobile money payments'),
                  value: switches['enable_mobile_money'] ?? false,
                  onChanged: (v) => setState(() => switches['enable_mobile_money'] = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accessibility widget on the website'),
                  value: switches['accessibility_widget_enabled'] ?? false,
                  onChanged: (v) => setState(() => switches['accessibility_widget_enabled'] = v),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Which roles may use which modules (the website's Role Permissions page). Admins always have everything.
class RolePermissionsScreen extends StatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  State<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  List<({String key, String label})> roles = [];
  List<Map<String, dynamic>> groups = [];
  Map<String, Set<String>> assigned = {};
  String? role;
  bool loading = true;
  bool saving = false;
  bool dirty = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  void apply(Map data) {
    roles = [for (final r in (data['roles'] as List)) (key: '${(r as Map)['key']}', label: '${r['label']}')];
    groups = [for (final g in (data['groups'] as List)) Map<String, dynamic>.from(g as Map)];
    final a = Map<String, dynamic>.from((data['assigned'] as Map?) ?? const {});
    assigned = {for (final r in roles) r.key: {for (final p in (a[r.key] as List? ?? const [])) '$p'}};
    if (role == null || roles.every((r) => r.key != role)) role = roles.isEmpty ? null : roles.first.key;
    dirty = false;
  }

  Future<void> load() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.get('/staff/admin/role-permissions');
      if (mounted) setState(() => apply((response.data as Map)['data'] as Map));
    } catch (e) {
      if (mounted) setState(() => error = api.messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final result = await runApi(
      context,
      (api) => api.put('/staff/admin/role-permissions', data: {
        'permissions': {for (final e in assigned.entries) e.key: e.value.toList()},
      }),
      busy: (b) => setState(() => saving = b),
    );
    if (result == null || !mounted) return;
    setState(() => apply((result.data as Map)['data'] as Map));
    showSuccess(context, 'Role permissions saved.');
  }

  Future<void> addRole() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add a role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Role name', hintText: 'e.g. Store Keeper'),
          onSubmitted: (v) => Navigator.pop(dialog, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, controller.text.trim()), child: const Text('Add role')),
        ],
      ),
    );
    controller.dispose();
    if (label == null || label.isEmpty || !mounted) return;
    final result = await runApi(context, (api) => api.post('/staff/admin/roles', data: {'label': label}), busy: (b) => setState(() => saving = b));
    if (result == null || !mounted) return;
    setState(() {
      final keep = assigned;
      apply((result.data as Map)['data'] as Map);
      for (final e in keep.entries) {
        assigned[e.key] = e.value;
      }
      role = roles.last.key;
    });
    showSuccess(context, 'Role added. Choose what it can do, then save.');
  }

  void toggle(String key, bool on) => setState(() {
        dirty = true;
        on ? assigned[role]!.add(key) : assigned[role]!.remove(key);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: !loading && error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: saving || !dirty ? null : save,
                  icon: saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                      : const Icon(Icons.check),
                  label: Text(dirty ? 'Save permissions' : 'No changes'),
                ),
              ),
            )
          : null,
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Admins can always do everything. Choose a role to set what it can use.', style: TextStyle(color: context.muted)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final r in roles)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${r.label} (${assigned[r.key]?.length ?? 0})'),
                        selected: role == r.key,
                        onSelected: (_) => setState(() => role = r.key),
                      ),
                    ),
                  ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add role'), onPressed: saving ? null : addRole),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (role != null)
              for (final g in groups) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: Row(
                            children: [
                              Expanded(child: Text('${g['category']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                              Builder(builder: (context) {
                                final keys = [for (final p in g['permissions'] as List) '${(p as Map)['key']}'];
                                final all = keys.every(assigned[role]!.contains);
                                return TextButton(
                                  onPressed: () => setState(() {
                                    dirty = true;
                                    all ? assigned[role]!.removeAll(keys) : assigned[role]!.addAll(keys);
                                  }),
                                  child: Text(all ? 'Clear' : 'Allow all'),
                                );
                              }),
                            ],
                          ),
                        ),
                        for (final p in g['permissions'] as List)
                          CheckboxListTile(
                            value: assigned[role]!.contains('${(p as Map)['key']}'),
                            onChanged: (v) => toggle('${p['key']}', v == true),
                            title: Text('${p['label']}'),
                            subtitle: '${p['description'] ?? ''}'.isEmpty ? null : Text('${p['description']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
