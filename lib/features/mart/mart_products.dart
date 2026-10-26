import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SelectField, SwitchRow, showEditor, gap14;
import 'mart_branches.dart' show openLabels;
import 'mart_common.dart';

// Products — the app version of MartProducts.jsx: list, editor (with a camera barcode scanner), units, categories, CSV import.

// ---------------- CSV (Excel → Save as CSV, or copy + paste from Excel) ----------------
const _heads = {
  'name': ['name', 'product', 'ឈ្មោះ', 'ឈ្មោះទំនិញ'],
  'barcode': ['barcode', 'code', 'បាកូដ'],
  'price': ['price', 'sale price', 'តម្លៃ', 'តម្លៃលក់'],
  'cost': ['cost', 'ថ្លៃដើម'],
  'unit': ['unit', 'ឯកតា'],
  'category': ['category', 'ប្រភេទ'],
};
const _order = ['name', 'barcode', 'price', 'cost', 'unit', 'category'];
List<Json> parseRows(String input) {
  final src = input.replaceFirst('﻿', '');
  final first = src.split(RegExp(r'\r?\n')).first;
  final sep = first.contains('\t') ? '\t' : (first.split(';').length > first.split(',').length ? ';' : ',');
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var q = false;
  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (q) {
      if (ch == '"' && i + 1 < src.length && src[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        q = false;
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      q = true;
    } else if (ch == sep) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
      row.add(cell.toString());
      rows.add(row);
      row = [];
      cell = StringBuffer();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  final clean = rows.map((r) => r.map((c) => c.trim()).toList()).where((r) => r.any((c) => c.isNotEmpty)).toList();
  if (clean.isEmpty) return [];
  final head = clean.first.map((h) => h.toLowerCase()).toList();
  final isHead = head.any((h) => _heads.values.any((l) => l.contains(h)));
  final cols = isHead ? head.map((h) => _heads.entries.where((e) => e.value.contains(h)).map((e) => e.key).firstOrNull).toList() : _order;
  return [
    for (final r in isHead ? clean.skip(1) : clean)
      () {
        final o = <String, dynamic>{};
        for (var i = 0; i < cols.length; i++) {
          final k = cols[i];
          if (k != null && i < r.length) o[k] = r[i];
        }
        for (final k in ['price', 'cost']) {
          if (o[k] != null) o[k] = str(o[k]).replaceAll(RegExp(r'[$៛,\s]'), '');
        }
        return o;
      }(),
  ];
}

const _example = '﻿name,barcode,price,cost,unit,category\nCoca-Cola 330ml,8850999320011,0.60,0.45,can,Drinks\nBread,,1.25,,ដុំ,Bakery\n';

class ProductsTab extends StatefulWidget {
  final MartCtx ctx;
  const ProductsTab({super.key, required this.ctx});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  List<Json>? _rows;
  late List<Json> _cats = objs(ctx.data['categories']), _units = objs(ctx.data['units']);
  final _q = TextEditingController();
  String _query = '', _cat = '';
  String _error = '';
  MartCtx get ctx => widget.ctx;

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
      final r = await Future.wait([ctx.api.get('${ctx.base}/products'), ctx.api.get('${ctx.base}/categories'), ctx.api.get('${ctx.base}/units')]);
      if (!mounted) return;
      setState(() {
        _rows = objs(r[0]['data']);
        _cats = objs(r[1]['data']);
        _units = objs(r[2]['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
  }

  void _changed() {
    _load();
    ctx.reload();
  }

  String _catName(Object? id) => str(_cats.where((c) => str(c['_id']) == str(id)).firstOrNull?['name']);
  String _unitName(Object? id) => unitName(_units.where((u) => str(u['_id']) == str(id)).firstOrNull, ctx.lang);

  Future<void> _edit(Json row) async {
    final saved = await showEditor<bool>(
      context,
      builder: (_) => ProductEditor(ctx: ctx, row: row, cats: _cats, units: _units),
    );
    if (saved == true) _changed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = _rows;
    final active = (rows ?? []).where((p) => p['active'] == true).length;
    final max = n(ctx.limits['products']);
    final full = active >= max;
    final t = _query.trim().toLowerCase();
    final shown = (rows ?? [])
        .where((p) => _cat.isEmpty || (_cat == 'none' ? p['category_id'] == null : str(p['category_id']) == _cat))
        .where((p) => t.isEmpty || str(p['name']).toLowerCase().contains(t) || str(p['barcode']).contains(t))
        .toList();
    final withStock = ctx.stockOn;
    if (_error.isNotEmpty && rows == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ctx.m('tabs.products'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Muted(ctx.m('productLimit', {'n': active, 'max': max})),
                        ],
                      ),
                    ),
                    Btn(
                      ctx.m('addProduct'),
                      icon: full ? LucideIcons.lock : LucideIcons.plus,
                      small: true,
                      onTap: ctx.readOnly || rows == null ? null : () => full ? ctx.notify(ctx.m('limitReached', {'max': max})) : _edit({}),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      ctx.m('unitsTitle'),
                      icon: LucideIcons.ruler,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly
                          ? null
                          : () async {
                              await showEditor<void>(
                                context,
                                builder: (_) => _UnitsSheet(ctx: ctx, units: _units, onChanged: _changed),
                              );
                              _load();
                            },
                    ),
                    Btn(
                      ctx.m('categories'),
                      icon: LucideIcons.tags,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly
                          ? null
                          : () async {
                              await showEditor<void>(
                                context,
                                builder: (_) => _CatsSheet(ctx: ctx, cats: _cats, onChanged: _changed),
                              );
                              _load();
                            },
                    ),
                    Btn(ctx.m('labels'), icon: LucideIcons.barcode, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly || rows == null ? null : () => openLabels(context, ctx, rows, _changed)),
                    Btn(
                      ctx.m('import'),
                      icon: LucideIcons.fileSpreadsheet,
                      kind: BtnKind.ghost,
                      small: true,
                      onTap: ctx.readOnly
                          ? null
                          : () => showEditor<void>(
                              context,
                              builder: (_) => _ImportSheet(ctx: ctx, onDone: _changed),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Field(
                  controller: _q,
                  hint: ctx.m('search'),
                  icon: LucideIcons.search,
                  onChanged: (v) => setState(() => _query = v),
                  suffix: IconButton(
                    tooltip: ctx.t('app.scanBarcode'),
                    icon: const Icon(LucideIcons.scanBarcode, size: 18),
                    onPressed: () async {
                      final v = await scanBarcode(context, ctx.t);
                      if (v == null) return;
                      _q.text = v;
                      setState(() => _query = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (k, label) in [('', ctx.m('allCats')), for (final cat in _cats) (str(cat['_id']), str(cat['name'])), ('none', ctx.m('noCat'))])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _cat == k,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _cat = k),
                            selectedColor: c.active,
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _cat == k ? c.brandInk : c.ink),
                            side: BorderSide(color: _cat == k ? c.brand : c.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          mGap,
          if (rows == null)
            const SkelList(rows: 6)
          else if (shown.isEmpty)
            Panel(
              child: Column(
                children: [
                  Icon(LucideIcons.package, size: 30, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(ctx.m('noProducts')),
                ],
              ),
            )
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Column(
                children: [
                  for (final (i, p) in shown.indexed) ...[
                    if (i > 0) Divider(height: 1, color: c.line, indent: 64),
                    _ProductRow(
                      ctx: ctx,
                      p: p,
                      sub: [
                        str(p['barcode']).isEmpty ? '—' : str(p['barcode']),
                        if (p['unit_id'] != null) _unitName(p['unit_id']),
                        if (p['category_id'] != null) _catName(p['category_id']),
                        if (p['active'] != true) ctx.m('off'),
                      ].where((x) => x.isNotEmpty).join(' · '),
                      withStock: withStock,
                      onTap: ctx.readOnly ? null : () => _edit(p),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final MartCtx ctx;
  final Json p;
  final String sub;
  final bool withStock;
  final VoidCallback? onTap;
  const _ProductRow({required this.ctx, required this.p, required this.sub, required this.withStock, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final photo = str(obj(p['photo'])['url']);
    final stock = n(p['stock']);
    final low = p['low_stock'] == null ? 5 : n(p['low_stock']);
    return Opacity(
      opacity: p['active'] == true ? 1 : .55,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: photo.isNotEmpty ? Image(image: netImage(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.package, size: 20, color: c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (p['fav'] == true) ...[const Icon(LucideIcons.star, size: 13, color: Color(0xFFE0A21A)), const SizedBox(width: 4)],
                        Flexible(
                          child: Text(
                            str(p['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (withStock && p['track_stock'] == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stock <= 0
                        ? c.dangerBg
                        : stock <= low
                        ? c.warnBg
                        : c.bg2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    qtyOf(stock),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: stock <= 0
                          ? c.danger
                          : stock <= low
                          ? c.warn
                          : c.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(money(p['price'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- editor
class ProductEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  final List<Json> cats, units;
  const ProductEditor({super.key, required this.ctx, required this.row, required this.cats, required this.units});
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late final Json r = widget.row;
  late final bool isNew = r['_id'] == null;
  late final _name = TextEditingController(text: str(r['name']));
  late final _code = TextEditingController(text: str(r['barcode']));
  late final _price = TextEditingController(text: r['price'] == null ? '' : '${r['price']}');
  late final _cost = TextEditingController(text: n(r['cost']) == 0 ? '' : '${r['cost']}');
  late final _stock = TextEditingController(text: isNew ? '' : qtyOf(r['stock']));
  late final _low = TextEditingController(text: r['low_stock'] == null ? '5' : qtyOf(r['low_stock']));
  late final _plu = TextEditingController(text: str(r['plu']));
  late final _rq = TextEditingController(text: n(r['reorder_qty']) == 0 ? '' : qtyOf(r['reorder_qty']));
  late String _unit = r['unit_id'] != null ? str(r['unit_id']) : (widget.units.isNotEmpty ? str(widget.units.first['_id']) : '');
  late String _cat = str(r['category_id']);
  late String _sup = str(r['supplier_id']);
  late bool _track = r['track_stock'] != false, _fav = r['fav'] == true, _active = r['active'] != false;
  late String _photo = str(obj(r['photo'])['url']);
  Uint8List? _file;
  List<Json> _sups = [];
  bool _busy = false;
  String _error = '';
  MartCtx get ctx => widget.ctx;
  bool get _scaleOn => ctx.addonOn('mart_scale');
  bool get _buyOn => ctx.addonOn('mart_purchase');
  bool get _supsOn => ctx.addonOn('mart_suppliers');

  @override
  void initState() {
    super.initState();
    if (_buyOn && _supsOn) {
      ctx.api.get('${ctx.base}/suppliers').then((x) {
        if (mounted) setState(() => _sups = objs(x['data']));
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    for (final x in [_name, _code, _price, _cost, _stock, _low, _plu, _rq]) {
      x.dispose();
    }
    super.dispose();
  }

  bool get _ok => _name.text.trim().isNotEmpty && _price.text.trim().isNotEmpty && (num.tryParse(_price.text.trim()) ?? -1) >= 0;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final stock = _stock.text.trim();
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'barcode': _code.text.trim(),
        'price': num.parse(_price.text.trim()),
        'cost': _cost.text.trim().isEmpty ? 0 : (num.tryParse(_cost.text.trim()) ?? 0),
        if (_unit.isNotEmpty) 'unit_id': _unit,
        'track_stock': _track,
        'low_stock': num.tryParse(_low.text.trim()) ?? 0,
        'category_id': _cat.isEmpty ? null : _cat,
        'fav': _fav,
        'active': _active,
        if (_scaleOn) 'plu': _plu.text.trim(),
        if (_buyOn) 'reorder_qty': num.tryParse(_rq.text.trim()) ?? 0,
        if (_buyOn && _supsOn) 'supplier_id': _sup.isEmpty ? null : _sup,
        if (ctx.stockOn && stock.isNotEmpty && (isNew || num.tryParse(stock) != n(r['stock']))) 'stock': num.tryParse(stock) ?? 0,
      };
      final res = isNew ? await ctx.api.post('${ctx.base}/products', body) : await ctx.api.put('${ctx.base}/products/${r['_id']}', body);
      final id = obj(res['data'])['_id'];
      if (_file != null) {
        await ctx.api.post('${ctx.base}/products/$id/photo', fileForm('photo', _file!, 'photo.jpg'));
      } else if (_photo.isEmpty && str(obj(r['photo'])['url']).isNotEmpty) {
        await ctx.api.delete('${ctx.base}/products/$id/photo');
      }
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.network ? ctx.t('app.offline') : e.message;
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ctx.api.delete('${ctx.base}/products/${r['_id']}');
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sym = ctx.cur == 'KHR' ? '៛' : '\$';
    const dec = TextInputType.numberWithOptions(decimal: true);
    final diff = !isNew && _stock.text.trim().isNotEmpty ? (num.tryParse(_stock.text.trim()) ?? 0) - n(r['stock']) : 0;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(isNew ? ctx.m('addProduct') : ctx.m('editProduct'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Field(label: ctx.m('productName'), controller: _name, maxLength: 120, autofocus: isNew, onChanged: (_) => setState(() {})),
                  gap14,
                  Field(
                    label: ctx.m('barcode'),
                    controller: _code,
                    maxLength: 40,
                    keyboard: TextInputType.number,
                    onChanged: (v) {
                      if (v.contains(RegExp(r'\s'))) {
                        _code.text = v.replaceAll(RegExp(r'\s'), '');
                      }
                    },
                    suffix: IconButton(
                      tooltip: ctx.t('app.scanBarcode'),
                      icon: const Icon(LucideIcons.scanBarcode, size: 18),
                      onPressed: () async {
                        final v = await scanBarcode(context, ctx.t);
                        if (v != null) setState(() => _code.text = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(ctx.m('barcodeHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  gap14,
                  pair(
                    Field(label: '${ctx.m('salePrice')} ($sym)', controller: _price, keyboard: dec, onChanged: (_) => setState(() {})),
                    Field(label: ctx.m('cost'), controller: _cost, keyboard: dec),
                  ),
                  gap14,
                  pair(
                    SelectField<String>(
                      label: ctx.m('category'),
                      value: _cat,
                      options: [('', ctx.m('noCat')), for (final x in widget.cats) (str(x['_id']), str(x['name']))],
                      onChanged: (v) => setState(() => _cat = v),
                    ),
                    SelectField<String>(
                      label: ctx.m('unit'),
                      value: _unit,
                      options: [
                        for (final u in widget.units) (str(u['_id']), [str(u['name_km']), str(u['name_en'])].where((x) => x.isNotEmpty).join(' / ')),
                      ],
                      onChanged: (v) => setState(() => _unit = v),
                    ),
                  ),
                  if (ctx.stockOn) ...[
                    gap14,
                    SwitchRow(title: ctx.m('trackStock'), value: _track, onChanged: (v) => setState(() => _track = v)),
                    if (_track) ...[
                      const SizedBox(height: 8),
                      pair(
                        Field(
                          label: isNew ? ctx.m('startStock') : ctx.m('inStock'),
                          controller: _stock,
                          hint: '0',
                          keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        Field(label: ctx.m('lowLevel'), controller: _low, keyboard: dec),
                      ),
                      if (diff != 0) ...[
                        const SizedBox(height: 4),
                        Text(ctx.m('stockEditHint', {'diff': '${diff > 0 ? '+' : ''}${qtyOf(diff)}'}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ],
                  ],
                  if (_scaleOn) ...[
                    gap14,
                    Field(
                      label: ctx.x('plu'),
                      controller: _plu,
                      maxLength: 6,
                      keyboard: TextInputType.number,
                      onChanged: (v) {
                        final d = v.replaceAll(RegExp(r'\D'), '');
                        if (d != v) _plu.text = d;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(ctx.x('pluHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                  if (_buyOn) ...[
                    gap14,
                    if (_supsOn) ...[
                      SelectField<String>(
                        label: ctx.x('supplier'),
                        value: _sup,
                        options: [('', ctx.x('noSupplier')), for (final s in _sups) (str(s['_id']), str(s['name']))],
                        onChanged: (v) => setState(() => _sup = v),
                      ),
                      gap14,
                    ],
                    Field(label: '${ctx.x('makePo')} · ${ctx.x('qty')}', controller: _rq, hint: 'auto', keyboard: dec),
                  ],
                  gap14,
                  Text(ctx.m('photo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  MImagePick(
                    ctx: ctx,
                    url: _photo,
                    bytes: _file,
                    maxSize: 600,
                    onPick: (b, _) async => setState(() => _file = b),
                    onRemove: () => setState(() {
                      _file = null;
                      _photo = '';
                    }),
                  ),
                  gap14,
                  SwitchRow(title: ctx.m('fav'), value: _fav, onChanged: (v) => setState(() => _fav = v)),
                  SwitchRow(title: ctx.m('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
                  if (_error.isNotEmpty) ...[gap14, Alert(_error)],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                if (!isNew) SureDelete(remove: ctx.m('remove'), sure: ctx.m('sure'), onDelete: _busy ? null : _remove),
                const Spacer(),
                Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn(_busy ? ctx.m('saving') : ctx.m('save'), small: true, busy: _busy, onTap: _busy || !_ok ? null : _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// a sheet with a title, a body and a Close button
class _ListSheet extends StatelessWidget {
  final String title, close;
  final List<Widget> children;
  const _ListSheet({required this.title, required this.close, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Btn(close, expand: true, onTap: () => Navigator.pop(context)),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------------------------------- units
class _UnitsSheet extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> units;
  final VoidCallback onChanged;
  const _UnitsSheet({required this.ctx, required this.units, required this.onChanged});
  @override
  State<_UnitsSheet> createState() => _UnitsSheetState();
}

class _UnitsSheetState extends State<_UnitsSheet> {
  late List<Json> _units = widget.units;
  final _km = TextEditingController(), _en = TextEditingController();
  final Map<String, (TextEditingController, TextEditingController)> _edit = {};
  bool _busy = false;
  String _error = '';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _km.dispose();
    _en.dispose();
    for (final (a, b) in _edit.values) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  (TextEditingController, TextEditingController) _of(Json u) =>
      _edit.putIfAbsent(str(u['_id']), () => (TextEditingController(text: str(u['name_km'])), TextEditingController(text: str(u['name_en']))));

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn();
      final r = await ctx.api.get('${ctx.base}/units');
      _units = objs(r['data']);
      widget.onChanged();
    } on ApiError catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final can = _km.text.trim().isNotEmpty || _en.text.trim().isNotEmpty;
    return _ListSheet(
      title: ctx.m('unitsTitle'),
      close: ctx.m('close'),
      children: [
        Muted(ctx.m('unitsSub')),
        gap14,
        Row(
          children: [
            Expanded(
              child: Field(controller: _km, hint: ctx.m('unitKmPh'), maxLength: 30, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Field(controller: _en, hint: ctx.m('unitEnPh'), maxLength: 30, onChanged: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Btn(
          ctx.m('addUnit'),
          icon: LucideIcons.plus,
          small: true,
          onTap: _busy || !can
              ? null
              : () => _run(() async {
                  await ctx.api.post('${ctx.base}/units', {'name_km': _km.text.trim(), 'name_en': _en.text.trim()});
                  _km.clear();
                  _en.clear();
                }),
        ),
        gap14,
        Row(
          children: [
            Expanded(
              child: Text(
                ctx.m('unitKm'),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ctx.m('unitEn'),
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 46),
          ],
        ),
        const SizedBox(height: 6),
        for (final u in _units)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final (i, ctl) in [_of(u).$1, _of(u).$2].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onFocusChange: (on) {
                        if (on) return;
                        final (km, en) = _of(u);
                        if (km.text == str(u['name_km']) && en.text == str(u['name_en'])) return;
                        _run(() => ctx.api.put('${ctx.base}/units/${u['_id']}', {'name_km': km.text.trim(), 'name_en': en.text.trim()}));
                      },
                      child: Field(controller: ctl, maxLength: 30),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                RoundBtn(
                  LucideIcons.trash2,
                  size: 40,
                  fg: c.danger,
                  tip: ctx.m('remove'),
                  onTap: _busy || _units.length <= 1 ? null : () => _run(() => ctx.api.delete('${ctx.base}/units/${u['_id']}')),
                ),
              ],
            ),
          ),
        if (_error.isNotEmpty) Alert(_error),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- categories
class _CatsSheet extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> cats;
  final VoidCallback onChanged;
  const _CatsSheet({required this.ctx, required this.cats, required this.onChanged});
  @override
  State<_CatsSheet> createState() => _CatsSheetState();
}

class _CatsSheetState extends State<_CatsSheet> {
  late List<Json> _cats = widget.cats;
  final _name = TextEditingController();
  final Map<String, TextEditingController> _edit = {};
  bool _busy = false;
  String _error = '';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _name.dispose();
    for (final x in _edit.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn();
      final r = await ctx.api.get('${ctx.base}/categories');
      _cats = objs(r['data']);
      widget.onChanged();
    } on ApiError catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _ListSheet(
      title: ctx.m('categories'),
      close: ctx.m('close'),
      children: [
        Row(
          children: [
            Expanded(
              child: Field(controller: _name, hint: ctx.m('newCat'), maxLength: 60, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            Btn(
              ctx.m('addCat'),
              icon: LucideIcons.plus,
              small: true,
              onTap: _busy || _name.text.trim().isEmpty
                  ? null
                  : () => _run(() async {
                      await ctx.api.post('${ctx.base}/categories', {'name': _name.text.trim(), 'sort': _cats.length});
                      _name.clear();
                    }),
            ),
          ],
        ),
        gap14,
        if (_cats.isEmpty) Muted(ctx.m('noCats')),
        for (final cat in _cats)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: (on) {
                      final ctl = _edit[str(cat['_id'])];
                      if (on || ctl == null || ctl.text.trim().isEmpty || ctl.text.trim() == str(cat['name'])) return;
                      _run(() => ctx.api.put('${ctx.base}/categories/${cat['_id']}', {'name': ctl.text.trim()}));
                    },
                    child: Field(controller: _edit.putIfAbsent(str(cat['_id']), () => TextEditingController(text: str(cat['name']))), maxLength: 60),
                  ),
                ),
                const SizedBox(width: 6),
                RoundBtn(LucideIcons.trash2, size: 40, fg: c.danger, tip: ctx.m('remove'), onTap: _busy ? null : () => _run(() => ctx.api.delete('${ctx.base}/categories/${cat['_id']}'))),
              ],
            ),
          ),
        if (_error.isNotEmpty) Alert(_error),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- import
class _ImportSheet extends StatefulWidget {
  final MartCtx ctx;
  final VoidCallback onDone;
  const _ImportSheet({required this.ctx, required this.onDone});
  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _paste = TextEditingController();
  List<Json> _rows = [];
  Json? _result;
  bool _busy = false;
  String _error = '';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _read(String t) => setState(() {
    _result = null;
    _rows = parseRows(t).where((r) => str(r['name']).isNotEmpty || str(r['price']).isNotEmpty).toList();
  });

  Future<void> _pick() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
    if (f == null) return;
    final b = await f.xFile.readAsBytes();
    _read(utf8.decode(b, allowMalformed: true));
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ctx.api.post('${ctx.base}/products/import', {'rows': _rows});
      setState(() => _result = obj(r['data']));
      widget.onDone();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final res = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(ctx.m('importTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Muted(ctx.m('importSub')),
                  gap14,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(ctx.m('importPick'), icon: LucideIcons.fileSpreadsheet, kind: BtnKind.ghost, small: true, onTap: _pick),
                      Btn(
                        ctx.m('template'),
                        icon: LucideIcons.download,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () => SharePlus.instance.share(
                          ShareParams(
                            files: [XFile.fromData(utf8.encode(_example), mimeType: 'text/csv', name: 'products-example.csv')],
                          ),
                        ),
                      ),
                      Btn(
                        MaterialLocalizations.of(context).pasteButtonLabel,
                        icon: LucideIcons.clipboardPaste,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: () async {
                          final d = await Clipboard.getData(Clipboard.kTextPlain);
                          if (d?.text == null) return;
                          _paste.text = d!.text!;
                          _read(d.text!);
                        },
                      ),
                    ],
                  ),
                  gap14,
                  Field(controller: _paste, hint: ctx.m('importPaste'), maxLines: 5, onChanged: _read),
                  if (_rows.isNotEmpty) ...[
                    gap14,
                    Text(ctx.m('importRows', {'n': _rows.length}), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: c.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          for (final (i, r) in _rows.take(8).indexed) ...[
                            if (i > 0) Divider(height: 1, color: c.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text([str(r['barcode']), str(r['category'])].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  Text(num.tryParse(str(r['price'])) != null ? money(r['price'], ctx.cur) : str(r['price']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (res != null) ...[
                    gap14,
                    Alert(ctx.m('importDone', {'a': n(res['added']), 'u': n(res['updated']), 's': n(res['skipped'])}), tone: Tone.good),
                    if (objs(res['errors']).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(ctx.m('importErrors'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      for (final x in objs(res['errors'])) Text('${ctx.m('row', {'n': x['row']})}: ${x['message']}', style: TextStyle(color: c.danger)),
                    ],
                  ],
                  if (_error.isNotEmpty) ...[gap14, Alert(_error)],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                const Spacer(),
                Btn(ctx.m('close'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn(ctx.m('importGo', {'n': _rows.length}), icon: LucideIcons.upload, small: true, busy: _busy, onTap: _busy || _rows.isEmpty || res != null ? null : _go),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
