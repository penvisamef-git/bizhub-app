import 'dart:convert';

import 'package:dio/dio.dart' show Dio, FormData, MultipartFile, Options, ResponseType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'data.dart';

// Buy coins (dashboard/client/licenses/CoinShop.jsx): pick packages → pay by bank transfer → send the screenshot.
// The BizHub team checks the bank and adds the coins.
class CoinShopPage extends ConsumerStatefulWidget {
  const CoinShopPage({super.key});
  @override
  ConsumerState<CoinShopPage> createState() => _CoinShopPageState();
}

class _CoinShopPageState extends ConsumerState<CoinShopPage> {
  final Map<String, int> _cart = {};

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final async = ref.watch(coinShopProvider);
    final d = async.valueOrNull;
    final packs = objs(d?['packages']);
    final lines = packs.where((p) => (_cart[str(p['key'])] ?? 0) > 0).toList();
    num coins = 0, bonus = 0, usdTotal = 0;
    for (final p in lines) {
      final q = _cart[str(p['key'])]!;
      coins += n(p['coins']) * q;
      bonus += (n(p['coins']) * n(p['bonus_pct']) / 100).floor() * q;
      usdTotal += n(p['usd']) * q;
    }
    final orders = objs(d?['orders']);
    return SubPage(
      title: t('coin.title'),
      onRefresh: () async {
        ref.invalidate(coinShopProvider);
        try {
          await ref.read(coinShopProvider.future);
        } catch (_) {}
      },
      bottom: lines.isEmpty
          ? null
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${t('coin.youGet')} ${fmt(coins + bonus)} ${t('coin.coins')}', style: Theme.of(context).textTheme.bodySmall),
                      Text(usd(usdTotal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Btn(
                  t('coin.checkout'),
                  icon: LucideIcons.shoppingCart,
                  onTap: () async {
                    final sent = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _Checkout(banks: objs(d?['banks']), hotline: obj(d?['hotline']), cart: Map.of(_cart), total: usdTotal, coins: coins + bonus),
                    );
                    if (sent == true) {
                      setState(_cart.clear);
                      ref.invalidate(coinShopProvider);
                    }
                  },
                ),
              ],
            ),
      children: [
        Muted(t('coin.sub')),
        const SizedBox(height: 14),
        if (async.hasError && d == null) LoadError(text: t('sa.loadFail'), retry: t('app.retry'), onRetry: () => ref.invalidate(coinShopProvider)),
        if (d == null && !async.hasError) const Panel(child: SkelList()),
        for (final p in packs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PackCard(
              p: p,
              qty: _cart[str(p['key'])] ?? 0,
              t: t,
              onQty: (q) => setState(() => q <= 0 ? _cart.remove(str(p['key'])) : _cart[str(p['key'])] = q.clamp(1, 20)),
            ),
          ),
        if (d != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.creditCard, size: 15, color: c.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(t('coin.soon'), style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 20),
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SecHead(t('coin.myOrders'), trailing: n(d['waiting']) > 0 ? Chip2(t('coin.waiting', {'n': d['waiting']}), tone: Tone.warn) : null),
                if (orders.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted(t('coin.noOrders'))),
                for (var i = 0; i < orders.length; i++) _OrderRow(o: orders[i], t: t, last: i == orders.length - 1),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  final Json p;
  final int qty;
  final T t;
  final ValueChanged<int> onQty;
  const _PackCard({required this.p, required this.qty, required this.t, required this.onQty});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = n(p['bonus_pct']);
    final free = (n(p['coins']) * pct / 100).floor();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: qty > 0 ? c.brand : Colors.transparent, width: 1.6),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        children: [
          const CoinIcon(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: fmt(p['coins']),
                    children: [
                      TextSpan(
                        text: ' ${t('coin.coins')}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(usd(p['usd']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (free > 0) Chip2(t('coin.free', {'n': fmt(free)}), tone: Tone.good, icon: LucideIcons.gift),
                  ],
                ),
              ],
            ),
          ),
          if (qty == 0)
            Btn(t('coin.add'), small: true, icon: LucideIcons.plus, onTap: () => onQty(1))
          else
            Container(
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  IconButton(onPressed: () => onQty(qty - 1), icon: const Icon(LucideIcons.minus, size: 16)),
                  Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(onPressed: qty >= 20 ? null : () => onQty(qty + 1), icon: const Icon(LucideIcons.plus, size: 16)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Json o;
  final T t;
  final bool last;
  const _OrderRow({required this.o, required this.t, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = str(o['status']);
    final tone = switch (st) {
      'approved' => Tone.good,
      'rejected' => Tone.danger,
      'pending' => Tone.warn,
      _ => Tone.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o['no']} · ${fmt(o['total_coins'])} ${t('coin.coins')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${usd(o['usd'])} · ${obj(o['bank'])['name'] ?? ''} · ${fmtDate(o['created_date'], time: true, lang: t.lang)}', style: Theme.of(context).textTheme.bodySmall),
                if (st == 'rejected' && str(o['reason']).isNotEmpty) Text(str(o['reason']), style: TextStyle(color: c.danger, fontSize: 12.5)),
              ],
            ),
          ),
          Chip2(t.or('coin.status.$st', st), tone: tone),
        ],
      ),
    );
  }
}

// bank → QR → screenshot → send
class _Checkout extends ConsumerStatefulWidget {
  final List<Json> banks;
  final Json hotline;
  final Map<String, int> cart;
  final num total, coins;
  const _Checkout({required this.banks, required this.hotline, required this.cart, required this.total, required this.coins});
  @override
  ConsumerState<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<_Checkout> {
  late String _bank = widget.banks.isEmpty ? '' : str(widget.banks.first['key']);
  final _ref = TextEditingController(), _note = TextEditingController();
  XFile? _proof;
  bool _busy = false, _sent = false;
  String _error = '';

  @override
  void dispose() {
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = ref.read(tProvider);
    if (_proof == null) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final bytes = await _proof!.readAsBytes();
      final form = FormData.fromMap({
        'items': jsonEncode([
          for (final e in widget.cart.entries) {'key': e.key, 'qty': e.value},
        ]),
        'bank': _bank,
        'reference': _ref.text.trim(),
        'note': _note.text.trim(),
        'proof': MultipartFile.fromBytes(bytes, filename: _proof!.name.isEmpty ? 'proof.jpg' : _proof!.name),
      });
      await ref.read(apiProvider).post('${Api.user}/coin-orders', form);
      setState(() => _sent = true);
    } on ApiError catch (e) {
      setState(() => _error = e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // the QR full size: pinch to zoom, tap to close
  void _viewQr(String url) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xE60A0A0E),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image(image: netImage(url), fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 12,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF)),
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // save the QR to the phone (share sheet → Save image), then scan it from the gallery in the bank app
  Future<void> _saveQr(String url, String name) async {
    try {
      final r = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(r.data ?? const []);
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'image/jpeg', name: '$name.jpg')]));
    } catch (_) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final bank = widget.banks.where((b) => str(b['key']) == _bank).firstOrNull;
    // a QR picture with exactly this amount in it? then the customer just scans and pays
    final fixed = bank == null ? null : objs(bank['amount_qrs']).where((q) => (n(q['usd']) * 100).round() == (widget.total * 100).round()).firstOrNull;
    final qrUrl = fixed != null ? str(fixed['qr']) : (bank == null ? '' : str(bank['qr']));
    final payUrl = fixed != null ? str(fixed['link']) : (bank == null ? '' : str(bank['link']));
    final h = widget.hotline;
    Widget copyRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              toast(context, t('coin.copied'));
            },
            icon: Icon(LucideIcons.copy, size: 15, color: c.brandInk),
            label: Text(t('coin.copy'), style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (_sent) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: c.goodBg, shape: BoxShape.circle),
              child: Icon(LucideIcons.circleCheck, color: c.good, size: 32),
            ),
            const SizedBox(height: 14),
            Text(t('coin.sentTitle'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Muted(t('coin.sentSub', {'coins': fmt(widget.coins)}), align: TextAlign.center),
            if (str(h['phone']).isNotEmpty || str(h['telegram']).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(t('coin.urgent'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (str(h['phone']).isNotEmpty) Btn(str(h['phone']), icon: LucideIcons.phone, small: true, kind: BtnKind.ghost, onTap: () => launchUrl(Uri.parse('tel:${str(h['phone']).replaceAll(RegExp(r'[^\d+]'), '')}'))),
                  if (str(h['telegram']).isNotEmpty)
                    Btn(
                      '@${str(h['telegram']).replaceFirst(RegExp(r'^https?://t\.me/', caseSensitive: false), '').replaceFirst('@', '')}',
                      icon: LucideIcons.send,
                      small: true,
                      kind: BtnKind.ghost,
                      onTap: () => launchUrl(Uri.parse('https://t.me/${str(h['telegram']).replaceFirst(RegExp(r'^https?://t\.me/', caseSensitive: false), '').replaceFirst('@', '')}'), mode: LaunchMode.externalApplication),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Btn(t('coin.done'), expand: true, onTap: () => Navigator.pop(context, true)),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      maxChildSize: .95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          Text(t('coin.payTitle', {'amt': usd(widget.total)}), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (widget.banks.isEmpty) Alert(t('coin.noBanks'), tone: Tone.warn),
          if (widget.banks.isNotEmpty) ...[
            Text(t('coin.step1'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in widget.banks)
                  ChoiceChip(
                    label: Text(str(b['name'])),
                    selected: _bank == str(b['key']),
                    onSelected: (_) => setState(() => _bank = str(b['key'])),
                    showCheckmark: false,
                    selectedColor: c.solid,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _bank == str(b['key']) ? c.onSolid : c.ink),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: c.line),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(t('coin.step2', {'amt': usd(widget.total)}), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (bank != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (qrUrl.isNotEmpty)
                      Center(
                        // tap: the QR full size (pinch to zoom)
                        child: GestureDetector(
                          onTap: () => _viewQr(qrUrl),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                // the amount QR is a tall poster: shown big so its QR stays easy to scan
                                child: Image(
                                  image: netImage(qrUrl),
                                  width: fixed != null ? 300 : 250,
                                  height: fixed != null ? 424 : 250,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const SizedBox(height: 40),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                                  child: const Icon(LucideIcons.maximize2, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (payUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Btn(
                          t('coin.payWith', {'bank': str(bank['name'])}),
                          icon: LucideIcons.externalLink,
                          onTap: () => launchUrl(Uri.parse(payUrl), mode: LaunchMode.externalApplication),
                        ),
                      ),
                    if (qrUrl.isNotEmpty)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _saveQr(qrUrl, '${str(bank['name'])}-${fixed != null ? widget.total.toStringAsFixed(0) : 'qr'}'),
                          icon: const Icon(LucideIcons.download, size: 16),
                          label: Text(t('coin.saveQr')),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: fixed != null ? c.goodBg : c.card, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        fixed != null ? t('coin.qrFixed') : t('coin.qrType', {'amt': usd(widget.total)}),
                        style: TextStyle(fontWeight: FontWeight.w600, color: fixed != null ? c.good : c.muted, height: 1.4),
                      ),
                    ),
                    if (str(bank['account_name']).isNotEmpty) copyRow(t('coin.accName'), str(bank['account_name'])),
                    if (str(bank['account_no']).isNotEmpty) copyRow(t('coin.accNo'), str(bank['account_no'])),
                    if (str(bank['note']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Muted(str(bank['note']))),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Text(t('coin.step3'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
                if (f != null) setState(() => _proof = f);
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _proof != null ? c.good : c.lineStrong, width: 1.4),
                  color: _proof != null ? c.goodBg : c.card,
                ),
                child: Row(
                  children: [
                    Icon(_proof != null ? LucideIcons.circleCheck : LucideIcons.upload, color: _proof != null ? c.good : c.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _proof?.name ?? t('coin.proofPick'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: _proof != null ? c.good : c.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Field(controller: _ref, label: t('coin.reference'), maxLength: 80),
            const SizedBox(height: 12),
            Field(controller: _note, label: t('coin.note'), maxLength: 300, maxLines: 2),
            if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
            const SizedBox(height: 18),
            Btn(_busy ? t('coin.sending') : t('coin.send'), icon: LucideIcons.send, busy: _busy, expand: true, onTap: _proof == null || _bank.isEmpty ? null : _send),
          ],
        ],
      ),
    );
  }
}
