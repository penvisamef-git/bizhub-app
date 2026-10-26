import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';

// Menu (the web's MenuTab): categories → items (sizes, add-ons, station, stock) · add-on groups · kitchen stations
class MenuSection extends StatefulWidget {
  final RestCtx ctx;
  const MenuSection({super.key, required this.ctx});
  @override
  State<MenuSection> createState() => _MenuSectionState();
}

class _MenuSectionState extends State<MenuSection> {
  String _view = 'items';
  List<Json>? _cats, _items, _groups, _stations;
  String? _catId;
  bool _sampling = false;
  RestCtx get ctx => widget.ctx;
  bool get _kitchen => ctx.addonOn('rest_kitchen');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        for (final k in const ['categories', 'items', 'addon-groups', 'stations']) ctx.api.get('${ctx.base}/$k'),
      ]);
      if (!mounted) return;
      setState(() {
        _cats = objs(r[0]['data']);
        _items = objs(r[1]['data']);
        _groups = objs(r[2]['data']);
        _stations = objs(r[3]['data']);
        if (_catId == null || !_cats!.any((c) => str(c['_id']) == _catId)) _catId = _cats!.isEmpty ? null : str(_cats!.first['_id']);
      });
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _samples() async {
    setState(() => _sampling = true);
    try {
      final r = await ctx.api.post('${ctx.base}/stock/sample');
      await _load();
      ctx.reload();
      ctx.notify(r['tracked'] == true ? ctx.t('stock.samplesDone') : ctx.t('stock.samplesDoneNoStock'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _sampling = false);
    }
  }

  Future<void> _move(String collection, List<Json> list, int i, int d) async {
    final ids = list.map((x) => str(x['_id'])).toList();
    final t = ids[i];
    ids[i] = ids[i + d];
    ids[i + d] = t;
    try {
      await ctx.api.put('${ctx.base}/$collection/order', {'ids': ids});
      _load();
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _toggle(Json item) async {
    final on = item['available'] != true;
    setState(
      () => _items = [
        for (final x in _items!) x['_id'] == item['_id'] ? {...x, 'available': on} : x,
      ],
    );
    try {
      await ctx.api.put('${ctx.base}/items/${item['_id']}', {'available': on});
    } catch (e) {
      ctx.fail(e);
      _load();
    }
  }

  Future<void> _open(Widget editor) async {
    final ok = await showEditor<bool>(context, builder: (_) => editor);
    if (ok == true) {
      _load();
      ctx.reload();
    }
  }

  // a new item stays open so a photo can be added (like the web)
  Future<void> _openItem(Json row) async {
    final result = await showEditor<Object>(
      context,
      builder: (_) => _ItemEditor(ctx: ctx, row: row, cats: _cats!, groups: _groups!, stations: _stations!, kitchen: _kitchen),
    );
    if (result == null) return;
    await _load();
    ctx.reload();
    if (result is Json && mounted) _openItem(result);
  }

  String _price(num v) => ctx.currency == 'KHR' ? fmtMoney(v, 'KHR') : fmtMoney(v);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_cats == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final ro = ctx.readOnly;
    final counts = {'items': _items!.length, 'groups': _groups!.length, 'stations': _stations!.length};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // items · add-on groups · stations
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), boxShadow: c.cardShadow),
          child: Row(
            children: [
              for (final k in const ['items', 'groups', 'stations'])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _view = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: _view == k ? c.solid : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (k == 'stations' && !_kitchen) ...[Icon(LucideIcons.lock, size: 12, color: _view == k ? c.onSolid : c.muted), const SizedBox(width: 4)],
                          Flexible(
                            child: Text(
                              ctx.r('menuTabs.$k'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _view == k ? c.onSolid : c.muted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${counts[k]}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _view == k ? c.onSolid.withValues(alpha: .7) : c.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap14,
        if (_view == 'items') ..._itemsView(c, ro),
        if (_view == 'groups') _groupsView(c, ro),
        if (_view == 'stations') _kitchen ? _stationsView(c, ro) : AddonPrompt(ctx: ctx, addonKey: 'rest_kitchen'),
      ],
    );
  }

  List<Widget> _itemsView(C c, bool ro) {
    final cats = _cats!;
    final i = cats.indexWhere((x) => str(x['_id']) == _catId);
    final cat = i < 0 ? null : cats[i];
    final items = _items!.where((x) => str(x['category_id']) == _catId).toList();
    return [
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(
              ctx.r('categories'),
              trailing: RoundBtn(
                LucideIcons.plus,
                size: 38,
                tip: ctx.r('addCategory'),
                onTap: ro ? null : () => _open(_CategoryEditor(ctx: ctx, row: const {})),
              ),
            ),
            if (cats.isEmpty) Muted(ctx.r('noCategories')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final x in cats)
                  ChoiceChip(
                    selected: str(x['_id']) == _catId,
                    onSelected: (_) => setState(() => _catId = str(x['_id'])),
                    showCheckmark: false,
                    selectedColor: c.active,
                    backgroundColor: c.bg2,
                    side: BorderSide(color: str(x['_id']) == _catId ? c.brand : c.line),
                    shape: const StadiumBorder(),
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: hexToColor(str(x['color'])), shape: BoxShape.circle),
                    ),
                    label: Text(
                      '${nameOf(x, ctx.lang)}  ${_items!.where((it) => str(it['category_id']) == str(x['_id'])).length}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: str(x['_id']) == _catId ? c.brandInk : c.ink),
                    ),
                  ),
              ],
            ),
            if (cat != null && !ro) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  RoundBtn(LucideIcons.arrowLeft, size: 36, tip: ctx.r('moveUp'), onTap: i == 0 ? null : () => _move('categories', cats, i, -1)),
                  const SizedBox(width: 6),
                  RoundBtn(LucideIcons.arrowRight, size: 36, tip: ctx.r('moveDown'), onTap: i == cats.length - 1 ? null : () => _move('categories', cats, i, 1)),
                  const SizedBox(width: 6),
                  Btn(
                    ctx.r('editCategory'),
                    icon: LucideIcons.pencil,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => _open(_CategoryEditor(ctx: ctx, row: cat)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      gap14,
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestHead(
              cat == null ? ctx.r('items') : nameOf(cat, ctx.lang),
              trailing: Btn(ctx.r('addItem'), icon: LucideIcons.plus, small: true, onTap: ro || cat == null ? null : () => _openItem({'category_id': _catId})),
            ),
            if (_items!.length <= 40) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  _sampling ? ctx.r('saving') : ctx.t('stock.addSamples'),
                  icon: LucideIcons.sparkles,
                  kind: BtnKind.ghost,
                  small: true,
                  busy: _sampling,
                  onTap: ro || _sampling ? null : _samples,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (cat != null && items.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Muted(ctx.r('noItems'))),
            for (final it in items) _itemRow(it, c, ro),
          ],
        ),
      ),
    ];
  }

  Widget _itemRow(Json it, C c, bool ro) {
    final photo = str(obj(it['photo'])['url']);
    final sizes = (it['sizes'] as List?)?.length ?? 0;
    final opts = (it['addon_group_ids'] as List?)?.length ?? 0;
    final stockOn = it['track_stock'] == true && ctx.addonOn('rest_stock');
    final stock = n(it['stock']), low = it['low_stock'] == null ? 5 : n(it['low_stock']);
    final meta = [str(it['code']), if (sizes > 0) '$sizes ${ctx.r('sizes').toLowerCase()}', if (opts > 0) '$opts ${ctx.r('options').toLowerCase()}'].where((x) => x.isNotEmpty).join(' · ');
    return Opacity(
      opacity: it['active'] == false ? .5 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: ro ? null : () => _openItem(it),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: photo.isNotEmpty ? Image(image: netImage(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.imagePlus, size: 20, color: c.muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nameOf(it, ctx.lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, decoration: it['available'] == false ? TextDecoration.lineThrough : null),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _price(n(it['price'])),
                              style: TextStyle(fontWeight: FontWeight.w800, color: c.brandInk),
                            ),
                            if (ctx.currency == 'USD') ...[
                              const SizedBox(width: 6),
                              Text(
                                fmtMoney(toKhr(n(it['price']), n(ctx.settings['khr_rate']), n(ctx.settings['khr_rounding']) == 0 ? 100 : n(ctx.settings['khr_rounding'])), 'KHR'),
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        if (meta.isNotEmpty || stockOn)
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (meta.isNotEmpty) Text(meta, style: TextStyle(color: c.muted, fontSize: 12)),
                              if (stockOn)
                                Chip2(
                                  stock <= 0 ? ctx.t('stock.soldOut') : ctx.t('stock.left', {'n': fmt(stock)}),
                                  tone: stock <= 0
                                      ? Tone.danger
                                      : stock <= low
                                      ? Tone.warn
                                      : Tone.good,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Switch.adaptive(value: it['available'] != false, onChanged: ro ? null : (_) => _toggle(it)),
                      Text(
                        it['available'] != false ? ctx.r('available') : ctx.r('soldOut'),
                        style: TextStyle(fontSize: 10.5, color: c.muted, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupsView(C c, bool ro) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RestHead(
          ctx.r('addonGroups'),
          sub: ctx.r('addonGroupsHint'),
          trailing: Btn(
            ctx.r('addGroup'),
            icon: LucideIcons.plus,
            small: true,
            onTap: ro ? null : () => _open(_GroupEditor(ctx: ctx, row: const {})),
          ),
        ),
        if (_groups!.isEmpty) Muted(ctx.r('noGroups')),
        for (final g in _groups!)
          _row(
            c,
            title: str(g['name']),
            sub:
                '${g['required'] == true ? '${ctx.r('groupRequired')} · ' : ''}${g['min']}–${g['max']} · ${objs(g['options']).map((o) => '${o['name']}${n(o['price']) > 0 ? ' +${_price(n(o['price']))}' : ''}').join(', ')}',
            onTap: ro ? null : () => _open(_GroupEditor(ctx: ctx, row: g)),
          ),
      ],
    ),
  );

  Widget _stationsView(C c, bool ro) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RestHead(
          ctx.r('stations'),
          sub: ctx.r('stationsHint'),
          trailing: Btn(
            ctx.r('addStation'),
            icon: LucideIcons.plus,
            small: true,
            onTap: ro ? null : () => _open(_StationEditor(ctx: ctx, row: const {})),
          ),
        ),
        if (_stations!.isEmpty) Muted(ctx.r('noStations')),
        for (final s in _stations!)
          _row(
            c,
            icon: LucideIcons.chefHat,
            title: str(s['name']),
            sub:
                '${ctx.r('printerTypes.${str(obj(s['printer'])['type']).isEmpty ? 'none' : obj(s['printer'])['type']}')}${str(obj(s['printer'])['address']).isNotEmpty ? ' · ${obj(s['printer'])['address']}' : ''}',
            onTap: ro ? null : () => _open(_StationEditor(ctx: ctx, row: s)),
          ),
      ],
    ),
  );

  Widget _row(C c, {IconData? icon, required String title, required String sub, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: c.ink), const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(LucideIcons.pencil, size: 14, color: c.muted),
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================================================= editors
mixin _Saver<W extends StatefulWidget> on State<W> {
  RestCtx get ctx;
  bool busy = false;
  Future<void> run(Future<Object?> Function() f, {bool returnResult = false}) async {
    setState(() => busy = true);
    try {
      final r = await f();
      if (mounted) Navigator.pop(context, returnResult ? r : true);
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => busy = false);
    }
  }
}

class _CategoryEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  const _CategoryEditor({required this.ctx, required this.row});
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> with _Saver {
  @override
  RestCtx get ctx => widget.ctx;
  late final _km = TextEditingController(text: str(widget.row['name_km']));
  late final _en = TextEditingController(text: str(widget.row['name_en']));
  late String _color = str(widget.row['color']).isEmpty ? '#E0581A' : str(widget.row['color']).toUpperCase();
  late bool _active = widget.row['active'] != false;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _km.dispose();
    _en.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorFrame(
    title: _isNew ? ctx.r('addCategory') : ctx.r('editCategory'),
    cancel: ctx.r('cancel'),
    save: ctx.r('save'),
    busy: busy,
    canSave: _km.text.trim().isNotEmpty || _en.text.trim().isNotEmpty,
    onSave: () => run(() {
      final data = {'name_km': _km.text, 'name_en': _en.text, 'color': _color, 'active': _active};
      return _isNew ? ctx.api.post('${ctx.base}/categories', data) : ctx.api.put('${ctx.base}/categories/${widget.row['_id']}', data);
    }),
    delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: busy ? null : () => run(() => ctx.api.delete('${ctx.base}/categories/${widget.row['_id']}'))),
    children: [
      Field(label: ctx.r('categoryNameKm'), controller: _km, maxLength: 60, autofocus: _isNew, onChanged: (_) => setState(() {})),
      gap14,
      Field(label: ctx.r('categoryNameEn'), controller: _en, maxLength: 60, onChanged: (_) => setState(() {})),
      gap14,
      ColorRow(value: _color, onChanged: (v) => setState(() => _color = v), customLabel: ctx.r('customColor'), saveLabel: ctx.r('save'), cancelLabel: ctx.r('cancel')),
      const SizedBox(height: 6),
      SwitchRow(title: ctx.r('showOnMenu'), value: _active, onChanged: (v) => setState(() => _active = v)),
    ],
  );
}

// name + price rows (sizes of an item, options of a group)
class _PricedRows extends StatelessWidget {
  final List<(TextEditingController, TextEditingController)> rows;
  final String nameLabel, addLabel, removeLabel;
  final int max;
  final VoidCallback onAdd;
  final void Function(int i) onRemove;
  final VoidCallback onChanged;
  const _PricedRows({
    required this.rows,
    required this.nameLabel,
    required this.addLabel,
    required this.removeLabel,
    required this.max,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Field(controller: rows[i].$1, hint: nameLabel, maxLength: 40, onChanged: (_) => onChanged()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Field(
                    controller: rows[i].$2,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 9,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 4),
                      child: Text('\$', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                RoundBtn(LucideIcons.trash2, size: 38, tip: removeLabel, fg: c.danger, onTap: () => onRemove(i)),
              ],
            ),
          ),
        if (rows.length < max)
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(addLabel, icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: onAdd),
          ),
      ],
    );
  }
}

typedef _Pair = (TextEditingController, TextEditingController);
_Pair _pair(Object? name, Object? price) => (TextEditingController(text: str(name)), TextEditingController(text: price == null ? '0' : '$price'));
List<Json> _pairsValue(List<_Pair> rows) => [
  for (final r in rows)
    if (r.$1.text.trim().isNotEmpty) {'name': r.$1.text, 'price': num.tryParse(r.$2.text) ?? 0},
];

class _ItemEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  final List<Json> cats, groups, stations;
  final bool kitchen;
  const _ItemEditor({required this.ctx, required this.row, required this.cats, required this.groups, required this.stations, required this.kitchen});
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> with _Saver {
  @override
  RestCtx get ctx => widget.ctx;
  Json get row => widget.row;
  bool get _isNew => row['_id'] == null;
  late final _km = TextEditingController(text: str(row['name_km']));
  late final _en = TextEditingController(text: str(row['name_en']));
  late final _price = TextEditingController(text: row['price'] == null ? '' : '${row['price']}');
  late final _cost = TextEditingController(text: row['cost'] == null || n(row['cost']) == 0 ? '' : '${row['cost']}');
  late final _code = TextEditingController(text: str(row['code']));
  late final _desc = TextEditingController(text: str(row['description']));
  late final _stock = TextEditingController();
  late final _low = TextEditingController(text: '${row['low_stock'] ?? 5}');
  late String _cat = str(row['category_id']).isNotEmpty ? str(row['category_id']) : (widget.cats.isEmpty ? '' : str(widget.cats.first['_id']));
  late String _station = str(row['station_id']);
  late final List<_Pair> _sizes = [for (final s in objs(row['sizes'])) _pair(s['name'], s['price'])];
  late final Set<String> _groupIds = {for (final g in (row['addon_group_ids'] as List? ?? const [])) '$g'};
  late bool _available = row['available'] != false, _active = row['active'] != false, _track = row['track_stock'] == true;
  late String _photo = str(obj(row['photo'])['url']);
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_km, _en, _price, _cost, _code, _desc, _stock, _low]) {
      c.dispose();
    }
    for (final p in _sizes) {
      p.$1.dispose();
      p.$2.dispose();
    }
    super.dispose();
  }

  bool get _can => (_km.text.trim().isNotEmpty || _en.text.trim().isNotEmpty) && num.tryParse(_price.text) != null && num.parse(_price.text) >= 0 && _cat.isNotEmpty;

  String _profitHint() {
    final p = num.tryParse(_price.text) ?? 0, cost = num.tryParse(_cost.text);
    if (p == 0 || cost == null) return ctx.t('stock.costHint');
    final profit = p - cost;
    return ctx.t('stock.profitHint', {'v': ctx.currency == 'KHR' ? fmtMoney(profit, 'KHR') : fmtMoney(profit), 'p': (profit / p * 100).round()});
  }

  Future<void> _pickPhoto(List<int> bytes, String name) async {
    setState(() => _uploading = true);
    try {
      final r = await ctx.api.post('${ctx.base}/items/${row['_id']}/photo', imageForm(bytes, 'photo.jpg'));
      setState(() => _photo = str(obj(obj(r['data'])['photo'])['url']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _dropPhoto() async {
    setState(() => _uploading = true);
    try {
      await ctx.api.delete('${ctx.base}/items/${row['_id']}/photo');
      setState(() => _photo = '');
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stockOn = ctx.addonOn('rest_stock');
    final step = ctx.currency == 'KHR' ? '' : '';
    return EditorFrame(
      title: _isNew ? ctx.r('addItem') : ctx.r('editItem'),
      cancel: ctx.r('cancel'),
      save: ctx.r('save'),
      busy: busy,
      canSave: _can,
      onSave: () => run(() async {
        final data = {
          'name_km': _km.text,
          'name_en': _en.text,
          'price': num.parse(_price.text),
          'cost': num.tryParse(_cost.text) ?? 0,
          'code': _code.text,
          'description': _desc.text,
          'category_id': _cat,
          'station_id': _station.isEmpty ? null : _station,
          'sizes': _pairsValue(_sizes),
          'addon_group_ids': _groupIds.toList(),
          'available': _available,
          'active': _active,
          'low_stock': int.tryParse(_low.text) ?? 0,
          if (stockOn) 'track_stock': _track,
          if (_isNew && _track) 'stock': num.tryParse(_stock.text) ?? 0, // first quantity only when created
        };
        if (_isNew) {
          final r = await ctx.api.post('${ctx.base}/items', data);
          return obj(r['data']); // reopen it so a photo can be added
        }
        await ctx.api.put('${ctx.base}/items/${row['_id']}', data);
        return true;
      }, returnResult: true),
      delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: busy ? null : () => run(() => ctx.api.delete('${ctx.base}/items/${row['_id']}'))),
      children: [
        Text(ctx.r('itemPhoto'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 8),
        _isNew ? Muted(ctx.r('savePhotoFirst')) : ImagePickRow(ctx: ctx, url: _photo, busy: _uploading, maxSize: 900, onPick: _pickPhoto, onRemove: _dropPhoto),
        gap14,
        Field(label: ctx.r('nameKm'), controller: _km, maxLength: 80, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.r('nameEn'), controller: _en, maxLength: 80, onChanged: (_) => setState(() {})),
        gap14,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Field(
                label: '${ctx.r('price')} (${ctx.currency})$step',
                controller: _price,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 10,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(
                label: '${ctx.t('stock.costLabel')} (${ctx.currency})',
                controller: _cost,
                hint: '0',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 10,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(_profitHint())),
        gap14,
        Field(label: ctx.r('code'), controller: _code, hint: ctx.r('codePh'), maxLength: 20),
        gap14,
        SelectField<String>(label: ctx.r('category'), value: _cat, options: [for (final x in widget.cats) (str(x['_id']), nameOf(x, ctx.lang))], onChanged: (v) => setState(() => _cat = v)),
        gap14,
        SelectField<String>(
          label: ctx.r('station'),
          value: _station,
          hint: widget.kitchen ? null : ctx.r('stationLocked'),
          options: [('', ctx.r('noStation')), for (final s in widget.stations) (str(s['_id']), str(s['name']))],
          onChanged: widget.kitchen ? (v) => setState(() => _station = v) : null,
        ),
        gap14,
        Field(label: ctx.r('description'), controller: _desc, maxLength: 300, maxLines: 2),
        gap14,
        Text(ctx.r('sizes'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Muted(ctx.r('sizesHint'))),
        _PricedRows(
          rows: _sizes,
          nameLabel: ctx.r('sizeName'),
          addLabel: ctx.r('addSize'),
          removeLabel: ctx.r('remove'),
          max: 10,
          onAdd: () => setState(() => _sizes.add(_pair('', 0))),
          onRemove: (i) => setState(() => _sizes.removeAt(i)),
          onChanged: () => setState(() {}),
        ),
        gap14,
        Text(ctx.r('addonGroups'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Muted(widget.groups.isEmpty ? ctx.r('noGroups') : ctx.r('addonGroupsHint'))),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in widget.groups)
              FilterChip(
                selected: _groupIds.contains(str(g['_id'])),
                onSelected: (on) => setState(() => on ? _groupIds.add(str(g['_id'])) : _groupIds.remove(str(g['_id']))),
                label: Text(str(g['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                selectedColor: c.active,
                checkmarkColor: c.brand,
                side: BorderSide(color: _groupIds.contains(str(g['_id'])) ? c.brand : c.line),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        gap14,
        // stock
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ctx.t('stock.stock'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (stockOn)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ctx.t('stock.trackStock'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Switch.adaptive(value: _track, onChanged: (v) => setState(() => _track = v)),
                      ],
                    )
                  else
                    Btn(
                      ctx.t('stock.unlockStock'),
                      icon: LucideIcons.lock,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: () {
                        Navigator.pop(context);
                        ctx.askBuy('rest_stock');
                      },
                    ),
                ],
              ),
              if (!stockOn) Padding(padding: const EdgeInsets.only(top: 6), child: Muted(ctx.t('stock.stockLockedHint'))),
              if (stockOn && _track) ...[
                const SizedBox(height: 10),
                if (_isNew) ...[
                  Field(label: ctx.t('stock.openingQty'), controller: _stock, hint: '0', keyboard: TextInputType.number, maxLength: 7),
                  Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.t('stock.openingHint'))),
                ] else
                  Row(
                    children: [
                      Text(ctx.t('stock.inStock'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Text(
                        fmt(n(row['stock'])),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: n(row['stock']) <= 0
                              ? c.danger
                              : n(row['stock']) <= (int.tryParse(_low.text) ?? 5)
                              ? c.warn
                              : c.good,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Muted(ctx.t('stock.changeInStock'))),
                    ],
                  ),
                gap14,
                Field(label: ctx.t('stock.lowAlert'), controller: _low, keyboard: TextInputType.number, maxLength: 6),
                Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.t('stock.lowAlertHint'))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.r('available'), value: _available, onChanged: (v) => setState(() => _available = v)),
        SwitchRow(title: ctx.r('showOnMenu'), value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
    );
  }
}

class _GroupEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  const _GroupEditor({required this.ctx, required this.row});
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> with _Saver {
  @override
  RestCtx get ctx => widget.ctx;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _min = TextEditingController(text: '${widget.row['min'] ?? 0}');
  late final _max = TextEditingController(text: '${widget.row['max'] ?? 1}');
  late bool _required = widget.row['required'] == true;
  late final List<_Pair> _options = [for (final o in objs(widget.row['options'])) _pair(o['name'], o['price'])];
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final min = int.tryParse(_min.text) ?? 0, max = int.tryParse(_max.text) ?? 1;
    return EditorFrame(
      title: _isNew ? ctx.r('addGroup') : ctx.r('editGroup'),
      cancel: ctx.r('cancel'),
      save: ctx.r('save'),
      busy: busy,
      canSave: _name.text.trim().isNotEmpty && min <= max,
      onSave: () => run(() {
        final data = {'name': _name.text, 'required': _required, 'min': min, 'max': max, 'options': _pairsValue(_options)};
        return _isNew ? ctx.api.post('${ctx.base}/addon-groups', data) : ctx.api.put('${ctx.base}/addon-groups/${widget.row['_id']}', data);
      }),
      delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: busy ? null : () => run(() => ctx.api.delete('${ctx.base}/addon-groups/${widget.row['_id']}'))),
      children: [
        Field(label: ctx.r('groupName'), hint: ctx.r('groupNamePh'), controller: _name, maxLength: 40, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Row(
          children: [
            Expanded(
              child: Field(label: ctx.r('minPick'), controller: _min, keyboard: TextInputType.number, maxLength: 2, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Field(label: ctx.r('maxPick'), controller: _max, keyboard: TextInputType.number, maxLength: 2, onChanged: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SwitchRow(
          title: ctx.r('groupRequired'),
          value: _required,
          onChanged: (v) => setState(() {
            _required = v;
            if (v && min < 1) _min.text = '1';
          }),
        ),
        Text(ctx.r('options'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 8),
        _PricedRows(
          rows: _options,
          nameLabel: ctx.r('optionName'),
          addLabel: ctx.r('addOption'),
          removeLabel: ctx.r('remove'),
          max: 30,
          onAdd: () => setState(() => _options.add(_pair('', 0))),
          onRemove: (i) => setState(() => _options.removeAt(i)),
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }
}

class _StationEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  const _StationEditor({required this.ctx, required this.row});
  @override
  State<_StationEditor> createState() => _StationEditorState();
}

class _StationEditorState extends State<_StationEditor> with _Saver {
  @override
  RestCtx get ctx => widget.ctx;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _addr = TextEditingController(text: str(obj(widget.row['printer'])['address']));
  late String _type = str(obj(widget.row['printer'])['type']).isEmpty ? 'none' : str(obj(widget.row['printer'])['type']);
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = ctx.addonOn('rest_printer');
    return EditorFrame(
      title: _isNew ? ctx.r('addStation') : ctx.r('editStation'),
      cancel: ctx.r('cancel'),
      save: ctx.r('save'),
      busy: busy,
      canSave: _name.text.trim().isNotEmpty,
      onSave: () => run(() {
        final data = {
          'name': _name.text,
          'printer': canPrint ? {'type': _type, 'address': _addr.text} : {'type': 'none'},
        };
        return _isNew ? ctx.api.post('${ctx.base}/stations', data) : ctx.api.put('${ctx.base}/stations/${widget.row['_id']}', data);
      }),
      delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: busy ? null : () => run(() => ctx.api.delete('${ctx.base}/stations/${widget.row['_id']}'))),
      children: [
        Field(label: ctx.r('stationName'), hint: 'Kitchen', controller: _name, maxLength: 40, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        SelectField<String>(
          label: ctx.r('printer'),
          value: canPrint ? _type : 'none',
          hint: canPrint ? null : ctx.r('printerNeedsAddon'),
          options: [
            for (final k in const ['none', 'network', 'usb']) (k, ctx.r('printerTypes.$k')),
          ],
          onChanged: canPrint ? (v) => setState(() => _type = v) : null,
        ),
        if (!canPrint) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.r('addonNames.rest_printer'),
              icon: LucideIcons.lock,
              small: true,
              onTap: ctx.readOnly
                  ? null
                  : () {
                      Navigator.pop(context);
                      ctx.askBuy('rest_printer');
                    },
            ),
          ),
        ],
        if (canPrint && _type != 'none') ...[gap14, Field(label: ctx.r('printerAddress'), hint: _type == 'network' ? '192.168.1.50' : 'USB001', controller: _addr, maxLength: 100)],
      ],
    );
  }
}
