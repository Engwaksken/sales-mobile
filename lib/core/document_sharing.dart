import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'branding.dart';
import 'config.dart';
import 'format.dart';

/// One product line on an invoice.
class DocumentLine {
  const DocumentLine({required this.name, this.quantity, this.price, required this.total});

  final String name;
  final dynamic quantity;
  final dynamic price;
  final dynamic total;
}

/// An invoice or receipt to render as a branded PDF.
class SalesDocument {
  const SalesDocument({
    required this.title,
    required this.number,
    this.details = const [],
    this.lines = const [],
    this.totals = const [],
    this.highlight,
    this.note,
    this.signer,
    this.signerRole,
    this.signature,
    this.signatureLabel = 'Sold by',
  });

  /// "Invoice", "Payment receipt".
  final String title;
  final String number;

  /// Label/value pairs shown under the header (customer, date, method...). Empty values are skipped.
  final List<(String, String?)> details;
  final List<DocumentLine> lines;

  /// Label/value pairs under the items; the last one is drawn bold.
  final List<(String, String)> totals;

  /// A prominent label/amount box, e.g. ('Amount received', 'UGX 50,000').
  final (String, String)? highlight;
  final String? note;

  /// The salesperson printed under the signature line; no block when null.
  final String? signer;
  final String? signerRole;

  /// PNG/JPEG bytes of the signer's signature; a blank line is drawn when null.
  final Uint8List? signature;
  final String signatureLabel;

  String get fileName {
    final safe = '$title $number'.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return '${safe.replaceAll(RegExp(r'-+$'), '')}.pdf';
  }
}

/// Renders [doc] as a PDF branded with the admin's name, logo and colour and opens the share sheet.
Future<void> shareSalesDocument(BuildContext context, SalesDocument doc) async {
  final brand = context.read<BrandingStore>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  try {
    final bytes = await buildSalesDocumentPdf(
      doc,
      brandName: brand.siteName,
      brandColor: brand.primary,
      logo: brand.logoBytes ?? brand.faviconBytes,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: doc.fileName)],
        fileNameOverrides: [doc.fileName],
        subject: '${doc.title} ${doc.number}'.trim(),
        sharePositionOrigin: box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not share the ${doc.title.toLowerCase()}.')));
  }
}

Future<Uint8List> buildSalesDocumentPdf(
  SalesDocument source, {
  required String brandName,
  required Color brandColor,
  Uint8List? logo,
  DateTime? generatedAt,
}) async {
  final doc = _latin1(source);
  brandName = _clean(brandName);
  final accent = PdfColor.fromInt(brandColor.toARGB32());
  final muted = PdfColor.fromHex('#6B7280');
  final line = PdfColor.fromHex('#E5E7EB');
  // PDF fills ignore alpha, so blend the brand colour with white for the tint.
  final tint = PdfColor(_mix(accent.red), _mix(accent.green), _mix(accent.blue));

  final image = await _logoImage(logo);
  final signatureImage = await _signatureImage(doc.signature);
  final details = doc.details.where((d) => (d.$2 ?? '').trim().isNotEmpty).toList();
  final printed = formatDate((generatedAt ?? DateTime.now()).toIso8601String(), withTime: true);

  pw.Widget label(String text) => pw.Text(text.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: muted, letterSpacing: 0.6));

  final pdf = pw.Document(title: '${doc.title} ${doc.number}', author: brandName, creator: brandName);
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
        // Faint logo watermark behind every page.
        buildBackground: image == null
            ? null
            : (context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.SizedBox(width: 300, height: 300, child: pw.Image(image, fit: pw.BoxFit.contain)),
                    ),
                  ),
                ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text('$brandName  |  ${doc.title} ${doc.number}', style: pw.TextStyle(fontSize: 9, color: muted)),
            ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: line))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated $printed', style: pw.TextStyle(fontSize: 8, color: muted)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      build: (context) => [
        // Brand header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (image != null) ...[
              pw.SizedBox(width: 56, height: 56, child: pw.Image(image, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Text(brandName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(doc.title.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                if (doc.number.isNotEmpty) pw.Text('No. ${doc.number}', style: pw.TextStyle(fontSize: 10, color: muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 3, color: accent),
        pw.SizedBox(height: 18),

        // Details grid
        if (details.isNotEmpty)
          pw.Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (final d in details)
                pw.SizedBox(
                  width: 150,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [label(d.$1), pw.SizedBox(height: 2), pw.Text(d.$2!.trim(), style: const pw.TextStyle(fontSize: 11))],
                  ),
                ),
            ],
          ),

        if (doc.highlight != null) ...[
          pw.SizedBox(height: 22),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: pw.BoxDecoration(color: tint, border: pw.Border(left: pw.BorderSide(color: accent, width: 4))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(doc.highlight!.$1, style: pw.TextStyle(fontSize: 12, color: muted)),
                pw.Text(doc.highlight!.$2, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)),
              ],
            ),
          ),
        ],

        // Items
        if (doc.lines.isNotEmpty) ...[
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Item', 'Qty', 'Unit price', 'Amount'],
            data: [
              for (final (i, l) in doc.lines.indexed)
                [
                  '${i + 1}',
                  l.name,
                  l.quantity == null ? '' : formatNumber(l.quantity),
                  l.price == null ? '' : money(l.price),
                  money(l.total),
                ],
            ],
            border: null,
            headerDecoration: pw.BoxDecoration(color: accent),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 10),
            rowDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5))),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],

        // Totals
        if (doc.totals.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 230,
              child: pw.Column(
                children: [
                  for (final (i, t) in doc.totals.indexed)
                    _totalRow(t.$1, t.$2, bold: i == doc.totals.length - 1, accent: accent, line: line),
                ],
              ),
            ),
          ),
        ],

        if (doc.signer != null && doc.signer!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 30),
          _signatureBlock(doc, signatureImage, muted: muted),
        ],

        pw.SizedBox(height: 32),
        if (doc.note != null && doc.note!.trim().isNotEmpty) ...[
          pw.Text(doc.note!.trim(), style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.SizedBox(height: 8),
        ],
        pw.Center(
          child: pw.Text('Thank you for your business.', style: pw.TextStyle(fontSize: 11, color: accent, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _totalRow(String label, String value, {required bool bold, required PdfColor accent, required PdfColor line}) {
  final style = pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: bold ? accent : null);
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
    decoration: bold ? pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: accent, width: 1.2))) : pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    ),
  );
}

/// The admin's logo when it is a PNG/JPEG the PDF can embed, else the bundled app logo.
Future<pw.ImageProvider?> _logoImage(Uint8List? bytes) async {
  if (bytes != null && _isRaster(bytes)) {
    try {
      return pw.MemoryImage(bytes);
    } catch (_) {}
  }
  try {
    final data = await rootBundle.load(AppConfig.logoAsset);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

bool _isRaster(Uint8List b) =>
    b.length > 4 &&
    ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) || (b[0] == 0xFF && b[1] == 0xD8));

double _mix(double channel) => channel * 0.1 + 0.9;

const _replacements = {
  '\u2014': '-', '\u2013': '-', '\u2018': "'", '\u2019': "'", '\u201C': '"', '\u201D': '"',
  '\u00D7': 'x', '\u2022': '-', '\u2026': '...', '\u00A0': ' ',
};

/// The built-in PDF fonts only cover Latin-1; swap or drop anything else so odd names never break a share.
String _clean(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final swap = _replacements[char];
    if (swap != null) {
      buffer.write(swap);
    } else if (rune >= 0x20 && rune <= 0x7E || rune >= 0xA1 && rune <= 0xFF) {
      buffer.write(char);
    } else if (rune == 0x0A) {
      buffer.write(char);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

SalesDocument _latin1(SalesDocument d) => SalesDocument(
  title: _clean(d.title),
  number: _clean(d.number),
  details: [for (final x in d.details) (_clean(x.$1), x.$2 == null ? null : _clean(x.$2!))],
  lines: [for (final l in d.lines) DocumentLine(name: _clean(l.name), quantity: l.quantity, price: l.price, total: l.total)],
  totals: [for (final t in d.totals) (_clean(t.$1), _clean(t.$2))],
  highlight: d.highlight == null ? null : (_clean(d.highlight!.$1), _clean(d.highlight!.$2)),
  note: d.note == null ? null : _clean(d.note!),
  signer: d.signer == null ? null : _clean(d.signer!),
  signerRole: d.signerRole == null ? null : _clean(d.signerRole!),
  signature: d.signature,
  signatureLabel: _clean(d.signatureLabel),
);

Future<pw.ImageProvider?> _signatureImage(Uint8List? bytes) async {
  if (bytes == null || !_isRaster(bytes)) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

pw.Widget _signatureBlock(SalesDocument doc, pw.ImageProvider? signature, {required PdfColor muted}) {
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 220,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              height: 56,
              alignment: pw.Alignment.bottomLeft,
              child: signature == null ? null : pw.Image(signature, height: 54, fit: pw.BoxFit.contain),
            ),
            pw.Container(height: 0.8, color: muted),
            pw.SizedBox(height: 4),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: doc.signer!.trim(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  if ((doc.signerRole ?? '').trim().isNotEmpty)
                    pw.TextSpan(text: '  -  ${doc.signerRole!.trim()}', style: pw.TextStyle(fontSize: 9, color: muted)),
                ],
              ),
            ),
            pw.Text(doc.signatureLabel, style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      pw.Spacer(),
    ],
  );
}
