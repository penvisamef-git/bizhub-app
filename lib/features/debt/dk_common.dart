import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../team/team_data.dart' show teamViewOnly;
import '../mart/mart_common.dart' show GoldBtn, todayKH;

// Debt Book — shared pieces (the web's dashboard/client/debt/text.js helpers + the dashboard ctx).
//   GET /api/user/businesses/:id/debt → { data: { business, book, license, addons, base_price, limits, totals, telegram, owner } }

class DkCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String addon) askBuy;
  final void Function(String tab, {String? customer}) go;
  final void Function(String text) notify;
  const DkCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/debt';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get book => obj(data['book']);
  Json get totals => obj(data['totals']);
  Json get limits => obj(data['limits']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get owner => data['owner'] != false;
  // View only team members (v1.5) can look but not change anything
  bool get readOnly => teamViewOnly(id) || business['status'] == false;
  num get rate => n(book['rate']) == 0 ? 4100 : n(book['rate']);
  String m(String key, [Map<String, Object?> vars = const {}]) => t('debt.$key', vars);

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

String _group(num v) => fmt(v);

// $12.50 · 20,000៛
String dkMoney(String cur, Object? v) {
  final x = n(v);
  if (cur == 'KHR') return '${_group(x.round())}៛';
  final a = x.abs();
  final cents = (a * 100).round();
  final whole = cents ~/ 100, part = cents % 100;
  return '${x < 0 ? '-' : ''}\$${_group(whole)}${part == 0 ? '' : '.${part.toString().padLeft(2, '0')}'}';
}

// what someone owes, both currencies: "$12.50 + 20,000៛" (or "$0")
String owed(Object? b) {
  final m = obj(b);
  final parts = [if (n(m['usd']) > 0) dkMoney('USD', m['usd']), if (n(m['khr']) > 0) dkMoney('KHR', m['khr'])];
  return parts.isEmpty ? dkMoney('USD', 0) : parts.join(' + ');
}

bool owes(Object? b) => n(obj(b)['usd']) > 0 || n(obj(b)['khr']) > 0;
num totalUsd(Object? b, num rate) => (n(obj(b)['usd']) > 0 ? n(obj(b)['usd']) : 0) + (n(obj(b)['khr']) > 0 ? n(obj(b)['khr']) : 0) / (rate == 0 ? 4100 : rate);

// Cambodia day "2026-10-13"
String dayOf(Object? d) {
  final x = DateTime.tryParse('${d ?? ''}');
  return x == null ? '' : x.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
}

String? fromDay(String day) => day.isEmpty ? null : DateTime.parse('${day}T12:00:00+07:00').toUtc().toIso8601String();

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String dkDate(Object? d, String lang) {
  final day = dayOf(d);
  if (day.isEmpty) return '';
  final x = DateTime.parse('${day}T00:00:00Z');
  return '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]} ${x.year}';
}

String dkTime(Object? d, String lang) {
  final x = DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
  if (x == null) return '';
  return '${x.day} ${(lang == 'km' ? _monKm : _monEn)[x.month - 1]}, ${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
}

// late / today / soon / later / ''
String dueState(Json c) {
  if (c['due_at'] == null || !owes(c['balance'])) return '';
  final today = todayKH(), due = dayOf(c['due_at']);
  if (due.compareTo(today) < 0) return 'late';
  final days = DateTime.parse('${due}T00:00:00Z').difference(DateTime.parse('${today}T00:00:00Z')).inDays;
  return days == 0
      ? 'today'
      : days <= 7
      ? 'soon'
      : 'later';
}

int daysLate(Json c) {
  final d = DateTime.parse('${todayKH()}T00:00:00Z').difference(DateTime.parse('${dayOf(c['due_at'])}T00:00:00Z')).inDays;
  return d < 0 ? 0 : d;
}

String lineNote(Json e, DkCtx ctx) {
  final note = str(e['note']);
  if (note == 'Opening balance · ជំពាក់ពីមុន') return ctx.m('openingLine');
  if (note == 'Imported · នាំចូល') return ctx.m('importedLine');
  if (note.isNotEmpty) return note;
  return e['kind'] == 'pay' ? ctx.m('linePay') : ctx.m('lineDebt');
}

String nDays(DkCtx ctx, int n) => n == 1 ? ctx.m('day1') : ctx.m('days', {'n': n});
String statementUrl(Object? token) => '${Config.siteUrl}/d/$token';

const dkAddonIcons = <String, IconData>{'debt_remind': LucideIcons.bellRing, 'debt_more': LucideIcons.users, 'debt_excel': LucideIcons.fileSpreadsheet, 'debt_nobrand': LucideIcons.eyeOff};
const dkDebt = Color(0xFFDC2626), dkPay = Color(0xFF059669);

class DkAvatar extends StatelessWidget {
  final Json c;
  final double size;
  const DkAvatar(this.c, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final photo = str(c['photo']);
    final name = str(c['name']).trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: col.active, shape: BoxShape.circle),
      child: photo.isNotEmpty
          ? Image(image: netImage(photo), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, color: col.brandInk, fontSize: size * .42),
            ),
    );
  }
}

// paid off · 3 days late · due today · due 20 Oct
class DueChip extends StatelessWidget {
  final DkCtx ctx;
  final Json c;
  const DueChip({super.key, required this.ctx, required this.c});
  @override
  Widget build(BuildContext context) {
    if (!owes(c['balance'])) return Chip2(ctx.m('paidOff'), tone: Tone.good);
    final st = dueState(c);
    if (st.isEmpty) return const SizedBox.shrink();
    if (st == 'late') {
      final d = daysLate(c);
      return Chip2(d == 1 ? ctx.m('late1') : ctx.m('late', {'n': d}), icon: LucideIcons.alarmClock, tone: Tone.danger);
    }
    if (st == 'today') return Chip2(ctx.m('dueToday'), tone: Tone.warn);
    return Chip2(ctx.m('due', {'date': dkDate(c['due_at'], ctx.lang)}), tone: st == 'soon' ? Tone.warn : Tone.muted);
  }
}

Widget dkPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

Widget dkHead(BuildContext context, IconData icon, String title, String sub) => dkPanel([
  Row(
    children: [
      Icon(icon, size: 20, color: context.c.brand),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
    ],
  ),
  const SizedBox(height: 6),
  Muted(sub),
]);

// "this page needs an add-on" with a buy button (DebtMore.jsx Locked)
class DkLocked extends StatelessWidget {
  final DkCtx ctx;
  final String addon;
  const DkLocked({super.key, required this.ctx, required this.addon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = ctx.addon(addon);
    return dkPanel([
      Center(child: Icon(dkAddonIcons[addon] ?? LucideIcons.lock, size: 30, color: c.brand)),
      const SizedBox(height: 8),
      Text(
        ctx.m('addonNames.$addon'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 4),
      Muted(ctx.m('addonWhat.$addon'), align: TextAlign.center),
      const SizedBox(height: 8),
      for (final p in ctx.t.list('debt.perks.$addon'))
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.check, size: 15, color: c.good),
              const SizedBox(width: 8),
              Expanded(child: Text(p)),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Center(
        child: GoldBtn(ctx.m('unlock', {'coins': '${fmt(n(a['price']))} ${ctx.m('coins')}${a['days'] != null ? ' ${ctx.m('perYear')}' : ''}'}), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
      ),
    ]);
  }
}
