import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/site.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import '../common/open_business.dart';
import 'data.dart';
import 'home_page.dart' show bizTypes;
import '../guesthouse/gh_common.dart' show GhCtx, ghPickPicture;
import '../mart/mart_common.dart' show fileForm;

// Add business / Edit business (dashboard/client/BusinessModal.jsx)
class AddBusinessPage extends ConsumerStatefulWidget {
  final Json? edit;
  const AddBusinessPage({super.key, this.edit});
  @override
  ConsumerState<AddBusinessPage> createState() => _AddBusinessPageState();
}

class _AddBusinessPageState extends ConsumerState<AddBusinessPage> {
  late final _name = TextEditingController(text: str(widget.edit?['name']));
  final _q = TextEditingController();
  final _typed = TextEditingController();
  late String _type = bizTypes.contains(widget.edit?['category']) ? str(widget.edit!['category']) : 'namecard';
  bool _busy = false, _noCoins = false, _confirmDelete = false;
  Uint8List? _logo; // stamp card: the shop logo (card + dashboard)
  String _error = '';
  bool get _editing => widget.edit != null;
  String _group = ''; // the category chip ('' = all)

  @override
  void dispose() {
    _name.dispose();
    _q.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    setState(() {
      _error = '';
      _noCoins = false;
    });
    if (_name.text.trim().length < 2) return setState(() => _error = t('messages.bizNameShort'));
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    try {
      await api.put('${Api.user}/businesses/${widget.edit!['_id']}', {'name': _name.text.trim()});
      if (_type == 'stamp_card') {
        final sc = '${Api.user}/businesses/${widget.edit!['_id']}/stamps';
        try {
          await api.put('$sc/settings', {'shop_name': _name.text.trim()});
        } catch (_) {}
        if (_logo != null) await api.post('$sc/logo', fileForm('logo', _logo!, 'logo.png'));
      }
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context, t('messages.saved2'));
        context.pop();
      }
    } on ApiError catch (e) {
      setState(() => _error = e.network ? t('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // stamp card: pick the shop logo (shown on the card and the dashboard)
  Widget _logoRow(T t, {VoidCallback? onPicked}) {
    final c = context.c;
    final km = t.lang == 'km';
    final photo = str(widget.edit?['photo']);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(14)),
          child: _logo != null
              ? Image.memory(_logo!, fit: BoxFit.cover)
              : photo.isNotEmpty
              ? Image(image: netImage(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
              : Icon(LucideIcons.stamp, color: c.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(km ? 'ឡូហ្គោហាង' : 'Shop logo', style: const TextStyle(fontWeight: FontWeight.w700)),
              Muted(km ? 'បង្ហាញលើកាត និងផ្ទាំងគ្រប់គ្រង' : 'Shown on the card and on your dashboard'),
            ],
          ),
        ),
        Btn(
          _logo != null || photo.isNotEmpty ? (km ? 'ប្តូរ' : 'Change') : (km ? 'ជ្រើសរូប' : 'Choose'),
          icon: LucideIcons.camera,
          kind: BtnKind.ghost,
          small: true,
          onTap: _busy
              ? null
              : () async {
                  final img = await ghPickPicture(
                    context,
                    GhCtx(id: '', api: ref.read(apiProvider), t: t, data: const {}, reload: () async {}, askBuy: (_, {item, onDone}) {}, go: (_) {}, notify: (m) => toast(context, m)),
                    maxSize: 600,
                  );
                  if (img != null && mounted) {
                    setState(() => _logo = img);
                    onPicked?.call();
                  }
                },
        ),
      ],
    );
  }

  Future<void> _delete() async {
    final t = ref.read(tProvider);
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).delete('${Api.user}/businesses/${widget.edit!['_id']}');
      ref.invalidate(dashboardProvider);
      ref.invalidate(licensesProvider);
      if (mounted) {
        toast(context, t('messages.bizDeleted'));
        context.pop();
      }
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  bool _matches(String k, T t) {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final other = T.of(t.km ? 'en' : 'km');
    return [
      t('sa.categoryNames.$k'),
      k,
      t.or('bizInfo.$k.tagline', ''),
      t.or('bizInfo.$k.best', ''),
      ...t.list('bizInfo.$k.included'),
      other.or('sa.categoryNames.$k', ''),
      other.or('bizInfo.$k.tagline', ''),
    ].join(' ').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final pr = ref.watch(bizPricesProvider).valueOrNull;
    final prices = obj(pr?['data']);
    final days = obj(pr?['days']);

    if (_editing) {
      final b = widget.edit!;
      return SubPage(
        title: t('messages.editBusiness'),
        bottom: Row(
          children: [
            Expanded(
              child: Btn(t('sa.cancel'), kind: BtnKind.ghost, onTap: () => context.pop()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Btn(_busy ? t('sa.saving') : t('sa.save'), busy: _busy, onTap: _save),
            ),
          ],
        ),
        children: [
          if (b['status'] == false) ...[Alert(t('messages.bizSuspended')), const SizedBox(height: 12)],
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TypeIcon(_type, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('messages.bizType'), style: Theme.of(context).textTheme.bodySmall),
                          Text(t('sa.categoryNames.$_type'), style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.lock, size: 16, color: c.muted),
                  ],
                ),
                const SizedBox(height: 6),
                Muted(t('messages.typeLocked')),
                const SizedBox(height: 18),
                Field(label: '${t('messages.bizName')} *', controller: _name, hint: t('messages.bizNamePh'), maxLength: 100),
                if (_type == 'stamp_card') ...[const SizedBox(height: 12), _logoRow(t)],
                if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Btn(
            t('app.manageWeb'),
            icon: LucideIcons.externalLink,
            kind: BtnKind.ghost,
            expand: true,
            onTap: () => openBusiness(context, id: str(b['_id']), name: str(b['name']), category: str(b['category'])),
          ),
          const SizedBox(height: 24),
          Panel(
            color: c.dangerBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_confirmDelete) ...[
                  Text(
                    t('messages.deleteForever'),
                    style: TextStyle(color: c.danger, fontWeight: FontWeight.w700, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(t('messages.typeNameToDelete', {'name': str(b['name'])}), style: TextStyle(color: c.danger)),
                  const SizedBox(height: 8),
                  Field(controller: _typed, hint: str(b['name']), onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                ],
                Btn(
                  _confirmDelete ? t('messages.confirmDelete') : t('messages.remove'),
                  icon: LucideIcons.trash2,
                  kind: BtnKind.danger,
                  expand: true,
                  busy: _busy && _confirmDelete,
                  onTap: _confirmDelete ? (_typed.text.trim() == str(b['name']).trim() ? _delete : null) : () => setState(() => _confirmDelete = true),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // groups from Super admin → Business groups (same as the web); a chip row to show one group
    final allGroups = siteOf(ref).bizGroups(t.lang, bizTypes);
    final groups = [
      for (final g in allGroups)
        if (_group.isEmpty || _group == g.$1) (g.$2, g.$3.where((k) => _matches(k, t)).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();
    String priceText(String k) {
      if (pr == null) return '…';
      final p = n(prices[k]);
      return p == 0 ? t('messages.free') : '${fmt(p)} ${days[k] != null ? t('messages.perYearShort') : '· ${t('messages.oneTime')}'}';
    }

    return SubPage(
      title: t('messages.addBusiness'),
      children: [
        Field(controller: _q, hint: t('bizWords.find'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        // categories
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (key, label, count) in [('', t('sa.all'), bizTypes.length), for (final g in allGroups) (g.$1, g.$2, g.$3.length)])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: _group == key ? c.solid : c.card,
                    shape: StadiumBorder(side: BorderSide(color: _group == key ? c.solid : c.line)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => _group = key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _group == key ? c.onSolid : c.ink),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$count',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _group == key ? c.onSolid.withValues(alpha: .7) : c.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty) Muted(t('bizWords.none')),
        for (final g in groups) ...[
          if (_group.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: Text(g.$1, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.5)),
            ),
          for (final k in g.$2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TypeTile(k: k, name: t('sa.categoryNames.$k'), tagline: t.or('bizInfo.$k.tagline', ''), price: priceText(k), onTap: pr == null ? null : () => _details(k)),
            ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  // tap a type → its details in a sheet, with Pay at the bottom
  Future<void> _details(String k) async {
    final t = ref.read(tProvider);
    final pr = ref.read(bizPricesProvider).valueOrNull;
    final price = n(obj(pr?['data'])[k]);
    final yearly = obj(pr?['days'])[k] != null;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) {
        final c = sheet.c;
        final balance = ref.read(sessionProvider)?.coins ?? 0;
        final short = price > balance;
        final included = t.list('bizInfo.$k.included');
        final later = t.list('bizInfo.$k.later');
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    Row(
                      children: [
                        TypeIcon(k, size: 58),
                        const SizedBox(width: 14),
                        Expanded(child: Text(t('sa.categoryNames.$k'), style: Theme.of(sheet).textTheme.titleLarge)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(t.or('bizInfo.$k.tagline', ''), style: TextStyle(color: c.muted, height: 1.5)),
                    const SizedBox(height: 14),
                    _PriceBox(t: t, price: price, yearly: yearly),
                    const SizedBox(height: 10),
                    if (t.or('bizInfo.$k.best', '').isNotEmpty) Text('${t('bizWords.best')}: ${t.or('bizInfo.$k.best', '')}', style: Theme.of(sheet).textTheme.bodySmall),
                    if (included.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(t('bizWords.included'), style: Theme.of(sheet).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      for (final x in included) _Li(x, LucideIcons.check, c.good),
                    ],
                    if (later.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(t('bizWords.later'), style: Theme.of(sheet).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      for (final x in later) _Li(x, LucideIcons.plus, c.muted),
                    ],
                  ],
                ),
              ),
              _PayBar(
                t: t,
                price: price,
                yearly: yearly,
                balance: balance,
                label: price > 0 ? '${t('messages.payAndCreate')} · ${fmt(price)}' : t('bizWords.nameIt'),
                onTap: short ? null : () => Navigator.pop(sheet, true),
                onTopUp: short
                    ? () {
                        Navigator.pop(sheet);
                        context.push('/o/coins');
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
    if (go == true && mounted) _checkout(k, price, yearly);
  }

  // Pay → name the business and check out (this sheet is the payment confirmation)
  Future<void> _checkout(String k, num price, bool yearly) async {
    setState(() {
      _type = k;
      _logo = null;
      _error = '';
      _noCoins = false;
    });
    final created = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _Checkout(page: this, k: k, price: price, yearly: yearly),
    );
    if (created == null || !mounted) return;
    final t = ref.read(tProvider);
    toast(context, n(created['_charged']) > 0 ? t('messages.bizCreatedPaid', {'coins': fmt(created['_charged'])}) : t('messages.bizCreated'));
    context.pop();
    // straight into the new business, like the web
    openBusiness(context, id: str(created['_id']), name: str(created['name']), category: str(created['category']));
  }

  // create it (called by the checkout sheet): the new business, or null + _error / _noCoins
  Future<Json?> _create() async {
    final t = ref.read(tProvider);
    if (_name.text.trim().length < 2) {
      _error = t('messages.bizNameShort');
      return null;
    }
    final api = ref.read(apiProvider);
    try {
      final r = await api.post('${Api.user}/businesses', {'name': _name.text.trim(), 'category': _type});
      if (r['balance'] is num) await ref.read(sessionProvider.notifier).patch({'coin_balance': r['balance']});
      coinsChanged(ref);
      final created = obj(r['data']);
      if (_type == 'stamp_card' && _logo != null) {
        try {
          await api.post('${Api.user}/businesses/${created['_id']}/stamps/logo', fileForm('logo', _logo!, 'logo.png'));
        } catch (_) {}
        ref.invalidate(dashboardProvider);
      }
      return {...created, '_charged': r['charged']};
    } on ApiError catch (e) {
      if (e.status == 402) {
        _noCoins = true;
      } else {
        _error = e.network ? t('app.offline') : e.message;
      }
      return null;
    }
  }
}

// the checkout: the business name (+ the shop logo for a stamp card), what you pay, your balance after
class _Checkout extends ConsumerStatefulWidget {
  final _AddBusinessPageState page;
  final String k;
  final num price;
  final bool yearly;
  const _Checkout({required this.page, required this.k, required this.price, required this.yearly});
  @override
  ConsumerState<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<_Checkout> {
  bool _busy = false;
  _AddBusinessPageState get p => widget.page;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      p._error = '';
      p._noCoins = false;
    });
    final created = await p._create();
    if (!mounted) return;
    if (created != null) {
      Navigator.pop(context, created);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final k = widget.k;
    final balance = ref.watch(sessionProvider)?.coins ?? 0;
    final price = widget.price;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TypeIcon(k, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('bizWords.nameIt'), style: Theme.of(context).textTheme.titleLarge),
                          Text(t('sa.categoryNames.$k'), style: TextStyle(color: c.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Field(
                  label: '${t('messages.bizName')} *',
                  controller: p._name,
                  hint: t('messages.bizNamePh'),
                  maxLength: 100,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmit: (_) => p._name.text.trim().length >= 2 && !_busy ? _go() : null,
                ),
                if (k == 'stamp_card') ...[const SizedBox(height: 12), StatefulBuilder(builder: (_, set) => p._logoRow(t, onPicked: () => set(() {})))],
                if (widget.yearly && price > 0) ...[const SizedBox(height: 8), Muted(t('messages.firstYear'))],
                if (p._noCoins) ...[
                  const SizedBox(height: 12),
                  Alert(
                    t('messages.notEnoughCoins'),
                    action: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/o/coins');
                      },
                      child: Text(
                        '${t('messages.topUp')} →',
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.danger),
                      ),
                    ),
                  ),
                ],
                if (p._error.isNotEmpty) ...[const SizedBox(height: 12), Alert(p._error)],
              ],
            ),
          ),
          _PayBar(
            t: t,
            price: price,
            yearly: widget.yearly,
            balance: balance,
            after: true,
            busy: _busy,
            label: price > 0 ? '${t('app.pay')} · ${fmt(price)}' : t('sa.save'),
            onTap: _busy || p._name.text.trim().length < 2 ? null : _go,
          ),
        ],
      ),
    );
  }
}

// the price, big
class _PriceBox extends StatelessWidget {
  final T t;
  final num price;
  final bool yearly;
  const _PriceBox({required this.t, required this.price, required this.yearly});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 8),
          Text(price > 0 ? fmt(price) : t('messages.free'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (price > 0) Text(' ${t('messages.coinsWord')}', style: TextStyle(color: c.muted)),
          const Spacer(),
          Icon(yearly ? LucideIcons.calendarClock : LucideIcons.infinity, size: 15, color: c.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              yearly ? t('bizWords.renewYear') : t('bizWords.oneTime'),
              textAlign: TextAlign.end,
              style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// the bottom of a sheet: what you pay, your coins (after paying), the button
class _PayBar extends StatelessWidget {
  final T t;
  final num price, balance;
  final bool yearly, after, busy;
  final String label;
  final VoidCallback? onTap, onTopUp;
  const _PayBar({required this.t, required this.price, required this.yearly, required this.balance, required this.label, this.onTap, this.onTopUp, this.after = false, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final short = price > balance;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${t('messages.youPay')} ',
                    children: [
                      TextSpan(
                        text: price > 0 ? '${fmt(price)} ${t('messages.coinsWord')}${yearly ? ' ${t('messages.perYearShort')}' : ''}' : t('messages.free'),
                        style: TextStyle(fontWeight: FontWeight.w800, color: short ? c.danger : c.ink),
                      ),
                    ],
                  ),
                  style: TextStyle(color: c.muted),
                ),
              ),
              Text(after && price > 0 ? '${t('messages.coinBalance')}: ${fmt(balance)} → ${fmt(balance - price)}' : '${t('messages.coinBalance')}: ${fmt(balance)}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (short) ...[
            const SizedBox(height: 10),
            Alert(
              t('messages.notEnoughCoins'),
              action: onTopUp == null
                  ? null
                  : GestureDetector(
                      onTap: onTopUp,
                      child: Text(
                        '${t('messages.topUp')} →',
                        style: TextStyle(fontWeight: FontWeight.w800, color: c.danger),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 10),
          Btn(label, busy: busy, lead: price > 0 && !busy ? const CoinIcon(size: 18) : null, onTap: onTap),
        ],
      ),
    );
  }
}

class _Li extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _Li(this.text, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45))),
      ],
    ),
  );
}

class _TypeTile extends StatelessWidget {
  final String k, name, tagline, price;
  final VoidCallback? onTap;
  const _TypeTile({required this.k, required this.name, required this.tagline, required this.price, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              TypeIcon(k, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if (tagline.isNotEmpty)
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 12.5),
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 5),
                        Text(price, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: c.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
