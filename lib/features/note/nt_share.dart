import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_api.dart';
import 'nt_common.dart';

// Share a note (5 levels) or a group (4 levels): PIN, end date, "Open from", options, "I've read it", safety,
// a custom link (note_link) checked while typing, copy / QR / share / open, and a new link (the web's ShareDialog.jsx).
// Returns the saved note / group (the API's noteOut / groupOut) or null.

Future<Json?> ntShareNote(BuildContext context, NtCtx ctx, Json note, {int groupCount = 0}) =>
    showSheet<Json>(context, (_) => NtShareSheet(ctx: ctx, item: note, group: false, groupCount: groupCount));

Future<Json?> ntShareGroup(BuildContext context, NtCtx ctx, Json group, {int pinNotes = 0}) =>
    showSheet<Json>(context, (_) => NtShareSheet(ctx: ctx, item: group, group: true, pinNotes: pinNotes));

class NtShareSheet extends StatefulWidget {
  final NtCtx ctx;
  final Json item; // the note or the group
  final bool group;
  final int groupCount; // a note: how many groups it is in
  final int pinNotes; // a group without a PIN: how many of its notes have their own PIN
  const NtShareSheet({super.key, required this.ctx, required this.item, required this.group, this.groupCount = 0, this.pinNotes = 0});
  @override
  State<NtShareSheet> createState() => NtShareSheetState();
}

class NtShareSheetState extends State<NtShareSheet> {
  NtCtx get ctx => widget.ctx;
  late Json _item = widget.item;
  Json get _s => obj(_item['share']);
  String get _id => str(_item['_id']);

  late String _level = str(_s['level']).isEmpty ? 'off' : str(_s['level']);
  final _pin = TextEditingController();
  bool _dropPin = false;
  late DateTime? _until = _dateOf(_s['expires_at']);
  late DateTime? _opens = _dateOf(_s['opens_at']);
  late bool _askName = _s['ask_name'] != false;
  late bool _allowFiles = _s['allow_files'] != false;
  late bool _showEntries = _s['show_entries'] != false;
  late bool _ack = _s['ack'] == true;
  late bool _hideOwner = _s['hide_owner'] == true;
  late bool _noCopy = _s['no_copy'] == true;
  // custom link
  late final _slug = TextEditingController(text: str(_s['slug']));
  Timer? _deb;
  Json? _check; // the last /link-check answer
  bool _checking = false;
  int _ask = 0;

  bool _busy = false, _relinking = false;
  String _error = '';

  static DateTime? _dateOf(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

  @override
  void dispose() {
    _deb?.cancel();
    _pin.dispose();
    _slug.dispose();
    super.dispose();
  }

  String get _url => ntUrl(_s['path']);
  String get _prefix => ntUrl(widget.group ? '/n/g/' : '/n/').replaceFirst(RegExp(r'^https?://'), '');

  // ---------------------------------------------------------------- custom link check (400 ms after typing)
  void _slugChanged(String v) {
    _deb?.cancel();
    _ask++; // any check still on its way is for older text now: its answer is dropped
    final want = v.trim();
    if (want.isEmpty || want == str(_s['slug'])) {
      setState(() {
        _check = null;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    _deb = Timer(const Duration(milliseconds: 400), () => _runCheck(want));
  }

  Future<void> _runCheck(String want) async {
    final ask = ++_ask;
    try {
      final r = await ctx.a.linkCheck(want, kind: widget.group ? 'group' : 'note', id: _id);
      // only the answer for what is in the field now counts
      if (!mounted || ask != _ask || _slug.text.trim() != want) return;
      setState(() {
        _check = {...obj(r['data']), 'asked': want};
        _checking = false;
      });
    } catch (e) {
      if (!mounted || ask != _ask) return;
      setState(() {
        _check = null;
        _checking = false;
      });
    }
  }

  void _useSuggestion(String s) {
    _slug.text = s;
    _slug.selection = TextSelection.collapsed(offset: s.length);
    _slugChanged(s);
  }

  // what the custom link field asks to save: null = no change, '' = remove
  String? get _slugToSave {
    final want = _slug.text.trim();
    final have = str(_s['slug']);
    if (want == have) return null;
    if (want.isEmpty) return '';
    final c = _check;
    // a check made for other text (older typing) never decides what is saved
    if (c == null || str(c['asked']) != want) return null;
    return c['ok'] == true || c['reason'] == 'mine' ? (str(c['slug']).isNotEmpty ? str(c['slug']) : want) : null;
  }

  bool get _slugBlocked {
    final want = _slug.text.trim();
    if (want.isEmpty || want == str(_s['slug'])) return false;
    return _checking || _slugToSave == null;
  }

  // ---------------------------------------------------------------- save
  Future<void> _save() async {
    final pin = _pin.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{4,8}$').hasMatch(pin)) return setState(() => _error = ctx.m('pinBad'));
    if (_slugBlocked) return setState(() => _error = ctx.m('linkFixFirst'));
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = <String, dynamic>{
      'level': _level,
      if (pin.isNotEmpty) 'pin': pin else if (_dropPin) 'pin': '',
      'expires_at': _until?.toUtc().toIso8601String(),
      'opens_at': _opens?.toUtc().toIso8601String(),
      'ask_name': _askName,
      if (!widget.group) 'allow_files': _allowFiles,
      if (!widget.group) 'show_entries': _showEntries,
      if (_ack != (_s['ack'] == true)) 'ack': _ack,
      'hide_owner': _hideOwner,
      'no_copy': _noCopy,
      'slug': ?_slugToSave,
    };
    try {
      final r = widget.group ? await ctx.a.groupShare(_id, body) : await ctx.a.share(_id, body);
      if (!mounted) return;
      ctx.notify(ctx.m('shareSaved'));
      Navigator.pop(context, obj(r['data']));
    } catch (e) {
      if (!mounted) return;
      final code = ntCode(e);
      setState(() {
        _busy = false;
        _error = ctx.errText(e);
        // taken by someone else a moment ago: show it as taken, with the free names the API suggests
        if (code == 'slug_taken' && e is ApiError) {
          final want = _slug.text.trim();
          _check = {'ok': false, 'reason': 'taken', 'slug': want, 'asked': want, 'suggestions': e.body['suggestions'] ?? obj(e.body['data'])['suggestions'] ?? const []};
          _checking = false;
        }
      });
      if (code.startsWith('need_')) ctx.fail(e);
    }
  }

  Future<void> _newLink() async {
    if (!await ntConfirm(context, ctx, ctx.m('newLinkAsk'), ctx.m('newLinkSub'), yes: ctx.m('newLink'), danger: false)) return;
    setState(() => _relinking = true);
    try {
      final r = widget.group ? await ctx.a.groupNewLink(_id) : await ctx.a.newLink(_id);
      if (!mounted) return;
      setState(() {
        _item = obj(r['data']);
        _slug.text = '';
        _check = null;
        _relinking = false;
      });
      ctx.notify(ctx.m('newLinkOk'));
    } catch (e) {
      if (mounted) setState(() => _relinking = false);
      ctx.fail(e);
    }
  }

  void _qr() => showSheet<void>(
    context,
    (s) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(str(_item[widget.group ? 'name' : 'title']).isEmpty ? ctx.m('untitled') : str(_item[widget.group ? 'name' : 'title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: s.c.cardShadow),
              child: QrImageView(data: _url, size: 220, padding: EdgeInsets.zero, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 10),
            SelectableText(_url.replaceFirst(RegExp(r'^https?://'), ''), textAlign: TextAlign.center, style: TextStyle(color: s.c.brand, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Btn(ctx.m('copyLink'), icon: LucideIcons.copy, kind: BtnKind.ghost, expand: true, onTap: () => _copy()),
          ],
        ),
      ),
    ),
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _url));
    ctx.notify(ctx.m('copied'));
  }

  Future<void> _pickDate({required bool opens}) async {
    final now = DateTime.now();
    final cur = opens ? _opens : _until;
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 5);
    // a saved date that has passed already (the link ended / opened) starts the picker at today
    var start = cur ?? now.add(Duration(days: opens ? 1 : 7));
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    final d = await showDatePicker(context: context, firstDate: first, lastDate: last, initialDate: start);
    if (d == null || !mounted) return;
    var at = DateTime(d.year, d.month, d.day, 23, 59);
    if (opens) {
      final t = await showTimePicker(context: context, initialTime: cur != null ? TimeOfDay.fromDateTime(cur) : const TimeOfDay(hour: 8, minute: 0));
      if (!mounted) return;
      at = DateTime(d.year, d.month, d.day, t?.hour ?? 8, t?.minute ?? 0);
    }
    setState(() => opens ? _opens = at : _until = at);
  }

  // ---------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final levels = widget.group ? ntGroupLevels : ntLevels;
    final hasPin = _s['has_pin'] == true && !_dropPin;
    final ackLocked = !ctx.ack && _s['ack'] != true;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(widget.group ? ctx.m('groupShareTitle') : ctx.m('shareTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- the link
                  _LinkBox(
                    ctx: ctx,
                    url: _url,
                    off: _level == 'off',
                    busy: _relinking,
                    onCopy: _copy,
                    onQr: _qr,
                    onShare: () => SharePlus.instance.share(ShareParams(text: _url)),
                    onOpen: () => ntLaunch(ctx, _url),
                    onNewLink: _newLink,
                  ),
                  if (!widget.group && widget.groupCount > 0) ...[const SizedBox(height: 10), Alert(ctx.m('inGroupHint', {'n': widget.groupCount}), tone: Tone.brand)],
                  const SizedBox(height: 18),
                  // ---------- level
                  _H(widget.group ? ctx.m('groupLevelTitle') : ctx.m('levelTitle')),
                  for (final k in levels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LevelCard(
                        icon: ntLevelIcons[k]!,
                        title: ctx.l('${widget.group ? 'groupLevels' : 'levels'}.$k').firstOrNull ?? k,
                        sub: (ctx.l('${widget.group ? 'groupLevels' : 'levels'}.$k')).skip(1).firstOrNull ?? '',
                        on: _level == k,
                        onTap: () => setState(() => _level = k),
                      ),
                    ),
                  const SizedBox(height: 10),
                  // ---------- PIN
                  _H(ctx.m('pinLabel')),
                  if (widget.group) Padding(padding: const EdgeInsets.only(bottom: 6), child: Muted(ctx.m('groupPinHint'))),
                  if (widget.group && widget.pinNotes > 0 && !hasPin && _pin.text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Alert(ctx.m('groupPinNotes', {'n': widget.pinNotes}), tone: Tone.warn),
                    ),
                  Field(
                    controller: _pin,
                    hint: hasPin ? '••••' : '',
                    icon: LucideIcons.lock,
                    keyboard: TextInputType.number,
                    maxLength: 8,
                    onChanged: (_) => setState(() => _dropPin = false),
                  ),
                  if (hasPin)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(ctx.m('pinOn'), style: TextStyle(color: c.muted, fontSize: 12.5))),
                          TextButton(onPressed: () => setState(() => _dropPin = true), child: Text(ctx.m('pinRemove'), style: TextStyle(color: c.danger))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  // ---------- dates
                  _DateRow(ctx: ctx, icon: LucideIcons.calendarClock, label: ctx.m('opensAt'), value: _opens, time: true, empty: ctx.m('opensNow'), hint: _opens == null ? ctx.m('opensHint') : ctx.m('opensHintOn'), onPick: () => _pickDate(opens: true), onClear: () => setState(() => _opens = null)),
                  const SizedBox(height: 8),
                  _DateRow(ctx: ctx, icon: LucideIcons.calendarX, label: ctx.m('expires'), value: _until, empty: ctx.m('noEnd'), onPick: () => _pickDate(opens: false), onClear: () => setState(() => _until = null)),
                  const SizedBox(height: 14),
                  // ---------- options
                  _H(ctx.m('options')),
                  _Switch(label: ctx.m('askName'), value: _askName, onChanged: (v) => setState(() => _askName = v)),
                  if (!widget.group) ...[
                    _Switch(label: ctx.m('allowFiles'), value: _allowFiles, onChanged: (v) => setState(() => _allowFiles = v)),
                    _Switch(label: ctx.m('showEntries'), value: _showEntries, onChanged: (v) => setState(() => _showEntries = v)),
                  ],
                  _Switch(
                    label: ctx.m('ackSwitch'),
                    sub: widget.group ? ctx.m('ackSwitchGroup') : ctx.m('ackSwitchSub'),
                    value: _ack,
                    locked: ackLocked,
                    price: fmt(ctx.price('note_ack')),
                    onLocked: () => ctx.askBuy('note_ack'),
                    onChanged: (v) => setState(() => _ack = v),
                  ),
                  const SizedBox(height: 8),
                  _H(ctx.m('safety')),
                  _Switch(label: ctx.m('hideOwner'), sub: ctx.m('hideOwnerSub'), value: _hideOwner, onChanged: (v) => setState(() => _hideOwner = v)),
                  _Switch(label: ctx.m('noCopy'), sub: ctx.m('noCopySub'), value: _noCopy, onChanged: (v) => setState(() => _noCopy = v)),
                  const SizedBox(height: 14),
                  // ---------- custom link
                  _H(ctx.m('linkField')),
                  if (!ctx.link && str(_s['slug']).isEmpty)
                    NtLockLine(ctx: ctx, text: ctx.m('linkWhy'), product: 'note_link')
                  else
                    _slugField(c),
                  if (_error.isNotEmpty) ...[const SizedBox(height: 12), Alert(_error)],
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
                Expanded(
                  child: Btn(ctx.m('cancel'), kind: BtnKind.ghost, onTap: _busy ? null : () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Btn(ctx.m('save'), busy: _busy, onTap: _save)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slugField(C c) {
    final ch = _check;
    final want = _slug.text.trim();
    final same = want == str(_s['slug']);
    Widget? state;
    if (want.isEmpty && str(_s['slug']).isNotEmpty) {
      state = Text(ctx.m('linkWillRemove'), style: TextStyle(color: c.warn, fontSize: 12.5, fontWeight: FontWeight.w600));
    } else if (same && want.isNotEmpty) {
      state = _StateLine(icon: LucideIcons.circleCheck, colour: c.good, text: ctx.m('linkMine'));
    } else if (_checking) {
      state = _StateLine(icon: LucideIcons.loaderCircle, colour: c.muted, text: ctx.m('linkChecking'));
    } else if (ch != null) {
      final ok = ch['ok'] == true || ch['reason'] == 'mine';
      final reason = str(ch['reason']);
      state = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateLine(icon: ok ? LucideIcons.circleCheck : LucideIcons.circleX, colour: ok ? c.good : c.danger, text: ok ? ctx.m('linkFree') : ctx.t.or('note.linkReasons.$reason', ctx.m('linkTaken'))),
          if (ch['dropped'] == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ctx.m('linkDropped'), style: TextStyle(color: c.muted, fontSize: 12))),
          if (!ok && (ch['suggestions'] as List? ?? const []).isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ctx.m('linkTry'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                for (final s in (ch['suggestions'] as List)) ActionChip(label: Text('$s'), onPressed: () => _useSuggestion('$s')),
              ],
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('$_prefix${_slug.text.trim().isEmpty ? ctx.m('linkPh') : _slug.text.trim()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        Field(
          controller: _slug,
          hint: ctx.m('linkPh'),
          icon: LucideIcons.link,
          maxLength: 40,
          onChanged: (v) {
            // typed: lowercase, spaces → "-" (the API also drops Khmer letters and says so)
            final norm = v.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
            if (norm != v) {
              _slug.value = TextEditingValue(text: norm, selection: TextSelection.collapsed(offset: norm.length));
            }
            _slugChanged(norm);
          },
          suffix: _slug.text.isEmpty ? null : IconButton(onPressed: () => setState(() => _slug.clear()), icon: Icon(LucideIcons.x, size: 17, color: c.muted)),
        ),
        const SizedBox(height: 6),
        state ?? Text(ctx.m('linkRules'), style: TextStyle(color: c.muted, fontSize: 12.5)),
      ],
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
  );
}

class _StateLine extends StatelessWidget {
  final IconData icon;
  final Color colour;
  final String text;
  const _StateLine({required this.icon, required this.colour, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: colour),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: colour, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    ],
  );
}

class _LinkBox extends StatelessWidget {
  final NtCtx ctx;
  final String url;
  final bool off, busy;
  final VoidCallback onCopy, onQr, onShare, onOpen, onNewLink;
  const _LinkBox({required this.ctx, required this.url, required this.off, required this.busy, required this.onCopy, required this.onQr, required this.onShare, required this.onOpen, required this.onNewLink});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.link, size: 16, color: off ? c.muted : c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url.replaceFirst(RegExp(r'^https?://'), ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: off ? c.muted : c.ink, decoration: off ? TextDecoration.lineThrough : null),
                ),
              ),
            ],
          ),
          if (off) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ctx.m('levels.off').isNotEmpty ? ctx.l('levels.off').skip(1).firstOrNull ?? '' : '', style: TextStyle(color: c.muted, fontSize: 12.5))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Btn(ctx.m('copyLink'), icon: LucideIcons.copy, small: true, kind: BtnKind.ghost, onTap: onCopy),
              Btn('QR', icon: LucideIcons.qrCode, small: true, kind: BtnKind.ghost, onTap: onQr),
              Btn(ctx.m('share'), icon: LucideIcons.share2, small: true, kind: BtnKind.ghost, onTap: onShare),
              Btn(ctx.m('openLink'), icon: LucideIcons.externalLink, small: true, kind: BtnKind.ghost, onTap: onOpen),
              Btn(ctx.m('newLink'), icon: LucideIcons.refreshCw, small: true, kind: BtnKind.ghost, busy: busy, onTap: ctx.readOnly ? null : onNewLink),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool on;
  final VoidCallback onTap;
  const _LevelCard({required this.icon, required this.title, required this.sub, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: on ? c.active : c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? c.brand : c.line, width: on ? 1.8 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: on ? c.brand.withValues(alpha: .14) : c.bg2, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: on ? c.brandInk : c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if (sub.isNotEmpty) Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, size: 20, color: on ? c.brand : c.lineStrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final String label;
  final String? sub;
  final bool value;
  final bool locked;
  final String price;
  final VoidCallback? onLocked;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.label, this.sub, required this.value, required this.onChanged, this.locked = false, this.price = '', this.onLocked});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: locked ? onLocked : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (locked) ...[const SizedBox(width: 6), Icon(LucideIcons.lock, size: 13, color: c.muted)],
                    ],
                  ),
                  if (sub != null && sub!.isNotEmpty) Text(sub!, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            locked ? NtGoldBtn(price, onTap: onLocked) : Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final NtCtx ctx;
  final IconData icon;
  final String label, empty;
  final String? hint;
  final DateTime? value;
  final bool time;
  final VoidCallback onPick, onClear;
  const _DateRow({required this.ctx, required this.icon, required this.label, required this.value, required this.empty, this.hint, this.time = false, required this.onPick, required this.onClear});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value;
    final text = v == null ? empty : (time ? ntTime(v.toUtc().toIso8601String(), ctx.lang) : ntDate(v.toUtc().toIso8601String(), ctx.lang));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: v == null ? c.muted : c.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (v != null) IconButton(onPressed: onClear, icon: Icon(LucideIcons.x, size: 17, color: c.muted)) else Icon(LucideIcons.chevronRight, size: 17, color: c.muted),
                ],
              ),
            ),
          ),
        ),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(hint!, style: TextStyle(color: c.muted, fontSize: 12))),
      ],
    );
  }
}
