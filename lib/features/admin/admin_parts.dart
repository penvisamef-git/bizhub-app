import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';

String? _who(Ref ref) => ref.watch(sessionProvider.select((s) => s?.token));

// GET /api/admin/overview — the super admin dashboard
final overviewProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  final d = obj((await ref.read(apiProvider).get('${Api.admin}/overview'))['data']);
  ref.read(treasuryProvider.notifier).state = n(obj(d['coins'])['treasury']);
  return d;
});

// GET /api/admin/platform/badges — { orders, chats } waiting
final badgesProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  return obj((await ref.read(apiProvider).get('${Api.admin}/platform/badges'))['data']);
});

// GET /api/admin/coins/summary
final coinSummaryProvider = FutureProvider<Json>((ref) async {
  _who(ref);
  final d = obj((await ref.read(apiProvider).get('${Api.admin}/coins/summary'))['data']);
  ref.read(treasuryProvider.notifier).state = n(d['treasury_balance']);
  return d;
});

void coinsMoved(WidgetRef ref) {
  ref.invalidate(overviewProvider);
  ref.invalidate(coinSummaryProvider);
}

String walletName(Object? customer, T t) {
  final c = obj(customer);
  if (c.isEmpty) return t('sa.treasuryWallet');
  return str(c['name']).isNotEmpty ? str(c['name']) : str(c['email']);
}

// ring chart 0–100 (SuperDashboardPage Donut)
class Donut extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color color, track;
  final Color? textColor;
  const Donut({super.key, required this.value, this.size = 96, this.stroke = 11, required this.color, required this.track, this.textColor});
  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, x, _) => CustomPaint(
          painter: _DonutPainter(x, stroke, color, track),
          child: Center(
            child: Text(
              '${v.round()}%',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .2, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double v, stroke;
  final Color color, track;
  _DonutPainter(this.v, this.stroke, this.color, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v / 100, false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.v != v || o.color != color;
}

// a person / business line: initial · name · sub · side
class ListRow extends StatelessWidget {
  final String name, sub;
  final Widget? side;
  final VoidCallback? onTap;
  final Widget? lead;
  final bool last;
  const ListRow({super.key, required this.name, required this.sub, this.side, this.onTap, this.lead, this.last = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            lead ?? Avatar(name: name, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (side != null) ...[const SizedBox(width: 8), side!],
          ],
        ),
      ),
    );
  }
}

Widget statusChip(bool on, T t) => Chip2(on ? t('sa.active') : t('sa.suspended'), tone: on ? Tone.good : Tone.danger);

// search box that waits a moment before asking the API
class SearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  const SearchBox({super.key, required this.hint, required this.onSearch});
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _c = TextEditingController();
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Field(
    controller: _c,
    hint: widget.hint,
    icon: LucideIcons.search,
    onChanged: (v) {
      _t?.cancel();
      _t = Timer(const Duration(milliseconds: 350), () => widget.onSearch(v.trim()));
    },
  );
}

class Segs extends StatelessWidget {
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onTap;
  const Segs({super.key, required this.items, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(it.$2),
                selected: value == it.$1,
                onSelected: (_) => onTap(it.$1),
                showCheckmark: false,
                selectedColor: c.solid,
                backgroundColor: c.card,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: value == it.$1 ? c.onSolid : c.ink),
                side: BorderSide(color: c.line),
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Generate coins / Transfer coins (parts.jsx modals)
Future<bool?> showGenerate(BuildContext context) => showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _GenerateSheet());
Future<bool?> showTransfer(BuildContext context, {Json? to}) => showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _TransferSheet(to: to));

class _GenerateSheet extends ConsumerStatefulWidget {
  const _GenerateSheet();
  @override
  ConsumerState<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends ConsumerState<_GenerateSheet> {
  final _amount = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  String _error = '';
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final t = ref.read(tProvider);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(apiProvider).post('${Api.admin}/coins/generate', {'amount': int.tryParse(_amount.text.replaceAll(',', '')) ?? 0, 'note': _note.text.trim()});
      coinsMoved(ref);
      if (mounted) {
        toast(context, t('sa.generatedOk'));
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('sa.generateCoins'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Muted(t('sa.generateHint')),
          const SizedBox(height: 16),
          Field(label: t('sa.amount'), controller: _amount, keyboard: TextInputType.number, prefix: const Padding(padding: EdgeInsets.all(12), child: CoinIcon(size: 20))),
          const SizedBox(height: 12),
          Field(label: t('sa.note'), hint: t('sa.noteHint'), controller: _note, maxLength: 300),
          if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
          const SizedBox(height: 18),
          Btn(t('sa.generateCoins'), icon: LucideIcons.circlePlus, busy: _busy, onTap: _go),
        ],
      ),
    );
  }
}

class _TransferSheet extends ConsumerStatefulWidget {
  final Json? to;
  const _TransferSheet({this.to});
  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController(), _note = TextEditingController(), _ref = TextEditingController(), _usd = TextEditingController(), _q = TextEditingController();
  late Json? _customer = widget.to;
  bool _toCustomer = true; // treasury → customer (swap = customer → treasury)
  String _method = '';
  List<Json> _found = [];
  bool _busy = false;
  String _error = '';
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    for (final c in [_amount, _note, _ref, _usd, _q]) {
      c.dispose();
    }
    super.dispose();
  }

  void _search(String q) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().isEmpty) return setState(() => _found = []);
      try {
        final r = await ref.read(apiProvider).get('${Api.admin}/customers', {'q': q.trim(), 'limit': 6});
        if (mounted) setState(() => _found = objs(r['data']));
      } catch (_) {}
    });
  }

  Future<void> _go() async {
    final t = ref.read(tProvider);
    if (_customer == null) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final cid = str(_customer!['_id']);
    try {
      await ref.read(apiProvider).post('${Api.admin}/coins/transfer', {
        'from': _toCustomer ? 'treasury' : cid,
        'to': _toCustomer ? cid : 'treasury',
        'amount': int.tryParse(_amount.text.replaceAll(',', '')) ?? 0,
        'note': _note.text.trim(),
        if (_method.isNotEmpty) 'payment': {'method': _method, 'reference': _ref.text.trim(), 'amount_usd': _usd.text.trim().isEmpty ? null : num.tryParse(_usd.text.trim())},
      });
      coinsMoved(ref);
      if (mounted) {
        toast(context, t('sa.transferredOk'));
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final treasury = ref.watch(treasuryProvider);
    Widget wallet(String title, String sub, IconData icon) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.brandInk),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final tre = wallet(t('sa.treasuryWallet'), '${t('sa.balance')}: ${fmt(treasury)}', LucideIcons.landmark);
    final cus = wallet(_customer == null ? t('sa.pickCustomer') : walletName(_customer, t), _customer == null ? '' : '${t('sa.balance')}: ${fmt(_customer!['coin_balance'])}', LucideIcons.userRound);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('sa.transferCoins'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Muted(t('sa.transferHint')),
            const SizedBox(height: 14),
            Row(
              children: [
                _toCustomer ? tre : cus,
                IconButton(tooltip: t('sa.swap'), onPressed: () => setState(() => _toCustomer = !_toCustomer), icon: const Icon(LucideIcons.arrowRightLeft, size: 18)),
                _toCustomer ? cus : tre,
              ],
            ),
            const SizedBox(height: 12),
            if (widget.to == null) ...[
              Field(controller: _q, hint: t('sa.pickCustomer'), icon: LucideIcons.search, onChanged: _search),
              for (final x in _found)
                ListRow(
                  name: str(x['name']).isNotEmpty ? str(x['name']) : str(x['email']),
                  sub: [str(x['email']), str(x['phone'])].where((e) => e.isNotEmpty).join(' · '),
                  side: Text(fmt(x['coin_balance']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => setState(() {
                    _customer = x;
                    _found = [];
                  }),
                ),
              const SizedBox(height: 12),
            ],
            Field(label: t('sa.amount'), controller: _amount, keyboard: TextInputType.number, prefix: const Padding(padding: EdgeInsets.all(12), child: CoinIcon(size: 20))),
            const SizedBox(height: 12),
            Field(label: t('sa.note'), hint: t('sa.noteHint'), controller: _note, maxLength: 300),
            const SizedBox(height: 12),
            Text(t('sa.paymentMethod'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Segs(
              items: [('', t('sa.paymentNone')), for (final m in ['KHQR', 'ABA', 'ACLEDA', 'Wing', 'Bank', 'Card', 'Cash', 'Other']) (m, m)],
              value: _method,
              onTap: (v) => setState(() => _method = v),
            ),
            if (_method.isNotEmpty) ...[
              const SizedBox(height: 12),
              Field(label: t('sa.reference'), controller: _ref, maxLength: 120),
              const SizedBox(height: 12),
              Field(label: t('sa.amountUsd'), controller: _usd, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ],
            if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
            const SizedBox(height: 18),
            Btn(t('sa.transferCoins'), icon: LucideIcons.arrowRightLeft, busy: _busy, onTap: _customer == null ? null : _go),
          ],
        ),
      ),
    );
  }
}
