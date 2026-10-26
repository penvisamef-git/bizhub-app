import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart' show fmt;
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show GoldBtn;

// Event Tickets — shared pieces (the web's dashboard/client/event: text.js words + the dashboard ctx).
//   GET /api/user/businesses/:id/events → { data: { business, org, pay_methods, hold_minutes, khqr_ready, listed, license,
//     addons, limits, themes, page_themes, cert_themes, feature, events, waiting, team } }

class EvCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String kind, {String? item}) askBuy; // 'renew' | an add-on key | 'feature' + event id
  final void Function(String tab, {String event, String status}) go;
  final void Function(String text) notify;
  final String event; // the event a tab opens with (from "Orders" / "Guests" on an event card)
  final String status;
  const EvCtx({
    required this.id,
    required this.api,
    required this.t,
    required this.data,
    required this.reload,
    required this.askBuy,
    required this.go,
    required this.notify,
    this.event = '',
    this.status = '',
  });

  String get base => '${Api.user}/businesses/$id/events';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get org => obj(data['org']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  List<Json> get events => objs(data['events']);
  List<Json> get payMethods => objs(data['pay_methods']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool on(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['read_only'] == true;
  String get orgName => str(org['name']).isNotEmpty ? str(org['name']) : str(business['name']);
  Json? eventById(String eid) => events.where((e) => str(e['_id']) == eid).firstOrNull;

  // the owner's words (ev.*) and the buyer pages' words (evp.*)
  String m(String key, [Map<String, Object?> vars = const {}]) => t('ev.$key', vars);
  String p(String key, [Map<String, Object?> vars = const {}]) => t('evp.$key', vars);
  String a(String key, [Map<String, Object?> vars = const {}]) => t('evapp.$key', vars);

  // the first event to show: the one asked for, else the next coming one, else the newest
  String firstEvent() {
    if (event.isNotEmpty && eventById(event) != null) return event;
    final now = DateTime.now().subtract(const Duration(days: 1));
    final soon = events.where((e) => e['status'] != 'draft' && (evDate(e['ends_at'] ?? e['starts_at'])?.isAfter(now) ?? false)).toList()
      ..sort((x, y) => (evDate(x['starts_at']) ?? now).compareTo(evDate(y['starts_at']) ?? now));
    if (soon.isNotEmpty) return str(soon.first['_id']);
    return events.isEmpty ? '' : str(events.first['_id']);
  }

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

String eventUrl(Object? slug) => '${Config.siteUrl}/ev/$slug';
String orderUrl(Object? token) => '${Config.siteUrl}/ev/o/$token';
String ticketUrl(Object? code) => '${Config.siteUrl}/ev/t/$code';
DateTime? evDate(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
String usd2(Object? v) {
  final x = n(v);
  return '\$${x % 1 == 0 ? fmt(x) : x.toStringAsFixed(2)}';
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
const _dayEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _dayKm = ['ច័ន្ទ', 'អង្គារ', 'ពុធ', 'ព្រហស្បតិ៍', 'សុក្រ', 'សៅរ៍', 'អាទិត្យ'];
String _p2(int x) => x.toString().padLeft(2, '0');
// "Sat 14 Nov 2026, 19:00"
String evWhen(Object? v, String lang, {bool time = true, bool year = true}) {
  final d = evDate(v);
  if (d == null) return '';
  final km = lang == 'km';
  final s = '${km ? _dayKm[d.weekday - 1] : _dayEn[d.weekday - 1]} ${d.day} ${km ? _monKm[d.month - 1] : _monEn[d.month - 1]}${year ? ' ${d.year}' : ''}';
  return time ? '$s, ${_p2(d.hour)}:${_p2(d.minute)}' : s;
}

String evTime(Object? v) {
  final d = evDate(v);
  return d == null ? '' : '${_p2(d.hour)}:${_p2(d.minute)}';
}

Future<void> evCopy(EvCtx ctx, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  ctx.notify(ctx.m('copied'));
}

// live now / upcoming / draft / past / cancelled
String evPhase(Json e, [DateTime? now]) {
  now ??= DateTime.now();
  if (e['status'] == 'cancelled') return 'cancelled';
  if (e['status'] == 'draft') return 'draft';
  final start = evDate(e['starts_at']) ?? now;
  final end = evDate(e['ends_at']) ?? start.add(const Duration(hours: 4));
  if (end.isBefore(now)) return 'past';
  if (!start.isAfter(now)) return 'live';
  return 'upcoming';
}

num evQty(Json e) => objs(e['types']).fold<num>(0, (a, t) => a + n(t['qty']));

const evAddonIcons = <String, IconData>{
  'ev_doors': LucideIcons.smartphone,
  'ev_team': LucideIcons.users,
  'ev_cashier': LucideIcons.store,
  'ev_invites': LucideIcons.gift,
  'ev_export': LucideIcons.download,
  'ev_nobrand': LucideIcons.sparkles,
  'ev_telegram': LucideIcons.bellRing,
  'ev_guest_tg': LucideIcons.send,
  'ev_seats': LucideIcons.armchair,
  'ev_shows': LucideIcons.calendarClock,
  'ev_promos': LucideIcons.tag,
  'ev_questions': LucideIcons.messageSquareText,
  'ev_autopay': LucideIcons.qrCode,
  'ev_certs': LucideIcons.award,
  'ev_waitlist': LucideIcons.hourglass,
  'ev_pricing': LucideIcons.timer,
  'ev_referrals': LucideIcons.megaphone,
  'ev_bundles': LucideIcons.layers,
  'ev_feedback': LucideIcons.star,
  'ev_sponsors': LucideIcons.handshake,
};
const evAddonOrder = [
  'ev_autopay',
  'ev_certs',
  'ev_waitlist',
  'ev_pricing',
  'ev_referrals',
  'ev_bundles',
  'ev_feedback',
  'ev_sponsors',
  'ev_telegram',
  'ev_guest_tg',
  'ev_seats',
  'ev_shows',
  'ev_promos',
  'ev_questions',
  'ev_cashier',
  'ev_invites',
  'ev_doors',
  'ev_team',
  'ev_export',
  'ev_nobrand',
];

// an add-on that isn't bought yet: what it does + Unlock (LockedBox on the web)
class EvLocked extends StatelessWidget {
  final EvCtx ctx;
  final String addon;
  final Widget child;
  const EvLocked({super.key, required this.ctx, required this.addon, required this.child});
  @override
  Widget build(BuildContext context) {
    if (ctx.on(addon)) return child;
    final c = context.c;
    final a = ctx.addon(addon);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(evAddonIcons[addon] ?? LucideIcons.lock, size: 18, color: c.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ctx.m('addonNames.$addon'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Icon(LucideIcons.lock, size: 14, color: c.muted),
            ],
          ),
          const SizedBox(height: 6),
          Text(ctx.m('addonWhat.$addon'), style: TextStyle(fontSize: 13, color: c.muted)),
          const SizedBox(height: 10),
          GoldBtn(ctx.m('unlock', {'coins': fmt(n(a['price']))}), onTap: ctx.readOnly ? null : () => ctx.askBuy(addon)),
        ],
      ),
    );
  }
}

// a horizontal row of choice chips
class EvChips extends StatelessWidget {
  final List<(String, String, num?)> items; // value, label, count
  final String value;
  final ValueChanged<String> onPick;
  const EvChips({super.key, required this.items, required this.value, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (v, label, count) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: v == value ? c.solid : c.chip,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onPick(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: v == value ? c.onSolid : c.ink),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            fmt(count),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: v == value ? c.onSolid.withValues(alpha: .7) : c.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// one number on top of a tab
class EvStat extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Tone? tone;
  final VoidCallback? onTap;
  const EvStat(this.label, this.value, {super.key, this.sub, this.tone, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = switch (tone) {
      Tone.good => c.good,
      Tone.warn => c.warn,
      Tone.danger => c.danger,
      Tone.brand => c.brand,
      _ => c.ink,
    };
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone == Tone.warn ? c.warn : c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: col),
              ),
              if (sub != null)
                Text(
                  sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// a grid of EvStat (2 per row on a phone)
class EvStats extends StatelessWidget {
  final List<Widget> children;
  const EvStats(this.children, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 640 ? 4 : 2;
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final x in children) SizedBox(width: w, child: x)],
      );
    },
  );
}

// "Which event?" — a button that opens a searchable list
class EvEventPick extends StatelessWidget {
  final EvCtx ctx;
  final String value;
  final ValueChanged<String> onChanged;
  final bool all;
  const EvEventPick({super.key, required this.ctx, required this.value, required this.onChanged, this.all = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final e = ctx.eventById(value);
    // the same box as the other select boxes (SelectField), opening a searchable list
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final v = await pickEvent(context, ctx, value, all: all);
        if (v != null) onChanged(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: const BoxConstraints(minHeight: 54),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e == null ? (all ? ctx.m('allEvents') : ctx.m('pickEvent')) : str(e['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: c.ink, fontWeight: FontWeight.w500),
                  ),
                  if (e != null) Text(evWhen(e['starts_at'], ctx.lang), style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

// a list to choose from (the same sheet as SelectField)
Future<String?> evPickFrom(BuildContext context, String title, List<(String, String)> options, {String? value}) async {
  final c = context.c;
  final r = await showModalBottomSheet<(String,)>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
            for (final (v, l) in options)
              ListTile(
                title: Text(l, style: TextStyle(fontWeight: v == value ? FontWeight.w800 : FontWeight.w500)),
                trailing: v == value ? Icon(LucideIcons.check, color: c.brand) : null,
                onTap: () => Navigator.pop(ctx, (v,)),
              ),
          ],
        ),
      ),
    ),
  );
  return r?.$1;
}

Future<String?> pickEvent(BuildContext context, EvCtx ctx, String value, {bool all = false}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _EventSheet(ctx: ctx, value: value, all: all),
);

class _EventSheet extends StatefulWidget {
  final EvCtx ctx;
  final String value;
  final bool all;
  const _EventSheet({required this.ctx, required this.value, required this.all});
  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final q = _q.text.trim().toLowerCase();
    final list = [...ctx.events]..sort((a, b) => (evDate(b['starts_at']) ?? DateTime(0)).compareTo(evDate(a['starts_at']) ?? DateTime(0)));
    final shown = list.where((e) => q.isEmpty || str(e['title']).toLowerCase().contains(q) || str(e['venue']).toLowerCase().contains(q)).toList();
    Widget row(String id, String title, String sub) => ListTile(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: id == widget.value ? FontWeight.w800 : FontWeight.w600),
      ),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: id == widget.value ? Icon(LucideIcons.check, color: c.brand) : null,
      onTap: () => Navigator.pop(context, id),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Field(controller: _q, hint: ctx.m('searchEvent'), icon: LucideIcons.search, onChanged: (_) => setState(() {}), autofocus: false),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.all) row('', ctx.m('allEvents'), ''),
                for (final e in shown) row(str(e['_id']), str(e['title']), '${evWhen(e['starts_at'], ctx.lang)}${e['status'] != 'published' ? ' · ${ctx.m('status.${e['status']}')}' : ''}'),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Muted(ctx.m('noMatch'), align: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ask for a line of text (reject reason, refund amount…)
Future<String?> askText(BuildContext context, {required String title, String hint = '', String initial = '', String ok = 'OK', String cancel = 'Cancel', TextInputType? keyboard}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(cancel)),
        FilledButton(onPressed: () => Navigator.pop(d, ctl.text), child: Text(ok)),
      ],
    ),
  );
}

Future<bool> askSure(BuildContext context, String text, {String ok = 'OK', String cancel = 'Cancel', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(d, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

// a tab's list body: pull to refresh, 16 px sides
class EvList extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  const EvList({super.key, required this.children, required this.onRefresh});
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: children,
    ),
  );
}

// a small title row inside a tab
class EvHead extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  const EvHead(this.title, {super.key, this.sub, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 2), Muted(sub!)],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

// status colours of an order / a ticket
Tone orderTone(String s) => switch (s) {
  'paid' => Tone.good,
  'review' => Tone.warn,
  'pending' => Tone.brand,
  'rejected' || 'cancelled' => Tone.danger,
  _ => Tone.muted,
};
