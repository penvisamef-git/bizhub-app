import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';
import '../common/qr_card.dart';
import '../mart/mart_common.dart' show GoldBtn, mGap;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../restaurant/rest_common.dart' show SwitchRow, gap14;
import 'fb_common.dart';

// FbMore.jsx: Categories · Share & QR

// ------------------------------------------------------------------------------------------- categories
class CategoriesTab extends StatefulWidget {
  final FbCtx ctx;
  const CategoriesTab({super.key, required this.ctx});
  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  FbCtx get ctx => widget.ctx;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  int _count(Object? cid) => ctx.books.where((b) => (b['category_ids'] as List? ?? const []).map((e) => '$e').contains('$cid')).length;

  void _edit(Json row) => showSheet<void>(context, (_) => _CatSheet(ctx: ctx, row: row));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cats = ctx.categories;
    final ro = ctx.readOnly;
    final max = n(ctx.limits['categories']);
    final unlimited = ctx.on('fb_categories');
    final qq = _q.text.trim().toLowerCase();
    final shown = cats.where((x) => qq.isEmpty || '${x['name']} ${x['about'] ?? ''}'.toLowerCase().contains(qq)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(
          context,
          LucideIcons.folderOpen,
          ctx.m('catsTitle'),
          ctx.m('catsSub'),
          actions: [
            Btn(
              ctx.m('addCat'),
              icon: LucideIcons.plus,
              small: true,
              onTap: ro
                  ? null
                  : () {
                      if (!unlimited && cats.length >= max) return ctx.askBuy({'addon': 'fb_categories'});
                      _edit({});
                    },
            ),
          ],
        ),
        mGap,
        if (!unlimited) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(LucideIcons.lock, size: 16, color: c.warn),
                const SizedBox(width: 8),
                Expanded(child: Text(ctx.m('catLimit'), style: const TextStyle(fontSize: 13))),
                GoldBtn(ctx.m('unlock', {'coins': fmt(n(ctx.addon('fb_categories')['price']))}), onTap: ro ? null : () => ctx.askBuy({'addon': 'fb_categories'})),
              ],
            ),
          ),
          mGap,
        ],
        if (cats.isEmpty)
          fbPanel([Icon(LucideIcons.folderOpen, size: 30, color: c.muted), const SizedBox(height: 8), Muted(ctx.m('noCats'), align: TextAlign.center)])
        else ...[
          if (cats.length > 3) ...[
            fbPanel([
              Field(controller: _q, hint: ctx.m('searchCats'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
              const SizedBox(height: 6),
              Muted(ctx.m('found', {'n': shown.length, 'max': cats.length})),
            ]),
            mGap,
          ],
          if (shown.isEmpty) fbPanel([Muted(ctx.m('noFoundCat'), align: TextAlign.center)]),
          for (final x in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: x['active'] == false ? .6 : 1,
                child: Panel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.folderOpen, color: c.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(x['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              '${ctx.m('booksIn', {'n': _count(x['_id'])})}${str(x['about']).isNotEmpty ? ' · ${x['about']}' : ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: ctx.m('linkQr'),
                        onPressed: () => openQr(context, ctx, url: catUrl(x['slug']), name: str(x['name']), relink: ('category', str(x['_id']))),
                        icon: const Icon(LucideIcons.qrCode, size: 18),
                      ),
                      IconButton(tooltip: ctx.m('edit'), onPressed: ro ? null : () => _edit(x), icon: const Icon(LucideIcons.pencil, size: 18)),
                      IconButton(
                        tooltip: ctx.m('delete'),
                        onPressed: ro
                            ? null
                            : () async {
                                if (!await fbConfirm(context, ctx, ctx.m('removeCat'), '${x['name']} — ${ctx.m('removeCatSub')}')) return;
                                final r = await ctx.run(() => ctx.api.delete('${ctx.base}/categories/${x['_id']}'));
                                if (r == null) return;
                                ctx.put(
                                  (d) => {
                                    'categories': objs(d['categories']).where((y) => y['_id'] != x['_id']).toList(),
                                    'books': [
                                      for (final b in objs(d['books'])) {...b, 'category_ids': (b['category_ids'] as List? ?? const []).where((y) => '$y' != '${x['_id']}').toList()},
                                    ],
                                  },
                                );
                              },
                        icon: Icon(LucideIcons.trash2, size: 18, color: c.danger),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CatSheet extends StatefulWidget {
  final FbCtx ctx;
  final Json row;
  const _CatSheet({required this.ctx, required this.row});
  @override
  State<_CatSheet> createState() => _CatSheetState();
}

class _CatSheetState extends State<_CatSheet> {
  FbCtx get ctx => widget.ctx;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _about = TextEditingController(text: str(widget.row['about']));
  late bool _active = widget.row['active'] != false;
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    final id = widget.row['_id'];
    final body = {'name': _name.text, 'about': _about.text, 'active': _active};
    try {
      if (id != null) {
        final r = await ctx.api.put('${ctx.base}/categories/$id', body);
        ctx.put(
          (d) => {
            'categories': [for (final x in objs(d['categories'])) x['_id'] == id ? obj(r['data']) : x],
          },
        );
      } else {
        final r = await ctx.api.post('${ctx.base}/categories', body);
        ctx.put(
          (d) => {
            'categories': [...objs(d['categories']), obj(r['data'])],
          },
        );
      }
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (e.body['code'] == 'category_limit') {
        if (mounted) Navigator.pop(context);
        ctx.askBuy({'addon': 'fb_categories'});
        return;
      }
      setState(() {
        _err = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MSheet(
    title: widget.row['_id'] != null ? ctx.m('edit') : ctx.m('addCat'),
    footer: [
      const Spacer(),
      Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
      const SizedBox(width: 8),
      Btn(ctx.m('save'), icon: LucideIcons.save, small: true, busy: _busy, onTap: _busy || _name.text.trim().isEmpty ? null : _save),
    ],
    children: [
      Field(label: ctx.m('catName'), controller: _name, maxLength: 60, autofocus: true, onChanged: (_) => setState(() {})),
      gap14,
      Field(label: ctx.m('catAbout'), controller: _about, hint: ctx.m('catAboutPh'), maxLength: 600, maxLines: 4, onChanged: (_) => setState(() {})),
      Align(alignment: Alignment.centerRight, child: Muted('${_about.text.length} / 600')),
      if (widget.row['_id'] != null) SwitchRow(title: ctx.m('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
      if (_err.isNotEmpty) ...[gap14, Alert(_err)],
    ],
  );
}

// ------------------------------------------------------------------------------------------- share
class ShareTab extends StatefulWidget {
  final FbCtx ctx;
  const ShareTab({super.key, required this.ctx});
  @override
  State<ShareTab> createState() => _ShareTabState();
}

class _ShareTabState extends State<ShareTab> {
  FbCtx get ctx => widget.ctx;
  String _busy = '';
  int _limit = 10;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _use(String k) async {
    if (k != 'classic' && !ctx.on('fb_qr_styles')) return ctx.askBuy({'addon': 'fb_qr_styles'});
    setState(() => _busy = k);
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'qr_style': k}), ctx.m('saved'));
    if (r != null) ctx.put((_) => {'settings': obj(r['data'])});
    if (mounted) setState(() => _busy = '');
  }

  // tap a QR style → the style sheet (the library QR card in that style, swipe for the next), Use / Unlock at the bottom
  Future<void> _open(String key, String url) async {
    final keys = qrCards.keys.toList();
    final price = n(ctx.addon('fb_qr_styles')['price']);
    await showLookSheet(
      context,
      title: ctx.m('qrStyles'),
      count: keys.length,
      initial: keys.indexOf(key),
      item: (context, i, refresh) {
        final k = keys[i];
        final q = qrCards[k]!;
        final using = (str(ctx.settings['qr_style']).isEmpty ? 'classic' : str(ctx.settings['qr_style'])) == k;
        final mine = k == 'classic' || ctx.on('fb_qr_styles');
        final art = qrCardArt(
          text: url,
          style: q.style,
          color: q.color,
          bg: q.bg,
          accent: q.accent ?? libColour(ctx),
          logo: ctx.logo.isNotEmpty,
          name: ctx.libName,
          header: '',
          footer: url.replaceFirst(RegExp(r'^https?://'), ''),
          width: 300,
        );
        return LookItem(
          name: q.name(ctx.lang),
          badge: using ? ctx.m('inUse') : (mine ? ctx.m(k == 'classic' ? 'free' : 'owned') : '${fmt(price)} ${ctx.m('coins')}'),
          badgeTone: using || mine ? Tone.good : Tone.warn,
          sub: mine ? null : ctx.m('qrStylesSub', {'n': qrCards.length, 'coins': fmt(price)}),
          preview: SizedBox(
            width: 300,
            child: FittedBox(
              child: CardArtView(art: art, logo: ctx.logo),
            ),
          ),
          acts: [
            if (!using && mine)
              LookAct(
                ctx.m('use'),
                icon: LucideIcons.check,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        await _use(k);
                        return true;
                      },
              ),
            if (!mine)
              LookAct(
                ctx.m('unlock', {'coins': fmt(price)}),
                gold: true,
                onTap: ctx.readOnly
                    ? null
                    : () async {
                        ctx.askBuy({'addon': 'fb_qr_styles'});
                        return true;
                      },
              ),
          ],
        );
      },
    );
  }

  Widget _qrBlock(BuildContext context, {required String url, required String name, required String header, (String, String)? relink, bool embed = false}) {
    final c = qrCards[str(ctx.settings['qr_style'])] ?? qrCards['classic']!;
    final art = qrCardArt(
      text: url,
      style: c.style,
      color: c.color,
      bg: c.bg,
      accent: c.accent ?? libColour(ctx),
      logo: ctx.logo.isNotEmpty,
      name: name,
      header: header,
      footer: url.replaceFirst(RegExp(r'^https?://'), ''),
      width: 300,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: FittedBox(
            child: CardArtView(art: art, logo: ctx.logo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                url.replaceFirst(RegExp(r'^https?://'), ''),
                style: TextStyle(color: context.c.brand, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Btn(
                ctx.m('linkQr'),
                icon: LucideIcons.qrCode,
                small: true,
                onTap: () => showSheet<void>(context, (_) => QrCardSheet(ctx: ctx, url: url, name: name, title: name, header: header, embed: embed, relink: relink)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unlocked = ctx.on('fb_qr_styles');
    final url = shelfUrl(ctx.settings['slug']);
    final using = str(ctx.settings['qr_style']).isEmpty ? 'classic' : str(ctx.settings['qr_style']);
    final qq = _q.text.trim().toLowerCase();
    final cats = ctx.categories.where((x) => qq.isEmpty || str(x['name']).toLowerCase().contains(qq)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(context, LucideIcons.qrCode, ctx.m('shareTitle'), ctx.m('shareSub')),
        mGap,
        fbPanel([
          Row(
            children: [
              Expanded(
                child: Text(ctx.m('qrStyles'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
              unlocked
                  ? Chip2(ctx.m('unlocked'), icon: LucideIcons.check, tone: Tone.good)
                  : GoldBtn(ctx.m('unlock', {'coins': fmt(n(ctx.addon('fb_qr_styles')['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy({'addon': 'fb_qr_styles'})),
            ],
          ),
          Muted(ctx.m('qrStylesSub', {'n': qrCards.length, 'coins': fmt(n(ctx.addon('fb_qr_styles')['price']))})),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .72,
            children: [
              for (final e in qrCards.entries)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(e.key, url),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: using == e.key ? c.brand : Colors.transparent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: FittedBox(child: CardArtView(art: qrThumbArt(ctx, e.key, url))),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.name(ctx.lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        if (using == e.key)
                          Text(
                            ctx.m('inUse'),
                            style: TextStyle(color: c.good, fontSize: 11, fontWeight: FontWeight.w700),
                          )
                        else if (_busy == e.key)
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (e.key == 'classic' || unlocked)
                          Text(e.key == 'classic' ? ctx.m('free') : ctx.m('owned'), style: TextStyle(color: c.muted, fontSize: 11))
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.lock, size: 10, color: c.muted),
                              const SizedBox(width: 2),
                              Text(ctx.m('locked2'), style: TextStyle(color: c.muted, fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ]),
        mGap,
        fbPanel([
          Row(
            children: [
              Icon(LucideIcons.library, size: 16, color: c.brand),
              const SizedBox(width: 6),
              Text(ctx.m('libraryQr'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ],
          ),
          const SizedBox(height: 10),
          _qrBlock(context, url: url, name: ctx.libName, header: ctx.m('libraryQr'), relink: ('library', ''), embed: true),
        ]),
        if (ctx.categories.isNotEmpty) ...[
          mGap,
          fbPanel([
            Field(controller: _q, hint: ctx.m('searchCats'), icon: LucideIcons.search, onChanged: (_) => setState(() => _limit = 10)),
            const SizedBox(height: 6),
            Muted(ctx.m('found', {'n': cats.length, 'max': ctx.categories.length})),
          ]),
          if (cats.isEmpty) ...[
            mGap,
            fbPanel([Muted(ctx.m('noFoundCat'), align: TextAlign.center)]),
          ],
          for (final x in cats.take(_limit)) ...[
            mGap,
            fbPanel([
              Row(
                children: [
                  Icon(LucideIcons.folderOpen, size: 16, color: c.brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${ctx.m('catQr')}: ${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _qrBlock(context, url: catUrl(x['slug']), name: str(x['name']), header: ctx.libName, relink: ('category', str(x['_id']))),
            ]),
          ],
          if (cats.length > _limit) ...[
            mGap,
            Center(
              child: Btn(ctx.m('showMore', {'n': cats.length - _limit}), kind: BtnKind.ghost, small: true, onTap: () => setState(() => _limit += 10)),
            ),
          ],
        ],
      ],
    );
  }
}
