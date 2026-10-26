import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_common.dart' show money;

// Shared pieces of the Guest House screens (the web's dashboard/client/guesthouse/text.js helpers + the dashboard ctx).
//   GET /api/user/businesses/:id/guesthouse → { data: { business, license, limits, free, addons{key:{price,active,expires_at}}, renew_price,
//                                                     settings, services, types, rooms, counts{rooms,types,live}, lists{sources,methods,id_types,amenities} } }

class GhCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String addon, {String? item, VoidCallback? onDone}) askBuy; // add-on, "guest_house" (renew), or a look with item
  final void Function(String tab) go;
  final void Function(String text) notify;
  const GhCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/guesthouse';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get settings => obj(data['settings']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  Json get counts => obj(data['counts']);
  List<Json> get types => objs(data['types']);
  List<Json> get rooms => objs(data['rooms']);
  List<Json> get services => objs(data['services']);
  List<String> list(String k) => (obj(data['lists'])[k] as List? ?? const []).map((e) => '$e').toList();
  List<String> get methods {
    final m = (settings['methods'] as List? ?? const []).map((e) => '$e').toList();
    return m.isEmpty ? ['cash'] : m;
  }

  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool addonOn(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['locked'] == true;
  String get cur => str(settings['currency']).isEmpty ? 'USD' : str(settings['currency']);
  String g(String key, [Map<String, Object?> vars = const {}]) => t('gh.$key', vars);
  String method(String k) => t.or('gh.methods.$k', k);
  Json? typeOf(Object? id) => types.where((x) => x['_id'] == id).firstOrNull;
  Json? roomOf(Object? id) => rooms.where((x) => x['_id'] == id).firstOrNull;
  String mo(Object? v) => money(v, cur);
  // printing: on (gh_printer), template, paper, auto print, QR on the bill
  Json get print => {
    'on': addonOn('gh_printer'),
    'theme': str(settings['print_theme']).isEmpty ? 'classic' : settings['print_theme'],
    'size': str(settings['print_size']).isEmpty ? '80' : '${settings['print_size']}',
    'auto': settings['print_auto'] == true,
    'qr': settings['print_qr'] != false,
  };

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy(str(e.body['product']));
    if (e is ApiError) return notify(e.network ? t('app.offline') : e.message);
    notify('$e');
  }

  // run a call; a 402 opens the shop, other errors show as a toast
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

// -------------------------------------------------------------------------------------------- days
const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
const _monLongEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _wdKm = ['ច', 'អ', 'ពុ', 'ព្រ', 'សុ', 'ស', 'អា'];
const _wdLongEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _wdLongKm = ['ថ្ងៃចន្ទ', 'ថ្ងៃអង្គារ', 'ថ្ងៃពុធ', 'ថ្ងៃព្រហស្បតិ៍', 'ថ្ងៃសុក្រ', 'ថ្ងៃសៅរ៍', 'ថ្ងៃអាទិត្យ'];

DateTime? _d(String day) => DateTime.tryParse('${day}T00:00:00Z');

// "12 Oct" · with weekday "Mon 12 Oct" · long "Monday 12 October"
String ghDay(String day, String lang, {bool weekday = false, bool year = false}) {
  final d = _d(day);
  if (d == null) return '';
  final km = lang == 'km';
  final s = '${d.day} ${(km ? _monKm : _monEn)[d.month - 1]}${year ? ' ${d.year}' : ''}';
  return weekday ? '${(km ? _wdKm : _wdEn)[d.weekday - 1]} $s' : s;
}

String ghDayLong(String day, String lang) {
  final d = _d(day);
  if (d == null) return '';
  return lang == 'km' ? '${_wdLongKm[d.weekday - 1]} ${d.day} ${_monKm[d.month - 1]}' : '${_wdLongEn[d.weekday - 1]} ${d.day} ${_monLongEn[d.month - 1]}';
}

String ghWeekday(String day, String lang) {
  final d = _d(day);
  return d == null ? '' : (lang == 'km' ? _wdKm : _wdEn)[d.weekday - 1];
}

bool ghWeekend(String day) => (_d(day)?.weekday ?? 1) >= 6;

String ghMonth(String m, String lang) {
  final i = int.parse(m.substring(5, 7)) - 1;
  return '${(lang == 'km' ? _monKm : _monLongEn)[i]} ${m.substring(0, 4)}';
}

String shiftMonth(String m, int by) {
  final y = int.parse(m.substring(0, 4)), mm = int.parse(m.substring(5, 7)) - 1 + by;
  final d = DateTime.utc(y, mm + 1, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

int nightsOf(String from, String to) {
  final a = _d(from), b = _d(to);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays;
}

// ------------------------------------------------------------------------------------------- widgets
// status pill of a stay (booked · in · out · cancelled · no_show)
class StayStatus extends StatelessWidget {
  final GhCtx ctx;
  final String status;
  const StayStatus(this.ctx, this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (status) {
      'booked' => (const Color(0xFF2563EB).withValues(alpha: .12), const Color(0xFF2563EB)),
      'in' => (c.goodBg, c.good),
      'out' => (c.bg2, c.muted),
      _ => (c.dangerBg, c.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        ctx.g('status.$status'),
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// a stay as one row: room tag · guest · dates · balance (+ an action on the right)
class StayRow extends StatelessWidget {
  final GhCtx ctx;
  final Json s;
  final String today;
  final bool showNo, showTotal, showStatus;
  final Widget? action;
  final VoidCallback onTap;
  const StayRow({super.key, required this.ctx, required this.s, required this.onTap, this.today = '', this.showNo = false, this.showTotal = false, this.showStatus = false, this.action});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final b = obj(s['bill']);
    final guest = obj(s['guest']);
    final late = s['status'] == 'booked' && today.isNotEmpty && str(s['from']).compareTo(today) < 0;
    final owe = n(b['balance']) > 0 && (!showStatus || ['booked', 'in', 'out'].contains(s['status']));
    final color = hexColor(str(ctx.typeOf(s['type_id'])?['color']), const Color(0xFF2563EB));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 48),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Text(
                str(s['room_name']),
                style: TextStyle(fontWeight: FontWeight.w800, color: c.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: str(guest['name'])),
                        if (showNo)
                          TextSpan(
                            text: '  ${str(s['no'])}',
                            style: TextStyle(color: c.muted, fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                        if (late)
                          TextSpan(
                            text: '  ${ctx.g('late')}',
                            style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${ghDay(str(s['from']), ctx.lang)} → ${ghDay(str(s['to']), ctx.lang)} · ${ctx.g('nights', {'n': n(b['nights'])})}'),
                        if (showTotal) TextSpan(text: ' · ${ctx.mo(b['total'])}'),
                        if (owe)
                          TextSpan(
                            text: ' · ${ctx.g('balance')} ${ctx.mo(b['balance'])}',
                            style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (showStatus) ...[const SizedBox(width: 8), StayStatus(ctx, str(s['status']))],
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

// − 2 + (people, nights)
class Stepper2 extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const Stepper2({super.key, required this.value, this.min = 0, this.max = 99, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget b(IconData i, bool on, int to) => InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: on ? () => onChanged(to) : null,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? c.card : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Icon(i, size: 16, color: on ? c.ink : c.muted.withValues(alpha: .5)),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          b(LucideIcons.minus, value > min, value - 1),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          b(LucideIcons.plus, value < max, value + 1),
        ],
      ),
    );
  }
}

// a row of choice chips (sources, ID types, methods, amenities)
class Chips<V> extends StatelessWidget {
  final List<(V, String)> options;
  final bool Function(V) on;
  final ValueChanged<V>? onTap;
  final Widget Function(V)? trail;
  const Chips({super.key, required this.options, required this.on, this.onTap, this.trail});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (v, label) in options)
          Material(
            color: on(v) ? c.active : c.bg2,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: onTap == null ? null : () => onTap!(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: on(v) ? c.brand : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (on(v)) ...[Icon(LucideIcons.check, size: 13, color: c.brandInk), const SizedBox(width: 4)],
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on(v) ? c.brandInk : c.ink),
                    ),
                    if (trail != null) trail!(v),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// a label above a field
class Label extends StatelessWidget {
  final String text;
  final String? hint;
  const Label(this.text, {super.key, this.hint});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (hint != null && hint!.isNotEmpty) ...[const SizedBox(height: 2), Muted(hint!)],
      ],
    ),
  );
}

Color hexColor(String hex, [Color fallback = const Color(0xFF64748B)]) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

const ghColors = ['#2563EB', '#16A34A', '#7C3AED', '#DB2777', '#EA580C', '#0891B2', '#CA8A04', '#475569'];

// gallery or camera → the picture's bytes
Future<Uint8List?> ghPickPicture(BuildContext context, GhCtx ctx, {int maxSize = 1200, bool cameraFirst = false}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in cameraFirst ? [ImageSource.camera, ImageSource.gallery] : [ImageSource.gallery, ImageSource.camera])
            ListTile(
              leading: Icon(k == ImageSource.camera ? LucideIcons.camera : LucideIcons.image),
              title: Text(k == ImageSource.camera ? ctx.t('app.takePhoto') : ctx.g('upload')),
              onTap: () => Navigator.pop(s, k),
            ),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final f = await ImagePicker().pickImage(source: src, maxWidth: maxSize.toDouble(), maxHeight: maxSize.toDouble(), imageQuality: 85);
  return f?.readAsBytes();
}
