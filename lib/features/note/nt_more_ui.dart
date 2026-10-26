import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_common.dart';
import 'nt_more_text.dart';

// Small pieces of the Digital Note dashboard sections (the same look as the other businesses' pages:
// a head panel, add-on cards, the - 1 + stepper, the storage meter, the views-per-day bars).

// the panel on top of a section: icon + title + a short line (+ buttons)
Widget ntHead(BuildContext context, IconData icon, String title, String sub, {List<Widget> actions = const [], Widget? trailing}) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: context.c.active, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 21, color: context.c.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          ?trailing,
        ],
      ),
      if (sub.isNotEmpty) ...[const SizedBox(height: 8), Muted(sub)],
      if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions)],
    ],
  ),
);

const ntGap = SizedBox(height: 12);

// an add-on card: icon, name, price line, what it does, (a picture), the buttons
class NtAddonCard extends StatelessWidget {
  final IconData icon;
  final String name, price, what;
  final bool on;
  final Widget? art;
  final List<Widget> foot;
  final String? testKey;
  const NtAddonCard({super.key, required this.icon, required this.name, required this.price, required this.what, this.on = false, this.art, this.foot = const [], this.testKey});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      key: testKey == null ? null : ValueKey(testKey),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: on ? c.goodBg : c.active, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: on ? c.good : c.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Row(
                      children: [
                        const CoinIcon(size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            price,
                            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(what, style: const TextStyle(height: 1.45)),
          if (art != null) ...[const SizedBox(height: 12), art!],
          if (foot.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: foot),
          ],
        ],
      ),
    );
  }
}

// - 1 +
class NtStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const NtStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 20});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
      color: c.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 17, color: onTap == null ? c.lineStrong : c.ink),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(LucideIcons.minus, value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          btn(LucideIcons.plus, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

// "700 MB of 5 GB used" + a bar (red when nearly full); parts = coloured pieces per file type
class NtStorageMeter extends StatelessWidget {
  final NtCtx ctx;
  final num used, limit;
  final List<(Color, num)> parts;
  final String? right;
  const NtStorageMeter({super.key, required this.ctx, required this.used, required this.limit, this.parts = const [], this.right});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = limit > 0 ? (used / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final hot = pct >= .9;
    final partsSum = parts.fold<num>(0, (a, p) => a + p.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ctx.m('mediaUsed', {'used': ntBytes(used), 'limit': ntBytes(limit)}),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
            Text(
              right ?? '${(pct * 100).round()}%',
              style: TextStyle(color: hot ? c.danger : c.muted, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: c.bg2)),
                if (parts.isEmpty)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    heightFactor: 1,
                    child: ColoredBox(color: hot ? c.danger : c.brand),
                  )
                else
                  Row(
                    children: [
                      for (final (col, b) in parts)
                        if (b > 0 && limit > 0) Expanded(flex: ((b / limit) * 10000).round().clamp(1, 10000), child: ColoredBox(color: col, child: const SizedBox.expand())),
                      // what the listed files don't cover (logo, group pictures…)
                      if (limit > 0 && used > partsSum) Expanded(flex: (((used - partsSum) / limit) * 10000).round().clamp(1, 10000), child: ColoredBox(color: c.brand.withValues(alpha: .35), child: const SizedBox.expand())),
                      if (limit > 0 && limit > used) Expanded(flex: (((limit - (used > partsSum ? used : partsSum)) / limit) * 10000).round().clamp(1, 10000), child: const SizedBox.shrink()),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// views per day (the last 30 days): small bars, the total and the best day — GET …/stats
class NtDayBars extends StatelessWidget {
  final NtCtx ctx;
  final Json stats; // { days: [{ day, views, people }], total: { views, people }, best: { day, views } }
  final String title;
  const NtDayBars({super.key, required this.ctx, required this.stats, required this.title});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = objs(stats['days']);
    final total = obj(stats['total']);
    final best = obj(stats['best']);
    final top = days.fold<num>(0, (a, d) => n(d['views']) > a ? n(d['views']) : a);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.chartColumn, size: 18, color: c.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Muted(ctx.m('statsSub')),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: ctx.m('statsViews'), value: fmt(n(total['views']))),
              const SizedBox(width: 10),
              _Stat(label: ctx.m('statsPeople'), value: fmt(n(total['people']))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 74,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Tooltip(
                      message: '${str(d['day'])} · ${ctx.m('statsTip', {'v': fmt(n(d['views'])), 'p': fmt(n(d['people']))})}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.2),
                        child: Container(
                          height: top > 0 ? (6 + 68 * (n(d['views']) / top)).toDouble() : 6,
                          decoration: BoxDecoration(
                            color: n(d['views']) > 0 ? c.brand.withValues(alpha: str(d['day']) == str(best['day']) ? 1 : .55) : c.bg2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            n(best['views']) > 0 ? '${ntDate(best['day'], ctx.lang)} · ${ctx.m('statsBest', {'n': fmt(n(best['views']))})}' : ctx.m('statsBestNone'),
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: context.c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: TextStyle(color: context.c.muted, fontSize: 12.5)),
        ],
      ),
    ),
  );
}

// pick a picture (gallery or camera) → (bytes, name, mime) or null
Future<(Uint8List, String, String)?> ntPickPicture(BuildContext context, NtCtx ctx, {int maxSize = 512}) async {
  final src = await showSheet<ImageSource>(
    context,
    (s) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(LucideIcons.image), title: Text(ntw(ctx, 'pickPhoto')), onTap: () => Navigator.pop(s, ImageSource.gallery)),
          ListTile(leading: const Icon(LucideIcons.camera), title: Text(ntw(ctx, 'takePhoto')), onTap: () => Navigator.pop(s, ImageSource.camera)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final f = await ImagePicker().pickImage(source: src, maxWidth: maxSize.toDouble(), maxHeight: maxSize.toDouble(), imageQuality: 90);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  final name = f.name.isEmpty ? 'picture.jpg' : f.name;
  final ext = name.toLowerCase().split('.').last;
  final mime = (f.mimeType ?? '').isNotEmpty ? f.mimeType! : (ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg'));
  return (bytes, name, mime);
}

// a small coloured pill (the web's rs-pill)
class NtPill extends StatelessWidget {
  final String text;
  final bool on, bad;
  final IconData? icon;
  const NtPill(this.text, {super.key, this.on = false, this.bad = false, this.icon});
  @override
  Widget build(BuildContext context) => Chip2(text, tone: bad ? Tone.danger : (on ? Tone.good : Tone.muted), icon: icon);
}
