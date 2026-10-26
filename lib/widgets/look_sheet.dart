import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import 'ui.dart';

// One way, everywhere in the app, to look at a style before using or buying it (themes, POS looks, receipt
// templates, page designs, card designs…): tap a style → this sheet opens on it with a big preview, swipe left /
// right for the next one, and the Use / Buy buttons stay at the bottom (no scrolling to find the preview).
//
//   showLookSheet(context, count: keys.length, initial: i, item: (ctx, i, refresh) => LookItem(...))

class LookAct {
  final String label;
  final IconData? icon;
  final bool gold; // a paid unlock (coins)
  final bool ghost;
  // return true to close the sheet afterwards (e.g. before opening the coin sheet)
  final Future<bool> Function()? onTap;
  const LookAct(this.label, {this.icon, this.gold = false, this.ghost = false, this.onTap});
}

class LookItem {
  final String name;
  final String? sub; // a short line under the name (style · colour, price…)
  final Widget preview;
  final String? badge; // In use / Owned / Free / 15 coins
  final Tone badgeTone;
  final List<Widget> extras; // own colours, options… (between the preview and the buttons)
  final List<LookAct> acts;
  // true: the preview has its own size (a phone screen, an A4 sheet…) and is scaled to fit · false: it fills the space
  final bool fit;
  const LookItem({required this.name, required this.preview, this.sub, this.badge, this.badgeTone = Tone.muted, this.extras = const [], this.acts = const [], this.fit = true});
}

typedef LookBuilder = LookItem Function(BuildContext context, int index, VoidCallback refresh);

Future<void> showLookSheet(BuildContext context, {String title = '', required int count, required int initial, required LookBuilder item}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _LookSheet(title: title, count: count, initial: initial.clamp(0, count - 1), item: item),
);

class _LookSheet extends StatefulWidget {
  final String title;
  final int count, initial;
  final LookBuilder item;
  const _LookSheet({required this.title, required this.count, required this.initial, required this.item});
  @override
  State<_LookSheet> createState() => _LookSheetState();
}

class _LookSheetState extends State<_LookSheet> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _i = widget.initial;
  String _busy = '';

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int d) {
    final to = (_i + d).clamp(0, widget.count - 1);
    if (to != _i) _pages.animateToPage(to, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = MediaQuery.sizeOf(context).height;
    final cur = widget.item(context, _i, () => setState(() {}));
    return SizedBox(
      height: h * .9,
      child: Column(
        children: [
          // name + where you are
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                RoundBtn(LucideIcons.chevronLeft, size: 38, onTap: _i > 0 ? () => _go(-1) : null),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.title.isNotEmpty) Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(cur.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      if (widget.count > 1) Text('${_i + 1} / ${widget.count}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RoundBtn(LucideIcons.chevronRight, size: 38, onTap: _i < widget.count - 1 ? () => _go(1) : null),
              ],
            ),
          ),
          // the big preview: swipe for the next one
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.count,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) {
                final it = i == _i ? cur : widget.item(context, i, () => setState(() {}));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Center(child: it.fit ? FittedBox(fit: BoxFit.contain, child: it.preview) : it.preview),
                );
              },
            ),
          ),
          // what it is + the buttons, always on screen
          Container(
            decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.line))),
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cur.badge != null || (cur.sub ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (cur.badge != null) Chip2(cur.badge!, tone: cur.badgeTone, icon: cur.badgeTone == Tone.good ? LucideIcons.circleCheck : null),
                        if ((cur.sub ?? '').isNotEmpty) Text(cur.sub!, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ...cur.extras,
                for (final (j, a) in cur.acts.indexed) ...[
                  if (j > 0) const SizedBox(height: 8),
                  _btn(a),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(LookAct a) {
    final key = a.label;
    Future<void> tap() async {
      setState(() => _busy = key);
      final close = await a.onTap!();
      if (!mounted) return;
      setState(() => _busy = '');
      // close this sheet itself — never what was opened on top of it (the coin sheet from a Buy button)
      if (close) {
        final route = ModalRoute.of(context);
        if (route == null || !route.isActive) return;
        if (route.isCurrent) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).removeRoute(route);
        }
      }
    }

    final off = a.onTap == null || _busy.isNotEmpty;
    if (a.gold) return _Gold(a.label, busy: _busy == key, onTap: off ? null : tap);
    return Btn(a.label, icon: a.icon, kind: a.ghost ? BtnKind.ghost : BtnKind.primary, expand: true, busy: _busy == key, onTap: off ? null : tap);
  }
}

// the big gold "Unlock · 25 coins" button
class _Gold extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  const _Gold(this.label, {this.busy = false, this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null && !busy ? .5 : 1,
    child: Material(
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 50,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFE0A21A)])),
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF3A2500))) else const CoinIcon(size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3A2500), fontSize: 15.5)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
