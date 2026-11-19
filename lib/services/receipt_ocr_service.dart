import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptData {
  ReceiptData({
    this.payee = '',
    this.date = '',
    this.amount,
    this.reference = '',
    this.paymentMethod = '',
    this.category = '',
    this.description = '',
    this.rawText = '',
  });

  final String payee;
  final String date;
  final double? amount;
  final String reference;
  final String paymentMethod;
  final String category;
  final String description;
  final String rawText;
}

class ReceiptOcrService {
  static Future<ReceiptData> read(File file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final input = InputImage.fromFile(file);
      final recognized = await recognizer.processImage(input);
      final text = recognized.text;
      final lines = text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final payee = _merchant(lines);
      final amount = _amount(lines);
      final date = _date(text);
      final reference = _reference(text);
      final method = _method(text);
      final category = _category(text);

      return ReceiptData(
        payee: payee,
        date: date,
        amount: amount,
        reference: reference,
        paymentMethod: method,
        category: category,
        description: [
          if (payee.isNotEmpty) 'Receipt from $payee',
          if (reference.isNotEmpty) 'Ref: $reference',
        ].join(', '),
        rawText: text,
      );
    } finally {
      await recognizer.close();
    }
  }

  static String _merchant(List<String> lines) {
    for (final line in lines.take(10)) {
      if (line.length < 3 || line.length > 80) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;
      if (RegExp(
        r'^(receipt|tax invoice|invoice|cash sale|date|time|tel|phone|tin|vat|total|subtotal|amount)\b',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }
      return line;
    }
    return '';
  }

  static double? _amount(List<String> lines) {
    final keywords = [
      RegExp(r'grand\s*total', caseSensitive: false),
      RegExp(r'amount\s*due', caseSensitive: false),
      RegExp(r'net\s*total', caseSensitive: false),
      RegExp(r'\btotal\b', caseSensitive: false),
    ];

    for (final keyword in keywords) {
      for (final line in lines.reversed) {
        if (!keyword.hasMatch(line)) continue;
        final values = _numbers(line);
        if (values.isNotEmpty) {
          values.sort();
          return values.last;
        }
      }
    }

    final values = <double>[];
    for (final line in lines) {
      values.addAll(_numbers(line).where((value) => value >= 100));
    }
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }

  static List<double> _numbers(String line) {
    final matches = RegExp(r'\d[\d,]*(?:\.\d{1,2})?').allMatches(line);
    return matches
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')))
        .whereType<double>()
        .toList();
  }

  static String _date(String text) {
    var m = RegExp(
      r'\b(20\d{2}|19\d{2})[-/.](0?[1-9]|1[0-2])[-/.](0?[1-9]|[12]\d|3[01])\b',
    ).firstMatch(text);

    if (m != null) {
      return '${m.group(1)!.padLeft(4, '0')}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
    }

    m = RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])[-/.](0?[1-9]|1[0-2])[-/.](\d{2,4})\b',
    ).firstMatch(text);

    if (m != null) {
      var year = int.parse(m.group(3)!);
      if (year < 100) year += year >= 70 ? 1900 : 2000;
      return '$year-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
    }

    return '';
  }

  static String _reference(String text) {
    final m = RegExp(
      r'\b(?:receipt|rcpt|invoice|inv|transaction|txn|reference|ref)\s*(?:no\.?|number|#|:)?\s*([A-Z0-9][A-Z0-9/_-]{2,})',
      caseSensitive: false,
    ).firstMatch(text);

    return m?.group(1) ?? '';
  }

  static String _method(String text) {
    final source = text.toLowerCase();

    if (RegExp(r'\b(mtn|airtel|mobile\s*money|momo)\b').hasMatch(source)) {
      return 'Mobile Money';
    }
    if (RegExp(r'\b(visa|mastercard|card|pos)\b').hasMatch(source)) {
      return 'Card';
    }
    if (RegExp(r'\b(bank|transfer|eft|rtgs)\b').hasMatch(source)) {
      return 'Bank Transfer';
    }
    if (RegExp(r'\bcash\b').hasMatch(source)) return 'Cash';

    return '';
  }

  static String _category(String text) {
    final source = text.toLowerCase();

    final rules = <String, RegExp>{
      'Fuel': RegExp(r'\b(fuel|petrol|diesel|shell|gas station)\b'),
      'Transport': RegExp(r'\b(transport|taxi|uber|boda|bus|parking)\b'),
      'Meals': RegExp(r'\b(food|restaurant|cafe|lunch|dinner|meal)\b'),
      'Utilities': RegExp(r'\b(umeme|nwsc|water bill|electricity)\b'),
      'Internet': RegExp(r'\b(internet|wifi|data bundle)\b'),
      'Airtime': RegExp(r'\b(airtime|recharge)\b'),
      'Rent': RegExp(r'\b(rent|landlord|lease)\b'),
      'Office Supplies': RegExp(r'\b(stationery|printing|paper|toner|ink)\b'),
    };

    for (final entry in rules.entries) {
      if (entry.value.hasMatch(source)) return entry.key;
    }
    return '';
  }
}
