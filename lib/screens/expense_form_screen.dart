import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/staff_lookups.dart';
import '../services/receipt_ocr_service.dart';
import '../widgets/common.dart';

/// Receipts say "MTN MoMo", "VISA", "EFT"...; map them onto the app's methods.
String? matchPaymentMethod(String text, List<String> methods) {
  final t = text.toLowerCase();
  String? pick(String method) => methods.contains(method) ? method : null;
  if (t.isEmpty) return null;
  for (final m in methods) {
    if (m.toLowerCase() == t) return m;
  }
  if (RegExp(r'mobile|momo|mtn|airtel|m-?pesa').hasMatch(t)) {
    return pick('Mobile Money');
  }
  if (RegExp(r'card|visa|master|pos').hasMatch(t)) return pick('Card');
  if (RegExp(r'bank|transfer|eft|rtgs|swift').hasMatch(t)) {
    return pick('Bank Transfer');
  }
  if (RegExp(r'cheque|check').hasMatch(t)) return pick('Cheque');
  if (t.contains('cash')) return pick('Cash');
  return null;
}

/// New expense: scan a receipt or fill the form. Payment method and category are
/// picked from lists; a new category can be typed and is saved for next time.
/// The title is optional (the server writes "Category – payee/date").
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  static const _newCategory = '__new__';

  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final payee = TextEditingController();
  final amount = TextEditingController();
  final reference = TextEditingController();
  final newCategory = TextEditingController();
  final description = TextEditingController();

  DateTime date = DateTime.now();
  String? paymentMethod = 'Cash';
  String? category;

  /// Bumped when a scan changes the dropdowns, so they show the new values.
  int _scanCount = 0;

  File? receipt;
  bool scanning = false;
  bool saving = false;
  String rawText = '';

  @override
  void initState() {
    super.initState();
    context.read<StaffLookups>().ensureLoaded();
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      payee,
      amount,
      reference,
      newCategory,
      description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> choose(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return;

    final file = File(image.path);
    setState(() {
      receipt = file;
      scanning = true;
      rawText = '';
    });

    try {
      final data = await ReceiptOcrService.read(file);
      if (!mounted) return;
      final lookups = context.read<StaffLookups>();

      setState(() {
        // Misread dates (future, or years back) are ignored; the picker cannot show them.
        final scannedDate = DateTime.tryParse(data.date);
        final now = DateTime.now();
        if (scannedDate != null &&
            !scannedDate.isAfter(now) &&
            scannedDate.year >= now.year - 3) {
          date = scannedDate;
        }
        if (data.payee.isNotEmpty) payee.text = data.payee;
        if (data.amount != null) amount.text = data.amount!.toStringAsFixed(2);
        if (data.reference.isNotEmpty) reference.text = data.reference;
        paymentMethod =
            matchPaymentMethod(data.paymentMethod, lookups.paymentMethods) ??
            paymentMethod;
        if (data.category.isNotEmpty) {
          final known = lookups.expenseCategoryNames
              .where((c) => c.toLowerCase() == data.category.toLowerCase())
              .firstOrNull;
          if (known != null) {
            category = known;
          } else {
            category = _newCategory;
            newCategory.text = data.category;
          }
        }
        if (data.description.isNotEmpty) description.text = data.description;
        rawText = data.rawText;
        _scanCount++;
      });

      showFlash(
        context,
        'Receipt scanned. Review the filled fields before saving.',
      );
    } catch (_) {
      if (mounted) {
        showFlash(
          context,
          'The receipt could not be read clearly. You can still enter the expense manually.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => date = picked);
  }

  /// What the server will call the expense if the title is left blank.
  String get suggestedTitle {
    final cat = category == _newCategory
        ? newCategory.text.trim()
        : (category ?? '');
    final who = payee.text.trim();
    if (cat.isEmpty) return 'Category – date';
    return '$cat – ${who.isNotEmpty ? who : formatDate(date.toIso8601String())}';
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final parsedAmount = double.tryParse(amount.text.replaceAll(',', ''));

    setState(() => saving = true);
    final api = context.read<ApiClient>();
    final lookups = context.read<StaffLookups>();

    try {
      final fields = <String, dynamic>{
        'expense_date': isoDate(date),
        'amount': parsedAmount,
        if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
        'payee': payee.text.trim(),
        'reference_no': reference.text.trim(),
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (category == _newCategory)
          'category_new': newCategory.text.trim()
        else
          'category': category,
        'description': description.text.trim(),
      };

      if (receipt != null) {
        fields['receipt_image'] = await MultipartFile.fromFile(
          receipt!.path,
          filename: receipt!.path.split(Platform.pathSeparator).last,
        );
      }

      await api.post('/expenses', data: FormData.fromMap(fields));
      // A typed category is now on the list.
      if (category == _newCategory) lookups.load();

      if (!mounted) return;
      showFlash(context, 'Expense saved successfully.');
      widget.onSaved?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showFlash(context, api.messageFromError(e), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups = context.watch<StaffLookups>();
    final methods = lookups.paymentMethods;
    final categories = lookups.expenseCategoryNames;
    if (paymentMethod != null && !methods.contains(paymentMethod)) {
      paymentMethod = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .45),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.document_scanner_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scan or upload a receipt',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'The receipt is read on the phone and fills the fields below. Check them before saving.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: scanning
                                ? null
                                : () => choose(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Scan'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: scanning
                                ? null
                                : () => choose(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Upload'),
                          ),
                        ),
                      ],
                    ),
                    if (scanning) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      const Text(
                        'Reading receipt...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                    if (receipt != null && !scanning) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          receipt!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixIcon: Icon(Icons.payments_outlined),
                prefixText: 'UGX ',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', ''));
                return n == null || n < 0 ? 'Enter the amount paid' : null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'category-$category-$_scanCount-${categories.length}',
              ),
              initialValue:
                  category == null ||
                      category == _newCategory ||
                      categories.contains(category)
                  ? category
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              hint: Text(
                categories.isEmpty
                    ? 'Loading categories...'
                    : 'Choose a category',
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                  value: _newCategory,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Add a new category',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
              validator: (v) => v == null ? 'Choose a category' : null,
              onChanged: (v) => setState(() => category = v),
            ),
            if (category == _newCategory) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: newCategory,
                autofocus: newCategory.text.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'New category name *',
                  hintText: 'e.g. Generator fuel',
                  helperText: 'Saved to the list for next time.',
                ),
                validator: (v) =>
                    category == _newCategory && (v == null || v.trim().isEmpty)
                    ? 'Type the category name'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('method-$paymentMethod-$_scanCount'),
              initialValue: paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: [
                for (final m in methods)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => paymentMethod = v),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                alignment: Alignment.centerLeft,
              ),
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                'Expense date: ${formatDate(date.toIso8601String())}',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: payee,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Paid to (payee / merchant)',
                hintText: 'e.g. Shell Bugolobi',
                prefixIcon: Icon(Icons.storefront),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                prefixIcon: const Icon(Icons.title),
                helperText: title.text.trim().isEmpty
                    ? 'If left blank: "$suggestedTitle"'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Reference / receipt number',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            if (rawText.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Text read from receipt',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rawText,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(saving ? 'Saving...' : 'Save Expense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
