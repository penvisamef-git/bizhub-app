import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../guesthouse/gh_common.dart' show GhCtx, ghPickPicture;

// Shared pieces of the Attendance screens (the web's dashboard/client/attendance/text.js helpers + the dashboard ctx).
//   GET /api/user/businesses/:id/attendance → { data: { business, license, limits, counts, setup, staff, shifts, branches, rules, code,
//                                                      slots, staff_slots, slot_price, renew_price, addons, selfie_required, qr_theme, qr_note } }

class AtCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  // "renew" · an add-on key · "att_branch" / "att_staff" (a slot; item = renew that one) · a look with item
  final void Function(String key, {String? item, VoidCallback? onDone}) askBuy;
  final void Function(String tab) go;
  final void Function(String text) notify;
  const AtCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/attendance';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  Json get counts => obj(data['counts']);
  Json get setup => obj(data['setup']);
  Json get rules => obj(data['rules']);
  List<Json> get staff => objs(data['staff']);
  List<Json> get shifts => objs(data['shifts']);
  List<Json> get branches => objs(data['branches']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool addonOn(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['locked'] == true;
  String a(String key, [Map<String, Object?> vars = const {}]) => t('att.$key', vars);
  Json? shiftOf(Object? id) => shifts.where((s) => s['_id'] == id).firstOrNull;

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) {
      final p = str(e.body['product']);
      return askBuy(p, item: e.body['item'] == null ? null : str(e.body['item']));
    }
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

// "1h 05m" from minutes; "25m" under an hour
String dur(Object? min) {
  final m = n(min).round();
  if (m == 0) return '0';
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h${m % 60 > 0 ? ' ${(m % 60).toString().padLeft(2, '0')}m' : ''}';
}

// "08:05" Cambodia time from a date
String hhmm(Object? d) {
  final x = DateTime.tryParse('${d ?? ''}')?.toUtc().add(const Duration(hours: 7));
  return x == null ? '' : '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
}

String initial(Object? name) {
  final s = '${name ?? ''}'.trim();
  return s.isEmpty ? '?' : s.characters.first.toUpperCase();
}

Color atHex(String hex, [Color fallback = const Color(0xFF2563EB)]) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  return h.length == 6 && v != null ? Color(0xFF000000 | v) : fallback;
}

const atColors = ['#2563EB', '#16A34A', '#F59E0B', '#DC2626', '#7C3AED', '#0891B2', '#DB2777', '#475569'];
const dayOrder = [1, 2, 3, 4, 5, 6, 0];

// a round letter avatar (shift colour)
class AtAvatar extends StatelessWidget {
  final Object? name;
  final String color;
  final double size;
  const AtAvatar(this.name, {super.key, this.color = '', this.size = 40});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = color.isEmpty ? null : atHex(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: col ?? c.active, shape: BoxShape.circle),
      child: Text(
        initial(name),
        style: TextStyle(fontWeight: FontWeight.w800, color: col != null ? Colors.white : c.brandInk, fontSize: size * .42),
      ),
    );
  }
}

// a small coloured tag (late, OT, flags…)
class AtTag extends StatelessWidget {
  final String text;
  final String tone; // ok · warn · bad · blue · ''
  final IconData? icon;
  const AtTag(this.text, {super.key, this.tone = '', this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      'ok' => (c.goodBg, c.good),
      'warn' => (c.warnBg, c.warn),
      'bad' => (c.dangerBg, c.danger),
      'blue' => (const Color(0xFF2563EB).withValues(alpha: .12), const Color(0xFF2563EB)),
      _ => (c.bg2, c.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

// the status of a day (present, late, absent…)
String statusTone(String s) => switch (s) {
  'present' => 'ok',
  'working' => 'blue',
  'absent' || 'missing_out' => 'bad',
  'not_yet' || 'leave' || 'holiday' => 'warn',
  _ => '',
};

Widget atPanel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(16)}) => Panel(
  padding: padding,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

// busy + error + "saved" for an editor sheet; a 402 closes it and opens the shop
mixin AtSave<W extends StatefulWidget> on State<W> {
  bool busy = false;
  String error = '';
  AtCtx get actx;
  Future<bool> save(Future<Json> Function() fn, {bool reload = true, String? ok}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final r = await fn();
      if (reload) await actx.reload();
      actx.notify(ok ?? (r['kept'] == true ? actx.a('keptOff') : actx.a('saved')));
      if (mounted) Navigator.pop(context, true);
      return true;
    } on ApiError catch (e) {
      if (e.status == 402 && e.body['product'] != null) {
        if (mounted) Navigator.pop(context);
        final p = str(e.body['product']);
        actx.askBuy(p);
      } else if (mounted) {
        setState(() {
          busy = false;
          error = e.network ? actx.t('app.offline') : e.message;
        });
      }
      return false;
    }
  }

  List<Widget> footer({required bool canSave, required VoidCallback onSave, VoidCallback? onRemove}) => [
    if (onRemove != null) _Sure(remove: actx.a('remove'), sure: actx.a('confirmDelete'), onDelete: busy ? null : onRemove),
    const Spacer(),
    Btn(actx.a('cancel'), kind: BtnKind.ghost, small: true, onTap: busy ? null : () => Navigator.pop(context)),
    const SizedBox(width: 8),
    Btn(busy ? actx.a('saving') : actx.a('save'), small: true, busy: busy, onTap: busy || !canSave ? null : onSave),
  ];
}

class _Sure extends StatefulWidget {
  final String remove, sure;
  final VoidCallback? onDelete;
  const _Sure({required this.remove, required this.sure, this.onDelete});
  @override
  State<_Sure> createState() => _SureState();
}

class _SureState extends State<_Sure> {
  bool _sure = false;
  @override
  Widget build(BuildContext context) => _sure
      ? Btn(widget.sure, kind: BtnKind.danger, small: true, onTap: widget.onDelete)
      : Btn(widget.remove, icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: widget.onDelete == null ? null : () => setState(() => _sure = true));
}

// camera / gallery picker (the guest house one; it only needs the api + words)
Future<Uint8List?> atPickPicture(BuildContext context, AtCtx a, {int maxSize = 1200, bool cameraFirst = false}) => ghPickPicture(
  context,
  GhCtx(id: a.id, api: a.api, t: a.t, data: const {}, reload: a.reload, askBuy: (_, {item, onDone}) {}, go: a.go, notify: a.notify),
  maxSize: maxSize,
  cameraFirst: cameraFirst,
);
