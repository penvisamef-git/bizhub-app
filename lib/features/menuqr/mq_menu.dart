import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../restaurant/rest_common.dart' show SwitchRow;
import 'mq_common.dart';

// Menu (MqMenu.jsx): categories as chips on top, their items below; search across all items
class MenuTab extends StatefulWidget {
  final MqCtx ctx;
  const MenuTab({super.key, required this.ctx});
  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  MqCtx get ctx => widget.ctx;
  List<Json>? _cats, _items;
  String _cat = '';
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([ctx.api.get('${ctx.base}/categories'), ctx.api.get('${ctx.base}/items')]);
      if (!mounted) return;
      final cats = objs(r[0]['data']);
      setState(() {
        _cats = cats;
        _items = objs(r[1]['data']);
        if (!cats.any((x) => x['_id'] == _cat)) _cat = cats.isEmpty ? '' : str(cats.first['_id']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _move(List<Json> list, int i, int j, String path) async {
    if (j < 0 || j >= list.length) return;
    final next = List.of(list);
    final x = next[i];
    next[i] = next[j];
    next[j] = x;
    setState(() => path == 'categories-order' ? _cats = next : _items = next);
    await ctx.run(() => ctx.api.put('${ctx.base}/$path', {'ids': next.map((e) => e['_id']).toList()}));
  }

  bool get _catFull => (_cats?.length ?? 0) >= n(ctx.limits['categories']) && !ctx.on('mq_categories');
  bool get _itemFull => (_items?.length ?? 0) >= n(ctx.limits['items']) && !ctx.on('mq_items');

  Widget _limitLine(int count, String key, String addon) {
    final c = context.c;
    if (ctx.on(addon)) return Text(ctx.m('noLimit', {'n': fmt(count)}), style: TextStyle(color: c.muted, fontSize: 12.5));
    final max = n(ctx.limits[key == 'catLimit' ? 'categories' : 'items']);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(ctx.m(key, {'n': count, 'max': max}), style: TextStyle(color: count >= max ? c.danger : c.muted, fontSize: 12.5)),
        if (count >= max)
          InkWell(
            onTap: () => ctx.askBuy({'addon': addon}),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 13),
                const SizedBox(width: 4),
                Text(
                  ctx.m('getMore'),
                  style: TextStyle(color: c.brand, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _editCat(Json cat) async {
    final items = _items ?? const [];
    final count = cat['_id'] == null ? 0 : items.where((x) => catsOf(x).length == 1 && catsOf(x).first == cat['_id']).length;
    final r = await showSheet<Json>(context, (_) => _CatSheet(ctx: ctx, cat: cat, count: count));
    if (r == null) return;
    await _load();
    ctx.reload();
    if (r['_id'] != null && cat['_id'] == null && mounted) setState(() => _cat = str(r['_id']));
  }

  Future<void> _editItem(Json item) async {
    await showSheet<void>(
      context,
      (_) => _ItemSheet(
        ctx: ctx,
        item: item,
        cats: _cats ?? const [],
        onChange: (row) {
          if (!mounted) return;
          setState(() {
            final l = _items ?? [];
            _items = l.any((x) => x['_id'] == row['_id']) ? [for (final x in l) x['_id'] == row['_id'] ? row : x] : [...l, row];
          });
        },
      ),
    );
    await _load();
    ctx.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cats = _cats, items = _items;
    if (cats == null || items == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 6));
    final q = _q.text.trim().toLowerCase();
    final shown = q.isNotEmpty ? items.where((i) => '${i['name_km']} ${i['name_en']}'.toLowerCase().contains(q)).toList() : items.where((i) => catsOf(i).contains(_cat)).toList();
    final current = cats.where((x) => x['_id'] == _cat).firstOrNull;
    final sameCat = q.isNotEmpty ? <Json>[] : items.where((x) => catsOf(x).contains(_cat)).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ---- categories ----
          mqPanel([
            Row(
              children: [
                Expanded(
                  child: Text(ctx.m('categories'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Btn(
                  ctx.m('addCategory'),
                  icon: _catFull ? LucideIcons.lock : LucideIcons.plus,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: ctx.readOnly ? null : () => _catFull ? ctx.askBuy({'addon': 'mq_categories'}) : _editCat({}),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _limitLine(cats.length, 'catLimit', 'mq_categories'),
            const SizedBox(height: 10),
            if (cats.isEmpty) Muted(ctx.m('noCats')),
            for (final (i, cat) in cats.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: cat['_id'] == _cat && q.isEmpty ? c.active : c.bg2, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() {
                          _cat = str(cat['_id']);
                          _q.clear();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: str(cat['icon']).isNotEmpty ? Text(str(cat['icon']), style: const TextStyle(fontSize: 18)) : Icon(LucideIcons.utensilsCrossed, size: 16, color: c.muted),
                              ),
                              Expanded(
                                child: Text(
                                  mqName(cat, ctx.lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cat['active'] == false ? c.muted : (cat['_id'] == _cat && q.isEmpty ? c.brandInk : c.ink),
                                    decoration: cat['active'] == false ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              Text('${items.where((x) => catsOf(x).contains(cat['_id'])).length}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _iconBtn(LucideIcons.arrowUp, ctx.readOnly || i == 0 ? null : () => _move(cats, i, i - 1, 'categories-order')),
                    _iconBtn(LucideIcons.arrowDown, ctx.readOnly || i == cats.length - 1 ? null : () => _move(cats, i, i + 1, 'categories-order')),
                    _iconBtn(LucideIcons.pencil, ctx.readOnly ? null : () => _editCat(cat)),
                  ],
                ),
              ),
          ]),
          const SizedBox(height: 12),
          // ---- items ----
          mqPanel([
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.isNotEmpty
                        ? ctx.m('search')
                        : current != null
                        ? '${str(current['icon']).isNotEmpty ? '${current['icon']} ' : ''}${mqName(current, ctx.lang)}'
                        : ctx.m('items'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Btn(
                  ctx.m('addItem'),
                  icon: _itemFull ? LucideIcons.lock : LucideIcons.plus,
                  small: true,
                  onTap: ctx.readOnly || cats.isEmpty
                      ? null
                      : () => _itemFull
                            ? ctx.askBuy({'addon': 'mq_items'})
                            : _editItem({
                                'category_ids': [if (_cat.isNotEmpty) _cat],
                              }),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _limitLine(items.length, 'itemLimit', 'mq_items'),
            const SizedBox(height: 10),
            Field(controller: _q, hint: ctx.m('search'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Muted(cats.isNotEmpty ? ctx.m('noItems') : ctx.m('noCats'), align: TextAlign.center),
              ),
            for (final it in shown) _itemRow(it, items, sameCat, q.isEmpty),
          ]),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap) => IconButton(visualDensity: VisualDensity.compact, onPressed: onTap, icon: Icon(icon, size: 16));

  Widget _itemRow(Json it, List<Json> items, List<Json> sameCat, bool canMove) {
    final c = context.c;
    final photos = objs(it['photos']);
    final sale = it['sale_price'];
    final k = sameCat.indexWhere((x) => x['_id'] == it['_id']);
    final idx = items.indexWhere((x) => x['_id'] == it['_id']);
    final other = ctx.lang == 'km' ? str(it['name_en']) : str(it['name_km']);
    return Opacity(
      opacity: it['active'] == false ? .55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _editItem(it),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: photos.isNotEmpty
                    ? Image(image: netImage(str(photos.first['url'])), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                    : Icon(LucideIcons.utensilsCrossed, size: 20, color: c.muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mqName(it, ctx.lang), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (other.isNotEmpty || photos.length > 1) Text('$other${photos.length > 1 ? ' · 📷 ${photos.length}' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (it['available'] == false) Chip2(ctx.m('soldOut'), tone: Tone.warn),
                        if (it['active'] == false) Chip2(ctx.m('hidden'), icon: LucideIcons.eyeOff),
                        for (final tg in (it['tags'] as List? ?? const [])) Chip2('${mqTagIcon[tg] ?? ''} ${ctx.t.or('mq.tagNames.$tg', '$tg')}', tone: Tone.brand),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (sale != null)
                    Text(
                      money(it['price'], ctx.currency),
                      style: TextStyle(color: c.muted, fontSize: 12, decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    money(sale ?? it['price'], ctx.currency),
                    style: TextStyle(fontWeight: FontWeight.w900, color: sale != null ? c.danger : c.ink),
                  ),
                  if (canMove)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconBtn(LucideIcons.arrowUp, ctx.readOnly || k <= 0 ? null : () => _move(items, idx, items.indexWhere((x) => x['_id'] == sameCat[k - 1]['_id']), 'items-order')),
                        _iconBtn(
                          LucideIcons.arrowDown,
                          ctx.readOnly || k < 0 || k == sameCat.length - 1 ? null : () => _move(items, idx, items.indexWhere((x) => x['_id'] == sameCat[k + 1]['_id']), 'items-order'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- category
const _emoji = ['☕', '🍵', '🧋', '🥤', '🍹', '🍺', '🍜', '🍚', '🍛', '🍲', '🥗', '🍔', '🍕', '🍗', '🥩', '🦐', '🍰', '🍦', '🥐', '🍳'];

class _CatSheet extends StatefulWidget {
  final MqCtx ctx;
  final Json cat;
  final int count;
  const _CatSheet({required this.ctx, required this.cat, required this.count});
  @override
  State<_CatSheet> createState() => _CatSheetState();
}

class _CatSheetState extends State<_CatSheet> {
  MqCtx get ctx => widget.ctx;
  late final _km = TextEditingController(text: str(widget.cat['name_km']));
  late final _en = TextEditingController(text: str(widget.cat['name_en']));
  late final _icon = TextEditingController(text: str(widget.cat['icon']));
  late bool _active = widget.cat['active'] != false;
  String _busy = '', _err = '';

  bool get _isNew => widget.cat['_id'] == null;

  @override
  void dispose() {
    _km.dispose();
    _en.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = 'save';
      _err = '';
    });
    final body = {'name_km': _km.text.trim(), 'name_en': _en.text.trim(), 'icon': _icon.text.trim(), 'active': _active};
    try {
      final r = _isNew ? await ctx.api.post('${ctx.base}/categories', body) : await ctx.api.put('${ctx.base}/categories/${widget.cat['_id']}', body);
      if (mounted) Navigator.pop(context, obj(r['data']));
    } on ApiError catch (e) {
      if (e.status == 402) {
        if (mounted) Navigator.pop(context);
        ctx.fail(e);
        return;
      }
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  Future<void> _remove() async {
    final name = _km.text.trim().isNotEmpty ? _km.text.trim() : _en.text.trim();
    final ask = widget.count > 0 ? ctx.m('deleteCatItems', {'name': name, 'n': widget.count}) : ctx.m('sure', {'name': name});
    if (!await mqConfirm(context, ctx, ask)) return;
    setState(() => _busy = 'remove');
    try {
      await ctx.api.delete('${ctx.base}/categories/${widget.cat['_id']}');
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context, <String, dynamic>{});
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final noName = _km.text.trim().isEmpty && _en.text.trim().isEmpty;
    return MSheet(
      title: _isNew ? ctx.m('addCategory') : ctx.m('edit'),
      footer: [
        if (!_isNew) Btn(ctx.m('delete'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, busy: _busy == 'remove', onTap: _busy.isNotEmpty || ctx.readOnly ? null : _remove),
        const Spacer(),
        Btn(ctx.m('save'), icon: LucideIcons.check, small: true, busy: _busy == 'save', onTap: _busy.isNotEmpty || ctx.readOnly || noName ? null : _save),
      ],
      children: [
        MqInput(ctx.m('nameKm'), _km, max: 60, onChanged: (_) => setState(() {})),
        MqInput(ctx.m('nameEn'), _en, max: 60, onChanged: (_) => setState(() {})),
        Text(ctx.m('icon'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in _emoji)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _icon.text = _icon.text == e ? '' : e),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _icon.text == e ? c.active : c.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _icon.text == e ? c.brand : Colors.transparent, width: 2),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 120,
            child: Field(controller: _icon, maxLength: 8, hint: '🍜', onChanged: (_) => setState(() {})),
          ),
        ),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.m('show'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (_err.isNotEmpty) Alert(_err),
      ],
    );
  }
}

// ---------------------------------------------------------------- item
class _ItemSheet extends StatefulWidget {
  final MqCtx ctx;
  final Json item;
  final List<Json> cats;
  final void Function(Json row) onChange;
  const _ItemSheet({required this.ctx, required this.item, required this.cats, required this.onChange});
  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  MqCtx get ctx => widget.ctx;
  late Json _item = widget.item;
  late final _km = TextEditingController(text: str(_item['name_km']));
  late final _en = TextEditingController(text: str(_item['name_en']));
  late final _dkm = TextEditingController(text: str(_item['desc_km']));
  late final _den = TextEditingController(text: str(_item['desc_en']));
  late final _price = TextEditingController(text: _item['price'] == null ? '' : _num(_item['price']));
  late final _sale = TextEditingController(text: _item['sale_price'] == null ? '' : _num(_item['sale_price']));
  late List<String> _catIds = () {
    final l = (_item['category_ids'] as List? ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (l.isNotEmpty) return l;
    if (str(_item['category_id']).isNotEmpty) return [str(_item['category_id'])];
    return widget.cats.isEmpty ? <String>[] : [str(widget.cats.first['_id'])];
  }();
  late final List<String> _tags = (_item['tags'] as List? ?? const []).map((e) => '$e').toList();
  late bool _available = _item['available'] != false;
  late bool _active = _item['active'] != false;
  String _busy = '', _err = '';

  static String _num(Object? v) {
    final x = n(v);
    return x == x.roundToDouble() ? '${x.toInt()}' : '$x';
  }

  bool get _isNew => _item['_id'] == null;
  int get _maxPhotos => n(ctx.limits['photos']).toInt();
  List<Json> get _photos => objs(_item['photos']);

  @override
  void dispose() {
    for (final x in [_km, _en, _dkm, _den, _price, _sale]) {
      x.dispose();
    }
    super.dispose();
  }

  void _set(Json row) {
    setState(() => _item = row);
    widget.onChange(row);
  }

  Future<void> _save({bool close = true}) async {
    setState(() {
      _busy = 'save';
      _err = '';
    });
    final promos = ctx.on('mq_promos');
    final body = <String, dynamic>{
      'name_km': _km.text.trim(),
      'name_en': _en.text.trim(),
      'desc_km': _dkm.text.trim(),
      'desc_en': _den.text.trim(),
      'category_ids': _catIds,
      'price': num.tryParse(_price.text.trim()) ?? 0,
      if (promos) 'sale_price': _sale.text.trim().isEmpty ? null : num.tryParse(_sale.text.trim()),
      'tags': _tags,
      'available': _available,
      'active': _active,
    };
    try {
      final r = _isNew ? await ctx.api.post('${ctx.base}/items', body) : await ctx.api.put('${ctx.base}/items/${_item['_id']}', body);
      final wasNew = _isNew;
      _set(obj(r['data']));
      ctx.notify(ctx.m('saved'));
      if (close && !wasNew && mounted) Navigator.pop(context);
      if (mounted) setState(() => _busy = '');
    } on ApiError catch (e) {
      if (e.status == 402) {
        if (mounted) Navigator.pop(context);
        ctx.fail(e);
        return;
      }
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  Future<bool> _attach(List<Json> list) async {
    setState(() => _busy = 'photo');
    for (final x in list.take(_maxPhotos - _photos.length)) {
      try {
        final r = await ctx.api.post('${ctx.base}/items/${_item['_id']}/photos', {'media_id': x['_id']});
        _set(obj(r['data']));
      } on ApiError catch (e) {
        setState(() => _err = e.message);
        break;
      }
    }
    if (mounted) setState(() => _busy = '');
    return true;
  }

  Future<void> _removePhoto(Json p) async {
    setState(() => _busy = 'del-${p['_id']}');
    try {
      final r = await ctx.api.delete('${ctx.base}/items/${_item['_id']}/photos/${p['_id']}');
      _set(obj(r['data']));
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    }
    if (mounted) setState(() => _busy = '');
  }

  Future<void> _cover(Json p) async {
    try {
      final ids = [p['_id'], ..._photos.where((x) => x['_id'] != p['_id']).map((x) => x['_id'])];
      final r = await ctx.api.put('${ctx.base}/items/${_item['_id']}/photos-order', {'ids': ids});
      _set(obj(r['data']));
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    }
  }

  Future<void> _remove() async {
    final name = _km.text.trim().isNotEmpty ? _km.text.trim() : _en.text.trim();
    if (!await mqConfirm(context, ctx, ctx.m('sure', {'name': name}))) return;
    setState(() => _busy = 'remove');
    try {
      await ctx.api.delete('${ctx.base}/items/${_item['_id']}');
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  Widget _pick(String label, bool on, VoidCallback onTap) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.active : c.bg2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? c.brand : c.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? c.brandInk : c.ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cur = ctx.currency;
    final promos = ctx.on('mq_promos');
    final noName = _km.text.trim().isEmpty && _en.text.trim().isEmpty;
    final photos = _photos;
    return MSheet(
      title: _isNew ? ctx.m('addItem') : mqName(_item, ctx.lang),
      footer: [
        if (!_isNew) Btn(ctx.m('delete'), icon: LucideIcons.trash2, kind: BtnKind.danger, small: true, busy: _busy == 'remove', onTap: _busy.isNotEmpty || ctx.readOnly ? null : _remove),
        const Spacer(),
        Btn(ctx.m('save'), icon: LucideIcons.check, small: true, busy: _busy == 'save', onTap: _busy.isNotEmpty || ctx.readOnly || noName ? null : () => _save()),
      ],
      children: [
        MqInput(ctx.m('nameKm'), _km, max: 80, onChanged: (_) => setState(() {})),
        MqInput(ctx.m('nameEn'), _en, max: 80, onChanged: (_) => setState(() {})),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: MqInput('${ctx.m('price')} (${cur == 'KHR' ? '៛' : '\$'})', _price, number: true)),
            if (promos) ...[const SizedBox(width: 10), Expanded(child: MqInput(ctx.m('salePrice'), _sale, number: true, hint: '—'))],
          ],
        ),
        if (!promos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.pop(context);
                ctx.askBuy({'addon': 'mq_promos'});
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(LucideIcons.lock, size: 15, color: c.warn),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ctx.m('salePriceLocked'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (promos) Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(ctx.m('salePriceHint'))),
        SwitchRow(title: ctx.m('available'), value: _available, onChanged: (v) => setState(() => _available = v)),
        SwitchRow(title: ctx.m('show'), value: _active, onChanged: (v) => setState(() => _active = v)),
        const SizedBox(height: 8),
        MqInput(ctx.m('descKm'), _dkm, max: 400, lines: 2),
        MqInput(ctx.m('descEn'), _den, max: 400, lines: 2),
        Text(ctx.m('categoriesPick'), style: const TextStyle(fontWeight: FontWeight.w700)),
        Muted(ctx.m('categoriesHint')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final cat in widget.cats)
              Builder(
                builder: (_) {
                  final id = str(cat['_id']);
                  final k = _catIds.indexOf(id);
                  return _pick(
                    '${k == 0 ? '★ ' : ''}${str(cat['icon'])} ${mqName(cat, 'km')}'.trim(),
                    k >= 0,
                    () => setState(() => k >= 0 ? _catIds = _catIds.where((x) => x != id).toList() : _catIds = [..._catIds, id]),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(ctx.m('tags'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final tg in mqTags) _pick('${mqTagIcon[tg]} ${ctx.m('tagNames.$tg')}', _tags.contains(tg), () => setState(() => _tags.contains(tg) ? _tags.remove(tg) : _tags.add(tg)))],
        ),
        const SizedBox(height: 14),
        Text('${ctx.m('photos')} (${photos.length}/$_maxPhotos)', style: const TextStyle(fontWeight: FontWeight.w700)),
        Muted(ctx.m('photosHint', {'n': _maxPhotos})),
        const SizedBox(height: 8),
        if (_isNew)
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              '${ctx.m('save')} → ${ctx.m('addPhoto')}',
              icon: LucideIcons.imagePlus,
              kind: BtnKind.ghost,
              small: true,
              busy: _busy == 'save',
              onTap: _busy.isNotEmpty || ctx.readOnly || noName ? null : () => _save(close: false),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, p) in photos.indexed)
                SizedBox(
                  width: 92,
                  height: 92,
                  child: MediaTile(
                    url: str(p['url']),
                    selected: i == 0,
                    badge: i == 0 ? mediaBadge(context, '★', true) : null,
                    corner: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0) _round(LucideIcons.star, ctx.readOnly ? null : () => _cover(p)),
                        const SizedBox(width: 4),
                        _busy == 'del-${p['_id']}'
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : _round(LucideIcons.x, ctx.readOnly || _busy.isNotEmpty ? null : () => _removePhoto(p)),
                      ],
                    ),
                  ),
                ),
              if (photos.length < _maxPhotos)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: ctx.readOnly || _busy.isNotEmpty ? null : () => pickMedia(context, ctx, max: _maxPhotos - photos.length, onPick: _attach),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _busy == 'photo' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(LucideIcons.imagePlus, color: c.muted),
                        const SizedBox(height: 4),
                        Text(
                          _busy == 'photo' ? ctx.m('uploading') : ctx.m('fromMedia'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (_err.isNotEmpty) ...[const SizedBox(height: 10), Alert(_err)],
      ],
    );
  }

  Widget _round(IconData icon, VoidCallback? onTap) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    ),
  );
}
