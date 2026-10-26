import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../common/shell.dart';
import 'admin_data.dart';
import 'admin_parts.dart';

// Super admin → Prices: coin pack + the price of every service, grouped by business type (PricesPage.jsx)
const _icons = <String, IconData>{
  'IdCard': LucideIcons.idCard,
  'UtensilsCrossed': LucideIcons.utensilsCrossed,
  'Fingerprint': LucideIcons.fingerprint,
  'BedDouble': LucideIcons.bedDouble,
  'ShoppingBasket': LucideIcons.shoppingBasket,
  'QrCode': LucideIcons.qrCode,
  'BookOpen': LucideIcons.bookOpen,
  'ScanLine': LucideIcons.scanLine,
  'Globe': LucideIcons.globe,
  'NotebookPen': LucideIcons.notebookPen,
  'Stamp': LucideIcons.stamp,
  'Ticket': LucideIcons.ticket,
  'StickyNote': LucideIcons.stickyNote,
};

String _num(Object? v) {
  final x = n(v);
  return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
}

class AdminPricesPage extends ConsumerStatefulWidget {
  const AdminPricesPage({super.key});
  @override
  ConsumerState<AdminPricesPage> createState() => _AdminPricesPageState();
}

class _AdminPricesPageState extends ConsumerState<AdminPricesPage> {
  Json? _saved; // { coin, prices }
  final _prices = <String, TextEditingController>{};
  final _coin = <String, TextEditingController>{};
  String _q = '', _type = '', _error = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._prices.values, ..._coin.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = obj((await ref.read(apiProvider).get('${Api.admin}/homepage'))['data']);
      final d = defaultHomepage;
      _fill({
        'coin': {...obj(d['coin']), ...obj(r['coin'])},
        'prices': {...obj(d['prices']), ...obj(r['prices'])},
      });
    } on ApiError catch (e) {
      setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    }
  }

  void _fill(Json data) {
    setState(() {
      _saved = data;
      _error = '';
      for (final e in obj(data['prices']).entries) {
        (_prices[e.key] ??= TextEditingController()).text = _num(e.value);
      }
      for (final e in obj(data['coin']).entries) {
        (_coin[e.key] ??= TextEditingController()).text = _num(e.value);
      }
    });
  }

  int get _changes {
    if (_saved == null) return 0;
    var k = 0;
    obj(_saved!['prices']).forEach((key, v) => k += n(_prices[key]?.text) != n(v) ? 1 : 0);
    obj(_saved!['coin']).forEach((key, v) => k += n(_coin[key]?.text) != n(v) ? 1 : 0);
    return k;
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    setState(() => _saving = true);
    try {
      final prices = {for (final e in _prices.entries) e.key: n(e.value.text)};
      final coin = {'pack_coins': n(_coin['pack_coins']?.text), 'pack_price_usd': n(_coin['pack_price_usd']?.text), 'signup_bonus': n(_coin['signup_bonus']?.text)};
      await ref.read(apiProvider).put('${Api.admin}/homepage', {'prices': prices, 'coin': coin});
      _fill({'coin': coin, 'prices': prices});
      if (mounted) toast(context, t('pr.saved'));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final km = t.lang == 'km';
    final changes = _changes;
    final usdPerCoin = n(_coin['pack_price_usd']?.text) / (n(_coin['pack_coins']?.text) < 1 ? 1 : n(_coin['pack_coins']?.text));
    final qq = _q.toLowerCase();
    final groups = [
      for (final g in priceGroups)
        if (_type.isEmpty || g['key'] == _type)
          {
            ...g,
            'items': [
              for (final i in objs(g['items']))
                if (qq.isEmpty || '${i['en']} ${i['km']} ${i['key']} ${g['en']} ${g['km']}'.toLowerCase().contains(qq)) i,
            ],
          },
    ].where((g) => (g['items'] as List).isNotEmpty).toList();

    Widget numField(TextEditingController ctl, {bool decimal = false, bool changed = false}) => SizedBox(
      width: 96,
      child: TextField(
        controller: ctl,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
        textAlign: TextAlign.right,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: changed ? c.active : c.bg2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: changed ? c.brand : c.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.brand, width: 1.6),
          ),
        ),
      ),
    );

    Widget head(IconData icon, String title, [String? count]) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: c.brandInk),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (count != null) Chip2(count),
        ],
      ),
    );

    return SubPage(
      title: t('messages.navPrices'),
      onRefresh: _load,
      bottom: _saved == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: Text(
                    changes > 0 ? t('pr.unsaved', {'n': changes}) : t('pr.allSaved'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: changes > 0 ? c.brandInk : c.muted),
                  ),
                ),
                if (changes > 0) ...[RoundBtn(LucideIcons.rotateCcw, size: 42, tip: t('pr.undo'), onTap: _saving ? null : () => _fill(_saved!)), const SizedBox(width: 8)],
                Btn(_saving ? t('pr.saving') : t('pr.save'), busy: _saving, onTap: changes == 0 ? null : _save),
              ],
            ),
      children: [
        Muted(t('pr.sub')),
        const SizedBox(height: 12),
        if (_error.isNotEmpty) Alert(_error),
        if (_saved == null && _error.isEmpty) const Panel(child: SkelList()),
        if (_saved != null) ...[
          SearchBox(hint: t('pr.search'), onSearch: (v) => setState(() => _q = v)),
          const SizedBox(height: 10),
          Segs(
            items: [
              ('', '${t('sa.allCategories')} ${priceGroups.fold<int>(0, (a, g) => a + objs(g['items']).length)}'),
              for (final g in priceGroups) (str(g['key']), '${km ? g['km'] : g['en']} ${objs(g['items']).length}'),
            ],
            value: _type,
            onTap: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          if (qq.isEmpty && _type.isEmpty)
            Panel(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head(LucideIcons.coins, t('pr.coins')),
                  for (final (k, label, dec) in [('pack_coins', t('pr.packCoins'), false), ('pack_price_usd', t('pr.packPrice'), true), ('signup_bonus', t('pr.bonus'), false)])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          numField(_coin[k]!, decimal: dec, changed: n(_coin[k]!.text) != n(obj(_saved!['coin'])[k])),
                        ],
                      ),
                    ),
                  Text(
                    '${t('pr.shown')}: ${_coin['pack_coins']!.text} coins = \$${_coin['pack_price_usd']!.text} · +${_coin['signup_bonus']!.text} free coins',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (groups.isEmpty) Panel(child: Muted(t('pr.none'))),
          for (final g in groups)
            Panel(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head(_icons[g['icon']] ?? LucideIcons.coins, str(km ? g['km'] : g['en']), '${(g['items'] as List).length}'),
                  for (final i in g['items'] as List<Json>) _row(i, t, c, km, usdPerCoin, numField),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _row(Json i, dynamic t, C c, bool km, num usdPerCoin, Widget Function(TextEditingController, {bool decimal, bool changed}) numField) {
    final key = str(i['key']);
    final ctl = _prices[key] ??= TextEditingController(text: '0');
    final changed = n(ctl.text) != n(obj(_saved!['prices'])[key]);
    final v = n(ctl.text);
    final desc = str(km ? i['d_km'] : i['d_en']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(str(km ? i['km'] : i['en']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    if (i['soon'] == true) Chip2(t('pr.soon'), tone: Tone.warn),
                    if (changed) Chip2(t('pr.changed'), tone: Tone.brand),
                  ],
                ),
                Text('${t('pr.units.${i['unit']}')}${desc.isNotEmpty ? ' · $desc' : ''}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              numField(ctl, changed: changed),
              const SizedBox(height: 3),
              Text(v == 0 ? t('pr.free') : t('pr.usd', {'v': (v * usdPerCoin).toStringAsFixed(2)}), style: TextStyle(fontSize: 11.5, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
