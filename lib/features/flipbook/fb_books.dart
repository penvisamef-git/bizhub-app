import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn, mGap;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'fb_common.dart';
import 'fb_data.dart';

// Books: upload a PDF (straight to Cloudinary, signed by our API), edit, password, contact form, clickable links — FbBooks.jsx + FbExtras.jsx

// a PDF picked on the phone
typedef PickedPdf = ({List<int> bytes, String name, int size});

Future<PickedPdf?> pickPdf() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
  if (f == null) return null;
  final bytes = await f.xFile.readAsBytes();
  return (bytes: bytes, name: f.name, size: bytes.length);
}

class BooksTab extends StatefulWidget {
  final FbCtx ctx;
  const BooksTab({super.key, required this.ctx});
  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  FbCtx get ctx => widget.ctx;
  final _q = TextEditingController();
  String _cat = '';
  double? _progress; // 0..1 while sending, 1.01 = checking
  String? _replacing;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String? _check(PickedPdf f) {
    if (!f.name.toLowerCase().endsWith('.pdf')) return ctx.m('notPdf');
    if (f.size > n(ctx.limits['big_bytes'])) return ctx.m('tooBigLocal', {'mb': n(ctx.limits['big_bytes']) ~/ 1048576});
    return null;
  }

  // PDF → Cloudinary (signed by our API) with progress, then [then] tells our API about it
  Future<Json> _send(PickedPdf f, Future<Json> Function(Json up) then) async {
    setState(() => _progress = 0);
    try {
      final sign = obj((await ctx.api.get('${ctx.base}/upload-sign'))['data']);
      final form = FormData.fromMap({
        for (final k in ['api_key', 'timestamp', 'signature', 'folder'])
          if (sign[k] != null) k: '${sign[k]}',
        'file': MultipartFile.fromBytes(f.bytes, filename: f.name),
      });
      final r = await Dio().post<Map<String, dynamic>>(
        str(sign['upload_url']),
        data: form,
        options: Options(validateStatus: (_) => true),
        onSendProgress: (a, b) {
          if (b > 0 && mounted) setState(() => _progress = a / b);
        },
      );
      final up = r.data ?? const {};
      if ((r.statusCode ?? 0) >= 300 || up['public_id'] == null) {
        throw ApiError(r.statusCode ?? 0, str(obj(up['error'])['message']).isNotEmpty ? str(obj(up['error'])['message']) : 'Upload failed (${r.statusCode})');
      }
      if (mounted) setState(() => _progress = 1.01);
      return await then(up);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  void _failUpload(Object e) {
    if (e is ApiError) {
      final code = str(e.body['code']);
      if (code == 'book_full') _slots('book');
      if (code == 'need_big') _slots('big');
    }
    ctx.fail(e);
  }

  void _slots(String kind) => showSheet<void>(context, (_) => BuySlotsSheet(ctx: ctx, kind: kind));

  Future<void> _add() async {
    if (ctx.readOnly || _progress != null) return;
    final f = await pickPdf();
    if (f == null) return;
    final bad = _check(f);
    if (bad != null) return ctx.notify(bad);
    final room = ctx.room;
    if (n(room['books']) >= n(room['book_capacity'])) {
      _slots('book');
      return ctx.notify(ctx.m('full'));
    }
    if (f.size > n(ctx.limits['bytes']) && n(room['big']) >= n(room['big_capacity'])) {
      _slots('big');
      return ctx.notify(ctx.m('needBig'));
    }
    try {
      final r = await _send(f, (u) => ctx.api.post('${ctx.base}/books', {'public_id': u['public_id'], 'name': f.name}));
      ctx.setBooks((l) => [obj(r['data']), ...l], r['room']);
      ctx.notify(ctx.m('added'));
    } catch (e) {
      _failUpload(e);
    }
  }

  Future<void> _replace(Json b) async {
    if (_progress != null) return;
    final f = await pickPdf();
    if (f == null) return;
    final bad = _check(f);
    if (bad != null) return ctx.notify(bad);
    setState(() => _replacing = str(b['_id']));
    try {
      final r = await _send(f, (u) => ctx.api.post('${ctx.base}/books/${b['_id']}/replace', {'public_id': u['public_id'], 'name': f.name}));
      ctx.setBooks((l) => [for (final x in l) x['_id'] == b['_id'] ? obj(r['data']) : x], r['room']);
      ctx.notify(ctx.m('replaced'));
    } catch (e) {
      _failUpload(e);
    }
    if (mounted) setState(() => _replacing = null);
  }

  void _move(int i, int d) {
    final list = [...ctx.books];
    final j = i + d;
    if (j < 0 || j >= list.length) return;
    final x = list[i];
    list[i] = list[j];
    list[j] = x;
    ctx.setBooks((_) => list);
    ctx.run(() => ctx.api.put('${ctx.base}/books-order', {'ids': list.map((b) => b['_id']).toList()}));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final books = ctx.books;
    final room = ctx.room;
    final l = ctx.limits;
    final ro = ctx.readOnly;
    final full = n(room['books']) >= n(room['book_capacity']);
    final words = _q.text.trim().toLowerCase();
    final filtering = words.isNotEmpty || _cat.isNotEmpty;
    final shown = books.where((b) {
      final cats = (b['category_ids'] as List? ?? const []).map((e) => '$e').toList();
      final okQ = words.isEmpty || '${b['title']} ${b['about'] ?? ''} ${b['slug']} ${obj(b['file'])['name'] ?? ''}'.toLowerCase().contains(words);
      final okC = _cat.isEmpty || (_cat == 'none' ? cats.isEmpty : cats.contains(_cat));
      return okQ && okC;
    }).toList();
    String catName(Object? cid) => str(ctx.categories.where((x) => x['_id'] == cid).firstOrNull?['name']);
    final p = _progress;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        fbHead(
          context,
          LucideIcons.bookOpen,
          ctx.m('booksTitle'),
          ctx.m('booksSub'),
          actions: [
            Chip2(ctx.m('room', {'n': room['books'], 'max': room['book_capacity']}), tone: full ? Tone.danger : Tone.muted),
            GoldBtn(ctx.m('moreBooks'), onTap: ro ? null : () => _slots('book')),
            Btn(ctx.m('bigRoom', {'n': room['big'], 'max': room['big_capacity']}), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _slots('big')),
          ],
        ),
        mGap,
        Material(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: ro || p != null ? null : _add,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.brand.withValues(alpha: .45), width: 1.5),
              ),
              child: Column(
                children: [
                  if (p != null && _replacing == null) ...[
                    const SizedBox(width: 30, height: 30, child: CircularProgressIndicator()),
                    const SizedBox(height: 10),
                    Text(p > 1 ? ctx.m('checking') : ctx.m('uploading', {'p': (p * 100).round()}), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: p > 1 ? null : p, minHeight: 8),
                    ),
                  ] else ...[
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: c.active,
                      child: Icon(LucideIcons.cloudUpload, size: 28, color: c.brand),
                    ),
                    const SizedBox(height: 10),
                    Text(ctx.m('upload'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 4),
                    Muted(ctx.m('dropSub', {'mb': n(l['bytes']) ~/ 1048576, 'pages': l['pages'], 'bmb': n(l['big_bytes']) ~/ 1048576, 'bpages': l['big_pages']}), align: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
        mGap,
        if (books.isEmpty)
          fbPanel([Icon(LucideIcons.bookOpen, size: 30, color: c.muted), const SizedBox(height: 8), Muted(ctx.m('noBooks'), align: TextAlign.center)])
        else ...[
          fbPanel([
            Field(controller: _q, hint: ctx.m('searchBooks'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _cat,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(value: '', child: Text(ctx.m('allCats'))),
                for (final x in ctx.categories)
                  DropdownMenuItem(
                    value: str(x['_id']),
                    child: Text(str(x['name']), overflow: TextOverflow.ellipsis),
                  ),
                DropdownMenuItem(value: 'none', child: Text(ctx.m('noCat'))),
              ],
              onChanged: (v) => setState(() => _cat = v ?? ''),
            ),
            const SizedBox(height: 6),
            Muted(ctx.m('found', {'n': shown.length, 'max': books.length})),
          ]),
          mGap,
          if (shown.isEmpty) fbPanel([Muted(ctx.m('noFound'), align: TextAlign.center)]),
          for (final b in shown) _card(context, b, books.indexOf(b), filtering, catName),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, Json b, int i, bool filtering, String Function(Object?) catName) {
    final c = context.c;
    final ro = ctx.readOnly;
    final file = obj(b['file']);
    final lf = obj(b['lead_form']);
    final links = (b['links'] as List? ?? const []);
    Widget tag(String t, {IconData? icon, Tone tone = Tone.muted}) => Chip2(t, icon: icon, tone: tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: b['published'] == false ? .7 : 1,
        child: Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(bookUrl(b['slug'])), mode: LaunchMode.externalApplication),
                    child: Container(
                      width: 78,
                      height: 104,
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: netImage(
                            str(b['cover'])),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(LucideIcons.bookOpen, color: c.muted),
                          ),
                          if (_replacing == b['_id'])
                            Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: Text(
                                _progress != null && _progress! <= 1 ? '${(_progress! * 100).round()}%' : '…',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(b['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            tag(ctx.m('pages', {'n': file['pages']})),
                            tag(mb(file['bytes'])),
                            tag(ctx.m('views', {'n': fmt(n(b['views']))})),
                            if (n(b['edition']) > 1) tag(ctx.m('edition', {'n': b['edition']})),
                            if (b['big'] == true) tag(ctx.m('big'), tone: Tone.warn),
                            if (b['has_password'] == true) tag(ctx.m('locked'), icon: LucideIcons.lock, tone: Tone.warn),
                            if (b['download'] == true) tag('', icon: LucideIcons.download),
                            if (str(lf['mode']).isNotEmpty && lf['mode'] != 'off') tag(ctx.m('formOn'), icon: LucideIcons.clipboardList, tone: Tone.good),
                            if (n(b['leads']) > 0) tag(ctx.m('contacts', {'n': fmt(n(b['leads']))}), icon: LucideIcons.users, tone: Tone.good),
                            if (links.isNotEmpty) tag(ctx.m('linksN', {'n': links.length}), icon: LucideIcons.mousePointerClick, tone: Tone.good),
                            if (b['published'] == false) tag(ctx.m('hidden'), icon: LucideIcons.eyeOff, tone: Tone.warn),
                          ],
                        ),
                        if ((b['category_ids'] as List? ?? const []).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final cid in b['category_ids'] as List)
                                if (catName(cid).isNotEmpty) Chip2(catName(cid), icon: LucideIcons.folderOpen, tone: Tone.brand),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Btn(
                    ctx.m('edit'),
                    icon: LucideIcons.pencil,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: ro ? null : () => showSheet<void>(context, (_) => EditBookSheet(ctx: ctx, book: b)),
                  ),
                  Btn(
                    ctx.m('linkQr'),
                    icon: LucideIcons.qrCode,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: () => openQr(context, ctx, url: bookUrl(b['slug']), name: str(b['title']), embed: true, relink: ('book', str(b['_id']))),
                  ),
                  Btn(ctx.m('replace'), icon: LucideIcons.refreshCw, kind: BtnKind.ghost, small: true, onTap: ro || _progress != null ? null : () => _replace(b)),
                  Btn(
                    ctx.m('password'),
                    icon: b['has_password'] == true ? LucideIcons.lock : LucideIcons.lockOpen,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: ro ? null : () => showSheet<void>(context, (_) => PasswordSheet(ctx: ctx, book: b)),
                  ),
                  Btn(
                    ctx.m('leadForm'),
                    icon: LucideIcons.clipboardList,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: ro ? null : () => showSheet<void>(context, (_) => LeadFormSheet(ctx: ctx, book: b)),
                  ),
                  Btn(
                    ctx.m('links'),
                    icon: LucideIcons.mousePointerClick,
                    kind: BtnKind.ghost,
                    small: true,
                    onTap: ro
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LinksEditor(ctx: ctx, book: b),
                            ),
                          ),
                  ),
                  RoundBtn(
                    LucideIcons.externalLink,
                    size: 36,
                    tip: ctx.m('open'),
                    onTap: () => launchUrl(Uri.parse(bookUrl(b['slug'])), mode: LaunchMode.externalApplication),
                  ),
                  RoundBtn(LucideIcons.arrowUp, size: 36, onTap: ro || filtering || i == 0 ? null : () => _move(i, -1)),
                  RoundBtn(LucideIcons.arrowDown, size: 36, onTap: ro || filtering || i == ctx.books.length - 1 ? null : () => _move(i, 1)),
                  RoundBtn(
                    LucideIcons.trash2,
                    size: 36,
                    fg: c.danger,
                    tip: ctx.m('delete'),
                    onTap: ro
                        ? null
                        : () async {
                            if (!await fbConfirm(context, ctx, ctx.m('removeBook'), '${b['title']} — ${ctx.m('removeBookSub')}')) return;
                            final r = await ctx.run(() => ctx.api.delete('${ctx.base}/books/${b['_id']}'));
                            if (r == null) return;
                            ctx.setBooks((l) => l.where((x) => x['_id'] != b['_id']).toList(), r['room']);
                            ctx.notify(str(r['message']));
                          },
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

// ------------------------------------------------------------------------------------------- edit one book
class EditBookSheet extends StatefulWidget {
  final FbCtx ctx;
  final Json book;
  const EditBookSheet({super.key, required this.ctx, required this.book});
  @override
  State<EditBookSheet> createState() => _EditBookSheetState();
}

class _EditBookSheetState extends State<EditBookSheet> {
  FbCtx get ctx => widget.ctx;
  late final _title = TextEditingController(text: str(widget.book['title']));
  late final _about = TextEditingController(text: str(widget.book['about']));
  late final _slug = TextEditingController(text: str(widget.book['slug']));
  late final List<String> _cats = (widget.book['category_ids'] as List? ?? const []).map((e) => '$e').toList();
  late bool _published = widget.book['published'] != false;
  late bool _download = widget.book['download'] == true;
  late String _reader = str(widget.book['reader_theme']);
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _title.dispose();
    _about.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owned = (ctx.data['reader_themes'] as List? ?? const ['classic']).map((e) => '$e').toList();
    return MSheet(
      title: ctx.m('edit'),
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          ctx.m('save'),
          icon: LucideIcons.save,
          small: true,
          busy: _busy,
          onTap: _busy || _title.text.trim().isEmpty
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _err = '';
                  });
                  try {
                    final r = await ctx.api.put('${ctx.base}/books/${widget.book['_id']}', {
                      'title': _title.text,
                      'about': _about.text,
                      'category_ids': _cats,
                      'published': _published,
                      'download': _download,
                      'reader_theme': _reader,
                      'slug': _slug.text,
                    });
                    ctx.setBook(obj(r['data']));
                    ctx.notify(ctx.m('saved'));
                    if (context.mounted) Navigator.pop(context);
                  } on ApiError catch (e) {
                    setState(() {
                      _err = e.message;
                      _busy = false;
                    });
                  }
                },
        ),
      ],
      children: [
        Field(label: ctx.m('bookTitle'), controller: _title, maxLength: 120, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.m('bookAbout'), controller: _about, maxLength: 600, maxLines: 3),
        gap14,
        Text(ctx.m('bookCats'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (ctx.categories.isEmpty)
          Muted(ctx.m('noCats'))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in ctx.categories)
                FilterChip(label: Text(str(x['name'])), selected: _cats.contains(str(x['_id'])), onSelected: (v) => setState(() => v ? _cats.add(str(x['_id'])) : _cats.remove(str(x['_id'])))),
            ],
          ),
        gap14,
        DropdownButtonFormField<String>(
          initialValue: owned.contains(_reader) ? _reader : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: ctx.m('readerLook'), isDense: true),
          items: [
            DropdownMenuItem(value: '', child: Text(ctx.m('readerDefault'))),
            for (final k in fbReaders.keys.where(owned.contains)) DropdownMenuItem(value: k, child: Text(fbReaders[k]!.name(ctx.lang))),
          ],
          onChanged: (v) => setState(() => _reader = v ?? ''),
        ),
        gap14,
        Field(
          label: ctx.m('bookLink'),
          controller: _slug,
          maxLength: 60,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12, right: 2),
            child: Center(
              widthFactor: 1,
              child: Text(
                '/b/',
                style: TextStyle(color: context.c.muted, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          onChanged: (v) {
            final x = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
            if (x != v) {
              _slug.value = TextEditingValue(
                text: x,
                selection: TextSelection.collapsed(offset: x.length),
              );
            }
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Muted(ctx.m('slugHint'))),
        SwitchRow(title: ctx.m('published'), value: _published, onChanged: (v) => setState(() => _published = v)),
        SwitchRow(title: ctx.m('allowDownload'), value: _download, onChanged: (v) => setState(() => _download = v)),
        if (_err.isNotEmpty) ...[gap14, Alert(_err)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- password
class PasswordSheet extends StatefulWidget {
  final FbCtx ctx;
  final Json book;
  const PasswordSheet({super.key, required this.ctx, required this.book});
  @override
  State<PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<PasswordSheet> {
  FbCtx get ctx => widget.ctx;
  final _p = TextEditingController();
  String _busy = '', _err = '';

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  Future<void> _act(bool set) async {
    setState(() {
      _busy = set ? 'set' : 'remove';
      _err = '';
    });
    try {
      final path = '${ctx.base}/books/${widget.book['_id']}/password';
      final r = set ? await ctx.api.post(path, {'password': _p.text}) : await ctx.api.delete(path);
      ctx.setBook(obj(r['data']));
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final owned = (ctx.data['passwords'] as List? ?? const []).map((e) => '$e').contains(str(b['_id']));
    return MSheet(
      title: ctx.m('pwTitle'),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: str(b['title']),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' — ${ctx.m('pwSub')}'),
            ],
          ),
        ),
        gap14,
        if (!owned) ...[
          Muted(ctx.m('pwWhat')),
          gap14,
          GoldBtn(
            ctx.m('pwUnlock', {'coins': fmt(n(ctx.prices['fb_password']))}),
            onTap: ctx.readOnly
                ? null
                : () {
                    Navigator.pop(context);
                    ctx.askBuy({'password': b});
                  },
          ),
        ] else ...[
          if (b['has_password'] == true)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip2(ctx.m('pwOn'), icon: LucideIcons.lock, tone: Tone.good),
            ),
          gap14,
          Field(label: ctx.m('pwNew'), controller: _p, maxLength: 40, onChanged: (_) => setState(() {})),
          gap14,
          Wrap(
            spacing: 8,
            children: [
              Btn(ctx.m('pwSet'), icon: LucideIcons.lock, small: true, busy: _busy == 'set', onTap: _busy.isNotEmpty || _p.text.length < 4 ? null : () => _act(true)),
              if (b['has_password'] == true)
                Btn(ctx.m('pwRemove'), icon: LucideIcons.lockOpen, kind: BtnKind.ghost, small: true, busy: _busy == 'remove', onTap: _busy.isNotEmpty ? null : () => _act(false)),
            ],
          ),
        ],
        gap14,
        Muted(ctx.m('pwNote')),
        if (_err.isNotEmpty) ...[gap14, Alert(_err)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- contact form of one book
class LeadFormSheet extends StatefulWidget {
  final FbCtx ctx;
  final Json book;
  const LeadFormSheet({super.key, required this.ctx, required this.book});
  @override
  State<LeadFormSheet> createState() => _LeadFormSheetState();
}

class _LeadFormSheetState extends State<LeadFormSheet> {
  FbCtx get ctx => widget.ctx;
  late final Json _lf0 = obj(widget.book['lead_form']);
  late String _mode = str(_lf0['mode']).isEmpty ? 'off' : str(_lf0['mode']);
  late final _page = TextEditingController(text: '${_lf0['page'] ?? 3}');
  late final _title = TextEditingController(text: str(_lf0['title']));
  late final _msg = TextEditingController(text: str(_lf0['message']));
  late final Map<String, bool> _ask = {
    for (final k in ['ask_email', 'ask_telegram', 'ask_note', 'skip']) k: _lf0[k] == true,
  };
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _page.dispose();
    _title.dispose();
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = ctx.on('fb_leads');
    final locked = !on && _mode != 'off';
    final pages = n(obj(widget.book['file'])['pages']).toInt().clamp(1, 1 << 20);
    return MSheet(
      title: '${ctx.m('leadForm')} · ${widget.book['title']}',
      footer: [
        const Spacer(),
        Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(
          ctx.m('save'),
          icon: LucideIcons.save,
          small: true,
          busy: _busy,
          onTap: _busy || locked
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _err = '';
                  });
                  try {
                    final r = await ctx.api.put('${ctx.base}/books/${widget.book['_id']}', {
                      'lead_form': {'mode': _mode, 'page': (int.tryParse(_page.text) ?? 1).clamp(1, pages), 'title': _title.text, 'message': _msg.text, ..._ask},
                    });
                    ctx.setBook(obj(r['data']));
                    ctx.notify(ctx.m('saved'));
                    if (context.mounted) Navigator.pop(context);
                  } on ApiError catch (e) {
                    setState(() {
                      _err = e.message;
                      _busy = false;
                    });
                  }
                },
        ),
      ],
      children: [
        Muted(ctx.m('leadFormSub')),
        gap14,
        Segmented<String>(value: _mode, options: [('off', ctx.m('lfOff')), ('before', ctx.m('lfBefore')), ('after', ctx.m('lfAfter'))], onChanged: (v) => setState(() => _mode = v)),
        if (locked) ...[gap14, NeedAddon(ctx: ctx, addon: 'fb_leads', onGo: () => Navigator.pop(context))],
        if (_mode != 'off') ...[
          gap14,
          if (_mode == 'after') ...[
            SizedBox(
              width: 160,
              child: Field(label: ctx.m('lfPage'), controller: _page, keyboard: TextInputType.number, maxLength: 4),
            ),
            gap14,
          ],
          Text(ctx.m('lfAsk'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, label) in [('ask_email', ctx.m('lfEmail')), ('ask_telegram', ctx.m('lfTelegram')), ('ask_note', ctx.m('lfNote'))])
                FilterChip(label: Text(label), selected: _ask[k]!, onSelected: (v) => setState(() => _ask[k] = v)),
            ],
          ),
          gap14,
          Field(label: ctx.m('lfTitle'), controller: _title, hint: ctx.m('lfTitlePh'), maxLength: 80),
          gap14,
          Field(label: ctx.m('lfMessage'), controller: _msg, hint: ctx.m('lfMessagePh'), maxLength: 300, maxLines: 2),
          gap14,
          SwitchRow(title: ctx.m('lfSkip'), value: _ask['skip']!, onChanged: (v) => setState(() => _ask['skip'] = v)),
        ],
        if (_err.isNotEmpty) ...[gap14, Alert(_err)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- clickable pages of one book
const _linkKinds = ['url', 'phone', 'telegram', 'facebook', 'map', 'youtube', 'email', 'page'];

class LinksEditor extends StatefulWidget {
  final FbCtx ctx;
  final Json book;
  const LinksEditor({super.key, required this.ctx, required this.book});
  @override
  State<LinksEditor> createState() => _LinksEditorState();
}

class _LinksEditorState extends State<LinksEditor> {
  FbCtx get ctx => widget.ctx;
  late final int _pages = n(obj(widget.book['file'])['pages']).toInt().clamp(1, 1 << 20);
  late final double _ratio = () {
    final f = obj(widget.book['file']);
    return n(f['width']) > 0 && n(f['height']) > 0 ? n(f['width']) / n(f['height']) : .707;
  }();
  late final List<Json> _links = [
    for (final (i, l) in objs(widget.book['links']).indexed) {...l, 'key': 'k$i'},
  ];
  int _page = 1;
  String? _sel;
  Rect? _draft;
  Offset? _start;
  bool _busy = false;
  String _err = '';
  final _value = TextEditingController(), _label = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  String _pageUrl(int p) => str(widget.book['page_url']).replaceAll('{page}', '$p');
  Json? get _cur => _links.where((l) => l['key'] == _sel).firstOrNull;

  void _pick(String? key) {
    setState(() => _sel = key);
    final cur = _cur;
    _value.text = str(cur?['value']);
    _label.text = str(cur?['label']);
  }

  void _go(int p) {
    setState(() => _page = p.clamp(1, _pages));
    _pick(null);
  }

  Future<void> _save() async {
    final bad = _links.where((l) => str(l['value']).trim().isEmpty).firstOrNull;
    if (bad != null) {
      setState(() {
        _page = n(bad['page']).toInt();
        _err = '${ctx.m('linkKinds.${bad['kind']}')}?';
      });
      _pick(str(bad['key']));
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final r = await ctx.api.put('${ctx.base}/books/${widget.book['_id']}/links', {
        'links': [
          for (final l in _links) {'page': l['page'], 'x': l['x'], 'y': l['y'], 'w': l['w'], 'h': l['h'], 'kind': l['kind'], 'value': str(l['value']).trim(), 'label': str(l['label'])},
        ],
      });
      ctx.setBook(obj(r['data']));
      ctx.notify(ctx.m('saved'));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() {
        _err = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.on('fb_links');
    final onPage = _links.where((l) => l['page'] == _page).toList();
    final pagesWith = (_links.map((l) => n(l['page']).toInt()).toSet().toList()..sort());
    final cur = _cur;
    return Scaffold(
      backgroundColor: c.appBg,
      appBar: AppBar(
        backgroundColor: c.appBg,
        title: Text('${ctx.m('links')} · ${widget.book['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Btn(ctx.m('save'), icon: LucideIcons.save, small: true, busy: _busy, onTap: _busy || !on ? null : _save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (!on) ...[NeedAddon(ctx: ctx, addon: 'fb_links', onGo: () => Navigator.pop(context)), mGap],
          Row(
            children: [
              Icon(LucideIcons.mousePointerClick, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Expanded(child: Muted(ctx.m('linksSub'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: _page <= 1 ? null : () => _go(_page - 1), icon: const Icon(LucideIcons.chevronLeft)),
              Text(ctx.m('pageOf', {'n': _page, 'max': _pages}), style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(onPressed: _page >= _pages ? null : () => _go(_page + 1), icon: const Icon(LucideIcons.chevronRight)),
            ],
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: _ratio,
                child: LayoutBuilder(
                  builder: (_, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    Offset pt(Offset p) => Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
                    return GestureDetector(
                      onPanStart: on
                          ? (d) => setState(() {
                              _start = pt(d.localPosition);
                              _draft = Rect.fromPoints(_start!, _start!);
                            })
                          : null,
                      onPanUpdate: on && _start != null ? (d) => setState(() => _draft = Rect.fromPoints(_start!, pt(d.localPosition))) : null,
                      onPanEnd: on && _start != null
                          ? (_) {
                              final r = _draft!;
                              setState(() {
                                _start = null;
                                _draft = null;
                              });
                              if (r.width < .02 || r.height < .015) return;
                              final key = 'n${DateTime.now().microsecondsSinceEpoch}';
                              setState(() => _links.add({'key': key, 'page': _page, 'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height, 'kind': 'url', 'value': '', 'label': ''}));
                              _pick(key);
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 10)],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(image: netImage(
                              _pageUrl(_page)),
                              fit: BoxFit.fill,
                              errorBuilder: (_, _, _) => Center(child: Icon(LucideIcons.imageOff, color: c.muted)),
                              loadingBuilder: (_, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator()),
                            ),
                            for (final l in onPage)
                              Positioned(
                                left: n(l['x']) * size.width,
                                top: n(l['y']) * size.height,
                                width: n(l['w']) * size.width,
                                height: n(l['h']) * size.height,
                                child: GestureDetector(
                                  onTap: () => _pick(str(l['key'])),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: c.brand.withValues(alpha: _sel == l['key'] ? .28 : .14),
                                      border: Border.all(color: c.brand, width: _sel == l['key'] ? 2.5 : 1.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.topLeft,
                                    padding: const EdgeInsets.all(2),
                                    child: Text(
                                      str(l['label']).isNotEmpty ? str(l['label']) : ctx.m('linkKinds.${l['kind']}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, color: c.brandInk, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ),
                            if (_draft != null)
                              Positioned(
                                left: _draft!.left * size.width,
                                top: _draft!.top * size.height,
                                width: _draft!.width * size.width,
                                height: _draft!.height * size.height,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.brand.withValues(alpha: .2),
                                    border: Border.all(color: c.brand, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (pagesWith.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final p in pagesWith) ChoiceChip(label: Text('$p (${_links.where((l) => l['page'] == p).length})'), selected: p == _page, onSelected: (_) => _go(p))],
            ),
          ],
          mGap,
          fbPanel([
            Row(
              children: [
                Expanded(
                  child: Text(ctx.m('linksN', {'n': _links.length}), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (onPage.isEmpty) Muted(ctx.m('noLinks')),
            for (final (i, l) in onPage.indexed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: _sel == l['key'],
                leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))),
                title: Text(str(l['label']).isNotEmpty ? str(l['label']) : ctx.m('linkKinds.${l['kind']}')),
                subtitle: Text(str(l['value']).isEmpty ? '…' : str(l['value']), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _pick(str(l['key'])),
              ),
            if (cur != null) ...[
              const Divider(),
              DropdownButtonFormField<String>(
                initialValue: str(cur['kind']),
                isExpanded: true,
                decoration: InputDecoration(labelText: ctx.m('linkOpens'), isDense: true),
                items: [for (final k in _linkKinds) DropdownMenuItem(value: k, child: Text(ctx.m('linkKinds.$k')))],
                onChanged: (v) => setState(() => cur['kind'] = v),
              ),
              gap14,
              Field(
                controller: _value,
                hint: ctx.m('linkPh.${cur['kind']}'),
                maxLength: 500,
                keyboard: cur['kind'] == 'page'
                    ? TextInputType.number
                    : cur['kind'] == 'phone'
                    ? TextInputType.phone
                    : TextInputType.url,
                onChanged: (v) => setState(() => cur['value'] = v),
              ),
              gap14,
              Field(label: ctx.m('linkLabel'), controller: _label, maxLength: 60, onChanged: (v) => setState(() => cur['label'] = v)),
              gap14,
              Align(
                alignment: Alignment.centerLeft,
                child: Btn(
                  ctx.m('delete'),
                  icon: LucideIcons.trash2,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () {
                    setState(() => _links.removeWhere((x) => x['key'] == _sel));
                    _pick(null);
                  },
                ),
              ),
            ],
            if (_err.isNotEmpty) ...[gap14, Alert(_err)],
          ]),
        ],
      ),
    );
  }
}
