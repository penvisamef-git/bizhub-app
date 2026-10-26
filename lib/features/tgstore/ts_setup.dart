import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show askSure;
import '../mart/mart_common.dart' show GoldBtn;
import '../restaurant/rest_common.dart' show SelectField, Segmented, SwitchRow;
import 'ts_common.dart';

// Store settings (TsSetup.jsx StoreTab + TsPay.jsx PayMethods + TsGrow.jsx HoursCard) and
// Delivery (TsMore.jsx: delivery zones + the riders' group)

dynamic _copy(Object? v) => v is Map ? <String, dynamic>{for (final e in v.entries) '${e.key}': _copy(e.value)} : (v is List ? [for (final x in v) _copy(x)] : v);
String _num(String v) => v.replaceAll(RegExp(r'[^\d.]'), '');
Future<List<int>?> _pickImage() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
  return f == null ? null : await f.readAsBytes();
}

FormData _imageForm(String field, List<int> bytes) => FormData.fromMap({field: MultipartFile.fromBytes(bytes, filename: '$field.jpg', contentType: DioMediaType.parse('image/jpeg'))});

// a text box that keeps its own controller (the forms here are plain maps)
class TsInput extends StatefulWidget {
  final String? label, hint;
  final String value;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboard;
  final bool enabled, numeric;
  final int? maxLength;
  final int maxLines;
  final Widget? prefix;
  const TsInput({super.key, this.label, this.hint, required this.value, this.onChanged, this.keyboard, this.enabled = true, this.numeric = false, this.maxLength, this.maxLines = 1, this.prefix});
  @override
  State<TsInput> createState() => _TsInputState();
}

class _TsInputState extends State<TsInput> {
  late final _c = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(TsInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text && widget.value != old.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Field(
    label: widget.label,
    hint: widget.hint,
    controller: _c,
    enabled: widget.enabled && widget.onChanged != null,
    keyboard: widget.numeric ? const TextInputType.numberWithOptions(decimal: true) : widget.keyboard,
    maxLength: widget.maxLength,
    maxLines: widget.maxLines,
    prefix: widget.prefix,
    onChanged: widget.onChanged == null
        ? null
        : (v) {
            if (widget.numeric) {
              final clean = _num(v);
              if (clean != v) {
                _c.text = clean;
                _c.selection = TextSelection.collapsed(offset: clean.length);
              }
              widget.onChanged!(clean);
            } else {
              widget.onChanged!(v);
            }
          },
  );
}

const _gap = SizedBox(height: 12);
String _numStr(Object? v) => v == null ? '' : (n(v) % 1 == 0 ? '${n(v).toInt()}' : '${n(v)}');

// ---------------------------------------------------------------- Store settings
class StoreTab extends StatefulWidget {
  final TsCtx ctx;
  const StoreTab({super.key, required this.ctx});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  TsCtx get ctx => widget.ctx;
  late Json f = _from(ctx.store);
  bool _busy = false, _logoBusy = false;
  String _error = '';

  Json _from(Json s) =>
      (_copy({
            'shop_name': s['shop_name'] ?? '',
            'phone': s['phone'] ?? '',
            'address': s['address'] ?? '',
            'about': s['about'] ?? '',
            'currency': s['currency'] ?? 'USD',
            'open': s['open'] != false,
            'delivery': {
              'on': obj(s['delivery'])['on'] == true,
              'fee': _numStr(obj(s['delivery'])['fee']),
              'free_from': _numStr(obj(s['delivery'])['free_from']),
              'min_order': _numStr(obj(s['delivery'])['min_order']),
              'note': obj(s['delivery'])['note'] ?? '',
            },
            'pickup': {'on': obj(s['pickup'])['on'] == true, 'note': obj(s['pickup'])['note'] ?? ''},
            'dine_in': {'on': obj(s['dine_in'])['on'] == true, 'tables': _numStr(obj(s['dine_in'])['tables'] ?? 10)},
            'pay': {
              'khqr': {'on': obj(obj(s['pay'])['khqr'])['on'] == true, 'bakong_id': obj(obj(s['pay'])['khqr'])['bakong_id'] ?? '', 'account_name': obj(obj(s['pay'])['khqr'])['account_name'] ?? ''},
              'cash': {'on': obj(obj(s['pay'])['cash'])['on'] != false},
            },
            'hours': s['hours'] is Map
                ? s['hours']
                : {
                    'on': false,
                    'days': List.generate(7, (_) => {'open': '07:00', 'close': '21:00', 'closed': false}),
                  },
          })
          as Json);

  void _set(String path, Object? v) => setState(() {
    final keys = path.split('.');
    Json t = f;
    for (final k in keys.take(keys.length - 1)) {
      t = t[k] as Json;
    }
    t[keys.last] = v;
  });
  Json g(String k) => obj(f[k]);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final d = g('delivery');
    final body = {
      'shop_name': f['shop_name'],
      'phone': f['phone'],
      'address': f['address'],
      'about': f['about'],
      'currency': f['currency'],
      'open': f['open'],
      'delivery': {...d, 'fee': num.tryParse('${d['fee']}') ?? 0, 'free_from': num.tryParse('${d['free_from']}') ?? 0, 'min_order': num.tryParse('${d['min_order']}') ?? 0},
      'pickup': f['pickup'],
      'dine_in': {...g('dine_in'), 'tables': int.tryParse('${g('dine_in')['tables']}') ?? 1},
      'pay': f['pay'],
      if (ctx.on('ts_hours')) 'hours': f['hours'],
    };
    try {
      final r = await ctx.api.put('${ctx.base}/settings', body);
      ctx.put({'store': obj(obj(r['data'])['store']), if (obj(r['data'])['open_now'] is Map) 'open_now': obj(obj(r['data'])['open_now'])});
      ctx.notify(ctx.m('saved'));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logo(bool remove) async {
    List<int>? bytes;
    if (!remove) {
      bytes = await _pickImage();
      if (bytes == null) return;
    }
    setState(() => _logoBusy = true);
    final r = await ctx.run(() => remove ? ctx.api.delete('${ctx.base}/logo') : ctx.api.post('${ctx.base}/logo', _imageForm('logo', bytes!)));
    if (mounted) setState(() => _logoBusy = false);
    if (r != null) {
      ctx.put({
        'store': {...ctx.store, 'logo': str(obj(r['data'])['logo'])},
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final sign = f['currency'] == 'KHR' ? '៛' : '\$';
    final zonesOn = ctx.on('ts_zones') && obj(ctx.store['zones'])['on'] == true;
    final d = g('delivery'), p = g('pickup'), di = g('dine_in'), khqr = obj(g('pay')['khqr']), cash = obj(g('pay')['cash']);
    final logo = str(ctx.store['logo']);
    ValueChanged<String>? on(String path) => ro ? null : (v) => _set(path, v);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        Muted(ctx.m('storeSub')),
        _gap,
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Alert(_error)),
        TsCard(
          title: ctx.m('shop'),
          icon: LucideIcons.store,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: ro || _logoBusy ? null : () => _logo(false),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: logo.isEmpty ? const LinearGradient(colors: [Color(0xFF0B77C2), Color(0xFF2AABEE)]) : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoBusy
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : logo.isNotEmpty
                        ? Image(image: netImage(logo), fit: BoxFit.cover)
                        : const Icon(LucideIcons.send, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Btn(logo.isEmpty ? ctx.m('addLogo') : ctx.m('changePhoto'), icon: LucideIcons.imagePlus, small: true, kind: BtnKind.ghost, onTap: ro || _logoBusy ? null : () => _logo(false)),
                      if (logo.isNotEmpty) Btn(ctx.m('removePhoto'), icon: LucideIcons.trash2, small: true, kind: BtnKind.ghost, onTap: ro || _logoBusy ? null : () => _logo(true)),
                    ],
                  ),
                ),
              ],
            ),
            _gap,
            TsInput(label: ctx.m('shopName'), value: str(f['shop_name']), maxLength: 80, onChanged: on('shop_name')),
            _gap,
            TsInput(label: ctx.m('phone'), value: str(f['phone']), maxLength: 40, keyboard: TextInputType.phone, onChanged: on('phone')),
            _gap,
            TsInput(label: ctx.m('aboutShop'), hint: ctx.m('aboutShopPh'), value: str(f['about']), maxLength: 300, onChanged: on('about')),
            _gap,
            TsInput(label: ctx.m('address'), value: str(f['address']), maxLength: 200, onChanged: on('address')),
            _gap,
            SelectField<String>(label: ctx.m('currency'), value: str(f['currency']), options: const [('USD', 'USD \$'), ('KHR', 'KHR ៛')], onChanged: ro ? null : (v) => _set('currency', v)),
            const SizedBox(height: 4),
            SwitchRow(title: ctx.m('isOpen'), sub: ctx.m('isOpenHint'), value: f['open'] == true, onChanged: ro ? null : (v) => _set('open', v)),
          ],
        ),
        TsCard(
          title: ctx.m('getting'),
          children: [
            SwitchRow(title: ctx.m('delivery'), value: d['on'] == true, onChanged: ro ? null : (v) => _set('delivery.on', v)),
            if (d['on'] == true) ...[
              TsInput(label: '${ctx.m('fee')} ($sign)', value: str(d['fee']), numeric: true, onChanged: zonesOn ? null : on('delivery.fee')),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2), visualDensity: VisualDensity.compact),
                  onPressed: () => ctx.go('delivery'),
                  child: Text(
                    zonesOn ? ctx.m('zonesInUse') : ctx.m('zonesTry'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.brand),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TsInput(label: '${ctx.m('freeFrom')} ($sign)', value: str(d['free_from']), numeric: true, onChanged: on('delivery.free_from')),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(ctx.m('freeFromHint'), style: TextStyle(fontSize: 12.5, color: c.muted)),
              ),
              _gap,
              TsInput(label: '${ctx.m('minOrder')} ($sign)', value: str(d['min_order']), numeric: true, onChanged: on('delivery.min_order')),
              _gap,
              TsInput(label: ctx.m('deliveryNote'), hint: ctx.m('deliveryNotePh'), value: str(d['note']), maxLength: 160, onChanged: on('delivery.note')),
              _gap,
            ],
            SwitchRow(title: ctx.m('pickup'), value: p['on'] == true, onChanged: ro ? null : (v) => _set('pickup.on', v)),
            if (p['on'] == true) ...[TsInput(label: ctx.m('pickupNote'), value: str(p['note']), maxLength: 160, onChanged: on('pickup.note')), _gap],
            SwitchRow(title: ctx.m('dineIn'), value: di['on'] == true, onChanged: ro ? null : (v) => _set('dine_in.on', v)),
            if (di['on'] == true)
              TsInput(label: ctx.m('tables'), value: str(di['tables']), keyboard: TextInputType.number, onChanged: ro ? null : (v) => _set('dine_in.tables', v.replaceAll(RegExp(r'\D'), ''))),
          ],
        ),
        TsCard(
          title: ctx.m('paying'),
          children: [
            SwitchRow(
              title: ctx.m('khqr'),
              sub: '${ctx.m('khqrHint')} ${ctx.data['khqr_auto'] == true ? ctx.m('khqrAuto') : ctx.m('khqrManual')}',
              value: khqr['on'] == true,
              onChanged: ro ? null : (v) => _set('pay.khqr.on', v),
            ),
            if (khqr['on'] == true) ...[
              TsInput(
                label: ctx.m('bakongId'),
                hint: ctx.m('bakongIdPh'),
                value: str(khqr['bakong_id']),
                maxLength: 60,
                keyboard: TextInputType.emailAddress,
                onChanged: ro ? null : (v) => _set('pay.khqr.bakong_id', v.trim()),
              ),
              _gap,
              TsInput(label: ctx.m('accountName'), value: str(khqr['account_name']), maxLength: 40, onChanged: on('pay.khqr.account_name')),
              _gap,
            ],
            SwitchRow(title: ctx.m('cash'), value: cash['on'] == true, onChanged: ro ? null : (v) => _set('pay.cash.on', v)),
          ],
        ),
        _PayMethods(ctx: ctx),
        _HoursCard(ctx: ctx, hours: obj(f['hours']), onChanged: ro ? null : (h) => setState(() => f['hours'] = h)),
        Btn(ctx.m('save'), icon: LucideIcons.check, expand: true, busy: _busy, onTap: ro || _busy ? null : _save),
      ],
    );
  }
}

// ---------------------------------------------------------------- the owner's own ways to pay
class _PayMethods extends StatefulWidget {
  final TsCtx ctx;
  const _PayMethods({required this.ctx});
  @override
  State<_PayMethods> createState() => _PayMethodsState();
}

class _PayMethodsState extends State<_PayMethods> {
  TsCtx get ctx => widget.ctx;
  Json? _edit; // {} new | a method
  String _busy = '';

  List<Json> get _list => objs(obj(ctx.store['pay'])['custom']);

  Future<bool> _run(String key, Future<Json> Function() fn) async {
    setState(() => _busy = key);
    final r = await ctx.run(fn);
    if (mounted) setState(() => _busy = '');
    if (r == null) return false;
    ctx.put({
      'store': {
        ...ctx.store,
        'pay': {...obj(ctx.store['pay']), 'custom': r['data']},
      },
    });
    return true;
  }

  Future<void> _save() async {
    final e = _edit!;
    if (str(e['name']).trim().isEmpty) return;
    final body = {'name': str(e['name']).trim(), 'info': str(e['info'])};
    final id = str(e['_id']);
    if (await _run('save', () => id.isNotEmpty ? ctx.api.put('${ctx.base}/pay-methods/$id', body) : ctx.api.post('${ctx.base}/pay-methods', body))) {
      if (mounted) setState(() => _edit = null);
    }
  }

  Future<void> _image(Json m) async {
    final id = str(m['_id']);
    if (str(m['image']).isNotEmpty) {
      await _run(id, () => ctx.api.delete('${ctx.base}/pay-methods/$id/image'));
      return;
    }
    final bytes = await _pickImage();
    if (bytes == null) return;
    await _run(id, () => ctx.api.post('${ctx.base}/pay-methods/$id/image', _imageForm('image', bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final more = ctx.on('ts_pay');
    final pay = obj(ctx.store['pay']);
    final used = (obj(pay['khqr'])['on'] == true ? 1 : 0) + (obj(pay['cash'])['on'] == true ? 1 : 0) + _list.length;
    final canAdd = more || (_list.isEmpty && used < n(ctx.data['pay_free']));
    final e = _edit;
    return TsCard(
      title: ctx.m('ownPay'),
      icon: LucideIcons.creditCard,
      sub: ctx.m('ownPaySub'),
      children: [
        for (final m in _list)
          Opacity(
            opacity: m['on'] == false ? .55 : 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    child: str(m['image']).isNotEmpty ? Image(image: netImage(str(m['image'])), fit: BoxFit.cover) : Icon(LucideIcons.qrCode, size: 20, color: c.muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(m['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (str(m['info']).isNotEmpty) Text(str(m['info']), style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: m['on'] != false,
                    onChanged: ro || _busy == str(m['_id']) ? null : (v) => _run(str(m['_id']), () => ctx.api.put('${ctx.base}/pay-methods/${m['_id']}', {'on': v})),
                  ),
                  if (more)
                    IconButton(
                      tooltip: str(m['image']).isNotEmpty ? ctx.m('removeQr') : ctx.m('addQr'),
                      onPressed: ro ? null : () => _image(m),
                      icon: Icon(str(m['image']).isNotEmpty ? LucideIcons.x : LucideIcons.imagePlus, size: 18),
                    )
                  else
                    Tooltip(
                      message: ctx.m('addonWhat.ts_pay'),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(LucideIcons.lock, size: 16, color: c.muted),
                      ),
                    ),
                  IconButton(tooltip: ctx.m('edit'), onPressed: ro ? null : () => setState(() => _edit = {...m}), icon: const Icon(LucideIcons.pencil, size: 18)),
                  IconButton(
                    tooltip: ctx.m('delete'),
                    onPressed: ro
                        ? null
                        : () async {
                            if (await askSure(context, ctx.m('removePayAsk', {'name': m['name']}), ok: ctx.m('delete'), cancel: ctx.m('cancel'), danger: true)) {
                              await _run(str(m['_id']), () => ctx.api.delete('${ctx.base}/pay-methods/${m['_id']}'));
                            }
                          },
                    icon: const Icon(LucideIcons.trash2, size: 18),
                  ),
                ],
              ),
            ),
          ),
        if (e != null) ...[
          TsInput(label: ctx.m('payName'), hint: ctx.m('payNamePh'), value: str(e['name']), maxLength: 40, onChanged: (v) => e['name'] = v),
          _gap,
          TsInput(label: ctx.m('payInfo'), hint: ctx.m('payInfoPh'), value: str(e['info']), maxLength: 300, onChanged: (v) => e['info'] = v),
          _gap,
          Wrap(
            spacing: 8,
            children: [
              Btn(ctx.m('save'), small: true, busy: _busy == 'save', onTap: _busy == 'save' ? null : _save),
              Btn(ctx.m('cancel'), small: true, kind: BtnKind.ghost, onTap: () => setState(() => _edit = null)),
            ],
          ),
        ] else ...[
          if (canAdd)
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(ctx.m('addPay'), icon: LucideIcons.plus, small: true, kind: BtnKind.ghost, onTap: ro ? null : () => setState(() => _edit = {'name': '', 'info': ''})),
            ),
          if (!more) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.lock, size: 15, color: c.warn),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ctx.m('freePay')} ${ctx.m('addonWhat.ts_pay')}',
                          style: TextStyle(fontSize: 13, color: c.warn, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GoldBtn('${ctx.m('addonNames.ts_pay')} · ${fmt(n(ctx.addon('ts_pay')['price']))}', onTap: ro ? null : () => ctx.askBuy('ts_pay')),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- opening hours (add-on ts_hours)
const _dayOrder = [1, 2, 3, 4, 5, 6, 0]; // Monday first on screen

class _HoursCard extends StatelessWidget {
  final TsCtx ctx;
  final Json hours;
  final ValueChanged<Json>? onChanged;
  const _HoursCard({required this.ctx, required this.hours, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!ctx.on('ts_hours')) {
      return TsCard(
        title: ctx.m('hours'),
        icon: LucideIcons.clock,
        children: [TsLocked(ctx: ctx, addon: 'ts_hours', small: true)],
      );
    }
    final days = objs(hours['days']);
    final names = ctx.t.list('ts.days');
    final now = obj(ctx.data['open_now']);
    void setDay(int i, Json patch) => onChanged?.call({
      ...hours,
      'days': [
        for (var j = 0; j < days.length; j++) j == i ? {...days[j], ...patch} : days[j],
      ],
    });
    Future<void> time(int i, String key) async {
      final cur = str(days[i][key]);
      final parts = cur.split(':');
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 7, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0),
        builder: (ctx2, child) => MediaQuery(data: MediaQuery.of(ctx2).copyWith(alwaysUse24HourFormat: true), child: child!),
      );
      if (picked != null) setDay(i, {key: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'});
    }

    return TsCard(
      title: ctx.m('hours'),
      icon: LucideIcons.clock,
      sub: ctx.m('hoursSub'),
      trailing: hours['on'] == true ? TsPill(now['open'] == true ? ctx.m('openNowChip') : ctx.m('closedNowChip'), tone: now['open'] == true ? Tone.good : Tone.danger) : null,
      children: [
        SwitchRow(title: ctx.m('hoursOn'), value: hours['on'] == true, onChanged: onChanged == null ? null : (v) => onChanged!({...hours, 'on': v})),
        if (hours['on'] == true && days.length == 7)
          for (final i in _dayOrder)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(i < names.length ? names[i] : '$i', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final k in ['open', 'close']) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: days[i]['closed'] == true || onChanged == null ? null : () => time(i, k),
                      child: Text(str(days[i][k])),
                    ),
                    if (k == 'open')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('–', style: TextStyle(color: c.muted)),
                      ),
                  ],
                  const Spacer(),
                  Text(ctx.m('closedDay'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                  Switch.adaptive(value: days[i]['closed'] == true, onChanged: onChanged == null ? null : (v) => setDay(i, {'closed': v})),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Delivery: zones + riders
class DeliveryTab extends StatelessWidget {
  final TsCtx ctx;
  const DeliveryTab({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
    children: [
      Muted(ctx.m('deliverySub')),
      _gap,
      if (obj(ctx.store['delivery'])['on'] != true)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Alert(ctx.m('deliveryOff'), tone: Tone.warn),
        ),
      if (ctx.on('ts_zones'))
        _Zones(ctx: ctx)
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TsLocked(ctx: ctx, addon: 'ts_zones'),
        ),
      if (ctx.on('ts_riders')) _Riders(ctx: ctx) else TsLocked(ctx: ctx, addon: 'ts_riders'),
    ],
  );
}

class _Zones extends StatefulWidget {
  final TsCtx ctx;
  const _Zones({required this.ctx});
  @override
  State<_Zones> createState() => _ZonesState();
}

class _ZonesState extends State<_Zones> {
  TsCtx get ctx => widget.ctx;
  late Json z;
  bool _busy = false;
  String _error = '';
  int _v = 0; // new rows get fresh text boxes

  @override
  void initState() {
    super.initState();
    _fill(obj(ctx.store['zones']));
  }

  void _fill(Json z0) {
    final steps = objs(z0['steps']);
    z = {
      'on': z0['on'] == true,
      'kind': str(z0['kind']).isEmpty ? 'area' : str(z0['kind']),
      'areas': [
        for (final a in objs(z0['areas'])) {...a, 'fee': _numStr(a['fee']), 'min_order': n(a['min_order']) > 0 ? _numStr(a['min_order']) : ''},
      ],
      'steps': [
        for (final s
            in steps.isNotEmpty
                ? steps
                : [
                    {'upto': 3, 'fee': 1},
                    {'upto': 6, 'fee': 1.5},
                    {'upto': 10, 'fee': 2.5},
                  ])
          {'upto': _numStr(s['upto']), 'fee': _numStr(s['fee'])},
      ],
      'pin': z0['lat'] != null ? '${z0['lat']}, ${z0['lng']}' : '',
    };
  }

  List<Json> get _areas => (z['areas'] as List).cast<Json>();
  List<Json> get _steps => (z['steps'] as List).cast<Json>();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final body = {
      'on': z['on'],
      'kind': z['kind'],
      'areas': [
        for (final a in _areas)
          if (str(a['name']).trim().isNotEmpty)
            {
              if (str(a['_id']).isNotEmpty) '_id': a['_id'],
              'name': str(a['name']).trim(),
              'fee': num.tryParse('${a['fee']}') ?? 0,
              'min_order': num.tryParse('${a['min_order']}') ?? 0,
              'on': a['on'] != false,
            },
      ],
      'steps': [
        for (final s in _steps)
          if ((num.tryParse('${s['upto']}') ?? 0) > 0) {'upto': num.parse('${s['upto']}'), 'fee': num.tryParse('${s['fee']}') ?? 0},
      ],
      'pin': str(z['pin']).trim().isEmpty ? null : str(z['pin']).trim(),
    };
    try {
      final r = await ctx.api.put('${ctx.base}/settings', {'zones': body});
      final st = obj(obj(r['data'])['store']);
      ctx.put({'store': st});
      setState(() {
        _fill(obj(st['zones']));
        _v++;
      });
      ctx.notify(ctx.m('saved'));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ctx.t('app.offline') : e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final sign = ctx.cur == 'KHR' ? '៛' : '\$';
    final pin = str(z['pin']).trim();
    final pinOk = RegExp(r'^-?\d{1,2}\.\d+\s*,\s*-?\d{1,3}\.\d+$').hasMatch(pin);
    return TsCard(
      title: ctx.m('addonNames.ts_zones'),
      icon: LucideIcons.map,
      sub: ctx.m('zonesSub'),
      children: [
        SwitchRow(title: ctx.m('zonesOn'), value: z['on'] == true, onChanged: ro ? null : (v) => setState(() => z['on'] = v)),
        Segmented<String>(value: str(z['kind']), options: [('area', ctx.m('zoneKinds.area')), ('distance', ctx.m('zoneKinds.distance'))], onChanged: ro ? null : (v) => setState(() => z['kind'] = v)),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12, left: 2),
          child: Text(ctx.m('zoneKindHint.${z['kind']}'), style: TextStyle(fontSize: 12.5, color: c.muted)),
        ),
        if (z['kind'] == 'area') ...[
          for (var i = 0; i < _areas.length; i++)
            Opacity(
              opacity: _areas[i]['on'] == false ? .55 : 1,
              child: Container(
                key: ValueKey('a$_v-${_areas[i]['_id'] ?? 'n$i'}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TsInput(hint: ctx.m('areaPh'), value: str(_areas[i]['name']), maxLength: 60, onChanged: ro ? null : (v) => _areas[i]['name'] = v),
                        ),
                        Switch.adaptive(value: _areas[i]['on'] != false, onChanged: ro ? null : (v) => setState(() => _areas[i]['on'] = v)),
                        IconButton(onPressed: ro ? null : () => setState(() => _areas.removeAt(i)), icon: const Icon(LucideIcons.trash2, size: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TsInput(label: ctx.m('feeIn', {'sign': sign}), hint: '0', value: str(_areas[i]['fee']), numeric: true, onChanged: ro ? null : (v) => _areas[i]['fee'] = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TsInput(
                            label: ctx.m('minIn', {'sign': sign}),
                            hint: ctx.m('none'),
                            value: str(_areas[i]['min_order']),
                            numeric: true,
                            onChanged: ro ? null : (v) => _areas[i]['min_order'] = v,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              ctx.m('addArea'),
              icon: LucideIcons.plus,
              small: true,
              kind: BtnKind.ghost,
              onTap: ro || _areas.length >= 40 ? null : () => setState(() => _areas.add({'name': '', 'fee': '', 'min_order': '', 'on': true})),
            ),
          ),
        ] else ...[
          TsInput(key: ValueKey('pin$_v'), label: ctx.m('shopPin'), hint: ctx.m('pinPh'), value: str(z['pin']), maxLength: 600, onChanged: ro ? null : (v) => setState(() => z['pin'] = v)),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ctx.m('pinHint'), style: TextStyle(fontSize: 12.5, color: c.muted)),
                if (pinOk)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => tsOpen('https://maps.google.com/?q=${pin.replaceAll(' ', '')}'),
                    icon: const Icon(LucideIcons.externalLink, size: 13),
                    label: Text(ctx.m('openMap')),
                  ),
              ],
            ),
          ),
          _gap,
          for (var i = 0; i < _steps.length; i++)
            Padding(
              key: ValueKey('s$_v-$i-${_steps.length}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TsInput(
                      label: i == 0 ? ctx.m('upTo') : null,
                      value: str(_steps[i]['upto']),
                      numeric: true,
                      prefix: const Padding(padding: EdgeInsets.only(left: 14, right: 6, top: 2), child: Text('km')),
                      onChanged: ro ? null : (v) => _steps[i]['upto'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TsInput(label: i == 0 ? ctx.m('feeIn', {'sign': sign}) : null, value: str(_steps[i]['fee']), numeric: true, onChanged: ro ? null : (v) => _steps[i]['fee'] = v),
                  ),
                  IconButton(onPressed: ro ? null : () => setState(() => _steps.removeAt(i)), icon: const Icon(LucideIcons.trash2, size: 18)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(ctx.m('addStep'), icon: LucideIcons.plus, small: true, kind: BtnKind.ghost, onTap: ro || _steps.length >= 12 ? null : () => setState(() => _steps.add({'upto': '', 'fee': ''}))),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(ctx.m('stepsHint'), style: TextStyle(fontSize: 12.5, color: c.muted)),
          ),
        ],
        if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Alert(_error)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(ctx.m('save'), small: true, busy: _busy, onTap: ro || _busy ? null : _save),
        ),
      ],
    );
  }
}

class _Riders extends StatefulWidget {
  final TsCtx ctx;
  const _Riders({required this.ctx});
  @override
  State<_Riders> createState() => _RidersState();
}

class _RidersState extends State<_Riders> {
  TsCtx get ctx => widget.ctx;
  Json? _d;
  Json? _link;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/riders');
      if (mounted) setState(() => _d = obj(r['data']));
    } catch (_) {
      if (mounted) setState(() => _d = {'connected': false, 'riders': [], 'waiting': 0, 'send_on': 'accepted'});
    }
  }

  Future<Json?> _run(String key, Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = key);
    final r = await ctx.run(fn, ok);
    if (mounted) setState(() => _busy = '');
    return r;
  }

  Future<void> _sendOn(String v) async {
    final r = await _run(
      'send',
      () => ctx.api.put('${ctx.base}/settings', {
        'riders': {'send_on': v},
      }),
      ctx.m('saved'),
    );
    if (r == null) return;
    ctx.put({
      'store': obj(obj(r['data'])['store']),
      'riders': {...ctx.riders, 'send_on': v},
    });
    setState(() => _d = {...?_d, 'send_on': v});
  }

  Future<void> _refresh() async {
    await ctx.reload();
    await _load();
    if (mounted) setState(() => _link = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = _d;
    final ro = ctx.readOnly;
    final riders = objs(d?['riders']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TsCard(
          title: ctx.m('addonNames.ts_riders'),
          icon: LucideIcons.bike,
          sub: ctx.m('ridersSub'),
          children: [
            for (final (i, s) in ctx.t.list('ts.ridersHow').indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                    ),
                    Expanded(
                      child: Text(s, style: TextStyle(color: c.muted, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (ctx.telegram['configured'] != true)
              Alert(ctx.m('tgNotReady'), tone: Tone.warn)
            else if (d == null)
              const SkelList(rows: 1)
            else if (d['connected'] == true) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TsPill(ctx.m('connected', {'name': str(d['chat_name']).isEmpty ? 'Telegram' : d['chat_name']}), tone: Tone.good),
                  if (n(d['waiting']) > 0) TsPill(ctx.m('ridersWaitingN', {'n': d['waiting']}), tone: Tone.brand),
                  Btn(
                    ctx.m('test'),
                    icon: LucideIcons.send,
                    small: true,
                    kind: BtnKind.ghost,
                    busy: _busy == 'test',
                    onTap: ro || _busy.isNotEmpty ? null : () => _run('test', () => ctx.api.post('${ctx.base}/riders/test'), ctx.m('saved')),
                  ),
                  Btn(
                    ctx.m('disconnect'),
                    icon: LucideIcons.unplug,
                    small: true,
                    kind: BtnKind.ghost,
                    onTap: ro || _busy.isNotEmpty
                        ? null
                        : () async {
                            final r = await _run('off', () => ctx.api.delete('${ctx.base}/riders'));
                            if (r == null) return;
                            ctx.put({
                              'riders': {...ctx.riders, 'connected': false, 'chat_name': ''},
                            });
                            setState(() => _d = {...?_d, 'connected': false, 'chat_name': ''});
                          },
                  ),
                ],
              ),
              _gap,
              Text(ctx.m('sendWhen'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Segmented<String>(
                value: str(d['send_on']).isEmpty ? 'accepted' : str(d['send_on']),
                options: [
                  for (final k in ['accepted', 'ready', 'manual']) (k, ctx.m('sendOn.$k')),
                ],
                onChanged: ro || _busy.isNotEmpty ? null : _sendOn,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(ctx.m('sendOnHint.${str(d['send_on']).isEmpty ? 'accepted' : d['send_on']}'), style: TextStyle(fontSize: 12.5, color: c.muted)),
              ),
            ] else ...[
              Muted(ctx.m('ridersNot')),
              const SizedBox(height: 8),
              if (_link == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('ridersConnect'),
                    icon: LucideIcons.users,
                    small: true,
                    busy: _busy == 'link',
                    onTap: ro || _busy.isNotEmpty
                        ? null
                        : () async {
                            final r = await _run('link', () => ctx.api.post('${ctx.base}/riders/link'));
                            if (r != null) setState(() => _link = obj(r['data']));
                          },
                  ),
                )
              else ...[
                Muted(ctx.m('ridersConnectHint')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(ctx.m('connectGroup'), icon: LucideIcons.users, small: true, onTap: () => tsOpen(str(_link!['group_url']))),
                    Btn(ctx.m('refresh'), small: true, kind: BtnKind.ghost, onTap: _refresh),
                  ],
                ),
              ],
            ],
          ],
        ),
        if (d != null)
          TsCard(
            title: ctx.m('ridersTable'),
            children: [
              if (riders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(LucideIcons.bike, size: 28, color: c.muted),
                      const SizedBox(height: 6),
                      Muted(ctx.m('noRiders'), align: TextAlign.center),
                    ],
                  ),
                )
              else
                for (final r in riders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Avatar(name: str(r['name']), size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str(r['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text([if (str(r['username']).isNotEmpty) '@${r['username']}', if (r['last'] != null) ctx.ago(r['last'])].join(' · '), style: TextStyle(fontSize: 12, color: c.muted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${ctx.m('delivered')} ${fmt(n(r['delivered']))}${n(r['taken']) > n(r['delivered']) ? ' / ${fmt(n(r['taken']))}' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            Text('${ctx.m('fees')} ${ctx.money(r['fees'])} · ${r['minutes'] == null ? '—' : ctx.m('minN', {'n': r['minutes']})}', style: TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}
