import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../services/receipt_ocr_service.dart';
import '../widgets/common.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final date = TextEditingController();
  final payee = TextEditingController();
  final amount = TextEditingController();
  final reference = TextEditingController();
  final paymentMethod = TextEditingController();
  final category = TextEditingController();
  final description = TextEditingController();

  File? receipt;
  bool scanning = false;
  bool saving = false;
  String rawText = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    date.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final controller in [date, payee, amount, reference, paymentMethod, category, description]) {
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
      setState(() {
        if (data.date.isNotEmpty) date.text = data.date;
        if (data.payee.isNotEmpty) payee.text = data.payee;
        if (data.amount != null) amount.text = data.amount!.toStringAsFixed(2);
        if (data.reference.isNotEmpty) reference.text = data.reference;
        if (data.paymentMethod.isNotEmpty) paymentMethod.text = data.paymentMethod;
        if (data.category.isNotEmpty) category.text = data.category;
        if (data.description.isNotEmpty) description.text = data.description;
        rawText = data.rawText;
      });

      showFlash(context, 'Receipt scanned. Review the filled fields before saving.');
    } catch (_) {
      if (mounted) {
        showFlash(context, 'The receipt could not be read clearly. You can still enter the expense manually.', error: true);
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> save() async {
    final parsedAmount = double.tryParse(amount.text.replaceAll(',', ''));

    if (date.text.isEmpty || parsedAmount == null || parsedAmount < 0) {
      showFlash(context, 'Expense date and a valid amount are required.', error: true);
      return;
    }

    setState(() => saving = true);
    final api = context.read<ApiClient>();

    try {
      final fields = <String, dynamic>{
        'expense_date': date.text.trim(),
        'amount': parsedAmount,
        'payee': payee.text.trim(),
        'reference_no': reference.text.trim(),
        'payment_method': paymentMethod.text.trim(),
        'category': category.text.trim(),
        'description': description.text.trim(),
      };

      if (receipt != null) {
        fields['receipt_image'] = await MultipartFile.fromFile(
          receipt!.path,
          filename: receipt!.path.split(Platform.pathSeparator).last,
        );
      }

      await api.post(
        '/expenses',
        data: FormData.fromMap(fields),
      );

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
    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.document_scanner_outlined),
                      SizedBox(width: 8),
                      Expanded(child: Text('Scan or upload a receipt', style: TextStyle(fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'NSales reads the receipt on the phone and fills the expense fields automatically.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: scanning ? null : () => choose(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Scan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: scanning ? null : () => choose(ImageSource.gallery),
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
                    const Text('Reading receipt...', style: TextStyle(fontSize: 12)),
                  ],
                  if (receipt != null && !scanning) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(receipt!, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(date, 'Expense date', icon: Icons.calendar_today),
          _field(payee, 'Payee / merchant', hint: 'e.g. Shell Bugolobi', icon: Icons.storefront),
          _field(amount, 'Amount', keyboard: TextInputType.number, icon: Icons.payments),
          _field(reference, 'Reference / receipt number', icon: Icons.tag),
          _field(paymentMethod, 'Payment method', hint: 'Cash, Mobile Money, Card...', icon: Icons.account_balance_wallet),
          _field(category, 'Category', hint: 'Fuel, Meals, Transport...', icon: Icons.category_outlined),
          _field(description, 'Description', lines: 3, icon: Icons.notes),
          if (rawText.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Text read from receipt', style: TextStyle(fontWeight: FontWeight.w700)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(rawText, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                ),
              ],
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(saving ? 'Saving...' : 'Save Expense'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: icon == null ? null : '  ${_hintFor(icon)}',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _hintFor(IconData icon) {
    if (icon == Icons.calendar_today) return 'Receipt date';
    if (icon == Icons.storefront) return 'Who was paid';
    if (icon == Icons.payments) return 'Receipt total';
    if (icon == Icons.tag) return 'Transaction reference';
    if (icon == Icons.account_balance_wallet) return 'How payment was made';
    if (icon == Icons.category_outlined) return 'Expense classification';
    return 'Short details about this expense';
  }
}
