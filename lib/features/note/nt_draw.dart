import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_extras_text.dart';

// Sign / Draw (note_sign): a full-screen pad with smooth strokes, 3 pen colours, 2 widths, undo, clear, a Signature mode
// (a line to sign on + "Signed by <name> · date" under it) and a Drawing mode. It saves a white PNG at 2× (the web's
// DrawPad.jsx) → the note's files (sign: true) → a "draw" block.

const _inks = [Color(0xFF111827), Color(0xFF1D4ED8), Color(0xFFC81E1E)];

class NtStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  NtStroke(this.points, this.color, this.width);
}

// the toolbar button: pad → upload → block after the caret
Future<void> ntDrawTool(NtEditorApi ed) async {
  final png = await ntOpenPad(ed.context, ed.ctx, name: ed.ctx.bizName);
  if (png == null) return;
  // every step of the upload has its own time limit (and really stops): no outer timer that only stops waiting
  final f = await ed.attachBytes(png.bytes, png.name, sign: true);
  if (f == null) return;
  ed.insertAfter(NtBlock.blank('draw')..fileId = str(f['_id']), focus: true);
  ed.ctx.notify(ed.ctx.m('signAdded'));
}

class NtPng {
  final Uint8List bytes;
  final String name;
  const NtPng(this.bytes, this.name);
}

Future<NtPng?> ntOpenPad(BuildContext context, NtCtx ctx, {String name = '', List<NtStroke>? strokes}) =>
    Navigator.of(context).push<NtPng>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => NtPadPage(ctx: ctx, name: name, strokes: strokes)));

class NtPadPage extends StatefulWidget {
  final NtCtx ctx;
  final String name;
  final List<NtStroke>? strokes; // tests: a drawing already on the pad
  final String mode;
  const NtPadPage({super.key, required this.ctx, this.name = '', this.strokes, this.mode = 'sign'});
  @override
  State<NtPadPage> createState() => _NtPadPageState();
}

class _NtPadPageState extends State<NtPadPage> {
  late final List<NtStroke> _strokes = [...?widget.strokes];
  late String _mode = widget.mode;
  int _ink = 0;
  bool _thick = false;
  bool _busy = false;
  String _err = '';
  late final _name = TextEditingController(text: widget.name);
  Size _size = const Size(360, 240);

  NtCtx get ctx => widget.ctx;
  double get _width => (_mode == 'sign' ? 2.6 : 3.4) * (_thick ? 2.1 : 1);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _caption {
    final now = DateTime.now();
    final date = ntDate(now.toUtc().toIso8601String(), ctx.lang);
    return ctx.m('signedBy', {'name': _name.text.trim().isEmpty ? '—' : _name.text.trim(), 'date': date});
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) return setState(() => _err = ctx.m('padEmpty'));
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final bytes = await ntRenderPad(_strokes, _size, sign: _mode == 'sign', caption: _mode == 'sign' ? _caption : '').timeout(const Duration(seconds: 20));
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      Navigator.pop(context, NtPng(bytes, '${_mode == 'sign' ? 'signature' : 'drawing'}-$stamp.png'));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = ctx.m('padUploadFail');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.appBg,
      appBar: AppBar(
        backgroundColor: c.appBg,
        surfaceTintColor: Colors.transparent,
        title: Text(ctx.m('padTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(LucideIcons.x), tooltip: ctx.m('cancel'), onPressed: _busy ? null : () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'sign', icon: const Icon(LucideIcons.signature, size: 17), label: Text(ctx.m('modeSign'))),
                  ButtonSegment(value: 'draw', icon: const Icon(LucideIcons.pencil, size: 17), label: Text(ctx.m('modeDraw'))),
                ],
                selected: {_mode},
                onSelectionChanged: _busy ? null : (v) => setState(() => _mode = v.first),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (_, box) {
                    _size = Size(box.maxWidth, box.maxHeight);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.line),
                        boxShadow: c.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        onPanStart: _busy
                            ? null
                            : (d) => setState(() {
                                _err = '';
                                _strokes.add(NtStroke([d.localPosition], _inks[_ink], _width));
                              }),
                        onPanUpdate: _busy
                            ? null
                            : (d) {
                                final last = _strokes.last.points;
                                if ((d.localPosition - last.last).distance < 1.2) return;
                                setState(() => last.add(d.localPosition));
                              },
                        child: CustomPaint(
                          painter: _PadPainter(_strokes, sign: _mode == 'sign', hint: _strokes.isEmpty ? (_mode == 'sign' ? ctx.m('signHere') : ctx.m('drawHere')) : '', caption: _mode == 'sign' ? _caption : ''),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(ctx.m('pen'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  for (final (i, ink) in _inks.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: i < ctx.l('inks').length ? ctx.l('inks')[i] : '',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _ink = i),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ink,
                              shape: BoxShape.circle,
                              border: Border.all(color: i == _ink ? c.brand : Colors.white, width: 3),
                              boxShadow: [if (i == _ink) BoxShadow(color: c.brand.withValues(alpha: .35), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: false, label: Text(ctx.m('thin'))),
                      ButtonSegment(value: true, label: Text(ctx.m('thick'))),
                    ],
                    selected: {_thick},
                    onSelectionChanged: (v) => setState(() => _thick = v.first),
                  ),
                ],
              ),
            ),
            if (_mode == 'sign')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _name,
                  maxLength: 60,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: ctx.m('padName'), counterText: '', prefixIcon: const Icon(LucideIcons.user, size: 18)),
                ),
              ),
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Alert(_err, tone: Tone.danger),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom * 0),
              child: Row(
                children: [
                  IconButton.filledTonal(tooltip: ctx.m('undo'), onPressed: _strokes.isEmpty || _busy ? null : () => setState(() => _strokes.removeLast()), icon: const Icon(LucideIcons.undo2)),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(tooltip: ctx.m('clear'), onPressed: _strokes.isEmpty || _busy ? null : () => setState(_strokes.clear), icon: const Icon(LucideIcons.eraser)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Btn(_busy ? ntE(ctx, 'drawing') : ctx.m('padSave'), icon: LucideIcons.check, busy: _busy, expand: true, onTap: _save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a smooth line through the points (curves through the middle points)
Path _smooth(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) return p..lineTo(pts.first.dx + .1, pts.first.dy + .1);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
    p.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  return p..lineTo(pts.last.dx, pts.last.dy);
}

void _paintStrokes(Canvas canvas, List<NtStroke> strokes) {
  for (final s in strokes) {
    canvas.drawPath(
      _smooth(s.points),
      Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }
}

// the signature line sits at 72% of the height; the caption under it
double _lineY(Size s) => s.height * .72;

void _paintCaption(Canvas canvas, Size size, String caption, {bool guide = false}) {
  final y = _lineY(size);
  canvas.drawLine(
    Offset(24, y),
    Offset(size.width - 24, y),
    Paint()
      ..color = guide ? const Color(0xFFB8BCC6) : const Color(0xFF9AA0AC)
      ..strokeWidth = 1.4,
  );
  if (caption.isEmpty) return;
  final tp = TextPainter(
    text: TextSpan(
      text: caption,
      style: const TextStyle(color: Color(0xFF4B5160), fontSize: 13, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: size.width - 48);
  tp.paint(canvas, Offset(24, y + 8));
}

class _PadPainter extends CustomPainter {
  final List<NtStroke> strokes;
  final bool sign;
  final String hint, caption;
  _PadPainter(this.strokes, {required this.sign, required this.hint, required this.caption});
  @override
  void paint(Canvas canvas, Size size) {
    if (sign) _paintCaption(canvas, size, caption, guide: true);
    if (hint.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: hint,
          style: const TextStyle(color: Color(0xFFB0B4BE), fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, sign ? _lineY(size) - tp.height - 18 : (size.height - tp.height) / 2));
    }
    _paintStrokes(canvas, strokes);
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}

// the clean copy: white paper, the strokes, the line + caption (signature), at 2×
Future<Uint8List> ntRenderPad(List<NtStroke> strokes, Size size, {bool sign = false, String caption = ''}) async {
  const k = 2.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(k);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  if (sign) _paintCaption(canvas, size, caption);
  _paintStrokes(canvas, strokes);
  final img = await rec.endRecording().toImage((size.width * k).round(), (size.height * k).round());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data == null) throw StateError('png');
  return data.buffer.asUint8List();
}
