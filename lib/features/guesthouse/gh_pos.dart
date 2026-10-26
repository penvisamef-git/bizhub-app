import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show MHead, GoldBtn, LockNote, SureDelete, mGap, mDayTime, fileForm, MLookCard, openLookSheet;
import '../mart/mart_kit.dart' show MSheet, showSheet;
import '../restaurant/rest_common.dart' show Segmented, SwitchRow, gap14;
import 'gh_common.dart';
import 'gh_receipt.dart';
import 'gh_setup.dart' show GhSave;

// Staff & POS (desk devices, staff, payment QR, guest display + its looks) and Printing — GhPosSetup.jsx, GhLooks.jsx, GhPrint.jsx.

Widget _panel(List<Widget> children) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

// a picture box with Upload / Change / Remove
class _Pic extends StatelessWidget {
  final GhCtx ctx;
  final String url;
  final bool busy, wide;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final String pickLabel;
  const _Pic({required this.ctx, required this.url, required this.busy, required this.onPick, this.onRemove, this.wide = false, this.icon = LucideIcons.imagePlus, required this.pickLabel});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: wide ? 132 : 84,
          height: wide ? 74 : 84,
          decoration: BoxDecoration(
            color: c.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: busy
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : url.isNotEmpty
              ? Image(image: netImage(url), fit: wide ? BoxFit.cover : BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink())
              : Icon(icon, size: 28, color: c.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Btn(busy ? ctx.g('uploading') : pickLabel, icon: LucideIcons.imagePlus, kind: BtnKind.ghost, small: true, busy: busy, onTap: busy || ctx.readOnly ? null : onPick),
              if (url.isNotEmpty && !busy && onRemove != null) Btn(ctx.g('remove'), icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : onRemove),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ POS
class PosTab extends StatefulWidget {
  final GhCtx ctx;
  const PosTab({super.key, required this.ctx});
  @override
  State<PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<PosTab> {
  List<Json>? _staff, _devices;
  Json? _code, _looks;
  bool _busy = false, _qrBusy = false, _imgBusy = false;
  String _lookBusy = '';
  late final _qrLabel = TextEditingController(text: str(ctx.settings['pay_qr_label']));
  Timer? _tick;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PosTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _loadLooks();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _qrLabel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Future.wait([
      ctx.api.get('${ctx.base}/staff').then((x) => objs(x['data']), onError: (_) => <Json>[]),
      ctx.api.get('${ctx.base}/pos/devices').then((x) => objs(x['data']), onError: (_) => <Json>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _staff = r[0];
      _devices = r[1];
    });
    _loadLooks();
  }

  Future<void> _loadLooks() async {
    try {
      final r = await ctx.api.get('${ctx.base}/display-themes');
      if (mounted) setState(() => _looks = obj(r['data']));
    } catch (_) {}
  }

  Future<void> _pair() async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.post('${ctx.base}/pos/pair-code'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) _code = obj(r['data']);
    });
    _tick?.cancel();
    if (r != null) {
      _tick = Timer.periodic(const Duration(seconds: 5), (t) async {
        final left = DateTime.tryParse(str(_code?['expires']))?.difference(DateTime.now());
        if (!mounted || (left != null && left.isNegative)) {
          t.cancel();
          if (mounted) setState(() => _code = null);
          return;
        }
        final before = _devices?.length ?? 0;
        await _load();
        if ((_devices?.length ?? 0) > before && mounted) setState(() => _code = null);
      });
    }
  }

  Future<void> _editStaff(Json row) async {
    final ok = await showSheet<bool>(context, (_) => _StaffEditor(ctx: ctx, row: row));
    if (ok == true) _load();
  }

  Future<void> _upload(String path, void Function(bool) busy) async {
    final b = await ghPickPicture(context, ctx, maxSize: 1600);
    if (b == null) return;
    setState(() => busy(true));
    if (await ctx.run(() => ctx.api.post('${ctx.base}/$path', fileForm('file', b, 'picture.jpg')), ctx.g('saved')) != null) await ctx.reload();
    if (mounted) setState(() => busy(false));
  }

  Future<void> _useLook(String k) async {
    setState(() => _lookBusy = k);
    try {
      await ctx.api.put('${ctx.base}/display-theme', {'theme': k});
      await ctx.reload();
      ctx.notify(ctx.g('saved'));
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('gh_display_theme', item: k, onDone: _loadLooks);
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _lookBusy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final staff = _staff;
    final staffOn = ctx.addonOn('gh_staff');
    final full = staff != null && staff.length >= n(ctx.limits['staff']);
    final sub = ctx.g('posSub').split('{link}');
    final code = str(_code?['code']);
    final qr = str(obj(ctx.settings['pay_qr'])['url']);
    final dispImg = str(obj(ctx.settings['display_image'])['url']);
    final dispOn = ctx.addonOn('gh_display');
    final looks = _looks;
    final owned = (looks?['owned'] as List? ?? const ['classic']).map((e) => '$e').toSet();
    final current = str(looks?['current']).isNotEmpty ? str(looks?['current']) : (str(ctx.settings['display_theme']).isEmpty ? 'classic' : str(ctx.settings['display_theme']));
    final lookPrice = n(looks?['price']) == 0 ? 75 : n(looks?['price']);
    final image = dispImg.isNotEmpty ? dispImg : str(obj(ctx.settings['cover'])['url']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(ctx.g('posTitle'), icon: LucideIcons.monitorSmartphone),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: sub.first),
                  const TextSpan(
                    text: '/pos/guest-house',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (sub.length > 1) TextSpan(text: sub[1]),
                ],
              ),
              style: TextStyle(color: c.muted, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(ctx.g('linkDevice'), icon: LucideIcons.link2, small: true, busy: _busy, onTap: ctx.readOnly || _busy ? null : _pair),
                Btn(
                  ctx.g('openPos'),
                  icon: LucideIcons.externalLink,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/pos/guest-house'), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
            if (code.isNotEmpty) ...[
              gap14,
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    Text(
                      ctx.g('pairCode'),
                      style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      code.replaceAllMapped(RegExp(r'^(\d{3})(\d{3})$'), (x) => '${x[1]} ${x[2]}'),
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 4, color: c.brandInk),
                    ),
                    const SizedBox(height: 4),
                    Muted(ctx.g('pairExpires'), align: TextAlign.center),
                  ],
                ),
              ),
            ],
            gap14,
            Text(ctx.g('devices'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (_devices == null)
              const SkelList(rows: 2)
            else if (_devices!.isEmpty)
              Muted(ctx.g('noDevices'))
            else
              for (final d in _devices!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.monitorSmartphone, size: 18, color: c.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str(d['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(ctx.g('lastSeen', {'time': mDayTime(d['last_seen'] ?? d['created_date'], ctx.lang)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (!ctx.readOnly)
                        SureDelete(
                          remove: ctx.g('removeDevice'),
                          sure: ctx.g('sure'),
                          onDelete: () async {
                            if (await ctx.run(() => ctx.api.delete('${ctx.base}/pos/devices/${d['_id']}')) != null) _load();
                          },
                        ),
                    ],
                  ),
                ),
          ]),
          mGap,
          _panel([
            MHead(ctx.g('staffTitle'), icon: LucideIcons.users, sub: staffOn ? ctx.g('staffSubAll') : ctx.g('staffSub', {'n': staff?.length ?? 0, 'max': n(ctx.limits['staff'])})),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Btn(
                  ctx.g('addStaff'),
                  icon: full ? LucideIcons.lock : LucideIcons.plus,
                  small: true,
                  onTap: ctx.readOnly || staff == null ? null : () => full ? ctx.askBuy('gh_staff') : _editStaff({}),
                ),
                if (!staffOn) GoldBtn('${ctx.g('addonInfo.gh_staff.name')} · ${fmt(n(ctx.addon('gh_staff')['price']))}', onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_staff')),
              ],
            ),
            const SizedBox(height: 8),
            if (staff == null)
              const SkelList(rows: 2)
            else if (staff.isEmpty)
              Muted(ctx.g('noStaff'))
            else
              for (final s in staff)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ctx.readOnly ? null : () => _editStaff(s),
                  child: Opacity(
                    opacity: s['active'] == false ? .5 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: c.active,
                            child: Icon(LucideIcons.userRound, size: 18, color: c.brandInk),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${ctx.t.or('gh.staffRoles.${s['role']}', str(s['role']))}${str(s['phone']).isNotEmpty ? ' · ${s['phone']}' : ''}${s['active'] == false ? ' · ${ctx.g('off')}' : ''}',
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 16, color: c.muted),
                        ],
                      ),
                    ),
                  ),
                ),
          ]),
          mGap,
          _panel([
            MHead(ctx.g('payQrTitle'), icon: LucideIcons.qrCode, sub: ctx.g('payQrSub')),
            _Pic(
              ctx: ctx,
              url: qr,
              busy: _qrBusy,
              icon: LucideIcons.qrCode,
              pickLabel: qr.isNotEmpty ? ctx.g('changeQr') : ctx.g('uploadQr'),
              onPick: () => _upload('pay-qr', (v) => _qrBusy = v),
              onRemove: () async {
                if (await ctx.run(() => ctx.api.delete('${ctx.base}/pay-qr'), ctx.g('saved')) != null) ctx.reload();
              },
            ),
            gap14,
            Focus(
              onFocusChange: (on) {
                if (on || _qrLabel.text == str(ctx.settings['pay_qr_label'])) return;
                ctx.run(() => ctx.api.put('${ctx.base}/settings', {'pay_qr_label': _qrLabel.text}), ctx.g('saved')).then((_) => ctx.reload());
              },
              child: Field(label: ctx.g('qrLabel'), hint: ctx.g('qrLabelPh'), controller: _qrLabel, maxLength: 60, enabled: !ctx.readOnly),
            ),
            gap14,
            Text(ctx.g('dispImgTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Muted(ctx.g('dispImgSub')),
            const SizedBox(height: 8),
            _Pic(
              ctx: ctx,
              url: dispImg,
              busy: _imgBusy,
              wide: true,
              pickLabel: ctx.g('upload'),
              onPick: () => _upload('display-image', (v) => _imgBusy = v),
              onRemove: () async {
                if (await ctx.run(() => ctx.api.delete('${ctx.base}/display-image'), ctx.g('saved')) != null) ctx.reload();
              },
            ),
            gap14,
            if (dispOn)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.goodBg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(LucideIcons.monitorUp, size: 17, color: c.good),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ctx.g('displayOn'))),
                  ],
                ),
              )
            else
              LockNote(
                text: ctx.g('addonInfo.gh_display.what'),
                button: ctx.g('unlock', {'coins': fmt(n(ctx.addon('gh_display')['price']))}),
                onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_display'),
              ),
          ]),
          mGap,
          _panel([
            MHead(ctx.g('looksTitle'), icon: LucideIcons.palette, sub: ctx.g('looksSub', {'price': fmt(lookPrice)})),
            LayoutBuilder(
              builder: (_, box) {
                final cols = box.maxWidth > 560 ? 2 : 1;
                final w = (box.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final k in ghLooks.keys)
                      SizedBox(
                        width: w,
                        child: MLookCard(
                          picture: GhDisplayThumb(look: k, name: str(ctx.business['name']), logo: str(ctx.business['logo_url']), image: image, lang: ctx.lang),
                          name: ghLookName(k, ctx.lang),
                          on: current == k,
                          locked: !owned.contains(k) && current != k,
                          status: current == k ? ctx.g('inUse') : (k == 'classic' ? ctx.g('free') : (owned.contains(k) ? ctx.g('owned') : '${fmt(lookPrice)} ${ctx.g('coins')}')),
                          onTap: () => openLookSheet(
                            context,
                            title: ctx.g('looksTitle'),
                            keys: ghLooks.keys.toList(),
                            start: k,
                            current: current,
                            owned: (x) => owned.contains(x) || x == current,
                            name: (x) => ghLookName(x, ctx.lang),
                            big: (x) => SizedBox(
                              width: 420,
                              child: GhDisplayThumb(look: x, name: str(ctx.business['name']), logo: str(ctx.business['logo_url']), image: image, lang: ctx.lang),
                            ),
                            status: (x) => current == x ? ctx.g('inUse') : (x == 'classic' ? ctx.g('free') : (owned.contains(x) ? ctx.g('owned') : '${fmt(lookPrice)} ${ctx.g('coins')}')),
                            useLabel: ctx.g('useLook'),
                            buyLabel: (_) => ctx.g('unlock', {'coins': '${fmt(lookPrice)} ${ctx.g('coins')}'}),
                            readOnly: ctx.readOnly || _lookBusy.isNotEmpty,
                            use: (x) async {
                              await _useLook(x);
                              return true;
                            },
                            buy: (x) => ctx.askBuy('gh_display_theme', item: x, onDone: _loadLooks),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _StaffEditor extends StatefulWidget {
  final GhCtx ctx;
  final Json row;
  const _StaffEditor({required this.ctx, required this.row});
  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> with GhSave {
  late final bool isNew = widget.row['_id'] == null;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _phone = TextEditingController(text: str(widget.row['phone']));
  final _pin = TextEditingController();
  late String _role = str(widget.row['role']).isEmpty ? 'desk' : str(widget.row['role']);
  late bool _active = widget.row['active'] != false;
  GhCtx get ctx => widget.ctx;
  @override
  GhCtx get gctx => ctx;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _pinOk => isNew ? RegExp(r'^\d{4}$').hasMatch(_pin.text) : (_pin.text.isEmpty || RegExp(r'^\d{4}$').hasMatch(_pin.text));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = {'name': _name.text.trim(), 'role': _role, 'phone': _phone.text.trim(), 'active': _active, if (_pin.text.isNotEmpty) 'pin': _pin.text};
    final roles = ['desk', 'manager', if (ctx.addonOn('gh_housekeeping') || _role == 'housekeeper') 'housekeeper'];
    final path = '${ctx.base}/staff';
    return MSheet(
      title: isNew ? ctx.g('addStaff') : ctx.g('editStaff'),
      footer: footer(
        canSave: _name.text.trim().isNotEmpty && _pinOk,
        onSave: () => save(() => isNew ? ctx.api.post(path, body) : ctx.api.put('$path/${widget.row['_id']}', body), reload: false),
        onRemove: isNew ? null : () => save(() => ctx.api.delete('$path/${widget.row['_id']}'), reload: false),
      ),
      children: [
        Field(label: ctx.g('staffName'), controller: _name, maxLength: 60, autofocus: isNew, onChanged: (_) => setState(() {})),
        gap14,
        Field(label: ctx.g('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone),
        gap14,
        Label(ctx.g('staffRole')),
        Segmented<String>(value: _role, options: [for (final k in roles) (k, ctx.g('staffRoles.$k'))], onChanged: (v) => setState(() => _role = v)),
        const SizedBox(height: 4),
        Text(ctx.g('staffRoleHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
        gap14,
        Field(
          label: isNew ? ctx.g('pin') : ctx.g('newPin'),
          controller: _pin,
          hint: '••••',
          maxLength: 4,
          keyboard: TextInputType.number,
          onChanged: (v) {
            final d = v.replaceAll(RegExp(r'\D'), '');
            if (d != v) _pin.text = d;
            setState(() {});
          },
        ),
        gap14,
        SwitchRow(title: ctx.g('staffActive'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (error.isNotEmpty) ...[gap14, Alert(error)],
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------------ PRINT
class PrintTab extends StatefulWidget {
  final GhCtx ctx;
  const PrintTab({super.key, required this.ctx});
  @override
  State<PrintTab> createState() => _PrintTabState();
}

class _PrintTabState extends State<PrintTab> {
  Json? _info;
  bool _busy = false;
  GhCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PrintTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data)) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/print');
      if (mounted) setState(() => _info = obj(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _save(Json body) async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.put('${ctx.base}/print', body);
      setState(() => _info = obj(r['data']));
      ctx.notify(ctx.g('saved'));
      ctx.reload();
    } on ApiError catch (e) {
      if (e.status == 402) {
        ctx.askBuy('gh_print_theme', item: body['theme'] == null ? null : str(body['theme']), onDone: _load);
      } else {
        ctx.fail(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (info == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 5));
    final on = info['on'] == true;
    final size = str(info['size']).isEmpty ? '80' : str(info['size']);
    final owned = (info['owned'] as List? ?? const []).map((e) => '$e').toSet();
    final current = str(info['current']);
    String status(String k) => current == k ? ctx.g('inUse') : (k == 'classic' ? ctx.g('free') : (owned.contains(k) ? ctx.g('owned') : '${fmt(n(info['price']))} ${ctx.g('coins')}'));
    final sample = ghSampleStay(ctx.lang);
    final paperW = size == 'a4' ? 520.0 : (size == '58' ? 220.0 : 300.0);
    Widget receipt(String k) => GhReceipt(stay: sample, data: ctx.data, lang: ctx.lang, theme: k, size: size, qr: info['qr'] == true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _panel([
          MHead(ctx.g('printTitle'), icon: LucideIcons.printer, sub: on ? ctx.g('printOn') : ctx.g('printOff')),
          if (!on)
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn('${ctx.g('unlock', {'coins': fmt(n(info['addon_price']))})} · ${ctx.g('forever')}', onTap: ctx.readOnly ? null : () => ctx.askBuy('gh_printer', onDone: _load)),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(ctx.g('testPrint'), icon: LucideIcons.printer, kind: BtnKind.ghost, small: true, onTap: () => showGhBill(context, ctx, sample)),
            ),
            const SizedBox(height: 6),
            Muted(ctx.t('app.printShare')),
          ],
        ]),
        mGap,
        _panel([
          Label(ctx.g('paper')),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Segmented<String>(
              value: size,
              options: [
                for (final k in ['80', '58', 'a4']) (k, ctx.g('papers.$k')),
              ],
              onChanged: ctx.readOnly || _busy ? null : (v) => _save({'size': v}),
            ),
          ),
          const SizedBox(height: 8),
          SwitchRow(title: ctx.g('printAuto'), value: info['auto'] == true, onChanged: ctx.readOnly || _busy ? null : (v) => _save({'auto': v})),
          SwitchRow(title: ctx.g('printQr'), value: info['qr'] == true, onChanged: ctx.readOnly || _busy ? null : (v) => _save({'qr': v})),
        ]),
        mGap,
        _panel([
          MHead(ctx.g('templatesTitle'), icon: LucideIcons.layoutTemplate, sub: ctx.g('templatesSub', {'price': fmt(n(info['price']))})),
          LayoutBuilder(
            builder: (_, box) {
              final cols = box.maxWidth > 520 ? 3 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in ghPrintThemes)
                    SizedBox(
                      width: w,
                      child: MLookCard(
                        picture: Container(
                          height: 230,
                          color: c.bg2,
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                child: SizedBox(width: paperW, child: receipt(t.key)),
                              ),
                            ),
                          ),
                        ),
                        name: t.name(ctx.lang),
                        on: current == t.key,
                        locked: !owned.contains(t.key),
                        status: status(t.key),
                        onTap: () => openLookSheet(
                          context,
                          title: ctx.g('templatesTitle'),
                          keys: [for (final x in ghPrintThemes) x.key],
                          start: t.key,
                          current: current,
                          owned: owned.contains,
                          name: (x) => ghPrintThemeOf(x).name(ctx.lang),
                          sub: (x) => ghPrintThemeOf(x).sub(ctx.lang),
                          big: (x) => Container(width: paperW, padding: const EdgeInsets.all(10), color: Colors.white, child: receipt(x)),
                          status: status,
                          useLabel: ctx.g('useLook'),
                          buyLabel: (_) => ctx.g('unlock', {'coins': '${fmt(n(info['price']))} ${ctx.g('coins')}'}),
                          readOnly: ctx.readOnly || _busy,
                          use: (x) async {
                            await _save({'theme': x});
                            return true;
                          },
                          buy: (x) => ctx.askBuy('gh_print_theme', item: x, onDone: _load),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ]),
      ],
    );
  }
}
