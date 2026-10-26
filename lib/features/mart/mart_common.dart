import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/look_sheet.dart';
import '../../widgets/ui.dart';

// Shared pieces of the Mini Mart screens (the web's dashboard/client/mart/text.js helpers + the dashboard ctx).
//   GET /api/user/businesses/:id/mart → { data: { business, license, limits, free, addons{key:{price,active,expires_at}}, renew_price,
//                                                settings, categories, units, counts{products,staff,unread}, lists } }

class MartCtx {
  final String id;
  final Api api;
  final T t;
  final Json data;
  final Future<void> Function() reload;
  final void Function(String addon, {String? item, VoidCallback? onDone}) askBuy; // add-on, "mart" (renew), or a look with item
  final void Function(String tab) go;
  final void Function(String text) notify;
  const MartCtx({required this.id, required this.api, required this.t, required this.data, required this.reload, required this.askBuy, required this.go, required this.notify});

  String get base => '${Api.user}/businesses/$id/mart';
  String get lang => t.lang;
  Json get business => obj(data['business']);
  Json get settings => obj(data['settings']);
  Json get license => obj(data['license']);
  Json get limits => obj(data['limits']);
  Json get counts => obj(data['counts']);
  Json addon(String k) => obj(obj(data['addons'])[k]);
  bool addonOn(String k) => addon(k)['active'] == true;
  bool get readOnly => business['status'] == false || license['locked'] == true;
  String get cur => str(settings['currency']).isEmpty ? 'USD' : str(settings['currency']);
  String m(String key, [Map<String, Object?> vars = const {}]) => t('mart.$key', vars);
  String w(String key, [Map<String, Object?> vars = const {}]) => t('mw.$key', vars);
  String x(String key, [Map<String, Object?> vars = const {}]) => t('mx.$key', vars);
  bool get stockOn => addonOn('mart_stock');
  Json get shop => {'name': business['name'], 'logo_url': business['logo_url'], 'address': business['address'], 'phone': business['phone'], 'receipt_note': settings['receipt_note']};
  // printing: on (mart_printer), template, paper width
  Json get print => {
    'on': addonOn('mart_printer'),
    'theme': str(settings['print_theme']).isEmpty ? 'classic' : settings['print_theme'],
    'size': str(settings['print_size']).isEmpty ? '80' : '${settings['print_size']}',
  };

  // payment method names: built-in, the shop's own (mart_payments) or the name kept on the sale
  String methodName(String k, [String? saved]) {
    final b = t.maybe('mart.methods.$k');
    if (b != null) return b;
    if (saved != null && saved.isNotEmpty) return saved;
    final own = objs(settings['custom_methods']).where((x) => x['key'] == k).firstOrNull;
    return own == null ? k : str(own['name']);
  }

  void fail(Object e) {
    if (e is ApiError && e.status == 402 && e.body['product'] != null) return askBuy(str(e.body['product']));
    if (e is ApiError) return notify(e.network ? t('app.offline') : e.message);
    notify('$e');
  }
}

String todayKH() => DateTime.now().toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
String addDaysKH(String day, int d) => DateTime.parse('${day}T00:00:00Z').add(Duration(days: d)).toIso8601String().substring(0, 10);

String _group(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

// $1,234.50 / 5,000៛ — negative as −$0.02
String money(Object? v, [String cur = 'USD']) {
  final x = n(v);
  if (x < 0 && x.abs() >= (cur == 'KHR' ? .5 : .005)) return '−${money(-x, cur)}';
  if (cur == 'KHR') return '${_group(x.abs().round())}៛';
  final cents = (x.abs() * 100).round();
  return '\$${_group(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
}

String riel(Object? v) => '${_group(n(v).round())}៛';
String qtyOf(Object? q) {
  final x = n(q);
  if (x == x.roundToDouble()) return '${x.toInt()}';
  return x.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}

const _monEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
String _p2(int x) => x.toString().padLeft(2, '0');
DateTime? _kh(Object? v) => DateTime.tryParse('${v ?? ''}')?.toUtc().add(const Duration(hours: 7));
String mTime(Object? v) {
  final d = _kh(v);
  return d == null ? '' : '${_p2(d.hour)}:${_p2(d.minute)}';
}

String mDayTime(Object? v, String lang) {
  final d = _kh(v);
  return d == null ? '' : '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]}, ${_p2(d.hour)}:${_p2(d.minute)}';
}

String mDate(Object? v, String lang) {
  final d = _kh(v);
  return d == null ? '' : '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]} ${d.year}';
}

// "14 Oct" for a YYYY-MM-DD day
String mDay(String day, String lang) {
  final d = DateTime.tryParse('${day}T00:00:00Z');
  return d == null ? '' : '${d.day} ${(lang == 'km' ? _monKm : _monEn)[d.month - 1]}';
}

String unitName(Json? u, String lang) {
  if (u == null || u.isEmpty) return '';
  final km = str(u['name_km']), en = str(u['name_en']);
  return lang == 'km' ? (km.isNotEmpty ? km : en) : (en.isNotEmpty ? en : km);
}

// ------------------------------------------------------------------------------------------- widgets
// a card head: icon tile + title + small text (+ a button on the right)
class MHead extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData? icon;
  final Widget? trailing;
  const MHead(this.title, {super.key, this.sub, this.icon, this.trailing});
  // a long text next to a button: the button goes under the text
  bool get _below => trailing != null && (sub ?? '').length > 40;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final head = Padding(
      padding: EdgeInsets.only(bottom: _below ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, size: 20, color: c.brandInk),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 3), Muted(sub!)],
              ],
            ),
          ),
          if (trailing != null && !_below) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (!_below) return head;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        Padding(
          padding: EdgeInsets.only(left: icon != null ? 54 : 0, bottom: 12),
          child: trailing!,
        ),
      ],
    );
  }
}

// gold "Unlock" button with the coin price
class GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const GoldBtn(this.label, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .5 : 1,
    child: Material(
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)])),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500), fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// a locked feature: what it does + unlock (the web's at-mgr-note with a gold button)
class LockNote extends StatelessWidget {
  final String text, button;
  final VoidCallback? onTap;
  const LockNote({super.key, required this.text, required this.button, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFC53D).withValues(alpha: .14),
        border: Border.all(color: const Color(0xFFFFC53D).withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.lock, size: 16, color: c.ink),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(height: 1.4, fontSize: 13.5))),
            ],
          ),
          const SizedBox(height: 10),
          GoldBtn(button, onTap: onTap),
        ],
      ),
    );
  }
}

// "Remove" → "Sure?"
class SureDelete extends StatefulWidget {
  final String remove, sure;
  final VoidCallback? onDelete;
  const SureDelete({super.key, required this.remove, required this.sure, this.onDelete});
  @override
  State<SureDelete> createState() => _SureDeleteState();
}

class _SureDeleteState extends State<SureDelete> {
  bool _sure = false;
  @override
  Widget build(BuildContext context) => _sure
      ? Btn(widget.sure, kind: BtnKind.danger, small: true, onTap: widget.onDelete)
      : Btn(widget.remove, icon: LucideIcons.trash2, kind: BtnKind.ghost, small: true, onTap: widget.onDelete == null ? null : () => setState(() => _sure = true));
}

// four numbers in two rows (the web's at-tiles)
class Tiles extends StatelessWidget {
  final List<(String value, String label, Color? tone)> items;
  const Tiles(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (_, box) {
        final cols = box.maxWidth > 560 ? 4 : 2;
        final w = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, (v, l, tone)) in items.indexed)
              Container(
                width: w,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: i == 0 ? c.active : c.bg2, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        v,
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: tone ?? (i == 0 ? c.brandInk : c.ink)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// one bar of a list (method, best seller…)
class BarRow extends StatelessWidget {
  final String label, value;
  final String? sub;
  final num pct;
  final Widget? lead;
  const BarRow({super.key, required this.label, required this.value, this.sub, required this.pct, this.lead});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ?lead,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: label),
                            if (sub != null)
                              TextSpan(
                                text: '  $sub',
                                style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1).toDouble(), minHeight: 6, color: c.brand, backgroundColor: c.bg2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const mGap = SizedBox(height: 14);

// gallery or camera → the picture's bytes
Future<Uint8List?> pickPicture(BuildContext context, MartCtx ctx, {int maxSize = 1000}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(LucideIcons.image), title: Text(ctx.m('upload')), onTap: () => Navigator.pop(s, ImageSource.gallery)),
          ListTile(leading: const Icon(LucideIcons.camera), title: Text(ctx.t('app.takePhoto')), onTap: () => Navigator.pop(s, ImageSource.camera)),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final f = await ImagePicker().pickImage(source: src, maxWidth: maxSize.toDouble(), maxHeight: maxSize.toDouble(), imageQuality: 88);
  return f?.readAsBytes();
}

// a picture with Upload / Change / Remove (gallery or camera)
class MImagePick extends StatelessWidget {
  final MartCtx ctx;
  final String url;
  final Uint8List? bytes;
  final bool busy, disabled, wide;
  final int maxSize;
  final Future<void> Function(Uint8List bytes, String name) onPick;
  final VoidCallback? onRemove;
  const MImagePick({
    super.key,
    required this.ctx,
    required this.url,
    this.bytes,
    required this.onPick,
    this.onRemove,
    this.busy = false,
    this.disabled = false,
    this.wide = false,
    this.maxSize = 1000,
  });

  Future<void> _choose(BuildContext context) async {
    final b = await pickPicture(context, ctx, maxSize: maxSize);
    if (b != null) await onPick(b, 'photo.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = bytes != null || url.isNotEmpty;
    return Row(
      children: [
        Container(
          width: wide ? 96 : 60,
          height: 60,
          decoration: BoxDecoration(
            color: c.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : url.isNotEmpty
              ? Image(image: netImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
              : Icon(LucideIcons.imagePlus, size: 22, color: c.muted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Btn(
            busy ? ctx.m('uploading') : (has ? ctx.m('change2') : ctx.m('upload')),
            icon: LucideIcons.imagePlus,
            kind: BtnKind.ghost,
            small: true,
            busy: busy,
            onTap: busy || disabled ? null : () => _choose(context),
          ),
        ),
        if (has && !busy && onRemove != null) ...[const SizedBox(width: 6), RoundBtn(LucideIcons.trash2, size: 38, tip: ctx.m('remove'), fg: c.danger, onTap: disabled ? null : onRemove)],
      ],
    );
  }
}

FormData fileForm(String field, List<int> bytes, String name) => FormData.fromMap({field: MultipartFile.fromBytes(bytes, filename: name)});

// a sheet with the camera that returns the first barcode it reads
Future<String?> scanBarcode(BuildContext context, T t) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true, // above the bottom bar when opened from a tab
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.black,
  builder: (_) => _Scan(t: t),
);

class _Scan extends StatefulWidget {
  final T t;
  const _Scan({required this.t});
  @override
  State<_Scan> createState() => _ScanState();
}

class _ScanState extends State<_Scan> {
  final _cam = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;
  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .7,
    child: Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _cam,
            onDetect: (cap) {
              final v = cap.barcodes.map((b) => b.rawValue ?? '').firstWhere((x) => x.isNotEmpty, orElse: () => '');
              if (v.isEmpty || _done) return;
              _done = true;
              Navigator.pop(context, v.replaceAll(RegExp(r'\s'), ''));
            },
            errorBuilder: (_, e) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.t('app.qrNoCamera'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 260,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Text(
            widget.t('app.pointAtBarcode'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton.filled(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- looks (POS, receipts, websites, order pages…)
// a card in a grid of looks: the picture + its name + one status line. Tap → the look sheet (big preview, Use / Buy).
class MLookCard extends StatelessWidget {
  final Widget picture;
  final String name, status;
  final bool on, locked, good;
  final VoidCallback onTap;
  const MLookCard({super.key, required this.picture, required this.name, required this.status, required this.onTap, this.on = false, this.locked = false, this.good = true});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? c.brand : c.line, width: on ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  picture,
                  if (locked)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.lock, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (on) ...[Icon(LucideIcons.check, size: 12, color: c.good), const SizedBox(width: 3)],
                        if (locked) ...[const CoinIcon(size: 12), const SizedBox(width: 3)],
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: locked ? c.muted : (good ? c.good : c.muted), fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// the look sheet for a grid of looks: tap one → its big preview, swipe for the others; Use (owned) or Unlock (coins)
Future<void> openLookSheet(
  BuildContext context, {
  required String title,
  required List<String> keys,
  required String start,
  required String current,
  required bool Function(String key) owned,
  required String Function(String key) name,
  required Widget Function(String key) big, // a fixed-size preview (it is scaled to fit)
  required String Function(String key) status, // In use / Free / Yours / 15 coins
  required String useLabel,
  required String Function(String key) buyLabel,
  required Future<bool> Function(String key) use, // true = done (close)
  required void Function(String key) buy, // opens the coin sheet
  bool readOnly = false,
  List<Widget> Function(String key, VoidCallback refresh)? extras,
  String Function(String key)? sub, // a short line about the look
}) => showLookSheet(
  context,
  title: title,
  count: keys.length,
  initial: keys.contains(start) ? keys.indexOf(start) : 0,
  item: (context, i, refresh) {
    final k = keys[i];
    final mine = owned(k);
    return LookItem(
      name: name(k),
      sub: sub?.call(k),
      preview: big(k),
      badge: status(k),
      badgeTone: k == current || mine ? Tone.good : Tone.warn,
      extras: extras?.call(k, refresh) ?? const [],
      acts: [
        if (k != current && mine) LookAct(useLabel, icon: LucideIcons.check, onTap: readOnly ? null : () => use(k)),
        if (!mine)
          LookAct(
            buyLabel(k),
            gold: true,
            onTap: readOnly
                ? null
                : () async {
                    // after the look sheet has closed (it closes when this returns true)
                    Future.delayed(const Duration(milliseconds: 60), () => buy(k));
                    return true;
                  },
          ),
      ],
    );
  },
);
