import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/tx_sheet.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../mart/mart_common.dart' show scanBarcode;
import 'data.dart';

// Wallet: balance, 3 buttons (buy coins · top-up card · scan the card QR), history
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});
  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  num? _balance;
  List<Json> _rows = [];
  int _page = 1, _pages = 1;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int p) async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiProvider).get('${Api.user}/wallet', {'page': p, 'limit': 20});
      final d = obj(r['data']);
      final pg = obj(r['pagination']);
      setState(() {
        _balance = n(d['balance']);
        _rows = p == 1 ? objs(d['transactions']) : [..._rows, ...objs(d['transactions'])];
        _page = p;
        _pages = n(pg['totalPages']).toInt();
        _error = '';
      });
      if (p == 1) ref.read(sessionProvider.notifier).patch({'coin_balance': _balance});
    } on ApiError catch (e) {
      setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _linkDone = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // opened from a top-up card QR: /app/wallet?redeem=123456789012 → /o/wallet?redeem=…
    if (_linkDone) return;
    _linkDone = true;
    final code = GoRouterState.of(context).uri.queryParameters['redeem'] ?? '';
    if (RegExp(r'^\d{12}$').hasMatch(code)) WidgetsBinding.instance.addPostFrameCallback((_) => _openCard(code));
  }

  // the 12 digits from a scanned card QR (a redeem link) or a typed / pasted code
  static String? cardCodeOf(String v) {
    final m = RegExp(r'redeem=(\d{12})').firstMatch(v);
    if (m != null) return m[1];
    final d = v.replaceAll(RegExp(r'\D'), '');
    return d.length == 12 ? d : null;
  }

  Future<void> _openCard([String code = '', bool auto = false]) async {
    final r = await showModalBottomSheet<Json>(
      context: context,
      useRootNavigator: true, // above the bottom bar
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RedeemSheet(code: code, auto: auto),
    );
    if (r == null || !mounted) return;
    setState(() => _balance = n(r['balance']));
    _load(1);
    coinsChanged(ref);
    toast(context, ref.read(tProvider)('messages.redeemOk', {'coins': fmt(r['amount'])}));
  }

  Future<void> _scan() async {
    final t = ref.read(tProvider);
    final v = await scanBarcode(context, t);
    if (v == null || v.isEmpty || !mounted) return;
    final code = cardCodeOf(v);
    if (code == null) return toast(context, t('wallet.notCard'));
    _openCard(code, true); // scanned = the card is in hand: redeem straight away
  }

  String _label(Json x, T t) => switch (str(x['type'])) {
    'signup_bonus' => t('messages.txBonus'),
    'spend' => t('messages.txSpend'),
    'card_redeem' => t('messages.txCard'),
    _ => x['direction'] == 'in' ? t('messages.txIn') : t('messages.txOut'),
  };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return TabPage(
      onRefresh: () => _load(1),
      children: [
        // balance
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(24), boxShadow: c.orangeShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.coins, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t('messages.coinBalance'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _balance == null
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skel(w: 110, h: 34))
                  : Text(
                      fmt(_balance),
                      style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
              Text(t('messages.walletEvery'), style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13.5)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // three big buttons: buy coins online · type a top-up card code · scan the card QR
        Row(
          children: [
            _Action(icon: LucideIcons.coins, label: t('wallet.buy'), onTap: () => context.push('/o/coins')),
            const SizedBox(width: 10),
            _Action(icon: LucideIcons.creditCard, label: t('wallet.card'), onTap: () => _openCard()),
            const SizedBox(width: 10),
            _Action(icon: LucideIcons.scanLine, label: t('wallet.scan'), onTap: _scan),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecHead(t('sa.history')),
              if (_error.isNotEmpty) Alert(_error),
              if (_loading && _rows.isEmpty && _error.isEmpty) const SkelList(),
              if (!_loading && _error.isEmpty && _rows.isEmpty) Muted(t('sa.nothingYet')),
              for (var i = 0; i < _rows.length; i++) TxRow(x: _rows[i], label: _label(_rows[i], t), t: t, last: i == _rows.length - 1),
              if (_page < _pages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Btn(t('messages.loadMore'), kind: BtnKind.ghost, small: true, busy: _loading, onTap: () => _load(_page + 1)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// one line of coin history: [Spent] New business: Shop QR … −25 / Balance: 50
class TxRow extends StatelessWidget {
  final Json x;
  final String label;
  final T t;
  final bool last;
  final String? sub;
  const TxRow({super.key, required this.x, required this.label, required this.t, this.last = false, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final inn = x['direction'] == 'in' || x['type'] == 'generate' || x['type'] == 'signup_bonus';
    final type = str(x['type']);
    final tone = switch (type) {
      'signup_bonus' => Tone.good,
      'spend' => Tone.warn,
      'card_redeem' => Tone.lime,
      'generate' => Tone.brand,
      _ => inn ? Tone.good : Tone.muted,
    };
    final biz = obj(x['business']);
    return InkWell(
      onTap: () => showTxSheet(context, x, t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Chip2(label, tone: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txTitle(x, t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  Text(
                    sub ??
                        '${fmtDate(x['created_date'], time: true, lang: t.lang)}${biz.isNotEmpty ? ' · ${biz['name']}' : ''}${str(x['payment_method']).isNotEmpty ? ' · ${x['payment_method']}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inn ? '+' : '−'}${fmt(x['amount'])}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: inn ? c.good : c.danger),
                ),
                if (x['balance_after'] != null) Text('${t('sa.balance')}: ${fmt(x['balance_after'])}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// "Top up with a card" — the 12-digit code from a BizHub top-up card (RedeemCard.jsx)
class _RedeemSheet extends ConsumerStatefulWidget {
  final String code;
  final bool auto; // scanned: redeem at once
  const _RedeemSheet({this.code = '', this.auto = false});
  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<_RedeemSheet> {
  late final _code = TextEditingController(text: _pretty(widget.code));

  static String _pretty(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length != 12) return '';
    return [for (var i = 0; i < 12; i += 4) d.substring(i, i + 4)].join(' ');
  }

  @override
  void initState() {
    super.initState();
    if (widget.auto && _digits.length == 12) WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
  }

  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _digits => _code.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _redeem() async {
    final t = ref.read(tProvider);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/wallet/redeem', {'code': _digits});
      if (mounted) Navigator.pop(context, obj(r['data']));
    } on ApiError catch (e) {
      setState(() => _error = e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
                child: const Icon(LucideIcons.creditCard, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('messages.cardTitle'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Muted(t('messages.cardSub')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Field(
            controller: _code,
            hint: t('messages.cardCodePh'),
            keyboard: TextInputType.number,
            maxLength: 14,
            onChanged: (v) {
              // 1234 5678 9012
              final d = v.replaceAll(RegExp(r'\D'), '');
              final f = [for (var i = 0; i < d.length; i += 4) d.substring(i, i + 4 > d.length ? d.length : i + 4)].join(' ');
              if (f != v) {
                _code.value = TextEditingValue(
                  text: f,
                  selection: TextSelection.collapsed(offset: f.length),
                );
              }
              setState(() {});
            },
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (_error.isNotEmpty) ...[const SizedBox(height: 10), Alert(_error)],
          const SizedBox(height: 12),
          Btn(_busy ? t('messages.redeeming') : t('messages.redeemBtn'), busy: _busy, expand: true, onTap: _digits.length == 12 ? _redeem : null),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              final clip = await Clipboard.getData('text/plain');
              final d = (clip?.text ?? '').replaceAll(RegExp(r'\D'), '');
              if (d.length >= 12) {
                final s = d.substring(0, 12);
                _code.text = '${s.substring(0, 4)} ${s.substring(4, 8)} ${s.substring(8)}';
                setState(() {});
              }
            },
            icon: Icon(LucideIcons.clipboardPaste, size: 16, color: c.brandInk),
            label: Text(
              MaterialLocalizations.of(context).pasteButtonLabel,
              style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// one of the 3 big wallet buttons
class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
