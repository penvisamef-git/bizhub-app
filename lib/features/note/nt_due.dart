import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_extras_text.dart';

// Checklist due date + who (free): "📅 Friday 9:00 · 👤 Dara" under a checklist line; late (not ticked) in red.
// due = "YYYY-MM-DD" or "YYYY-MM-DDTHH:mm" in Cambodia time (UTC+7) — the web's note/due.jsx.

DateTime _today() {
  final x = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime.utc(x.year, x.month, x.day);
}

DateTime? _dayOf(String due) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(due);
  if (m == null) return null;
  return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String _timeOf(String due) => due.length >= 16 ? due.substring(11, 16) : '';
String _two(int v) => v.toString().padLeft(2, '0');
String ntDueKey(DateTime d, [String time = '']) => '${d.year}-${_two(d.month)}-${_two(d.day)}${time.isEmpty ? '' : 'T$time'}';

// late = the day (and time) has passed, Cambodia time
bool ntDueLate(String due) {
  final d = _dayOf(due);
  if (d == null) return false;
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final t = _timeOf(due);
  if (t.isEmpty) return d.isBefore(_today());
  final at = d.add(Duration(hours: int.parse(t.substring(0, 2)), minutes: int.parse(t.substring(3, 5))));
  return at.isBefore(DateTime.utc(now.year, now.month, now.day, now.hour, now.minute));
}

String ntDueLabel(NtCtx ctx, String due) {
  final d = _dayOf(due);
  if (d == null) return '';
  final diff = d.difference(_today()).inDays;
  final day = switch (diff) {
    0 => ctx.m('dueToday'),
    1 => ctx.m('dueTomorrow'),
    -1 => ctx.m('dueYesterday'),
    _ => ntDate(d.subtract(const Duration(hours: 7)).toIso8601String(), ctx.lang),
  };
  final t = _timeOf(due);
  return t.isEmpty ? day : '$day $t';
}

// the line under a checklist item (also tappable in the editor)
class NtDueLine extends StatelessWidget {
  final NtCtx ctx;
  final NtBlock block;
  final VoidCallback? onTap;
  const NtDueLine({super.key, required this.ctx, required this.block, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final late = block.due.isNotEmpty && !block.done && ntDueLate(block.due);
    final col = late ? c.danger : c.muted;
    final parts = <Widget>[
      if (block.due.isNotEmpty) ...[
        Icon(LucideIcons.calendarClock, size: 13, color: col),
        const SizedBox(width: 4),
        Text(
          late ? '${ntDueLabel(ctx, block.due)} · ${ctx.m('dueLate')}' : ntDueLabel(ctx, block.due),
          style: TextStyle(color: col, fontSize: 12.5, fontWeight: late ? FontWeight.w800 : FontWeight.w600, decoration: TextDecoration.none),
        ),
      ],
      if (block.due.isNotEmpty && block.who.isNotEmpty) Text('  ·  ', style: TextStyle(color: c.muted, fontSize: 12.5)),
      if (block.who.isNotEmpty) ...[
        Icon(LucideIcons.user, size: 13, color: c.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            block.who,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ];
    final line = Padding(
      padding: const EdgeInsets.only(left: 34, bottom: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
    if (onTap == null) return Align(alignment: Alignment.centerLeft, child: line);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: line),
    );
  }
}

// the read-only look of a checklist line: the text + its due line
Widget ntCheckView(NtBlockView v) {
  final b = v.block;
  if (b.due.isEmpty && b.who.isEmpty) return NtTextView(view: v);
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [NtTextView(view: v), NtDueLine(ctx: v.ctx, block: b)]);
}

// under a checklist line in the editor
Widget? ntDueBelow(NtEditorApi? ed, NtBlockView v) {
  final b = v.block;
  if (b.t != 'check' || (b.due.isEmpty && b.who.isEmpty)) return null;
  return NtDueLine(ctx: v.ctx, block: b, onTap: ed == null || ed.readOnly ? null : () => ntDueSheet(ed, b));
}

// the toolbar button: the selected checklist line
Future<void> ntDueTool(NtEditorApi ed) async {
  final b = ed.currentBlock;
  if (b == null || b.t != 'check') {
    ed.ctx.notify(ntE(ed.ctx, 'dueAddSub'));
    return;
  }
  await ntDueSheet(ed, b);
}

Future<void> ntDueSheet(NtEditorApi ed, NtBlock b) async {
  final out = await showSheet<(String, String)>(ed.context, (_) => NtDueSheet(ctx: ed.ctx, due: b.due, who: b.who));
  if (out == null) return;
  b
    ..due = out.$1
    ..who = out.$2;
  ed.rebuild();
  ed.changed();
}

class NtDueSheet extends StatefulWidget {
  final NtCtx ctx;
  final String due, who;
  const NtDueSheet({super.key, required this.ctx, this.due = '', this.who = ''});
  @override
  State<NtDueSheet> createState() => _NtDueSheetState();
}

class _NtDueSheetState extends State<NtDueSheet> {
  late DateTime? _day = _dayOf(widget.due);
  late String _time = _timeOf(widget.due);
  late final _who = TextEditingController(text: widget.who);
  List<String> _people = const [];

  NtCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    ctx.a.people().then((r) {
      if (mounted) setState(() => _people = [for (final x in (r['data'] as List? ?? const [])) '$x']);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _who.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = _today();
    final first = now.subtract(const Duration(days: 365)), last = now.add(const Duration(days: 3650));
    // a due date further back (or ahead) than the picker goes starts it at the nearest end
    var start = _day ?? now;
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    final d = await showDatePicker(context: context, initialDate: start, firstDate: first, lastDate: last);
    if (d != null) setState(() => _day = DateTime.utc(d.year, d.month, d.day));
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final h = parts.length == 2 ? int.tryParse(parts[0]) : null, mi = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final t = await showTimePicker(context: context, initialTime: h == null || mi == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: h.clamp(0, 23), minute: mi.clamp(0, 59)));
    if (t != null) setState(() => _time = '${_two(t.hour)}:${_two(t.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = _today();
    final q = _who.text.trim().toLowerCase();
    final names = _people.where((p) => p.toLowerCase() != q && (q.isEmpty || p.toLowerCase().contains(q))).take(10).toList();
    Widget quick(String label, DateTime d) {
      final on = _day == d;
      return ChoiceChip(label: Text(label), selected: on, onSelected: (_) => setState(() => _day = d));
    }

    return MSheet(
      title: ctx.m('dueTitle'),
      footer: [
        TextButton(onPressed: () => Navigator.pop(context, ('', '')), child: Text(ctx.m('dueClear'))),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, (_day == null ? '' : ntDueKey(_day!, _time), _who.text.trim().length > 60 ? _who.text.trim().substring(0, 60) : _who.text.trim())),
          icon: const Icon(LucideIcons.check, size: 16),
          label: Text(ctx.m('dueDone')),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            quick(ctx.m('dueToday'), today),
            quick(ctx.m('dueTomorrow'), today.add(const Duration(days: 1))),
            quick(ctx.m('dueNextWeek'), today.add(const Duration(days: 7))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PickBox(icon: LucideIcons.calendar, label: ctx.m('dueDate'), value: _day == null ? '—' : ntDueLabel(ctx, ntDueKey(_day!)), onTap: _pickDay),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickBox(
                icon: LucideIcons.clock,
                label: ctx.m('dueTime'),
                value: _time.isEmpty ? '—' : _time,
                onTap: _day == null ? null : _pickTime,
                onClear: _time.isEmpty ? null : () => setState(() => _time = ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _who,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: ctx.m('dueWho'), hintText: ctx.m('dueWhoPh'), counterText: '', prefixIcon: const Icon(LucideIcons.user, size: 18)),
        ),
        if (names.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final p in names) ActionChip(avatar: Avatar(name: p, size: 20), label: Text(p), onPressed: () => setState(() => _who.text = p))],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LucideIcons.bellRing, size: 14, color: c.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(ctx.m('dueHint'), style: TextStyle(color: c.muted, fontSize: 12.5))),
          ],
        ),
      ],
    );
  }
}

class _PickBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap, onClear;
  const _PickBox({required this.icon, required this.label, required this.value, this.onTap, this.onClear});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11.5)),
                      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                if (onClear != null) IconButton(visualDensity: VisualDensity.compact, onPressed: onClear, icon: Icon(LucideIcons.x, size: 16, color: c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// str() kept for callers that read due / who off raw json
String ntDueOf(Json b) => str(b['due']);
