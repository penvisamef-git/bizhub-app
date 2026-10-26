import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../event/ev_common.dart' show askText;
import '../mart/mart_common.dart' show GoldBtn;
import '../team/team_data.dart' show teamViewOnly;

// Telegram Store (v2.0) — shared pieces of the app version of the web's dashboard/client/tgstore (same API, same words).
//   GET /api/user/businesses/:id/tgstore → { data: { business, store, license, counts, links, telegram, riders, khqr_auto,
//     addons, open_now, themes, history, pay_free } }

class TsCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(Json patch) put; // change the loaded data without asking the server again
  final void Function(String kind, {String? item}) askBuy; // 'renew' | an add-on key | 'theme' + design key
  final void Function(String tab) go;
  final void Function(String text) notify;
  const TsCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.put, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/tgstore';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get store => obj(data['store']);
  Json get license => obj(data['license']);
  Json get counts => obj(data['counts']);
  Json get links => obj(data['links']);
  Json get telegram => obj(data['telegram']);
  Json get riders => obj(data['riders']);
  Json get themes => obj(data['themes']);
  String get cur => str(store['currency']).isEmpty ? 'USD' : str(store['currency']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  // View only team members (v1.5) can look but not change anything
  bool get readOnly => teamViewOnly(id) || business['status'] == false || license['read_only'] == true;
  String get shopName => str(store['shop_name']).isNotEmpty ? str(store['shop_name']) : str(business['name']);
  String get webLink => str(links['web']);
  String get mainLink => str(links['telegram']).isNotEmpty ? str(links['telegram']) : webLink;

  // the owner's words (ts.*) and the store pages' words (tsp.*)
  String m(String key, [Map<String, Object?> vars = const {}]) => t('ts.$key', vars);
  String p(String key, [Map<String, Object?> vars = const {}]) => t('tsp.$key', vars);
  String money(Object? v) => tsMoney(v, cur);
  String ago(Object? v) => tsAgo(v, t);

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy(str(e.body['product']));
    if (e is ApiError) return notify(e.network ? t('app.offline') : e.message);
    notify('$e');
  }

  Future<Json?> run(Future<Json> Function() fn, [String? ok]) async {
    try {
      final r = await fn();
      if (ok != null) notify(ok);
      return r;
    } catch (e) {
      fail(e);
      return null;
    }
  }
}

// money: dollars with cents, riel whole
String tsMoney(Object? v, [String cur = 'USD']) {
  final x = n(v);
  return cur == 'KHR' ? '${fmt(x.round())}៛' : '\$${x.toStringAsFixed(2)}';
}

DateTime? tsDate(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
String _p2(int x) => x.toString().padLeft(2, '0');
String tsTime(Object? v) {
  final d = tsDate(v);
  return d == null ? '' : '${_p2(d.hour)}:${_p2(d.minute)}';
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String tsDay(Object? v, String lang) {
  final d = tsDate(v);
  if (d == null) return '';
  return '${d.day} ${lang == 'km' ? _monKm[d.month - 1] : _monEn[d.month - 1]} ${d.year}';
}

String tsYmd(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';

String tsAgo(Object? v, T t) {
  final d = tsDate(v);
  if (d == null) return '';
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return t('ts.justNow');
  if (s < 3600) return t('ts.minAgo', {'n': s ~/ 60});
  if (s < 86400) return t('ts.hAgo', {'n': s ~/ 3600});
  return t('ts.dAgo', {'n': s ~/ 86400});
}

Future<void> tsCopy(BuildContext context, String text, String done) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, done);
}

Future<void> tsOpen(String url) async {
  final u = Uri.tryParse(url);
  if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
}

const tsAddonIcons = <String, IconData>{
  'ts_promos': LucideIcons.tag,
  'ts_broadcast': LucideIcons.megaphone,
  'ts_reports': LucideIcons.chartColumn,
  'ts_hours': LucideIcons.clock,
  'ts_nobrand': LucideIcons.eyeOff,
  'ts_history': LucideIcons.history,
  'ts_pay': LucideIcons.creditCard,
  'ts_link': LucideIcons.link2,
  'ts_remind': LucideIcons.shoppingCart,
  'ts_zones': LucideIcons.map,
  'ts_riders': LucideIcons.bike,
  'ts_pos': LucideIcons.monitorSmartphone,
};
const tsModeIcons = <String, IconData>{'delivery': LucideIcons.bike, 'pickup': LucideIcons.shoppingBag, 'dine_in': LucideIcons.utensilsCrossed};

Tone tsStatusTone(String s) => switch (s) {
  'new' => Tone.brand,
  'accepted' => Tone.warn,
  'ready' || 'on_way' => Tone.lime,
  'done' => Tone.good,
  'cancelled' => Tone.danger,
  _ => Tone.muted,
};

// an add-on that isn't bought yet: what it does + Unlock (Locked on the web)
class TsLocked extends StatelessWidget {
  final TsCtx ctx;
  final String addon;
  final bool small;
  const TsLocked({super.key, required this.ctx, required this.addon, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    final yearly = a['days'] != null;
    final label = small ? ctx.m('unlock', {'coins': fmt(n(a['price']))}) : ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${yearly ? ' ${ctx.m('perYear')}' : ''}'});
    if (small) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(LucideIcons.lock, size: 15, color: c.warn),
            const SizedBox(width: 8),
            Expanded(child: Text(ctx.m('addonWhat.$addon'), style: TextStyle(fontSize: 13, color: c.warn, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            GoldBtn(label, onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
          ],
        ),
      );
    }
    return Panel(
      child: Column(
        children: [
          Icon(tsAddonIcons[addon] ?? LucideIcons.lock, size: 28, color: c.brand),
          const SizedBox(height: 8),
          Text(ctx.m('addonNames.$addon'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          Muted(ctx.m('addonWhat.$addon'), align: TextAlign.center),
          const SizedBox(height: 10),
          for (final p in ctx.t.list('ts.perks.$addon'))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.check, size: 14, color: c.good),
                  const SizedBox(width: 6),
                  Flexible(child: Text(p, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          GoldBtn(label, onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
        ],
      ),
    );
  }
}

// a small pill (ts-pill)
class TsPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Tone tone;
  const TsPill(this.text, {super.key, this.icon, this.tone = Tone.muted});
  @override
  Widget build(BuildContext context) => Chip2(text, icon: icon, tone: tone);
}

// one line with an icon (ts-order-line)
class TsLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? trailing;
  const TsLine(this.icon, this.text, {super.key, this.color, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: color ?? c.muted)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: color ?? c.ink))),
          ?trailing,
        ],
      ),
    );
  }
}

// one order: what, who, where, how paid + the buttons for its next step (OrderCard on the web).
// act(order, status, extra) — status 'paid' marks it paid, 'riders' sends it to the riders' group.
typedef TsAct = Future<void> Function(Json o, String status, [Json extra]);

class TsOrderCard extends StatefulWidget {
  final Json o;
  final T t;
  final bool readOnly, ridersOn, busy, plain;
  final TsAct act;
  final Widget? extra; // more buttons (Print on the staff screen)
  const TsOrderCard({super.key, required this.o, required this.t, required this.act, this.readOnly = false, this.ridersOn = false, this.busy = false, this.plain = false, this.extra});
  @override
  State<TsOrderCard> createState() => _TsOrderCardState();
}

class _TsOrderCardState extends State<TsOrderCard> {
  String m(String k, [Map<String, Object?> v = const {}]) => widget.t('ts.$k', v);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final o = widget.o;
    final cur = str(o['currency']).isEmpty ? 'USD' : str(o['currency']);
    final status = str(o['status']);
    final mode = str(o['mode']);
    final pay = obj(o['pay']);
    final payName = pay['method'] == 'custom' ? str(obj(pay['custom'])['name']) : m('payMethods.${pay['method']}');
    final open = !['done', 'cancelled'].contains(status);
    final who = obj(o['customer']);
    final zone = o['zone'] is Map ? obj(o['zone']) : null;
    final rider = o['rider'] is Map ? obj(o['rider']) : null;
    final off = widget.readOnly || widget.busy;
    Widget b(String key, String label, VoidCallback fn, {bool primary = false, IconData? icon}) => Btn(label, icon: icon, small: true, kind: primary ? BtnKind.primary : BtnKind.ghost, onTap: off ? null : fn, busy: false, key: ValueKey('ts-o${o['no']}-$key'));
    Future<void> reject() async {
      final why = await askText(context, title: m('rejectAsk'), hint: m('rejectPh'), ok: m('reject'), cancel: m('cancel'));
      if (why != null) await widget.act(o, 'cancelled', {'reason': why});
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('#${o['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            TsPill(m('statuses.$status'), tone: tsStatusTone(status)),
            TsPill('${m('modes.$mode')}${mode == 'dine_in' && str(o['table']).isNotEmpty ? ' ${o['table']}' : ''}', icon: tsModeIcons[mode]),
            TsPill('$payName · ${m('payStates.${pay['status']}')}', icon: LucideIcons.circleDollarSign, tone: pay['status'] == 'paid' ? Tone.good : (pay['status'] == 'proof' ? Tone.warn : Tone.muted)),
            if (o['from_remind'] == true) TsPill(m('wonBack'), icon: LucideIcons.shoppingCart, tone: Tone.warn),
            Text('${tsTime(o['created_date'])} · ${tsAgo(o['created_date'], widget.t)}', style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
        const SizedBox(height: 10),
        for (final l in objs(o['items']))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${fmt(n(l['qty']))} × ', style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: str(l['name'])),
                        if (objs(l['options']).isNotEmpty) TextSpan(text: ' · ${objs(l['options']).map((x) => str(x['choice'])).join(', ')}', style: TextStyle(color: c.muted, fontSize: 13)),
                        if (str(l['note']).isNotEmpty) TextSpan(text: ' — ${l['note']}', style: TextStyle(color: c.muted, fontStyle: FontStyle.italic, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(tsMoney(l['total'], cur)),
              ],
            ),
          ),
        if (n(o['discount']) > 0) _sumRow(context, '🏷 ${m('discount', {'code': o['promo']})}', '−${tsMoney(o['discount'], cur)}', muted: true),
        if (n(o['fee']) > 0) _sumRow(context, m('deliveryFee'), tsMoney(o['fee'], cur), muted: true),
        Divider(height: 14, color: c.line),
        _sumRow(context, m('total'), tsMoney(o['total'], cur), bold: true),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (str(who['name']).isNotEmpty) Text(str(who['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
            if (str(who['phone']).isNotEmpty)
              InkWell(
                onTap: () => tsOpen('tel:${who['phone']}'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.phone, size: 13, color: c.brand), const SizedBox(width: 4), Text(str(who['phone']), style: TextStyle(color: c.brand))]),
              ),
            if (str(who['username']).isNotEmpty)
              InkWell(onTap: () => tsOpen('https://t.me/${who['username']}'), child: Text('@${who['username']}', style: TextStyle(color: c.brand))),
            Text(o['via'] == 'telegram' ? m('viaTelegram') : m('viaWeb'), style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
        if (mode == 'delivery' && str(o['address']).isNotEmpty) TsLine(LucideIcons.mapPin, str(o['address'])),
        if (mode == 'delivery' && zone != null)
          TsLine(
            LucideIcons.map,
            [if (str(zone['name']).isNotEmpty && !str(zone['name']).endsWith(' km')) str(zone['name']), if (zone['km'] != null) '${zone['km']} km'].join(' · '),
            trailing: zone['lat'] == null
                ? null
                : InkWell(
                    onTap: () => tsOpen('https://maps.google.com/?q=${zone['lat']},${zone['lng']}'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.externalLink, size: 12, color: c.brand), const SizedBox(width: 3), Text(m('openMap'), style: TextStyle(color: c.brand, fontWeight: FontWeight.w700, fontSize: 13))]),
                  ),
          ),
        if (rider != null)
          TsLine(LucideIcons.bike, '${rider['name']}${str(rider['username']).isNotEmpty ? ' @${rider['username']}' : ''} · ${rider['delivered_at'] != null ? m('riderDone') : (rider['picked_at'] != null ? m('riderPicked') : m('riderTook'))} · ${tsTime(rider['delivered_at'] ?? rider['picked_at'] ?? rider['taken_at'])}'),
        if (mode == 'delivery' && rider == null && o['riders_sent'] == true && open) TsLine(LucideIcons.bike, m('ridersWaiting'), color: c.muted),
        if (str(o['note']).isNotEmpty) TsLine(LucideIcons.messageSquareText, str(o['note'])),
        if (status == 'accepted' && n(o['eta_min']) > 0) TsLine(LucideIcons.clock, m('eta', {'n': o['eta_min']})),
        if (status == 'cancelled' && str(o['reason']).isNotEmpty) TsLine(LucideIcons.x, str(o['reason']), color: c.danger),
        if (open || str(pay['proof']).isNotEmpty || pay['status'] != 'paid' || widget.extra != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'new') ...[
                b('accept', m('accept'), () => widget.act(o, 'accepted'), primary: true, icon: LucideIcons.check),
                b('eta15', m('min', {'n': 15}), () => widget.act(o, 'accepted', {'eta': 15}), icon: LucideIcons.clock),
                b('eta30', m('min', {'n': 30}), () => widget.act(o, 'accepted', {'eta': 30}), icon: LucideIcons.clock),
                b('reject', m('reject'), reject, icon: LucideIcons.x),
              ],
              if (status == 'accepted' && mode != 'delivery') b('ready', m('ready'), () => widget.act(o, 'ready'), primary: true),
              if (status == 'accepted' && mode == 'delivery') b('on_way', m('onWay'), () => widget.act(o, 'on_way'), primary: true, icon: LucideIcons.bike),
              if (['accepted', 'ready', 'on_way'].contains(status)) b('done', m('doneBtn'), () => widget.act(o, 'done'), primary: status != 'accepted', icon: LucideIcons.check),
              if (pay['status'] != 'paid' && status != 'cancelled') b('paid', m('markPaid'), () => widget.act(o, 'paid'), icon: LucideIcons.circleDollarSign),
              if (mode == 'delivery' && ['accepted', 'ready'].contains(status) && o['riders_sent'] != true && widget.ridersOn) b('riders', m('toRiders'), () => widget.act(o, 'riders'), icon: LucideIcons.send),
              if (str(pay['proof']).isNotEmpty) Btn(m('seeProof'), icon: LucideIcons.image, small: true, kind: BtnKind.ghost, onTap: () => _proof(context, str(pay['proof']))),
              ?widget.extra,
            ],
          ),
        ],
      ],
    );
    if (widget.plain) return body;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status == 'new' ? c.brand : c.line, width: status == 'new' ? 1.6 : 1),
      ),
      child: widget.busy ? Stack(children: [body, const Positioned.fill(child: Center(child: CircularProgressIndicator()))]) : body,
    );
  }

  Widget _sumRow(BuildContext context, String a, String b, {bool bold = false, bool muted = false}) {
    final c = context.c;
    final st = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: muted ? c.muted : c.ink, fontSize: bold ? 15 : 14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [Expanded(child: Text(a, style: st)), Text(b, style: st)]),
    );
  }

  void _proof(BuildContext context, String url) => showDialog<void>(
    context: context,
    builder: (d) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InteractiveViewer(child: Image(image: netImage(url), fit: BoxFit.contain)),
          Positioned(top: 8, right: 8, child: RoundBtn(LucideIcons.x, size: 38, onTap: () => Navigator.pop(d))),
        ],
      ),
    ),
  );
}

// the day's KPIs on top of Orders (ts-kpi)
class TsKpi extends StatelessWidget {
  final String label, value;
  final bool hot;
  const TsKpi(this.label, this.value, {super.key, this.hot = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hot ? c.active : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hot ? c.brand : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: hot ? c.brandInk : c.ink)),
        ],
      ),
    );
  }
}

// a grid of TsKpi (2 per row on a phone, 4 on a tablet)
class TsKpis extends StatelessWidget {
  final List<Widget> children;
  const TsKpis(this.children, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 640 ? (children.length >= 5 ? 5 : 4) : 2;
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (final x in children) SizedBox(width: w, child: x)]);
    },
  );
}

// a card section with a title (panel-card + ts-h3)
class TsCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final String? sub;
  final List<Widget> children;
  final Widget? trailing;
  const TsCard({super.key, this.title, this.icon, this.sub, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 17, color: c.brand), const SizedBox(width: 8)],
                Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                ?trailing,
              ],
            ),
            if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 4), Muted(sub!)],
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

// a QR code for a link (with the owner's colours and logo when "Own link & QR" is on)
class TsQr extends StatelessWidget {
  final String text;
  final double size;
  final Color fg, bg;
  final String logo;
  const TsQr(this.text, {super.key, this.size = 168, this.fg = const Color(0xFF1F1A16), this.bg = Colors.white, this.logo = ''});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.c.line)),
    child: QrImageView(
      data: text.isEmpty ? ' ' : text,
      size: size,
      padding: EdgeInsets.zero,
      backgroundColor: bg,
      errorCorrectionLevel: logo.isNotEmpty ? QrErrorCorrectLevel.H : QrErrorCorrectLevel.M,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: fg),
      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: fg),
      embeddedImage: logo.isNotEmpty ? netImage(logo) : null,
      embeddedImageStyle: QrEmbeddedImageStyle(size: Size(size * .22, size * .22)),
    ),
  );
}
