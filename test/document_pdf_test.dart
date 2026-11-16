import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/document_sharing.dart';
import 'package:nsales_native/widgets/signature_pad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const invoice = SalesDocument(
    title: 'Invoice',
    number: 'INV-00042',
    details: [('Billed to', 'Jane Customer'), ('Date', '16 Nov 2026'), ('Phone', null)],
    lines: [
      DocumentLine(name: 'Cement 50kg', quantity: 10, price: 38000, total: 380000),
      DocumentLine(name: 'Iron sheets', quantity: 4, price: 52000, total: 208000),
    ],
    totals: [('Total', 'UGX 588,000'), ('Paid', 'UGX 300,000'), ('Balance due', 'UGX 288,000')],
  );

  test('builds a PDF invoice with brand details', () async {
    final bytes = await buildSalesDocumentPdf(invoice, brandName: 'Test Hardware', brandColor: const Color(0xFF1D2B72));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['PDF_SAMPLE_OUT'];
    if (out != null) File('$out/invoice.pdf').writeAsBytesSync(bytes);
  });

  test('draws a signature to a cropped transparent PNG and signs the invoice', () async {
    final png = await renderSignaturePng([
      [const Offset(20, 60), const Offset(60, 20), const Offset(100, 70), const Offset(140, 30), const Offset(180, 65)],
      [const Offset(200, 40), const Offset(240, 42)],
    ]);
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(bytesFromDataUri(pngDataUri(png)), png);
    expect(bytesFromDataUri('not a data uri'), isNull);

    final logo = File('assets/icons/logo.png').readAsBytesSync();
    final signed = SalesDocument(
      title: invoice.title,
      number: invoice.number,
      details: invoice.details,
      lines: invoice.lines,
      totals: invoice.totals,
      signer: 'Grace Nakato',
      signerRole: 'Cashier',
      signature: png,
    );
    final bytes = await buildSalesDocumentPdf(signed, brandName: 'Test Hardware', brandColor: const Color(0xFF1D2B72), logo: logo);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final unsigned = await buildSalesDocumentPdf(invoice, brandName: 'Test Hardware', brandColor: const Color(0xFF1D2B72), logo: logo);
    expect(bytes.length, greaterThan(unsigned.length));
    final out = Platform.environment['PDF_SAMPLE_OUT'];
    if (out != null) File('$out/invoice-signed.pdf').writeAsBytesSync(bytes);
  });

  test('builds a PDF receipt and names the file safely', () async {
    const receipt = SalesDocument(
      title: 'Payment receipt',
      number: 'RCT/0007',
      details: [('Received from', 'Zoë Nakato — 宏'), ('Method', 'Mobile money')],
      highlight: ('Amount received', 'UGX 300,000'),
    );
    final bytes = await buildSalesDocumentPdf(receipt, brandName: 'Test Hardware', brandColor: Colors.teal);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(receipt.fileName, 'Payment-receipt-RCT-0007.pdf');
    final out = Platform.environment['PDF_SAMPLE_OUT'];
    if (out != null) File('$out/receipt.pdf').writeAsBytesSync(bytes);
  });
}
