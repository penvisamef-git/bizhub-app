import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../mart/mart_kit.dart' show DayField;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'admin_customers.dart';
import 'admin_parts.dart';

// Super admin → Coins → Top-up cards (CardsPanel.jsx + lib/topupCard.js): phone-card style QR + 12-digit code
String formatCode(Object? code) => str(code).replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ');
String redeemLink(Object? code) => '${Config.siteUrl}/app/wallet?redeem=$code';

bool _expired(Json c) => c['status'] == 'active' && c['expires_at'] != null && (DateTime.tryParse(str(c['expires_at']))?.isBefore(DateTime.now()) ?? false);
String _statusOf(Json c) => _expired(c) ? 'expired' : str(c['status']);

class AdminCardsPage extends ConsumerStatefulWidget {
  const AdminCardsPage({super.key});
  @override
  ConsumerState<AdminCardsPage> createState() => _AdminCardsPageState();
}

class _AdminCardsPageState extends ConsumerState<AdminCardsPage> with PagedLoad {
  String _q = '', _status = '';
  @override
  String get path => '${Api.admin}/coins/cards';
  @override
  Map<String, dynamic> get query => {'status': _status, 'q': _q.replaceAll(' ', ''), 'limit': 20};

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> _create() async {
    final t = ref.read(tProvider);
    final made = await showModalBottomSheet<List<Json>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _CreateSheet());
    if (made == null || !mounted) return;
    toast(context, t('sa.cardsCreated'));
    coinsMoved(ref);
    setState(() => _status = '');
    load(reset: true);
    _show(made, title: '${t('sa.newCards')} · ${made.length}');
  }

  void _show(List<Json> cards, {required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CardsSheet(cards: cards, title: title),
    );
  }

  Future<void> _delete(Json card) async {
    final t = ref.read(tProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('sa.deleteCard')),
        content: Text('${formatCode(card['code'])} · ${fmt(card['amount'])}\n\n${t('sa.deleteCardConfirm')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('sa.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.c.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('sa.deleteCard')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).delete('${Api.admin}/coins/cards/${card['_id']}');
      if (mounted) toast(context, t('sa.cardDeleted'));
      coinsMoved(ref);
      load(reset: true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final sum = obj(lastResponse['summary']);
    Widget chip(String key, {bool coins = true}) {
      final x = obj(sum[key]);
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: key == 'active' ? c.active : c.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t('sa.cardStatus.$key')}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(fmt(x['count']), style: const TextStyle(fontWeight: FontWeight.w800)),
            if (coins) ...[Text(' · ${fmt(x['coins'])} '), const CoinIcon(size: 14)],
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: SubPage(
        title: t('sa.tabCards'),
        onRefresh: () => load(reset: true),
        actions: [RoundBtn(LucideIcons.plus, size: 42, tip: t('sa.createCards'), onTap: _create)],
        children: [
          if (sum.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [chip('active'), chip('redeemed'), chip('cancelled', coins: false)]),
            ),
          const SizedBox(height: 12),
          SearchBox(
            hint: t('sa.searchCode'),
            onSearch: (v) {
              _q = v;
              load(reset: true);
            },
          ),
          const SizedBox(height: 10),
          Segs(
            items: [
              ('', t('sa.all')),
              for (final k in ['active', 'redeemed', 'cancelled', 'expired']) (k, t('sa.cardStatus.$k')),
            ],
            value: _status,
            onTap: (v) {
              setState(() => _status = v);
              load(reset: true);
            },
          ),
          const SizedBox(height: 12),
          Btn(t('sa.createCards'), icon: LucideIcons.plus, expand: true, onTap: _create),
          const SizedBox(height: 12),
          if (p.error.isNotEmpty) Alert(p.error),
          if (p.page == 0 && p.loading) const Panel(child: SkelList()),
          if (p.page > 0 && p.rows.isEmpty) Panel(child: Muted(t('sa.nothingYet'))),
          for (final card in p.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CardRow(
                card: card,
                t: t,
                onView: () => _show([card], title: '${fmt(card['amount'])} · ${formatCode(card['code'])}'),
                onDelete: () => _delete(card),
              ),
            ),
          if (p.page > 0 && p.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final Json card;
  final T t;
  final VoidCallback onView, onDelete;
  const _CardRow({required this.card, required this.t, required this.onView, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = _statusOf(card);
    final by = obj(card['redeemed_by']);
    final active = card['status'] == 'active';
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: active ? onView : null,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(gradient: active && st != 'expired' ? c.gradient : null, color: active && st != 'expired' ? null : c.chip, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(
              fmt(card['amount']),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: active && st != 'expired' ? Colors.white : c.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCode(card['code']),
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: .5),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip2(
                      t('sa.cardStatus.$st'),
                      tone: switch (st) {
                        'active' => Tone.good,
                        'redeemed' => Tone.brand,
                        'expired' => Tone.warn,
                        _ => Tone.muted,
                      },
                    ),
                    if (card['expires_at'] != null) Text('≤ ${fmtDate(card['expires_at'], lang: t.lang)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (str(card['note']).isNotEmpty) str(card['note']),
                    if (by.isNotEmpty)
                      '${t('sa.usedBy')}: ${by['name']} · ${fmtDate(card['redeemed_date'], time: true, lang: t.lang)}'
                    else
                      '${t('sa.created')}: ${fmtDate(card['created_date'], time: true, lang: t.lang)}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (active) ...[
            IconButton(onPressed: onView, tooltip: t('sa.view'), icon: const Icon(LucideIcons.eye, size: 19)),
            IconButton(
              onPressed: onDelete,
              tooltip: t('sa.deleteCard'),
              icon: Icon(LucideIcons.trash2, size: 19, color: c.danger),
            ),
          ],
        ],
      ),
    );
  }
}

// make cards: amount × quantity, taken from the treasury
class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet();
  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _amount = TextEditingController(text: '100');
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  String _expiry = '', _err = '';
  bool _busy = false;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.admin}/coins/cards', {
        'amount': n(_amount.text),
        'quantity': n(_qty.text),
        'note': _note.text.trim(),
        if (_expiry.isNotEmpty) 'expires_at': '${_expiry}T23:59:59+07:00',
      });
      if (mounted) Navigator.pop(context, objs(r['data']));
    } on ApiError catch (e) {
      setState(() {
        _busy = false;
        _err = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final treasury = ref.watch(treasuryProvider);
    final total = n(_amount.text) * n(_qty.text);
    final over = treasury != null && total > treasury;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('sa.createCards'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Muted(t('sa.cardHint')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in [50, 100, 200, 500, 1000]) ChoiceChip(label: Text(fmt(v)), selected: n(_amount.text) == v, onSelected: (_) => setState(() => _amount.text = '$v')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Field(label: t('sa.cardAmount'), controller: _amount, keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Field(label: t('sa.cardQuantity'), controller: _qty, keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DayField(label: t('sa.cardExpiry'), value: _expiry, first: tomorrow, onChanged: (v) => setState(() => _expiry = v)),
            if (_expiry.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _expiry = ''), child: const Text('×')),
              ),
            const SizedBox(height: 12),
            Field(label: t('sa.note'), controller: _note, maxLength: 300),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: over ? c.dangerBg : c.bg2, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t('sa.cardTotal'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const CoinIcon(size: 18),
                          const SizedBox(width: 4),
                          Text(
                            fmt(total),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: over ? c.danger : c.ink),
                          ),
                        ],
                      ),
                      if (treasury != null) Text('${t('sa.treasury')}: ${fmt(treasury)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
            const SizedBox(height: 14),
            Btn(_busy ? t('sa.saving') : t('sa.createCards'), icon: LucideIcons.creditCard, busy: _busy, onTap: total < 1 ? null : _go),
          ],
        ),
      ),
    );
  }
}

// card pictures with share / copy code
class _CardsSheet extends ConsumerStatefulWidget {
  final List<Json> cards;
  final String title;
  const _CardsSheet({required this.cards, required this.title});
  @override
  ConsumerState<_CardsSheet> createState() => _CardsSheetState();
}

class _CardsSheetState extends ConsumerState<_CardsSheet> {
  late final _keys = [for (final _ in widget.cards) GlobalKey()];
  bool _sharing = false;

  Future<void> _share(List<int> idx) async {
    setState(() => _sharing = true);
    try {
      await shareWidgets([for (final i in idx) _keys[i]], (k) {
        final card = widget.cards[idx[k]];
        return 'bizhub-card-${card['amount']}-${str(card['code']).substring((str(card['code']).length - 4).clamp(0, 99))}.png';
      });
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final many = widget.cards.length > 1;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .95,
      builder: (_, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
                if (many) Btn(t('sa.printAll'), icon: LucideIcons.share2, small: true, busy: _sharing, onTap: () => _share([for (var i = 0; i < widget.cards.length; i++) i])),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: widget.cards.length,
              itemBuilder: (_, i) {
                final card = widget.cards[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      RepaintBoundary(
                        key: _keys[i],
                        child: TopupCardArt(card: card),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Btn(t('sa.share'), icon: LucideIcons.share2, small: true, onTap: _sharing ? null : () => _share([i])),
                          const SizedBox(width: 8),
                          Btn(
                            t('sa.copyCode'),
                            icon: LucideIcons.copy,
                            kind: BtnKind.ghost,
                            small: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: str(card['code'])));
                              toast(context, t('sa.copied'));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Btn(t('sa.done'), expand: true, kind: BtnKind.ghost, onTap: () => Navigator.pop(context)),
            ),
          ),
        ],
      ),
    );
  }
}

// the card picture (drawCardImage): orange header + amount, QR to redeem, the code
class TopupCardArt extends StatelessWidget {
  final Json card;
  const TopupCardArt({super.key, required this.card});
  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF16171B), grey = Color(0xFF6A6E7A);
    final exp = card['expires_at'] == null ? '' : 'Valid until ${fmtDate(card['expires_at'])}';
    return Container(
      width: 320,
      color: const Color(0xFFECEEF2),
      padding: const EdgeInsets.all(18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x2416171B), blurRadius: 18, offset: Offset(0, 7))],
        ),
        child: Column(
          children: [
            Container(
              height: 148,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE0581A), Color(0xFFE8701A), Color(0xFFE08A1A)], stops: [0, .55, 1], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -45,
                    top: -45,
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: .12), width: 16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Logo(height: 20, white: true),
                            Spacer(),
                            Text(
                              'TOP-UP CARD',
                              style: TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: .6),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              fmt(card['amount']),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 46, height: 1),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'coins',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'កាក់ BizHub',
                          style: TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE6E8EE), width: 1.5),
              ),
              child: QrImageView(
                data: redeemLink(card['code']),
                size: 178,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ink),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'CODE · លេខកូដ',
              style: TextStyle(color: grey, fontWeight: FontWeight.w700, fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              formatCode(card['code']),
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 24, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Scan with your phone camera, or open BizHub → Wallet → enter the code',
                textAlign: TextAlign.center,
                style: TextStyle(color: grey, fontWeight: FontWeight.w600, fontSize: 8),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              ['ស្កេន ឬបញ្ចូលលេខកូដ ក្នុង BizHub', exp].where((e) => e.isNotEmpty).join('  ·  '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: grey, fontWeight: FontWeight.w600, fontSize: 8.5),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
