import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, mGap;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'qg_common.dart';
import 'qg_data.dart';
import 'qr_art.dart';

// Print templates (qr_print, one-time each): pick one, pick a QR code, write the texts, print — QgPrint.jsx + qrgen/prints.js.
// The page is drawn here in points (A4 = 595 × 842) and shared as a picture to print.

const _swatches = ['#E0581A', '#DC2626', '#DB2777', '#9333EA', '#4F46E5', '#0284C7', '#0D9488', '#16A34A', '#CA8A04', '#111827'];
double _mm(double v) => v * 2.835;
const _ink = Color(0xFF1D1F24);

class PrintTab extends StatefulWidget {
  final QgCtx ctx;
  const PrintTab({super.key, required this.ctx});
  @override
  State<PrintTab> createState() => _PrintTabState();
}

class _PrintTabState extends State<PrintTab> {
  QgCtx get ctx => widget.ctx;
  String _key = printTpls.first.key;
  late String _cid = ctx.codes.isEmpty ? '' : str(ctx.codes.first['_id']);
  late final _t1 = TextEditingController(text: ctx.lang == 'km' ? 'ស្កេនមើលម៉ឺនុយ' : 'Scan for our menu');
  late final _t2 = TextEditingController(text: str(ctx.business['name']));
  final _t3 = TextEditingController();
  late String _color = (str(ctx.settings['color']).isEmpty ? '#E0581A' : str(ctx.settings['color'])).toUpperCase();
  final _paper = GlobalKey();
  bool _busy = false;

  @override
  void dispose() {
    _t1.dispose();
    _t2.dispose();
    _t3.dispose();
    super.dispose();
  }

  Color get _c => Color(0xFF000000 | (int.tryParse(_color.replaceFirst('#', ''), radix: 16) ?? 0xE0581A));

  PrintPage _pageOf(String key, Json? code) => PrintPage(tpl: key, code: code, ctx: ctx, t1: _t1.text, t2: _t2.text, t3: _t3.text, color: _c);

  // tap a template → the template sheet (a big paper with your code, swipe for the next), Use / Buy at the bottom.
  // "Use" picks it for the paper below (print / share stay on the page).
  Future<void> _open(String key, Set<String> owned, Json? code) async {
    final keys = [for (final x in printTpls) x.key];
    final price = n(ctx.prices['qr_print']);
    await showLookSheet(
      context,
      title: ctx.m('printTitle'),
      count: keys.length,
      initial: keys.indexOf(key),
      item: (context, i, refresh) {
        final x = printTpls[i];
        final mine = owned.contains(x.key);
        final using = _key == x.key;
        return LookItem(
          name: x.name(ctx.lang),
          badge: using ? ctx.t('looks.inUse') : (mine ? ctx.m('yours') : '${fmt(price)} ${ctx.m('coins')}'),
          badgeTone: using || mine ? Tone.good : Tone.warn,
          preview: Container(
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: _pageOf(x.key, code),
          ),
          acts: [
            if (!using && mine)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: () async {
                  setState(() => _key = x.key);
                  return true;
                },
              ),
            if (!mine)
              LookAct(
                ctx.m('printBuy', {'coins': '${fmt(price)} ${ctx.m('coins')}'}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        setState(() => _key = x.key);
                        ctx.askBuy({'print': x.key});
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final owned = (ctx.data['prints'] as List? ?? const []).map((e) => '$e').toSet();
    final codes = ctx.codes;
    final code = codes.where((x) => x['_id'] == _cid).firstOrNull ?? codes.firstOrNull;
    final tpl = printTpls.firstWhere((x) => x.key == _key);
    final mine = owned.contains(_key);
    Widget field(String label, TextEditingController ctl, int max) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Field(label: label, controller: ctl, maxLength: max, onChanged: (_) => setState(() {})),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        qgHead(context, LucideIcons.printer, ctx.m('printTitle'), ctx.m('printSub')),
        mGap,
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final x in printTpls)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _open(x.key, owned, code),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _key == x.key ? c.brand : c.line, width: _key == x.key ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6)]),
                              child: FittedBox(child: _pageOf(x.key, code)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            x.name(ctx.lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          owned.contains(x.key)
                              ? Icon(LucideIcons.check, size: 13, color: c.good)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CoinIcon(size: 11),
                                    const SizedBox(width: 3),
                                    Text(fmt(n(ctx.prices['qr_print'])), style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        mGap,
        qgPanel([
          if (codes.isEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted(ctx.m('printNoCodes')))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: str(code?['_id']),
                isExpanded: true,
                decoration: InputDecoration(labelText: ctx.m('printPick'), isDense: true),
                items: [
                  for (final x in codes)
                    DropdownMenuItem(
                      value: str(x['_id']),
                      child: Text(str(x['name']), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _cid = v ?? ''),
              ),
            ),
          field(ctx.m('printText1'), _t1, 60),
          field(ctx.m('printText2'), _t2, 80),
          field(ctx.m('printText3'), _t3, 100),
          Text(ctx.m('printColor'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ColorRow(
            value: _color,
            colors: _swatches,
            customLabel: ctx.m('printColor'),
            saveLabel: ctx.m('save'),
            cancelLabel: ctx.m('cancel'),
            onChanged: (v) => setState(() => _color = v.toUpperCase()),
          ),
        ]),
        mGap,
        qgPanel([
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .1), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: AspectRatio(
                aspectRatio: tpl.landscape ? 297 / 210 : 210 / 297,
                child: FittedBox(
                  child: RepaintBoundary(key: _paper, child: _pageOf(_key, code)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (mine)
            Btn(
              ctx.m('printGo'),
              icon: LucideIcons.printer,
              busy: _busy,
              onTap: code == null || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await shareWidgets([_paper], (_) => 'print-$_key.png');
                      } catch (e) {
                        ctx.fail(e);
                      }
                      if (mounted) setState(() => _busy = false);
                    },
            )
          else
            GoldBtn(ctx.m('printBuy', {'coins': '${fmt(n(ctx.prices['qr_print']))} ${ctx.m('coins')}'}), onTap: ctx.readOnly ? null : () => ctx.askBuy({'print': _key})),
          const SizedBox(height: 8),
          Muted(ctx.m('printTip'), align: TextAlign.center),
        ]),
      ],
    );
  }
}

// one A4 page (in points)
class PrintPage extends StatelessWidget {
  final String tpl;
  final Json? code;
  final QgCtx ctx;
  final String t1, t2, t3;
  final Color color;
  const PrintPage({super.key, required this.tpl, required this.code, required this.ctx, required this.t1, required this.t2, required this.t3, required this.color});

  bool get _land => printTpls.where((x) => x.key == tpl).firstOrNull?.landscape ?? false;

  static final _ratios = <String, double>{};
  double get _ratio {
    if (code == null) return 1;
    return _ratios.putIfAbsent('${code!['_id']}|${code!['design']}|${code!['type']}', () {
      final a = codeArt(code!, size: 100, scanMe: ctx.scanMe);
      return a.height / a.width;
    });
  }

  Widget _q(double w) => SizedBox(
    width: w,
    height: w * _ratio,
    child: code == null
        ? AspectRatio(aspectRatio: 1, child: Container(color: const Color(0xFFEEEEEE)))
        : FittedBox(
            child: QrView(code: code!, logo: ctx.logo, size: 600, scanMe: ctx.scanMe),
          ),
  );

  Widget _logo(double size, {Color? border}) => ctx.logo.isEmpty
      ? const SizedBox.shrink()
      : Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: border == null ? null : Border.all(color: border, width: _mm(.8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image(image: netImage(ctx.logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        );

  TextStyle _t(double size, {Color color = _ink, FontWeight weight = FontWeight.w600, double height = 1.15}) =>
      TextStyle(fontSize: size, color: color, fontWeight: weight, height: height, fontFamily: 'KantumruyPro', fontFamilyFallback: const ['PlusJakartaSans']);

  Widget _text(String s, TextStyle st, {int lines = 2}) => s.isEmpty ? const SizedBox.shrink() : Text(s, textAlign: TextAlign.center, maxLines: lines, overflow: TextOverflow.ellipsis, style: st);

  List<Widget> _gap(List<Widget> xs, double g) => [
    for (final (i, x) in xs.where((x) => x is! SizedBox || x.width != 0.0).indexed) ...[if (i > 0) SizedBox(height: g), x],
  ];

  @override
  Widget build(BuildContext context) {
    final w = _mm(_land ? 297 : 210), h = _mm(_land ? 210 : 297);
    final business = str(ctx.business['name']);
    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Container(
        width: w,
        height: h,
        color: Colors.white,
        child: DefaultTextStyle(style: _t(12), child: _body(business)),
      ),
    );
  }

  Widget _fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

  Widget _body(String business) {
    const grey = Color(0xFF555555);
    switch (tpl) {
      case 'tent':
        Widget half() => Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _mm(9),
              child: ColoredBox(color: color),
            ),
            Positioned.fill(
              top: _mm(11),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _mm(20), vertical: _mm(3)),
                child: _fit(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _gap([
                      _logo(_mm(16)),
                      SizedBox(
                        width: _mm(240),
                        child: _text(t1, _t(30, color: color, weight: FontWeight.w800)),
                      ),
                      _q(_mm(58)),
                      SizedBox(width: _mm(240), child: _text(t2, _t(15))),
                      if (t3.isNotEmpty)
                        SizedBox(
                          width: _mm(240),
                          child: _text(t3, _t(11, color: grey)),
                        ),
                      _text(business, _t(10, color: const Color(0xFF888888)), lines: 1),
                    ], _mm(3)),
                  ),
                ),
              ),
            ),
          ],
        );
        return Column(
          children: [
            Expanded(child: RotatedBox(quarterTurns: 2, child: half())),
            const _Dashed(),
            Expanded(child: half()),
          ],
        );
      case 'poster':
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _mm(12),
              child: ColoredBox(color: color),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(_mm(18), _mm(16), _mm(18), _mm(18)),
              child: Center(
                child: _fit(
                  SizedBox(
                    width: _mm(174),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _logo(_mm(18)),
                            if (ctx.logo.isNotEmpty) SizedBox(width: _mm(4)),
                            Flexible(
                              child: _text(business, _t(16, color: color, weight: FontWeight.w700), lines: 1),
                            ),
                          ],
                        ),
                        SizedBox(height: _mm(12)),
                        _text(t1, _t(44, weight: FontWeight.w800, height: 1.1), lines: 3),
                        SizedBox(height: _mm(6)),
                        _text(t2, _t(20, color: const Color(0xFF444444))),
                        SizedBox(height: _mm(10)),
                        Container(
                          padding: EdgeInsets.all(_mm(6)),
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: _mm(2)),
                            borderRadius: BorderRadius.circular(_mm(8)),
                          ),
                          child: _q(_mm(104)),
                        ),
                        if (t3.isNotEmpty) ...[SizedBox(height: _mm(10)), _text(t3, _t(15, color: grey))],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'poster_bold':
        return Container(
          color: color,
          padding: EdgeInsets.all(_mm(16)),
          alignment: Alignment.center,
          child: _fit(
            SizedBox(
              width: _mm(178),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _gap([
                  _text(t1.toUpperCase(), _t(50, color: Colors.white, weight: FontWeight.w900, height: 1.05), lines: 3),
                  Container(
                    width: _mm(140),
                    padding: EdgeInsets.all(_mm(10)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_mm(10)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), offset: Offset(0, _mm(6)))],
                    ),
                    child: Column(children: _gap([_q(_mm(110)), _text(t2, _t(20, weight: FontWeight.w700))], _mm(5))),
                  ),
                  if (t3.isNotEmpty) _text(t3, _t(16, color: Colors.white.withValues(alpha: .92))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _logo(_mm(16), border: Colors.white),
                      if (ctx.logo.isNotEmpty) SizedBox(width: _mm(4)),
                      Flexible(
                        child: _text(business, _t(15, color: Colors.white, weight: FontWeight.w700), lines: 1),
                      ),
                    ],
                  ),
                ], _mm(8)),
              ),
            ),
          ),
        );
      case 'a5_card':
        Widget one() => Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: _mm(6)),
            ),
          ),
          padding: EdgeInsets.all(_mm(8)),
          child: Center(
            child: _fit(
              SizedBox(
                width: _mm(180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _gap([
                    _logo(_mm(14)),
                    _text(t1, _t(26, color: color, weight: FontWeight.w800)),
                    _q(_mm(70)),
                    _text(t2, _t(14)),
                    if (t3.isNotEmpty) _text(t3, _t(10, color: const Color(0xFF666666))),
                  ], _mm(3.5)),
                ),
              ),
            ),
          ),
        );
        return Column(
          children: [
            Expanded(child: one()),
            const _Dashed(),
            Expanded(child: one()),
          ],
        );
      case 'stickers':
        return _grid(
          3,
          4,
          (_) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: _mm(.6)),
              borderRadius: BorderRadius.circular(_mm(5)),
            ),
            padding: EdgeInsets.all(_mm(3)),
            child: _fit(
              SizedBox(
                width: _mm(52),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _gap([_q(_mm(42)), _text(t1, _t(11, color: color, weight: FontWeight.w800)), if (t2.isNotEmpty) _text(t2, _t(8, color: grey), lines: 1)], _mm(1.5)),
                ),
              ),
            ),
          ),
        );
      case 'round_stickers':
        return _grid(
          4,
          5,
          (_) => Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                constraints: BoxConstraints(maxWidth: _mm(46)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: _mm(.8)),
                ),
                child: LayoutBuilder(
                  builder: (_, box) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _q(box.maxWidth * .58),
                      SizedBox(height: _mm(1)),
                      SizedBox(
                        width: box.maxWidth * .74,
                        child: _text(t1, _t(7.5, color: color, weight: FontWeight.w800, height: 1.1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case 'wifi_card':
        return _grid(
          2,
          4,
          (_) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_mm(3)),
              border: Border(
                left: BorderSide(color: color, width: _mm(4)),
                top: BorderSide(color: const Color(0xFFBBBBBB), width: _mm(.5)),
                right: BorderSide(color: const Color(0xFFBBBBBB), width: _mm(.5)),
                bottom: BorderSide(color: const Color(0xFFBBBBBB), width: _mm(.5)),
              ),
            ),
            padding: EdgeInsets.all(_mm(5)),
            child: Row(
              children: [
                _q(_mm(38)),
                SizedBox(width: _mm(5)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _t(15, color: color, weight: FontWeight.w800),
                      ),
                      SizedBox(height: _mm(1.5)),
                      Text(t2, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(10)),
                      if (t3.isNotEmpty) ...[
                        SizedBox(height: _mm(1.5)),
                        Text(
                          t3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(9, color: const Color(0xFF666666)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case 'badge':
        return _grid(
          2,
          2,
          (_) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDDDDD), width: _mm(.5)),
              borderRadius: BorderRadius.circular(_mm(6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: color,
                  padding: EdgeInsets.all(_mm(5)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _logo(_mm(11), border: Colors.white),
                      if (ctx.logo.isNotEmpty) SizedBox(width: _mm(3)),
                      Flexible(
                        child: _text(business, _t(12, color: Colors.white, weight: FontWeight.w700), lines: 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(_mm(4), _mm(4), _mm(4), _mm(6)),
                    child: _fit(
                      SizedBox(
                        width: _mm(84),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _gap([
                            _text(t1, _t(24, weight: FontWeight.w800)),
                            _text(t2, _t(13, color: color, weight: FontWeight.w700)),
                            _q(_mm(44)),
                            if (t3.isNotEmpty) _text(t3, _t(9, color: const Color(0xFF666666))),
                          ], _mm(3)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return Center(child: _q(_mm(120)));
    }
  }

  Widget _grid(int cols, int rows, Widget Function(int i) cell) => Padding(
    padding: EdgeInsets.all(_mm(8)),
    child: Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: _mm(4)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < cols; col++) ...[if (col > 0) SizedBox(width: _mm(4)), Expanded(child: cell(r * cols + col))],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _Dashed extends StatelessWidget {
  const _Dashed();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, .5), Offset(x + 4, .5), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
