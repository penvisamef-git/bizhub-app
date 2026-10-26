import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented;
import 'mart_common.dart';

// Shared pieces of the newer Mini Mart sections (the web's MartGrowKit.jsx): add-on head, product picker, period bar, sheet frame.

// the head of a section; locked → what it does + its perks + unlock
class MAddonHead extends StatelessWidget {
  final MartCtx ctx;
  final String addon, title, sub;
  final IconData icon;
  final List<String> perks;
  final bool yearly;
  final Widget? action; // shown when the add-on is on
  const MAddonHead({super.key, required this.ctx, required this.addon, required this.icon, required this.title, required this.sub, this.perks = const [], this.yearly = true, this.action});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    final on = ctx.addonOn(addon);
    final price = fmt(n(a['price']));
    final buy = !on || a['status'] == 'expiring';
    final until = on && a['expires_at'] != null ? ctx.x('activeUntil', {'date': mDate(a['expires_at'], ctx.lang)}) : sub;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MHead(title, icon: icon, sub: until),
          if (on && action != null) Align(alignment: Alignment.centerLeft, child: action!),
          if (buy) ...[
            if (on && action != null) const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: GoldBtn(on ? ctx.x('renew') : (yearly ? ctx.x('unlockYear', {'coins': price}) : ctx.x('unlockOnce', {'coins': price})), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
            ),
          ],
          if (!on && perks.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final p in perks)
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
          ],
        ],
      ),
    );
  }
}

// a locked section with only a short note (the older stock / suppliers / debt look)
class MLocked extends StatelessWidget {
  final MartCtx ctx;
  final String addon, text, button;
  final IconData icon;
  const MLocked({super.key, required this.ctx, required this.addon, required this.icon, required this.text, required this.button});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Panel(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: c.brand),
              ),
              const SizedBox(height: 14),
              Text(
                ctx.m('addonInfo.$addon.name'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              GoldBtn(button, onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
            ],
          ),
        ),
      ],
    );
  }
}

// a bottom sheet: title, scrolling body, buttons at the bottom
class MSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget> footer;
  const MSheet({super.key, required this.title, required this.children, this.footer = const []});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          if (footer.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Row(children: footer),
            ),
        ],
      ),
    );
  }
}

Future<R?> showSheet<R>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<R>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: builder);

// busy + error + "saved" for a sheet's save button
mixin SheetSave<W extends StatefulWidget> on State<W> {
  bool busy = false;
  String error = '';
  MartCtx get mctx;
  Future<bool> save(Future<Json> Function() fn, {String? ok, bool close = true}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await fn();
      mctx.notify(ok ?? mctx.m('saved'));
      if (close && mounted) Navigator.pop(context, true);
      return true;
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.network ? mctx.t('app.offline') : e.message;
        });
      }
      return false;
    } finally {
      if (mounted && !close) setState(() => busy = false);
    }
  }
}

// a product picked from a searchable list (a sheet with search + camera scan)
Future<Json?> pickProduct(BuildContext context, MartCtx ctx, List<Json> products, {Set<String> exclude = const {}}) =>
    showSheet<Json>(context, (_) => _ProductPicker(ctx: ctx, products: products, exclude: exclude));

class _ProductPicker extends StatefulWidget {
  final MartCtx ctx;
  final List<Json> products;
  final Set<String> exclude;
  const _ProductPicker({required this.ctx, required this.products, required this.exclude});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ctx = widget.ctx;
    final t = _q.text.trim().toLowerCase();
    final exact = widget.products.where((p) => t.isNotEmpty && str(p['barcode']) == t).toList();
    final list = (exact.isNotEmpty ? exact : widget.products.where((p) => p['active'] != false && (t.isEmpty || str(p['name']).toLowerCase().contains(t) || str(p['barcode']).startsWith(t))))
        .where((p) => !widget.exclude.contains(str(p['_id'])))
        .take(40)
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Field(
              controller: _q,
              hint: ctx.x('pickProduct'),
              icon: LucideIcons.search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                tooltip: ctx.t('app.scanBarcode'),
                icon: const Icon(LucideIcons.scanBarcode, size: 18),
                onPressed: () async {
                  final v = await scanBarcode(context, ctx.t);
                  if (v == null) return;
                  final hit = widget.products.where((p) => str(p['barcode']) == v).firstOrNull;
                  if (hit != null && context.mounted) return Navigator.pop(context, hit);
                  setState(() => _q.text = v);
                },
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Muted(ctx.m('noProducts')))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(str(p['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [str(p['barcode']), if (p['track_stock'] == true && ctx.stockOn) '${ctx.m('inStock')}: ${qtyOf(p['stock'])}'].where((x) => x.isNotEmpty).join(' · '),
                          style: TextStyle(color: c.muted, fontSize: 12.5),
                        ),
                        trailing: Text(money(p['price'], ctx.cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// a field that shows the picked product (tap to choose)
class ProductField extends StatelessWidget {
  final MartCtx ctx;
  final String? label;
  final Json? value;
  final VoidCallback onTap;
  const ProductField({super.key, required this.ctx, this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[Text(label!, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8)],
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(value == null ? LucideIcons.search : LucideIcons.package, size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? ctx.x('pickProduct') : str(value!['name']),
                    style: TextStyle(fontWeight: value == null ? FontWeight.w400 : FontWeight.w700, color: value == null ? c.muted : c.ink, fontSize: 15.5),
                  ),
                ),
                Icon(LucideIcons.chevronDown, size: 16, color: c.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// a day (YYYY-MM-DD) chosen with the date picker
class DayField extends StatelessWidget {
  final String? label;
  final String value; // '' = none
  final String hint;
  final ValueChanged<String> onChanged;
  final DateTime? first, last;
  const DayField({super.key, this.label, required this.value, required this.onChanged, this.hint = '—', this.first, this.last});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[Text(label!, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8)],
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final now = DateTime.parse(todayKH());
            final d = await showDatePicker(context: context, firstDate: first ?? DateTime(2020), lastDate: last ?? DateTime(now.year + 10), initialDate: DateTime.tryParse(value) ?? now);
            if (d != null) onChanged(d.toIso8601String().substring(0, 10));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 17, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value.isEmpty ? hint : '${mDay(value, lang)} ${value.substring(0, 4)}',
                    style: TextStyle(color: value.isEmpty ? c.muted : c.ink, fontWeight: FontWeight.w600),
                  ),
                ),
                if (value.isNotEmpty)
                  InkWell(
                    onTap: () => onChanged(''),
                    child: Icon(LucideIcons.x, size: 15, color: c.muted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// day / month for reports → params ({day} or {month})
class Period {
  String mode = 'month', day = todayKH(), month = todayKH().substring(0, 7);
  Map<String, String> get params => mode == 'day' ? {'day': day} : {'month': month};
  String get key => mode == 'day' ? day : month;
}

String prevMonth(String m) {
  final y = int.parse(m.substring(0, 4)), mm = int.parse(m.substring(5, 7));
  return mm == 1 ? '${y - 1}-12' : '$y-${(mm - 1).toString().padLeft(2, '0')}';
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String monthName(String m, String lang) => '${(lang == 'km' ? _monKm : _monEn)[int.parse(m.substring(5, 7)) - 1]} ${m.substring(0, 4)}';

// Today · This month · Last month + ‹ month › stepper
class PeriodBar extends StatelessWidget {
  final MartCtx ctx;
  final Period p;
  final VoidCallback onChanged;
  const PeriodBar({super.key, required this.ctx, required this.p, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = todayKH().substring(0, 7);
    final sel = p.mode == 'day' && p.day == todayKH()
        ? 'today'
        : p.mode == 'month' && p.month == now
        ? 'month'
        : p.mode == 'month' && p.month == prevMonth(now)
        ? 'last'
        : '';
    String nextMonth(String m) {
      final y = int.parse(m.substring(0, 4)), mm = int.parse(m.substring(5, 7));
      return mm == 12 ? '${y + 1}-01' : '$y-${(mm + 1).toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            value: sel,
            options: [('today', ctx.x('today')), ('month', ctx.x('month')), ('last', ctx.x('lastMonth'))],
            onChanged: (v) {
              if (v == 'today') {
                p.mode = 'day';
                p.day = todayKH();
              } else {
                p.mode = 'month';
                p.month = v == 'month' ? now : prevMonth(now);
              }
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (p.mode == 'day') {
                  p.day = addDaysKH(p.day, -1);
                } else {
                  p.month = prevMonth(p.month);
                }
                onChanged();
              },
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
            ),
            Expanded(
              child: Text(
                p.mode == 'day' ? '${mDay(p.day, ctx.lang)} ${p.day.substring(0, 4)}' : monthName(p.month, ctx.lang),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: c.ink),
              ),
            ),
            IconButton(
              onPressed: (p.mode == 'day' ? p.day == todayKH() : p.month == now)
                  ? null
                  : () {
                      if (p.mode == 'day') {
                        p.day = addDaysKH(p.day, 1);
                      } else {
                        p.month = nextMonth(p.month);
                      }
                      onChanged();
                    },
              icon: const Icon(LucideIcons.chevronRight, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

// a coloured pill (ok / warn / bad / info / plain)
class Pill extends StatelessWidget {
  final String text;
  final String tone;
  const Pill(this.text, {super.key, this.tone = ''});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      'ok' => (c.goodBg, c.good),
      'warn' => (c.warnBg, c.warn),
      'bad' => (c.dangerBg, c.danger),
      'info' => (const Color(0xFF2563EB).withValues(alpha: .12), const Color(0xFF2563EB)),
      _ => (c.bg2, c.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// a card with a title row (+ an optional trailing widget)
Widget mCard(BuildContext context, String title, List<Widget> children, {Widget? trailing, String? sub}) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ?trailing,
        ],
      ),
      if (sub != null) ...[const SizedBox(height: 4), Muted(sub)],
      const SizedBox(height: 10),
      ...children,
    ],
  ),
);

// a number field that keeps only digits, dot and minus
const decimalKeys = TextInputType.numberWithOptions(decimal: true);
num? numOf(String s) => num.tryParse(s.trim());
String r3(num v) => qtyOf((v * 1000).round() / 1000);
