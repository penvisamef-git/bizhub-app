import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show EvHead, askSure;
import '../restaurant/rest_common.dart' show SelectField, SwitchRow;
import 'ts_common.dart';

// Products (+ categories): what customers can order — the web's TsSetup.jsx ProductsTab + ProductModal.
//   GET /categories  POST /categories  PUT /categories/:cid  DELETE /categories/:cid
//   GET /products  POST /products  PUT /products/:pid  DELETE /products/:pid  POST|DELETE /products/:pid/photo (multipart "photo")

class ProductsTab extends StatefulWidget {
  final TsCtx ctx;
  const ProductsTab({super.key, required this.ctx});
  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  List<Json>? _cats, _rows;
  String _cat = ''; // '' all · 'none' no category · an id
  String _error = '';
  String _busy = '';
  TsCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([ctx.api.get('${ctx.base}/categories'), ctx.api.get('${ctx.base}/products')]);
      if (!mounted) return;
      setState(() {
        _cats = objs(r[0]['data']);
        _rows = objs(r[1]['data']);
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
  }

  Future<void> _run(Future<Json> Function() fn, [String? ok]) async {
    final r = await ctx.run(fn, ok);
    if (r == null) return;
    await _load();
    ctx.reload();
  }

  String _catName(Json c) => ctx.lang == 'km' && str(c['name_km']).isNotEmpty ? str(c['name_km']) : str(c['name']);

  Future<void> _catForm([Json? cat]) async {
    final name = TextEditingController(text: str(cat?['name']));
    final km = TextEditingController(text: str(cat?['name_km']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(cat == null ? ctx.m('addCategory') : ctx.m('edit'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Field(controller: name, hint: ctx.m('categoryName'), maxLength: 60, autofocus: true),
            const SizedBox(height: 10),
            Field(controller: km, hint: ctx.m('categoryNameKm'), maxLength: 80),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(ctx.m('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(cat == null ? ctx.m('add') : ctx.m('save'))),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final body = {'name': name.text.trim(), 'name_km': km.text.trim()};
    await _run(() => cat == null ? ctx.api.post('${ctx.base}/categories', body) : ctx.api.put('${ctx.base}/categories/${cat['_id']}', body), ctx.m('saved'));
  }

  Future<void> _catMenu(Json cat) async {
    if (ctx.readOnly) return;
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(_catName(cat), style: Theme.of(s).textTheme.titleMedium),
            ),
            ListTile(leading: const Icon(LucideIcons.pencil), title: Text(ctx.m('edit')), onTap: () => Navigator.pop(s, 'edit')),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: s.c.danger),
              title: Text(ctx.m('delete'), style: TextStyle(color: s.c.danger)),
              onTap: () => Navigator.pop(s, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (pick == 'edit') return _catForm(cat);
    if (pick == 'delete' && await askSure(context, ctx.m('removeCategoryAsk', {'name': cat['name']}), ok: ctx.m('delete'), cancel: ctx.m('cancel'), danger: true)) {
      if (_cat == str(cat['_id'])) setState(() => _cat = '');
      await _run(() => ctx.api.delete('${ctx.base}/categories/${cat['_id']}'), ctx.m('saved'));
    }
  }

  Future<void> _edit([Json? p]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ProductSheet(ctx: ctx, product: p, categories: _cats ?? const [], startCat: _cat == 'none' ? '' : _cat),
    );
    if (saved == true) {
      await _load();
      ctx.reload();
      ctx.notify(ctx.m('saved'));
    }
  }

  Future<void> _remove(Json p) async {
    if (!await askSure(context, ctx.m('removeProductAsk', {'name': p['name']}), ok: ctx.m('delete'), cancel: ctx.m('cancel'), danger: true)) return;
    await _run(() => ctx.api.delete('${ctx.base}/products/${p['_id']}'), ctx.m('saved'));
  }

  Future<void> _soldOut(Json p) async {
    setState(() => _busy = str(p['_id']));
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/products/${p['_id']}', {'sold_out': !(p['sold_out'] == true)}));
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (r != null && r['data'] is Map) _rows = [for (final x in _rows!) str(x['_id']) == str(p['_id']) ? obj(r['data']) : x];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cats = _cats ?? const <Json>[];
    final rows = _rows;
    final shown = (rows ?? const <Json>[]).where((p) => _cat.isEmpty || (_cat == 'none' ? str(p['category_id']).isEmpty : str(p['category_id']) == _cat)).toList();
    final anyNoCat = (rows ?? const <Json>[]).any((p) => str(p['category_id']).isEmpty);
    Widget chip(String v, String label, {VoidCallback? onLong}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: v == _cat ? c.solid : c.chip,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _cat = v),
          onLongPress: onLong,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: v == _cat ? c.onSolid : c.ink),
                ),
                if (onLong != null && !ctx.readOnly) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onLong,
                    child: Icon(LucideIcons.ellipsis, size: 14, color: v == _cat ? c.onSolid : c.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          EvHead(
            ctx.m('tabs.products'),
            sub: ctx.m('productsSub'),
            trailing: Btn(ctx.m('addProduct'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit(), key: const ValueKey('ts-add-product')),
          ),
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Alert(_error)),
          Text(
            ctx.m('categories'),
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip('', ctx.m('allCats')),
                for (final cat in cats) chip(str(cat['_id']), _catName(cat), onLong: () => _catMenu(cat)),
                if (anyNoCat && cats.isNotEmpty) chip('none', ctx.m('noCategory')),
                if (!ctx.readOnly)
                  ActionChip(
                    avatar: Icon(LucideIcons.plus, size: 14, color: c.brand),
                    label: Text(ctx.m('addCategory')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _catForm(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (rows == null)
            const SkelList(rows: 3)
          else if (shown.isEmpty)
            Panel(
              child: Column(
                children: [
                  Icon(LucideIcons.package, size: 30, color: c.muted),
                  const SizedBox(height: 8),
                  Muted(ctx.m('noProducts'), align: TextAlign.center),
                  const SizedBox(height: 12),
                  Btn(ctx.m('addProduct'), icon: LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : () => _edit()),
                ],
              ),
            )
          else
            for (final p in shown) _row(context, p),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Json p) {
    final c = context.c;
    final photo = str(p['photo']);
    final name = ctx.lang == 'km' && str(p['name_km']).isNotEmpty ? str(p['name_km']) : str(p['name']);
    final out = p['sold_out'] == true;
    final opts = objs(p['options']);
    return Opacity(
      opacity: p['hidden'] == true ? .6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: ctx.readOnly ? null : () => _edit(p),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: photo.isNotEmpty ? Image(image: netImage(photo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.camera, size: 22, color: c.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    ctx.money(p['price']),
                    style: TextStyle(color: c.brand, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (out) TsPill(ctx.m('soldOut'), tone: Tone.danger) else if (p['stock'] != null) TsPill(ctx.m('left', {'n': fmt(n(p['stock']))})),
                      if (p['hidden'] == true) TsPill(ctx.m('hidden'), icon: LucideIcons.eyeOff),
                      if (opts.isNotEmpty) TsPill(opts.map((g) => str(g['name'])).join(' · ')),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: 32,
                  child: FittedBox(
                    child: _busy == str(p['_id'])
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : Switch.adaptive(value: !out, onChanged: ctx.readOnly ? null : (_) => _soldOut(p)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: ctx.m('edit'), visualDensity: VisualDensity.compact, icon: const Icon(LucideIcons.pencil, size: 17), onPressed: ctx.readOnly ? null : () => _edit(p)),
                    IconButton(
                      tooltip: ctx.m('delete'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                      onPressed: ctx.readOnly ? null : () => _remove(p),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// a choice group being edited
class _Opt {
  final TextEditingController name;
  bool multi, required;
  final List<(TextEditingController, TextEditingController)> choices;
  _Opt(String n, this.multi, this.required, this.choices) : name = TextEditingController(text: n);
  void dispose() {
    name.dispose();
    for (final (a, b) in choices) {
      a.dispose();
      b.dispose();
    }
  }
}

(TextEditingController, TextEditingController) _choice([String name = '', String price = '']) => (TextEditingController(text: name), TextEditingController(text: price));
final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

class _ProductSheet extends StatefulWidget {
  final TsCtx ctx;
  final Json? product;
  final List<Json> categories;
  final String startCat;
  const _ProductSheet({required this.ctx, required this.product, required this.categories, this.startCat = ''});
  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  TsCtx get ctx => widget.ctx;
  late final Json? p = widget.product;
  late final _name = TextEditingController(text: str(p?['name']));
  late final _km = TextEditingController(text: str(p?['name_km']));
  late final _price = TextEditingController(text: p == null ? '' : '${p!['price'] ?? ''}');
  late final _about = TextEditingController(text: str(p?['about']));
  late final _stock = TextEditingController(text: p?['stock'] == null ? '' : '${p!['stock']}');
  late String _cat = p == null ? widget.startCat : str(p!['category_id']);
  late bool _soldOut = p?['sold_out'] == true && !(p?['stock'] == 0);
  late bool _hidden = p?['hidden'] == true;
  late final List<_Opt> _opts = [
    for (final g in objs(p?['options']))
      _Opt(str(g['name']), g['multi'] == true, g['required'] == true, [for (final ch in objs(g['choices'])) _choice(str(ch['name']), n(ch['price']) > 0 ? '${ch['price']}' : '')]),
  ];
  List<int>? _file; // a new photo
  late String _photo = str(p?['photo']);
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    for (final x in [_name, _km, _price, _about, _stock]) {
      x.dispose();
    }
    for (final g in _opts) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (mounted) setState(() => _file = bytes);
  }

  Future<void> _removePhoto() async {
    if (p == null) return setState(() => _file = null);
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.delete('${ctx.base}/products/${p!['_id']}/photo'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        _photo = '';
        _file = null;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = {
      'name': _name.text.trim(),
      'name_km': _km.text.trim(),
      'price': num.tryParse(_price.text.trim()) ?? 0,
      'about': _about.text.trim(),
      'category_id': _cat.isEmpty ? null : _cat,
      'stock': _stock.text.trim().isEmpty ? null : int.tryParse(_stock.text.trim()),
      'sold_out': _soldOut,
      'hidden': _hidden,
      'options': [
        for (final g in _opts)
          if (g.name.text.trim().isNotEmpty)
            {
              'name': g.name.text.trim(),
              'multi': g.multi,
              'required': g.required,
              'choices': [
                for (final (a, b) in g.choices)
                  if (a.text.trim().isNotEmpty) {'name': a.text.trim(), 'price': num.tryParse(b.text.trim()) ?? 0},
              ],
            },
      ].where((g) => (g['choices'] as List).isNotEmpty).toList(),
    };
    try {
      final r = p == null ? await ctx.api.post('${ctx.base}/products', body) : await ctx.api.put('${ctx.base}/products/${p!['_id']}', body);
      if (_file != null) {
        final id = obj(r['data'])['_id'];
        await ctx.api.post('${ctx.base}/products/$id/photo', FormData.fromMap({'photo': MultipartFile.fromBytes(_file!, filename: 'photo.jpg', contentType: DioMediaType.parse('image/jpeg'))}));
      }
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sign = ctx.cur == 'KHR' ? '៛' : '\$';
    final canSave = _name.text.trim().isNotEmpty && _price.text.trim().isNotEmpty && !_busy;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      maxChildSize: .95,
      builder: (_, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              children: [
                Text(p == null ? ctx.m('addProduct') : ctx.m('editProduct'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Alert(_error)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        InkWell(
                          onTap: _busy ? null : _pick,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: c.chip,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: c.line),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _file != null
                                ? Image.memory(Uint8List.fromList(_file!), fit: BoxFit.cover)
                                : (_photo.isNotEmpty ? Image(image: netImage(_photo), fit: BoxFit.cover) : Icon(LucideIcons.imagePlus, size: 26, color: c.muted)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_file != null || _photo.isNotEmpty)
                          TextButton(
                            onPressed: _busy ? null : _removePhoto,
                            child: Text(ctx.m('removePhoto'), style: TextStyle(fontSize: 12, color: c.danger)),
                          )
                        else
                          TextButton(
                            onPressed: _busy ? null : _pick,
                            child: Text(ctx.m('addPhoto'), style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Field(label: ctx.m('name'), controller: _name, maxLength: 80, onChanged: (_) => setState(() {})),
                          const SizedBox(height: 10),
                          Field(label: '${ctx.m('price')} ($sign)', controller: _price, keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Field(label: ctx.m('nameKm'), controller: _km, maxLength: 120),
                const SizedBox(height: 12),
                SelectField<String>(
                  label: ctx.m('category'),
                  value: _cat,
                  options: [('', ctx.m('noCategory')), for (final cat in widget.categories) (str(cat['_id']), str(cat['name']))],
                  onChanged: (v) => setState(() => _cat = v),
                ),
                const SizedBox(height: 12),
                Field(label: ctx.m('about'), controller: _about, maxLength: 300, maxLines: 2),
                const SizedBox(height: 12),
                Field(label: ctx.m('stock'), controller: _stock, keyboard: TextInputType.number),
                Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.m('stockHint'))),
                const SizedBox(height: 4),
                SwitchRow(title: ctx.m('soldOut'), value: _soldOut, onChanged: (v) => setState(() => _soldOut = v)),
                SwitchRow(title: ctx.m('hidden'), value: _hidden, onChanged: (v) => setState(() => _hidden = v)),
                const SizedBox(height: 8),
                Text(ctx.m('options'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Muted(ctx.m('optionsHint')),
                const SizedBox(height: 10),
                for (var i = 0; i < _opts.length; i++) _optBox(context, i),
                if (_opts.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Btn(ctx.m('addOption'), icon: LucideIcons.plus, small: true, kind: BtnKind.ghost, onTap: () => setState(() => _opts.add(_Opt('', false, false, [_choice(), _choice()])))),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Btn(ctx.m('cancel'), kind: BtnKind.ghost, expand: true, onTap: _busy ? null : () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Btn(ctx.m('save'), expand: true, busy: _busy, onTap: canSave ? _save : null, key: const ValueKey('ts-product-save')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optBox(BuildContext context, int i) {
    final c = context.c;
    final g = _opts[i];
    final sign = ctx.cur == 'KHR' ? '៛' : '\$';
    // a Material (not a coloured box), so the switches inside show their touch ripple
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Field(controller: g.name, hint: ctx.m('optionNamePh'), maxLength: 40),
                  ),
                  IconButton(
                    tooltip: ctx.m('delete'),
                    icon: Icon(LucideIcons.trash2, size: 17, color: c.danger),
                    onPressed: () => setState(() => _opts.removeAt(i).dispose()),
                  ),
                ],
              ),
              SwitchRow(
                title: ctx.m('required'),
                value: g.required,
                onChanged: (v) => setState(() {
                  g.required = v;
                  if (v) g.multi = false;
                }),
              ),
              SwitchRow(
                title: ctx.m('multi'),
                value: g.multi,
                onChanged: (v) => setState(() {
                  g.multi = v;
                  if (v) g.required = false;
                }),
              ),
              for (var k = 0; k < g.choices.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Field(controller: g.choices[k].$1, hint: ctx.m('choicePh'), maxLength: 40),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: g.choices[k].$2,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: _decimal,
                          decoration: InputDecoration(
                            hintText: ctx.m('extra'),
                            prefixText: '+$sign ',
                            filled: true,
                            fillColor: c.card,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: c.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: c.line),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: ctx.m('delete'),
                        icon: Icon(LucideIcons.x, size: 16, color: c.muted),
                        onPressed: () => setState(() {
                          final (a, b) = g.choices.removeAt(k);
                          a.dispose();
                          b.dispose();
                        }),
                      ),
                    ],
                  ),
                ),
              if (g.choices.length < 12)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(ctx.m('addChoice'), icon: LucideIcons.plus, small: true, kind: BtnKind.ghost, onTap: () => setState(() => g.choices.add(_choice()))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
