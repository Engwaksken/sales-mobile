import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decodes a `data:image/...;base64,` URI (as the API sends signatures) into bytes.
Uint8List? bytesFromDataUri(Object? value) {
  final text = value is String ? value.trim() : '';
  final comma = text.indexOf(',');
  if (!text.startsWith('data:image/') || comma < 0) return null;
  try {
    return base64Decode(text.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

String pngDataUri(Uint8List bytes) => 'data:image/png;base64,${base64Encode(bytes)}';

/// Full-screen pad to draw a signature. Pops with trimmed, transparent PNG bytes, or null.
class SignaturePadScreen extends StatefulWidget {
  const SignaturePadScreen({super.key});

  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  final List<List<Offset>> strokes = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    // Signing is easier with the phone on its side.
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> save() async {
    if (strokes.isEmpty) return;
    setState(() => saving = true);
    final bytes = await renderSignaturePng(strokes);
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw your signature'),
        actions: [
          TextButton(
            onPressed: strokes.isEmpty ? null : () => setState(strokes.clear),
            child: const Text('Clear'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: strokes.isEmpty || saving ? null : save,
              style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Use this'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Semantics(
                    label: 'Signature drawing area',
                    child: GestureDetector(
                      onPanStart: (d) => setState(() => strokes.add([d.localPosition])),
                      onPanUpdate: (d) => setState(() => strokes.last.add(d.localPosition)),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _SignaturePainter(strokes, guide: scheme.outlineVariant),
                        child: strokes.isEmpty
                            ? const Center(
                                child: Text(
                                  'Sign here with your finger',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                                ),
                              )
                            : const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _ink = Color(0xFF0F172A);
const _stroke = 3.2;

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, {this.guide});

  final List<List<Offset>> strokes;
  final Color? guide;

  @override
  void paint(Canvas canvas, Size size) {
    if (guide != null) {
      final y = size.height * .72;
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), Paint()..color = guide!..strokeWidth = 1);
    }
    _drawStrokes(canvas, strokes, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}

void _drawStrokes(Canvas canvas, List<List<Offset>> strokes, Offset shift) {
  final paint = Paint()
    ..color = _ink
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first - shift, _stroke / 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx - shift.dx, stroke.first.dy - shift.dy);
    for (var i = 1; i < stroke.length - 1; i++) {
      // Smooth the line through the midpoints between touches.
      final a = stroke[i] - shift;
      final b = stroke[i + 1] - shift;
      path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    final last = stroke.last - shift;
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }
}

/// Renders strokes to a transparent PNG cropped to the ink, at 2x for crisp printing.
Future<Uint8List> renderSignaturePng(List<List<Offset>> strokes, {double scale = 2}) async {
  final points = strokes.expand((s) => s);
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  const pad = 10.0;
  final origin = Offset(minX - pad, minY - pad);
  final width = math.max(1.0, maxX - minX + pad * 2);
  final height = math.max(1.0, maxY - minY + pad * 2);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  _drawStrokes(canvas, strokes, origin);
  final image = await recorder.endRecording().toImage((width * scale).ceil(), (height * scale).ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
