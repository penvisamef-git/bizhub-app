import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/color_pick.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';

// Setup · Profile · Money · Staff (the web's SetupTab, ProfileTab, MoneyTab, StaffTab)

// ================================================================================================ setup
const _setupOrder = ['profile', 'money', 'tables', 'menu', 'staff'];

class SetupSection extends StatelessWidget {
  final RestCtx ctx;
  const SetupSection({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final setup = obj(ctx.overview['setup']);
    final steps = obj(setup['steps']);
    final done = n(setup['done']), total = n(setup['total']);
    final ready = setup['ready'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Row(
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(value: total == 0 ? 0 : done / total, strokeWidth: 7, color: c.brand, backgroundColor: c.bg2, strokeCap: StrokeCap.round),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${done.toInt()}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                            ),
                            TextSpan(
                              text: '/${total.toInt()}',
                              style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.r('setupTitle'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Muted(ctx.r('setupSub')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _setupOrder.length; i++) ...[
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => ctx.go(_setupOrder[i]),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: steps[_setupOrder[i]] == true ? c.good : c.bg2, shape: BoxShape.circle),
                  child: steps[_setupOrder[i]] == true ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.t.list('rest.steps.${_setupOrder[i]}').firstOrNull ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(ctx.t.list('rest.steps.${_setupOrder[i]}').elementAtOrNull(1) ?? '', style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                steps[_setupOrder[i]] == true ? Chip2(ctx.r('doneTag'), tone: Tone.good) : Chip2(ctx.r('open'), tone: Tone.brand),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Panel(
          color: ready ? c.goodBg : null,
          child: Row(
            children: [
              Icon(LucideIcons.monitorSmartphone, size: 28, color: ready ? c.good : c.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ready ? ctx.r('posReady') : ctx.r('posNotReady'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (ready) Text(ctx.r('posReadySub'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================================= settings form
// edit some keys of the restaurant settings with a save bar (useSettingsForm on the web)
mixin SettingsForm<W extends StatefulWidget> on State<W> {
  RestCtx get ctx;
  List<String> get keys;
  Json get extra => const {};
  late Json form = pickKeys(ctx.settings);
  bool saving = false;

  Json pickKeys(Json s) => {for (final k in keys) k: jsonDecode(jsonEncode(s[k] ?? ''))};
  bool get dirty => jsonEncode(form) != jsonEncode(pickKeys(ctx.settings));
  void set(String key, Object? value) => setState(() => form = {...form, key: value});
  void undo() => setState(() => form = pickKeys(ctx.settings));

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final r = await ctx.api.put('${ctx.base}/settings', {...form, ...extra});
      ctx.setSettings(obj(r['data']), r['setup'] == null ? null : obj(r['setup']));
      form = pickKeys(obj(r["data"]));
      ctx.notify(ctx.r('saved'));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

// a text box bound to one form key (keeps the cursor while typing)
class FormText extends StatefulWidget {
  final String? label, hint;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboard;
  final bool enabled;
  final Widget? prefix, suffix;
  const FormText({super.key, this.label, this.hint, required this.value, required this.onChanged, this.maxLength, this.maxLines = 1, this.keyboard, this.enabled = true, this.prefix, this.suffix});
  @override
  State<FormText> createState() => _FormTextState();
}

class _FormTextState extends State<FormText> {
  late final _c = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(FormText old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value; // undo / saved elsewhere
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
    maxLength: widget.maxLength,
    maxLines: widget.maxLines,
    keyboard: widget.keyboard,
    enabled: widget.enabled,
    prefix: widget.prefix,
    suffix: widget.suffix,
    onChanged: widget.onChanged,
  );
}

Widget _affix(String text) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14),
  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
);

// ============================================================================================== profile
class ProfileSection extends StatefulWidget {
  final RestCtx ctx;
  const ProfileSection({super.key, required this.ctx});
  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> with SettingsForm {
  @override
  RestCtx get ctx => widget.ctx;
  @override
  final keys = const ['name_km', 'name_en', 'type', 'phone', 'address', 'map_url', 'hours', 'tin', 'color'];
  String _busy = '';

  Future<void> _pick(String kind, List<int> bytes, String name) async {
    setState(() => _busy = kind);
    try {
      final r = await ctx.api.post('${ctx.base}/image', imageForm(bytes, '$kind.jpg', {'kind': kind}));
      ctx.setSettings(obj(r['data']), r['setup'] == null ? null : obj(r['setup']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _drop(String kind) async {
    setState(() => _busy = kind);
    try {
      final r = await ctx.api.delete('${ctx.base}/image', {'kind': kind});
      ctx.setSettings(obj(r['data']), r['setup'] == null ? null : obj(r['setup']));
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ro = ctx.readOnly;
    final noName = str(form['name_km']).trim().isEmpty && str(form['name_en']).trim().isEmpty;
    Widget text(String key, String label, {int max = 80, String? hint, TextInputType? kb}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormText(label: label, hint: hint, value: str(form[key]), onChanged: (v) => set(key, v), maxLength: max, keyboard: kb, enabled: !ro),
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RestHead(ctx.r('tabs.profile'), sub: ctx.r('profileSub')),
                    Text(ctx.r('logo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ImagePickRow(
                      ctx: ctx,
                      url: str(obj(ctx.settings['logo'])['url']),
                      busy: _busy == 'logo',
                      maxSize: 512,
                      disabled: ro,
                      onPick: (b, n) => _pick('logo', b, n),
                      onRemove: () => _drop('logo'),
                    ),
                    Padding(padding: const EdgeInsets.only(top: 6, bottom: 14), child: Muted(ctx.r('logoHint'))),
                    Text(ctx.r('cover'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ImagePickRow(
                      ctx: ctx,
                      url: str(obj(ctx.settings['cover'])['url']),
                      busy: _busy == 'cover',
                      wide: true,
                      maxSize: 1600,
                      disabled: ro,
                      onPick: (b, n) => _pick('cover', b, n),
                      onRemove: () => _drop('cover'),
                    ),
                    Padding(padding: const EdgeInsets.only(top: 6, bottom: 16), child: Muted(ctx.r('coverHint'))),
                    text('name_km', ctx.r('nameKm')),
                    text('name_en', ctx.r('nameEn')),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SelectField<String>(
                        label: ctx.r('type'),
                        value: str(form['type']),
                        options: [
                          for (final k in const ['restaurant', 'cafe', 'bar', 'bakery', 'stall']) (k, ctx.r('types.$k')),
                        ],
                        onChanged: ro ? null : (v) => set('type', v),
                      ),
                    ),
                    text('phone', ctx.r('phone'), max: 30, hint: '012 345 678', kb: TextInputType.phone),
                    text('address', ctx.r('address'), max: 200),
                    text('map_url', ctx.r('mapUrl'), max: 300, hint: 'maps.app.goo.gl/…', kb: TextInputType.url),
                    text('hours', ctx.r('hours'), max: 120, hint: ctx.r('hoursPh')),
                    text('tin', ctx.r('tin'), max: 40, hint: 'K001-123456789'),
                    Text(ctx.r('color'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 10),
                    ColorRow(
                      value: str(form['color']).toUpperCase(),
                      onChanged: ro ? null : (v) => set('color', v),
                      customLabel: ctx.r('customColor'),
                      saveLabel: ctx.r('save'),
                      cancelLabel: ctx.r('cancel'),
                    ),
                    if (noName) ...[gap14, Alert(ctx.r('nameNeeded'))],
                  ],
                ),
              ),
            ],
          ),
        ),
        RestSaveBar(ctx: ctx, dirty: dirty, saving: saving, onSave: save, onUndo: undo, disabled: ro || noName),
      ],
    );
  }
}

// ================================================================================================ money
class MoneySection extends StatefulWidget {
  final RestCtx ctx;
  const MoneySection({super.key, required this.ctx});
  @override
  State<MoneySection> createState() => _MoneySectionState();
}

class _MoneySectionState extends State<MoneySection> with SettingsForm {
  @override
  RestCtx get ctx => widget.ctx;
  @override
  final keys = const [
    'currency',
    'khr_rate',
    'khr_rounding',
    'vat',
    'service_charge',
    'pay_mode',
    'bill_numbering',
    'payment_methods',
    'receipt_size',
    'receipt_footer',
    'wifi_name',
    'wifi_pass',
    'receipt_printer',
  ];
  @override
  Json get extra => const {'mark_money_saved': true};

  void _nested(String key, Json patch) => set(key, {...obj(form[key]), ...patch});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final firstSave = ctx.settings['money_saved'] != true; // the first save always counts as "money step done"
    final limit = ctx.limits['payments'];
    final methods = objs(form['payment_methods']);
    final full = limit != null && methods.length >= n(limit);
    final vat = obj(form['vat']), service = obj(form['service_charge']);
    final printer = {'type': 'none', 'address': '', ...obj(form['receipt_printer'])};
    void setMethod(int i, Json patch) => set('payment_methods', [
      for (var j = 0; j < methods.length; j++) j == i ? {...methods[j], ...patch} : methods[j],
    ]);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RestHead(ctx.r('tabs.money'), sub: ctx.r('moneySub')),
                    label(ctx.r('currency')),
                    Segmented<String>(value: str(form['currency']), options: const [('USD', 'USD (\$)'), ('KHR', 'KHR (៛)')], onChanged: ro ? null : (v) => set('currency', v)),
                    Padding(padding: const EdgeInsets.only(top: 6, bottom: 14), child: Muted(ctx.r('currencyHint'))),
                    FormText(
                      label: ctx.r('rate'),
                      value: str(form['khr_rate']),
                      keyboard: TextInputType.number,
                      maxLength: 5,
                      enabled: !ro,
                      prefix: _affix('1 USD ='),
                      suffix: _affix('៛'),
                      onChanged: (v) => set('khr_rate', num.tryParse(v) ?? v),
                    ),
                    Padding(padding: const EdgeInsets.only(top: 6, bottom: 14), child: Muted(ctx.r('rateHint'))),
                    SelectField<String>(
                      label: ctx.r('rounding'),
                      value: '${form['khr_rounding']}',
                      options: [
                        for (final v in const [1, 100, 500, 1000]) ('$v', '${fmt(v)} ៛'),
                      ],
                      onChanged: ro ? null : (v) => set('khr_rounding', int.parse(v)),
                    ),
                    gap14,
                    label(ctx.r('payMode')),
                    Segmented<String>(value: str(form['pay_mode']), options: [('after', ctx.r('payAfter')), ('before', ctx.r('payBefore'))], onChanged: ro ? null : (v) => set('pay_mode', v)),
                    gap14,
                    label('${ctx.r('vat')} · ${ctx.r('service').split(' (').first}'),
                    SwitchRow(title: ctx.r('vat'), value: vat['enabled'] == true, onChanged: ro ? null : (v) => _nested('vat', {'enabled': v})),
                    if (vat['enabled'] == true) ...[
                      FormText(
                        value: str(vat['rate']),
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        maxLength: 4,
                        enabled: !ro,
                        suffix: _affix('%'),
                        onChanged: (v) => _nested('vat', {'rate': num.tryParse(v) ?? v}),
                      ),
                      const SizedBox(height: 10),
                      Segmented<bool>(
                        value: vat['included'] == true,
                        options: [(false, ctx.r('vatOnTop')), (true, ctx.r('vatIncluded'))],
                        onChanged: ro ? null : (v) => _nested('vat', {'included': v}),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SwitchRow(title: ctx.r('service'), value: service['enabled'] == true, onChanged: ro ? null : (v) => _nested('service_charge', {'enabled': v})),
                    if (service['enabled'] == true)
                      FormText(
                        value: str(service['rate']),
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        maxLength: 4,
                        enabled: !ro,
                        suffix: _affix('%'),
                        onChanged: (v) => _nested('service_charge', {'rate': num.tryParse(v) ?? v}),
                      ),
                  ],
                ),
              ),
              gap14,
              // ---------- payment methods ----------
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RestHead(
                      ctx.r('payments'),
                      sub: limit != null ? ctx.r('paymentsHint', {'n': methods.length, 'max': n(limit)}) : ctx.r('paymentsUnlimited'),
                      trailing: Btn(
                        ctx.r('addPayment'),
                        icon: full ? LucideIcons.lock : LucideIcons.plus,
                        kind: BtnKind.ghost,
                        small: true,
                        onTap: ro
                            ? null
                            : () => full
                                  ? ctx.askBuy('rest_payments')
                                  : set('payment_methods', [
                                      ...methods,
                                      {'name': '', 'kind': 'bank', 'active': true},
                                    ]),
                      ),
                    ),
                    for (var i = 0; i < methods.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            FormText(
                              key: ValueKey('pm-${methods[i]['_id'] ?? i}'),
                              value: str(methods[i]['name']),
                              hint: ctx.r('paymentName'),
                              maxLength: 40,
                              enabled: !ro,
                              onChanged: (v) => setMethod(i, {'name': v}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectField<String>(
                                    value: str(methods[i]['kind']),
                                    options: [
                                      for (final k in const ['cash', 'bank', 'qr', 'card', 'other']) (k, ctx.r('kinds.$k')),
                                    ],
                                    onChanged: ro ? null : (v) => setMethod(i, {'kind': v}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(value: methods[i]['active'] != false, onChanged: ro ? null : (v) => setMethod(i, {'active': v})),
                                RoundBtn(
                                  LucideIcons.trash2,
                                  size: 38,
                                  tip: ctx.r('remove'),
                                  fg: c.danger,
                                  onTap: ro || methods.length <= 1 ? null : () => set('payment_methods', [...methods]..removeAt(i)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (full) AddonPrompt(ctx: ctx, addonKey: 'rest_payments'),
                  ],
                ),
              ),
              gap14,
              // ---------- receipt ----------
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RestHead(ctx.r('receipt')),
                    label(ctx.r('receiptSize')),
                    Segmented<int>(value: n(form['receipt_size']).toInt() == 58 ? 58 : 80, options: const [(80, '80 mm'), (58, '58 mm')], onChanged: ro ? null : (v) => set('receipt_size', v)),
                    gap14,
                    label(ctx.r('billNumbers')),
                    Segmented<String>(
                      value: str(form['bill_numbering']),
                      options: [('daily', ctx.r('billDaily')), ('running', ctx.r('billRunning'))],
                      onChanged: ro ? null : (v) => set('bill_numbering', v),
                    ),
                    gap14,
                    FormText(label: ctx.r('footer'), hint: ctx.r('footerPh'), value: str(form['receipt_footer']), maxLength: 200, enabled: !ro, onChanged: (v) => set('receipt_footer', v)),
                    gap14,
                    FormText(label: ctx.r('wifiName'), value: str(form['wifi_name']), maxLength: 40, enabled: !ro, onChanged: (v) => set('wifi_name', v)),
                    gap14,
                    FormText(label: ctx.r('wifiPass'), value: str(form['wifi_pass']), maxLength: 40, enabled: !ro, onChanged: (v) => set('wifi_pass', v)),
                  ],
                ),
              ),
              gap14,
              // ---------- printer ----------
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RestHead(ctx.r('printers'), sub: ctx.addonOn('rest_printer') ? ctx.r('printersSub') : null),
                    if (ctx.addonOn('rest_printer')) ...[
                      SelectField<String>(
                        label: ctx.r('receiptPrinter'),
                        value: str(printer['type']),
                        options: [
                          for (final k in const ['none', 'network', 'usb']) (k, ctx.r('printerTypes.$k')),
                        ],
                        onChanged: ro ? null : (v) => set('receipt_printer', {...printer, 'type': v}),
                      ),
                      if (printer['type'] != 'none') ...[
                        gap14,
                        FormText(
                          label: ctx.r('printerAddress'),
                          hint: printer['type'] == 'network' ? '192.168.1.50' : 'USB001',
                          value: str(printer['address']),
                          maxLength: 100,
                          enabled: !ro,
                          onChanged: (v) => set('receipt_printer', {...printer, 'address': v}),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Muted(ctx.r('kitchenPrintersHint')),
                    ] else
                      AddonPrompt(ctx: ctx, addonKey: 'rest_printer', sub: ctx.r('printerLockedSub')),
                  ],
                ),
              ),
            ],
          ),
        ),
        RestSaveBar(ctx: ctx, dirty: dirty || firstSave, saving: saving, onSave: save, onUndo: undo, disabled: ro || methods.any((m) => str(m['name']).trim().isEmpty)),
      ],
    );
  }
}

// ================================================================================================ staff
const _roles = ['manager', 'cashier', 'waiter', 'kitchen'];

class StaffSection extends StatefulWidget {
  final RestCtx ctx;
  const StaffSection({super.key, required this.ctx});
  @override
  State<StaffSection> createState() => _StaffSectionState();
}

class _StaffSectionState extends State<StaffSection> {
  List<Json>? _staff;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ctx.api.get('${ctx.base}/staff');
      if (mounted) setState(() => _staff = objs(r['data']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _edit(Json row) async {
    final saved = await showEditor<bool>(
      context,
      builder: (_) => _StaffEditor(ctx: ctx, row: row),
    );
    if (saved == true) {
      _load();
      ctx.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final staff = _staff;
    if (staff == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 3));
    final limit = ctx.limits['staff'];
    final full = limit != null && staff.length >= n(limit);
    void add() => full ? ctx.askBuy('rest_staff') : _edit({});
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RestHead(
                ctx.r('tabs.staff'),
                sub: limit == null ? ctx.r('staffUnlimited', {'n': staff.length}) : ctx.r('staffCount', {'n': staff.length, 'max': n(limit)}),
                trailing: Btn(ctx.r('addStaff'), icon: full ? LucideIcons.lock : LucideIcons.plus, small: true, onTap: ctx.readOnly ? null : add),
              ),
              Muted(ctx.r('staffSub')),
              if (limit != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: (staff.length / n(limit)).clamp(0, 1).toDouble(), minHeight: 6, color: c.brand, backgroundColor: c.bg2),
                ),
              ],
            ],
          ),
        ),
        gap14,
        if (staff.isEmpty)
          Panel(
            child: Column(
              children: [
                Icon(LucideIcons.keyRound, size: 30, color: c.muted),
                const SizedBox(height: 10),
                Text(
                  ctx.r('noStaff'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 12),
                Btn(ctx.r('addStaff'), icon: LucideIcons.plus, onTap: ctx.readOnly ? null : add),
              ],
            ),
          ),
        for (final s in staff) ...[
          Panel(
            padding: const EdgeInsets.all(14),
            onTap: ctx.readOnly ? null : () => _edit(s),
            child: Opacity(
              opacity: s['active'] == false ? .55 : 1,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _roleColor(str(s['role'])).withValues(alpha: .15), shape: BoxShape.circle),
                    child: Text(
                      str(s['name']).isEmpty ? '?' : String.fromCharCodes(str(s['name']).runes.take(1)).toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _roleColor(str(s['role']))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${ctx.r('roles.${s['role']}')}${str(s['phone']).isNotEmpty ? ' · ${s['phone']}' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (s['active'] == false) Chip2(ctx.r('hidden')),
                  Icon(LucideIcons.chevronRight, size: 18, color: c.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (full) AddonPrompt(ctx: ctx, addonKey: 'rest_staff', title: ctx.r('staffLimitTitle', {'max': n(limit)}), sub: ctx.r('staffLimitSub')),
      ],
    );
  }
}

Color _roleColor(String role) => switch (role) {
  'manager' => const Color(0xFF7B1FA2),
  'waiter' => const Color(0xFF1A73E8),
  'kitchen' => const Color(0xFF2E7D32),
  _ => const Color(0xFFE0581A),
};

class _StaffEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  const _StaffEditor({required this.ctx, required this.row});
  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> {
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _phone = TextEditingController(text: str(widget.row['phone']));
  final _pin = TextEditingController();
  late String _role = str(widget.row['role']).isEmpty ? 'cashier' : str(widget.row['role']);
  late bool _active = widget.row['active'] != false;
  bool _busy = false;
  String _error = '';
  RestCtx get ctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;
  bool get _pinOk => _isNew ? RegExp(r'^\d{4}$').hasMatch(_pin.text) : (_pin.text.isEmpty || RegExp(r'^\d{4}$').hasMatch(_pin.text));

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final data = {'name': _name.text, 'role': _role, 'phone': _phone.text, 'active': _active, if (_pin.text.isNotEmpty) 'pin': _pin.text};
      if (_isNew) {
        await ctx.api.post('${ctx.base}/staff', data);
      } else {
        await ctx.api.put('${ctx.base}/staff/${widget.row['_id']}', data);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        if (mounted) Navigator.pop(context, false);
        ctx.askBuy(str(e.body['product']));
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ctx.api.delete('${ctx.base}/staff/${widget.row['_id']}');
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return EditorFrame(
      title: _isNew ? ctx.r('addStaff') : ctx.r('editStaff'),
      cancel: ctx.r('cancel'),
      save: ctx.r('save'),
      busy: _busy,
      canSave: _name.text.trim().isNotEmpty && _pinOk,
      onSave: _save,
      delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: _busy ? null : _remove),
      children: [
        Field(label: ctx.r('staffName'), controller: _name, maxLength: 60, autofocus: _isNew, onChanged: (_) => setState(() {})),
        gap14,
        Text(ctx.r('role'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 8),
        for (final k in _roles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _role = k),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _role == k ? c.active : c.bg2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _role == k ? c.brand : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(_role == k ? LucideIcons.circleCheck : LucideIcons.circle, size: 18, color: _role == k ? c.brand : c.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ctx.r('roles.$k'), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(ctx.r('roleHints.$k'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Field(
          label: _isNew ? ctx.r('pin') : ctx.r('newPin'),
          controller: _pin,
          hint: '••••',
          keyboard: TextInputType.number,
          maxLength: 4,
          onChanged: (v) {
            final d = v.replaceAll(RegExp(r'\D'), '');
            if (d != v) _pin.text = d;
            setState(() {});
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Muted(ctx.r('pinHint'))),
        gap14,
        Field(label: '${ctx.r('phone')} (${ctx.r('optional')})', controller: _phone, keyboard: TextInputType.phone, maxLength: 30),
        const SizedBox(height: 6),
        SwitchRow(title: ctx.r('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
        if (_error.isNotEmpty) Alert(_error),
      ],
    );
  }
}
