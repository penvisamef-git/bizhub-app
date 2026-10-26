import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SelectField, SwitchRow, showEditor, gap14;
import 'mart_common.dart';

// POS devices + Settings — the app version of MartSetup.jsx, MartPayMethods.jsx, MartPosLooks.jsx and MartScale.jsx.

Widget _panel(List<Widget> children) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Future<Json?> _run(MartCtx ctx, Future<Json> Function() fn, [String? ok]) async {
  try {
    final r = await fn();
    if (ok != null) ctx.notify(ok);
    return r;
  } catch (e) {
    ctx.fail(e);
    return null;
  }
}

// ------------------------------------------------------------------------------------------------ POS
class PosTab extends StatefulWidget {
  final MartCtx ctx;
  const PosTab({super.key, required this.ctx});
  @override
  State<PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<PosTab> {
  List<Json>? _staff, _devices;
  Json? _code;
  bool _busy = false, _qrBusy = false;
  late final _qrLabel = TextEditingController(text: str(ctx.settings['pay_qr_label']));
  Timer? _tick;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
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
  }

  Future<void> _pair() async {
    setState(() => _busy = true);
    final r = await _run(ctx, () => ctx.api.post('${ctx.base}/pos/pair-code'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) _code = obj(r['data']);
    });
    // a new device shows up here while the code is open
    _tick?.cancel();
    if (r != null) {
      _tick = Timer.periodic(const Duration(seconds: 5), (t) async {
        final left = DateTime.tryParse(str(_code?['expires']))?.difference(DateTime.now()) ?? Duration.zero;
        if (!mounted || left.isNegative) {
          t.cancel();
          if (mounted) setState(() => _code = null);
          return;
        }
        final before = _devices?.length ?? 0;
        await _load();
        if ((_devices?.length ?? 0) > before && mounted) setState(() => _code = null);
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _editStaff(Json row) async {
    final ok = await showEditor<bool>(
      context,
      builder: (_) => _StaffEditor(ctx: ctx, row: row),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final staff = _staff;
    final full = staff != null && staff.length >= n(ctx.limits['staff']);
    final sub = ctx.m('posSub').split('{link}');
    final code = str(_code?['code']);
    final left = DateTime.tryParse(str(_code?['expires']))?.difference(DateTime.now());
    final qr = str(obj(ctx.settings['pay_qr'])['url']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _panel([
            MHead(ctx.m('posTitle'), icon: LucideIcons.monitorSmartphone),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: sub.first),
                  const TextSpan(
                    text: '/pos/mini-mart',
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
                Btn(ctx.m('linkDevice'), icon: LucideIcons.link2, small: true, busy: _busy, onTap: ctx.readOnly || _busy ? null : _pair),
                Btn(
                  ctx.m('openPos'),
                  icon: LucideIcons.externalLink,
                  kind: BtnKind.ghost,
                  small: true,
                  onTap: () => launchUrl(Uri.parse('${Config.siteUrl}/pos/mini-mart'), mode: LaunchMode.externalApplication),
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
                      ctx.m('pairCode'),
                      style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      code.replaceAllMapped(RegExp(r'^(\d{3})(\d{3})$'), (x) => '${x[1]} ${x[2]}'),
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 4, color: c.brandInk),
                    ),
                    const SizedBox(height: 4),
                    Muted('${ctx.m('pairExpires')}${left != null && !left.isNegative ? '  ·  ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}' : ''}', align: TextAlign.center),
                  ],
                ),
              ),
            ],
            gap14,
            Text(ctx.m('devices'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (_devices == null)
              const SkelList(rows: 2)
            else if (_devices!.isEmpty)
              Muted(ctx.m('noDevices'))
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
                            Text(ctx.m('lastSeen', {'time': mDayTime(d['last_seen'] ?? d['created_date'], ctx.lang)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (!ctx.readOnly)
                        SureDelete(
                          remove: ctx.m('removeDevice'),
                          sure: ctx.m('sure'),
                          onDelete: () async {
                            if (await _run(ctx, () => ctx.api.delete('${ctx.base}/pos/devices/${d['_id']}')) != null) _load();
                          },
                        ),
                    ],
                  ),
                ),
          ]),
          mGap,
          _panel([
            MHead(
              ctx.m('staffTitle'),
              icon: LucideIcons.users,
              sub: ctx.addonOn('mart_staff') ? '${staff?.length ?? 0} · ${ctx.m('addonInfo.mart_staff.name')}' : ctx.m('staffSub', {'n': staff?.length ?? 0, 'max': n(ctx.limits['staff'])}),
              trailing: Btn(
                ctx.m('addStaff'),
                icon: full ? LucideIcons.lock : LucideIcons.plus,
                small: true,
                onTap: ctx.readOnly || staff == null ? null : () => full ? ctx.askBuy('mart_staff') : _editStaff({}),
              ),
            ),
            if (staff == null)
              const SkelList(rows: 2)
            else if (staff.isEmpty)
              Muted(ctx.m('noStaff'))
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
                                Text('${ctx.m('staffRoles.${s['role']}')}${str(s['phone']).isNotEmpty ? ' · ${s['phone']}' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
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
            MHead(ctx.m('payQrTitle'), icon: LucideIcons.qrCode, sub: ctx.m('payQrSub')),
            Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: qr.isNotEmpty ? Image(image: netImage(qr), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()) : Icon(LucideIcons.qrCode, size: 30, color: c.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QrPick(
                        ctx: ctx,
                        label: _qrBusy ? ctx.m('uploading') : (qr.isNotEmpty ? ctx.m('changeQr') : ctx.m('uploadQr')),
                        busy: _qrBusy,
                        onPick: (b, name) async {
                          setState(() => _qrBusy = true);
                          if (await _run(ctx, () => ctx.api.post('${ctx.base}/pay-qr', fileForm('file', b, name)), ctx.m('saved')) != null) await ctx.reload();
                          if (mounted) setState(() => _qrBusy = false);
                        },
                      ),
                      if (qr.isNotEmpty && !_qrBusy)
                        Btn(
                          ctx.m('remove'),
                          icon: LucideIcons.trash2,
                          kind: BtnKind.ghost,
                          small: true,
                          onTap: ctx.readOnly
                              ? null
                              : () async {
                                  if (await _run(ctx, () => ctx.api.delete('${ctx.base}/pay-qr'), ctx.m('saved')) != null) ctx.reload();
                                },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            gap14,
            Focus(
              onFocusChange: (on) {
                if (on || _qrLabel.text == str(ctx.settings['pay_qr_label'])) return;
                _run(ctx, () => ctx.api.put('${ctx.base}/settings', {'pay_qr_label': _qrLabel.text}), ctx.m('saved')).then((_) => ctx.reload());
              },
              child: Field(label: ctx.m('qrLabel'), hint: ctx.m('qrLabelPh'), controller: _qrLabel, maxLength: 60, enabled: !ctx.readOnly),
            ),
          ]),
          mGap,
          PosLooks(ctx: ctx),
          mGap,
          DisplayCard(ctx: ctx),
        ],
      ),
    );
  }
}

// a button that picks a picture (gallery / camera)
class _QrPick extends StatelessWidget {
  final MartCtx ctx;
  final String label;
  final bool busy;
  final Future<void> Function(List<int> bytes, String name) onPick;
  const _QrPick({required this.ctx, required this.label, required this.busy, required this.onPick});
  @override
  Widget build(BuildContext context) => Btn(
    label,
    icon: LucideIcons.imagePlus,
    kind: BtnKind.ghost,
    small: true,
    busy: busy,
    onTap: busy || ctx.readOnly
        ? null
        : () async {
            final b = await pickPicture(context, ctx, maxSize: 900);
            if (b != null) await onPick(b, 'qr.jpg');
          },
  );
}

class _StaffEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _StaffEditor({required this.ctx, required this.row});
  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> {
  late final bool isNew = widget.row['_id'] == null;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _phone = TextEditingController(text: str(widget.row['phone']));
  final _pin = TextEditingController();
  late String _role = str(widget.row['role']).isEmpty ? 'cashier' : str(widget.row['role']);
  late bool _active = widget.row['active'] != false;
  bool _busy = false;
  String _error = '';
  MartCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _pinOk => isNew ? RegExp(r'^\d{4}$').hasMatch(_pin.text) : (_pin.text.isEmpty || RegExp(r'^\d{4}$').hasMatch(_pin.text));

  Future<void> _go(Future<Json> Function() fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn();
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
    final body = {'name': _name.text.trim(), 'role': _role, 'phone': _phone.text.trim(), 'active': _active, if (_pin.text.isNotEmpty) 'pin': _pin.text};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(isNew ? ctx.m('addStaff') : ctx.m('editStaff'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Field(label: ctx.m('staffName'), controller: _name, maxLength: 60, autofocus: isNew, onChanged: (_) => setState(() {})),
                  gap14,
                  Field(label: ctx.m('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone),
                  gap14,
                  Text(ctx.m('staffRole'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Segmented<String>(
                    value: _role,
                    options: [
                      for (final k in ['cashier', 'manager']) (k, ctx.m('staffRoles.$k')),
                    ],
                    onChanged: (v) => setState(() => _role = v),
                  ),
                  const SizedBox(height: 4),
                  Text(ctx.m('staffRoleHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  gap14,
                  Field(
                    label: isNew ? ctx.m('pin') : ctx.m('newPin'),
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
                  SwitchRow(title: ctx.m('staffActive'), value: _active, onChanged: (v) => setState(() => _active = v)),
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
                if (!isNew) SureDelete(remove: ctx.m('remove'), sure: ctx.m('sure'), onDelete: _busy ? null : () => _go(() => ctx.api.delete('${ctx.base}/staff/${widget.row['_id']}'))),
                const Spacer(),
                Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn(
                  _busy ? ctx.m('saving') : ctx.m('save'),
                  small: true,
                  busy: _busy,
                  onTap: _busy || _name.text.trim().isEmpty || !_pinOk
                      ? null
                      : () => _go(() => isNew ? ctx.api.post('${ctx.base}/staff', body) : ctx.api.put('${ctx.base}/staff/${widget.row['_id']}', body)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- POS looks
// the 24 looks (pos/mart/posThemes.js): accent, second colour, page tint, top bar, product cards, corner radius
class PosLook {
  final String en, km, head, card;
  final Color a, a2, bg;
  final double r;
  const PosLook(this.en, this.km, this.a, this.a2, this.bg, this.head, this.card, this.r);
}

const posLookKeys = [
  'classic',
  'ocean',
  'sunset',
  'forest',
  'berry',
  'midnight',
  'royal',
  'coral',
  'mint',
  'amber',
  'slate',
  'rose',
  'lime',
  'sky',
  'cocoa',
  'ink',
  'neon',
  'lotus',
  'angkor',
  'candy',
  'sand',
  'ruby',
  'jade',
  'paper',
];
const martPosLooks = <String, PosLook>{
  'classic': PosLook('Classic', 'បុរាណ', Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFFF1F4F9), 'light', 'tile', 14),
  'ocean': PosLook('Ocean', 'សមុទ្រ', Color(0xFF0369A1), Color(0xFF0EA5E9), Color(0xFFEEF6FB), 'accent', 'tile', 16),
  'sunset': PosLook('Sunset', 'ថ្ងៃលិច', Color(0xFFEA580C), Color(0xFFF43F5E), Color(0xFFFFF4EC), 'accent', 'photo', 18),
  'forest': PosLook('Forest', 'ព្រៃឈើ', Color(0xFF166534), Color(0xFF65A30D), Color(0xFFF1F5EF), 'dark', 'list', 10),
  'berry': PosLook('Berry', 'ផ្លែបឺរី', Color(0xFFBE185D), Color(0xFF7C3AED), Color(0xFFFDF2F8), 'accent', 'round', 20),
  'midnight': PosLook('Midnight', 'ពាក់កណ្តាលអធ្រាត្រ', Color(0xFF4F46E5), Color(0xFF22D3EE), Color(0xFFEEF0FB), 'dark', 'tile', 14),
  'royal': PosLook('Royal', 'រាជវង្ស', Color(0xFF4338CA), Color(0xFFA855F7), Color(0xFFF3F2FF), 'accent', 'compact', 12),
  'coral': PosLook('Coral', 'ផ្កាថ្ម', Color(0xFFE11D48), Color(0xFFFB923C), Color(0xFFFFF5F3), 'light', 'round', 22),
  'mint': PosLook('Mint', 'ជីអង្កាម', Color(0xFF0D9488), Color(0xFF34D399), Color(0xFFEFFCF8), 'light', 'photo', 16),
  'amber': PosLook('Amber', 'អាំប័រ', Color(0xFFD97706), Color(0xFFDC2626), Color(0xFFFFFBEB), 'accent', 'bold', 12),
  'slate': PosLook('Slate', 'ថ្មខៀវ', Color(0xFF334155), Color(0xFF0EA5E9), Color(0xFFF1F5F9), 'dark', 'compact', 8),
  'rose': PosLook('Rose', 'កុលាប', Color(0xFFE11D48), Color(0xFFF472B6), Color(0xFFFFF1F2), 'light', 'tile', 18),
  'lime': PosLook('Lime', 'ក្រូចឆ្មារ', Color(0xFF4D7C0F), Color(0xFF84CC16), Color(0xFFF7FEE7), 'accent', 'list', 12),
  'sky': PosLook('Sky', 'មេឃ', Color(0xFF2563EB), Color(0xFF38BDF8), Color(0xFFF0F7FF), 'light', 'photo', 20),
  'cocoa': PosLook('Cocoa', 'កាកាវ', Color(0xFF6F4E37), Color(0xFFC08552), Color(0xFFF6F0EA), 'dark', 'list', 10),
  'ink': PosLook('Ink', 'ទឹកខ្មៅ', Color(0xFF18181B), Color(0xFF52525B), Color(0xFFF4F4F5), 'dark', 'bold', 4),
  'neon': PosLook('Neon', 'នីអុង', Color(0xFF65A30D), Color(0xFFC026D3), Color(0xFFF5F5F4), 'dark', 'tile', 10),
  'lotus': PosLook('Lotus', 'ផ្កាឈូក', Color(0xFFDB2777), Color(0xFF16A34A), Color(0xFFFDF4F8), 'light', 'round', 18),
  'angkor': PosLook('Angkor', 'អង្គរ', Color(0xFFB45309), Color(0xFF7C2D12), Color(0xFFFBF5EA), 'accent', 'list', 6),
  'candy': PosLook('Candy', 'ស្ករគ្រាប់', Color(0xFFDB2777), Color(0xFF06B6D4), Color(0xFFFFF0F6), 'accent', 'round', 24),
  'sand': PosLook('Sand', 'ខ្សាច់', Color(0xFFA16207), Color(0xFFD97706), Color(0xFFFAF6EF), 'light', 'compact', 8),
  'ruby': PosLook('Ruby', 'ត្បូងទទឹម', Color(0xFFB91C1C), Color(0xFFEA580C), Color(0xFFFFF1F1), 'dark', 'bold', 12),
  'jade': PosLook('Jade', 'ត្បូងខៀវ', Color(0xFF059669), Color(0xFF0D9488), Color(0xFFF0FDF4), 'accent', 'photo', 14),
  'paper': PosLook('Paper', 'ក្រដាស', Color(0xFF1F2937), Color(0xFF6B7280), Color(0xFFF7F4EC), 'light', 'list', 2),
};
String posLookName(String k, String lang) => lang == 'km' ? (martPosLooks[k]?.km ?? k) : (martPosLooks[k]?.en ?? k);
const _presets = ['#0F766E', '#0369A1', '#2563EB', '#4F46E5', '#7C3AED', '#BE185D', '#E11D48', '#DC2626', '#EA580C', '#D97706', '#65A30D', '#16A34A', '#334155', '#18181B'];
const _sample = [('Coca', Color(0xFFDC2626)), ('Bread', Color(0xFFB45309)), ('Water', Color(0xFF2563EB)), ('Chips', Color(0xFFCA8A04)), ('Eggs', Color(0xFF64748B)), ('Oil', Color(0xFF16A34A))];

// a small picture of the POS in one look: top bar, product cards, the cart
class MartPosThumb extends StatelessWidget {
  final String look, name;
  final String color;
  const MartPosThumb({super.key, required this.look, required this.name, this.color = ''});
  @override
  Widget build(BuildContext context) {
    final d = martPosLooks[look] ?? martPosLooks['classic']!;
    final a = color.isNotEmpty ? hexToColor(color) : d.a;
    final a2 = color.isNotEmpty ? Color.lerp(a, Colors.white, .38)! : d.a2;
    final bg = color.isNotEmpty ? Color.lerp(const Color(0xFFF4F6F9), a, .06)! : d.bg;
    final r = (d.r < 18 ? d.r : 18) * .45;
    final topBg = switch (d.head) {
      'accent' => a,
      'dark' => const Color(0xFF1F2430),
      _ => Colors.white,
    };
    final topFg = d.head == 'light' ? const Color(0xFF1F2430) : Colors.white;
    Widget card((String, Color) p) {
      final (label, col) = p;
      final dot = Container(
        decoration: BoxDecoration(color: col, shape: d.card == 'round' ? BoxShape.circle : BoxShape.rectangle, borderRadius: d.card == 'round' ? null : BorderRadius.circular(r * .7)),
        alignment: Alignment.center,
        child: Text(
          label.substring(0, 2),
          style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w800),
        ),
      );
      final price = Text(
        '\$1.25',
        style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: d.card == 'bold' ? Colors.white : a),
      );
      final title = Text(
        label,
        maxLines: 1,
        style: TextStyle(fontSize: 6, fontWeight: FontWeight.w700, color: d.card == 'bold' || d.card == 'photo' ? Colors.white : const Color(0xFF1F2430)),
      );
      return Container(
        decoration: BoxDecoration(
          color: d.card == 'bold' ? a : Colors.white,
          gradient: d.card == 'photo' ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.white, .35)!, col]) : null,
          borderRadius: BorderRadius.circular(r),
        ),
        padding: const EdgeInsets.all(3),
        child: switch (d.card) {
          'list' || 'compact' => Row(
            children: [
              SizedBox(width: 12, height: 12, child: dot),
              const SizedBox(width: 3),
              Expanded(child: title),
              price,
            ],
          ),
          'photo' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              title,
              Text(
                '\$1.25',
                style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: .9)),
              ),
            ],
          ),
          _ => Column(
            children: [
              Expanded(
                child: Center(child: AspectRatio(aspectRatio: 1, child: dot)),
              ),
              title,
              price,
            ],
          ),
        },
      );
    }

    final listy = d.card == 'list' || d.card == 'compact';
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        color: bg,
        child: Column(
          children: [
            Container(
              height: 16,
              color: topBg,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: topFg),
                    ),
                  ),
                  for (final on in [false, true, false])
                    Container(
                      width: 9,
                      height: 4,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(color: on ? (d.head == 'light' ? a : Colors.white) : topFg.withValues(alpha: .25), borderRadius: BorderRadius.circular(2)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: listy
                          ? Column(
                              children: [
                                for (final p in _sample.take(d.card == 'compact' ? 6 : 5))
                                  Expanded(
                                    child: Padding(padding: const EdgeInsets.only(bottom: 2), child: card(p)),
                                  ),
                              ],
                            )
                          : Column(
                              children: [
                                for (final row in [_sample.sublist(0, 3), _sample.sublist(3)])
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (final p in row)
                                          Expanded(
                                            child: Padding(padding: const EdgeInsets.all(1.5), child: card(p)),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            for (final w in [.9, .7, .8])
                              Container(
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 4),
                                child: FractionallySizedBox(
                                  widthFactor: w,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Container(
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [a, a2]),
                                borderRadius: BorderRadius.circular(r * .8),
                              ),
                              child: const Text(
                                '\$4.10',
                                style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosLooks extends StatefulWidget {
  final MartCtx ctx;
  const PosLooks({super.key, required this.ctx});
  @override
  State<PosLooks> createState() => _PosLooksState();
}

class _PosLooksState extends State<PosLooks> {
  Json? _info;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _run(ctx, () => ctx.api.get('${ctx.base}/pos-themes'));
    if (r != null && mounted) setState(() => _info = obj(r['data']));
  }

  Future<void> _put(Map<String, Object?> body) async {
    final r = await _run(ctx, () => ctx.api.put('${ctx.base}/pos-theme', body), ctx.w('posLookSaved'));
    if (r != null && mounted) setState(() => _info = obj(r['data']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (info == null) return const SkelList(rows: 3);
    final owned = (info['owned'] as List? ?? const []).map((e) => '$e').toSet();
    final current = str(info['current']).isEmpty ? 'classic' : str(info['current']);
    final color = str(info['color']);
    final lookA = colorToHex((martPosLooks[current] ?? martPosLooks['classic']!).a);
    String status(String k) => current == k ? ctx.w('inUse') : (k == 'classic' ? ctx.w('free') : (owned.contains(k) ? ctx.m('yours') : '${n(info['price'])} ${ctx.m('coins')}'));
    void open(String k) => openLookSheet(
      context,
      title: ctx.w('posLooks'),
      keys: posLookKeys,
      start: k,
      current: current,
      owned: owned.contains,
      name: (x) => posLookName(x, ctx.lang),
      big: (x) => SizedBox(
        width: 380,
        child: MartPosThumb(look: x, name: str(ctx.business['name']), color: current == x ? color : ''),
      ),
      status: status,
      useLabel: ctx.w('use'),
      buyLabel: (_) => ctx.m('unlock', {'coins': '${fmt(n(info['price']))} ${ctx.m('coins')}'}),
      readOnly: ctx.readOnly,
      use: (x) async {
        await _put({'theme': x});
        return true;
      },
      buy: (x) => ctx.askBuy('mart_pos_theme', item: x, onDone: _load),
    );
    return _panel([
      MHead(ctx.w('posLooks'), icon: LucideIcons.palette, sub: ctx.w('posLooksSub', {'price': n(info['price'])})),
      Text(ctx.w('posColor'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: ctx.readOnly || color.isEmpty ? null : () => _put({'color': ''}),
            child: Tooltip(
              message: ctx.w('colorLook'),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hexToColor(lookA),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.isEmpty ? c.ink : Colors.transparent, width: 2),
                ),
                child: color.isEmpty ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Muted(ctx.w('colorLookShort')),
        ],
      ),
      const SizedBox(height: 10),
      ColorRow(value: color, colors: _presets, customLabel: ctx.w('colorCustom'), saveLabel: ctx.m('save'), cancelLabel: ctx.m('cancel'), onChanged: ctx.readOnly ? null : (v) => _put({'color': v})),
      gap14,
      LayoutBuilder(
        builder: (_, box) {
          final cols = box.maxWidth > 520 ? 3 : 2;
          final w = (box.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in posLookKeys)
                SizedBox(
                  width: w,
                  child: MLookCard(
                    picture: MartPosThumb(look: k, name: str(ctx.business['name']), color: current == k ? color : ''),
                    name: posLookName(k, ctx.lang),
                    on: current == k,
                    locked: !owned.contains(k),
                    status: status(k),
                    onTap: () => open(k),
                  ),
                ),
            ],
          );
        },
      ),
    ]);
  }
}

// Customer screen (mart_display): how to open it on the POS
class DisplayCard extends StatelessWidget {
  final MartCtx ctx;
  const DisplayCard({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ctx.addonOn('mart_display');
    return _panel([
      MHead(
        ctx.x('dsTitle'),
        icon: LucideIcons.monitor,
        sub: on ? ctx.x('dsHow') : ctx.x('dsSub'),
        trailing: on ? Chip2(ctx.x('activeForever'), icon: LucideIcons.check, tone: Tone.good) : null,
      ),
      if (!on) ...[
        for (final p in ctx.t.list('mx.dsPerks'))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.check, size: 15, color: c.good),
                const SizedBox(width: 8),
                Expanded(child: Text(p)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: GoldBtn(ctx.x('unlockOnce', {'coins': n(ctx.addon('mart_display')['price'] ?? 40)}), onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_display')),
        ),
      ],
    ]);
  }
}

// ------------------------------------------------------------------------------------------- Settings
const _free = ['cash', 'aba', 'khqr'];
const _pmColors = ['#0D9488', '#2563EB', '#7C3AED', '#DB2777', '#DC2626', '#EA580C', '#CA8A04', '#16A34A', '#0891B2', '#475569'];

class SettingsTab extends StatefulWidget {
  final MartCtx ctx;
  const SettingsTab({super.key, required this.ctx});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final _name = TextEditingController(), _phone = TextEditingController(), _addr = TextEditingController(), _rate = TextEditingController(), _note = TextEditingController();
  String _cur = 'USD';
  int _round = 100;
  List<String> _methods = [];
  late Json _start;
  bool _busy = false, _logoBusy = false;
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(SettingsTab old) {
    super.didUpdateWidget(old);
    // the shop's own payment methods changed (saved at once): keep the ticks the owner made here
    if (!identical(old.ctx.data, widget.ctx.data) && !_dirty) _reset();
  }

  @override
  void dispose() {
    for (final x in [_name, _phone, _addr, _rate, _note]) {
      x.dispose();
    }
    super.dispose();
  }

  Json get _now => {
    'name': _name.text,
    'phone': _phone.text,
    'address': _addr.text,
    'currency': _cur,
    'khr_rate': _rate.text,
    'khr_round': _round,
    'methods': _methods.join(','),
    'receipt_note': _note.text,
  };
  bool get _dirty => _now.entries.any((e) => '${e.value}' != '${_start[e.key]}');

  void _reset() {
    final s = ctx.settings, b = ctx.business;
    _name.text = str(b['name']);
    _phone.text = str(b['phone']);
    _addr.text = str(b['address']);
    _cur = ctx.cur;
    _rate.text = str(s['khr_rate']).isEmpty ? '4100' : '${s['khr_rate']}';
    _round = n(s['khr_round']) == 0 ? 100 : n(s['khr_round']).toInt();
    _methods = (s['methods'] as List? ?? const ['cash']).map((e) => '$e').toList();
    _note.text = str(s['receipt_note']);
    _start = _now;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok =
        await _run(ctx, () => ctx.api.put('${ctx.base}/profile', {'name': _name.text.trim(), 'phone': _phone.text.trim(), 'address': _addr.text.trim()})) != null &&
        await _run(
              ctx,
              () => ctx.api.put('${ctx.base}/settings', {'currency': _cur, 'khr_rate': num.tryParse(_rate.text) ?? 4100, 'khr_round': _round, 'methods': _methods, 'receipt_note': _note.text}),
              ctx.m('saved'),
            ) !=
            null;
    if (ok) await ctx.reload();
    if (mounted) {
      setState(() {
        _busy = false;
        if (ok) _start = _now;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final logo = str(ctx.business['logo_url']);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _panel([
                MHead(ctx.m('shop'), icon: LucideIcons.store),
                Text(ctx.m('logo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                MImagePick(
                  ctx: ctx,
                  url: logo,
                  busy: _logoBusy,
                  disabled: ro,
                  onPick: (b, name) async {
                    setState(() => _logoBusy = true);
                    if (await _run(ctx, () => ctx.api.post('${ctx.base}/logo', fileForm('file', b, name)), ctx.m('saved')) != null) await ctx.reload();
                    if (mounted) setState(() => _logoBusy = false);
                  },
                  onRemove: () async {
                    if (await _run(ctx, () => ctx.api.delete('${ctx.base}/logo'), ctx.m('saved')) != null) ctx.reload();
                  },
                ),
                gap14,
                Field(label: ctx.m('shopName'), controller: _name, maxLength: 100, enabled: !ro, onChanged: (_) => setState(() {})),
                gap14,
                Field(label: ctx.m('phone'), controller: _phone, maxLength: 30, keyboard: TextInputType.phone, enabled: !ro, onChanged: (_) => setState(() {})),
                gap14,
                Field(label: ctx.m('address'), controller: _addr, maxLength: 300, enabled: !ro, onChanged: (_) => setState(() {})),
              ]),
              mGap,
              _panel([
                MHead(ctx.m('money'), icon: LucideIcons.banknote),
                Text(ctx.m('currency'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Segmented<String>(value: _cur, options: const [('USD', 'USD (\$)'), ('KHR', 'KHR (៛)')], onChanged: ro ? null : (v) => setState(() => _cur = v)),
                const SizedBox(height: 4),
                Text(ctx.m('currencyHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                gap14,
                Field(label: ctx.m('rate'), controller: _rate, keyboard: TextInputType.number, enabled: !ro, onChanged: (_) => setState(() {})),
                gap14,
                Text(ctx.m('khrRound'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Segmented<int>(
                  value: _round,
                  options: [
                    for (final k in [100, 500, 1000]) (k, riel(k)),
                  ],
                  onChanged: ro ? null : (v) => setState(() => _round = v),
                ),
                gap14,
                Text(ctx.m('payMethods'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _PayMethods(ctx: ctx, methods: _methods, setMethods: (v) => setState(() => _methods = v)),
                gap14,
                Field(label: ctx.m('receiptNote'), hint: ctx.m('receiptNotePh'), controller: _note, maxLength: 300, maxLines: 2, enabled: !ro, onChanged: (_) => setState(() {})),
              ]),
              mGap,
              ScaleCard(ctx: ctx),
            ],
          ),
        ),
        // save bar
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _dirty
              ? Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: c.card,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -4))],
                  ),
                  child: Row(
                    children: [
                      Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy ? null : () => setState(_reset)),
                      const Spacer(),
                      Btn(_busy ? ctx.m('saving') : ctx.m('save'), busy: _busy, onTap: ro || _busy || _name.text.trim().isEmpty ? null : _save),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// Cash, ABA, KHQR are free; with mart_payments the shop makes its own (name, colour, QR picture)
class _PayMethods extends StatelessWidget {
  final MartCtx ctx;
  final List<String> methods;
  final ValueChanged<List<String>> setMethods;
  const _PayMethods({required this.ctx, required this.methods, required this.setMethods});

  void _toggle(String k) {
    if (methods.contains(k)) {
      if (methods.length > 1) setMethods(methods.where((x) => x != k).toList());
    } else {
      setMethods([...methods, k]);
    }
  }

  Future<void> _edit(BuildContext context, Json row) async {
    final r = await showEditor<(Json, String)>(
      context,
      builder: (_) => _MethodEditor(ctx: ctx, row: row),
    );
    if (r == null) return;
    final (res, removed) = r;
    final keys = (obj(res['data'])['methods'] as List? ?? const []).map((e) => '$e').toList();
    final added = str(res['key']);
    setMethods({...methods.where((k) => k != removed && (_free.contains(k) || !k.startsWith('x_') || keys.contains(k))), if (added.isNotEmpty) added}.toList());
    ctx.reload();
  }

  Widget _chip(BuildContext context, String k, Color? color, String sub, {VoidCallback? onEdit}) {
    final c = context.c;
    final on = methods.contains(k);
    final icon = k == 'cash' ? LucideIcons.banknote : ((k == 'aba' || k == 'khqr') ? LucideIcons.qrCode : LucideIcons.wallet);
    return Material(
      color: on ? c.active : c.bg2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: ctx.readOnly || (on && methods.length == 1) ? null : () => _toggle(k),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color ?? c.brand, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.methodName(k), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(sub, style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: ctx.readOnly ? null : onEdit,
                  icon: Icon(LucideIcons.pencil, size: 15, color: c.muted),
                ),
              Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, size: 20, color: on ? c.brand : c.lineStrong),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.settings;
    final unlocked = ctx.addonOn('mart_payments');
    final own = objs(s['custom_methods']);
    final legacy = (s['methods'] as List? ?? const []).map((e) => '$e').where((k) => !_free.contains(k) && !k.startsWith('x_')).toList();
    final label = TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ctx.w('pmFree'), style: label),
        const SizedBox(height: 6),
        for (final k in _free) Padding(padding: const EdgeInsets.only(bottom: 6), child: _chip(context, k, null, k == 'cash' ? ctx.w('pmCashSub') : ctx.w('pmQrSub'))),
        for (final k in legacy) Padding(padding: const EdgeInsets.only(bottom: 6), child: _chip(context, k, const Color(0xFF64748B), ctx.w('pmLegacy'))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(ctx.w('pmOwn'), style: label)),
            if (unlocked && own.length < 20) Btn(ctx.w('pmAdd'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ctx.readOnly ? null : () => _edit(context, {})),
          ],
        ),
        const SizedBox(height: 6),
        if (!unlocked)
          LockNote(
            text: ctx.w('pmLocked'),
            button: '${ctx.m('unlock', {'coins': n(ctx.addon('mart_payments')['price'] ?? 55)})} · ${ctx.m('forever')}',
            onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_payments'),
          )
        else if (own.isEmpty)
          Muted(ctx.w('pmNone'))
        else
          for (final x in own)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _chip(
                context,
                str(x['key']),
                hexToColor(str(x['color']), const Color(0xFF0D9488)),
                str(obj(x['qr'])['url']).isNotEmpty ? ctx.w('pmHasQr') : ctx.w('pmNoQr'),
                onEdit: () => _edit(context, x),
              ),
            ),
      ],
    );
  }
}

class _MethodEditor extends StatefulWidget {
  final MartCtx ctx;
  final Json row;
  const _MethodEditor({required this.ctx, required this.row});
  @override
  State<_MethodEditor> createState() => _MethodEditorState();
}

class _MethodEditorState extends State<_MethodEditor> {
  late final bool isNew = widget.row['key'] == null;
  late final _name = TextEditingController(text: str(widget.row['name']));
  late String _color = str(widget.row['color']).isEmpty ? _pmColors.first : str(widget.row['color']).toUpperCase();
  late String _qr = str(obj(widget.row['qr'])['url']);
  String _busy = '', _error = '';
  Json? _last;
  MartCtx get ctx => widget.ctx;
  String get _key => str(widget.row['key']);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<Json?> _go(String kind, Future<Json> Function() fn) async {
    setState(() {
      _busy = kind;
      _error = '';
    });
    try {
      final r = await fn();
      _last = r;
      return r;
    } on ApiError catch (e) {
      setState(() => _error = e.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopScope(
      canPop: _busy.isEmpty,
      onPopInvokedWithResult: (didPop, _) {},
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(isNew ? ctx.w('pmAdd') : ctx.w('pmEdit'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field(label: ctx.w('pmName'), hint: 'ACLEDA, Wing, Pi Pay…', controller: _name, maxLength: 40, autofocus: isNew, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 4),
                    Text(ctx.w('pmNameHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                    gap14,
                    Text(ctx.w('pmColor'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final col in _pmColors)
                          InkWell(
                            borderRadius: BorderRadius.circular(99),
                            onTap: () => setState(() => _color = col),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: hexToColor(col),
                                shape: BoxShape.circle,
                                border: Border.all(color: _color == col ? c.ink : Colors.transparent, width: 2),
                              ),
                              child: _color == col ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                            ),
                          ),
                      ],
                    ),
                    gap14,
                    if (isNew)
                      Muted(ctx.w('pmQrLater'))
                    else ...[
                      Text(ctx.w('pmQr'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      MImagePick(
                        ctx: ctx,
                        url: _qr,
                        busy: _busy == 'qr',
                        maxSize: 900,
                        onPick: (b, name) async {
                          final r = await _go('qr', () => ctx.api.post('${ctx.base}/pay-methods/$_key/qr', fileForm('file', b, name)));
                          final x = objs(obj(r?['data'])['custom_methods']).where((y) => y['key'] == _key).firstOrNull;
                          if (x != null) setState(() => _qr = str(obj(x['qr'])['url']));
                        },
                        onRemove: () async {
                          if (await _go('qr', () => ctx.api.delete('${ctx.base}/pay-methods/$_key/qr')) != null) setState(() => _qr = '');
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(ctx.w('pmQrHint'), style: TextStyle(color: c.muted, fontSize: 12.5)),
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
                  if (!isNew)
                    SureDelete(
                      remove: ctx.w('pmRemove'),
                      sure: ctx.m('sure'),
                      onDelete: _busy.isNotEmpty
                          ? null
                          : () async {
                              final r = await _go('remove', () => ctx.api.delete('${ctx.base}/pay-methods/$_key'));
                              if (r != null && context.mounted) Navigator.pop(context, (r, _key));
                            },
                    ),
                  const Spacer(),
                  Btn(ctx.m('cancel'), kind: BtnKind.ghost, small: true, onTap: _busy.isNotEmpty ? null : () => Navigator.pop(context, _last == null ? null : (_last!, ''))),
                  const SizedBox(width: 8),
                  Btn(
                    _busy == 'save' ? ctx.m('saving') : ctx.m('save'),
                    small: true,
                    busy: _busy == 'save',
                    onTap: _busy.isNotEmpty || _name.text.trim().isEmpty
                        ? null
                        : () async {
                            final body = {'name': _name.text.trim(), 'color': _color};
                            final r = await _go('save', () => isNew ? ctx.api.post('${ctx.base}/pay-methods', body) : ctx.api.put('${ctx.base}/pay-methods/$_key', body));
                            if (r != null && context.mounted) Navigator.pop(context, (r, ''));
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Weighing-scale barcodes (mart_scale): the label format the POS reads
class ScaleCard extends StatefulWidget {
  final MartCtx ctx;
  const ScaleCard({super.key, required this.ctx});
  @override
  State<ScaleCard> createState() => _ScaleCardState();
}

class _ScaleCardState extends State<ScaleCard> {
  Json? _s;
  final _prefix = TextEditingController();
  MartCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ScaleCard old) {
    super.didUpdateWidget(old);
    if (old.ctx.addonOn('mart_scale') != ctx.addonOn('mart_scale')) _load();
  }

  @override
  void dispose() {
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/scale');
      if (!mounted) return;
      setState(() {
        _s = obj(r['data']);
        _prefix.text = str(_s!['prefix']);
      });
    } catch (_) {}
  }

  Future<void> _save(Json patch) async {
    final next = {..._s!, ...patch};
    setState(() => _s = next);
    final r = await _run(ctx, () => ctx.api.put('${ctx.base}/scale', {'on': next['on'], 'prefix': next['prefix'], 'item_len': n(next['item_len']), 'mode': next['mode']}), ctx.x('saved'));
    if (r != null && mounted) setState(() => _s = {...next, ...obj(r['data'])});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final active = s['active'] == true;
    // an example label for the format chosen
    final prefix = str(s['prefix']);
    final len = n(s['item_len']).toInt();
    final valLen = 12 - prefix.length - len;
    final item = '123'.padLeft(len, '0');
    final val = (s['mode'] == 'weight' ? '1250' : (ctx.cur == 'KHR' ? '5000' : '375')).padLeft(valLen < 0 ? 0 : valLen, '0');
    final d12 = '$prefix$item$val';
    String? example;
    if (d12.length >= 12 && RegExp(r'^\d+$').hasMatch(d12)) {
      final d = d12.substring(0, 12);
      var sum = 0;
      for (var i = 0; i < 12; i++) {
        sum += int.parse(d[i]) * (i.isOdd ? 3 : 1);
      }
      final code = '$d${(10 - sum % 10) % 10}';
      final value = int.parse(code.substring(prefix.length + len, 12));
      final shown = s['mode'] == 'price' ? money(ctx.cur == 'KHR' ? value : value / 100, ctx.cur) : '${value / 1000} kg';
      example = ctx.x('scExample', {'code': code, 'item': code.substring(prefix.length, prefix.length + len), 'value': shown});
    }
    return _panel([
      MHead(ctx.x('scTitle'), icon: LucideIcons.scale, sub: ctx.x('scSub')),
      if (!active)
        Align(
          alignment: Alignment.centerLeft,
          child: GoldBtn(ctx.x('unlockOnce', {'coins': n(ctx.addon('mart_scale')['price'] ?? 50)}), onTap: ctx.readOnly ? null : () => ctx.askBuy('mart_scale')),
        )
      else ...[
        SwitchRow(title: ctx.x('scOn'), value: s['on'] == true, onChanged: ctx.readOnly ? null : (v) => _save({'on': v})),
        if (s['on'] == true) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (on) {
                    if (!on && RegExp(r'^\d{1,2}$').hasMatch(_prefix.text) && _prefix.text != str(_s?['prefix'])) _save({'prefix': _prefix.text});
                  },
                  child: Field(label: ctx.x('prefix'), controller: _prefix, maxLength: 2, keyboard: TextInputType.number, enabled: !ctx.readOnly),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectField<int>(
                  label: ctx.x('itemLen'),
                  value: len,
                  options: [
                    for (final k in [4, 5, 6]) (k, '$k'),
                  ],
                  onChanged: ctx.readOnly ? null : (v) => _save({'item_len': v}),
                ),
              ),
            ],
          ),
          gap14,
          Segmented<String>(
            value: str(s['mode']),
            options: [
              for (final k in ['weight', 'price']) (k, ctx.x('modes.$k')),
            ],
            onChanged: ctx.readOnly ? null : (v) => _save({'mode': v}),
          ),
          if (example != null) ...[
            gap14,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
              child: Text(example, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 8),
          Muted(ctx.x('scProducts', {'n': n(s['products'])})),
        ],
      ],
    ]);
  }
}
