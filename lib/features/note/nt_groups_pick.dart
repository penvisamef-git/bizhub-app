import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/buy_sheet.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_common.dart';

// Groups of notes in small places: the picture / folder icon, the "groups for this note" picker and
// "create a group" (paid: the note_group price, once per group). The Groups section itself is phase 2.

class NtGroupIcon extends StatelessWidget {
  final Json group;
  final double size;
  const NtGroupIcon(this.group, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) {
    final col = ntAccent(str(group['color']));
    final pic = str(group['icon_image']);
    final emoji = str(group['icon']);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(size * .32)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: pic.isNotEmpty
          ? Image(image: netImage(pic), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(LucideIcons.folder, size: size * .5, color: col))
          : emoji.isNotEmpty
          ? Text(emoji, style: TextStyle(fontSize: size * .5))
          : Icon(LucideIcons.folder, size: size * .5, color: col),
    );
  }
}

// a small chip with a group's name (in lists)
class NtGroupChip extends StatelessWidget {
  final Json group;
  final bool on;
  final VoidCallback? onTap;
  const NtGroupChip(this.group, {super.key, this.on = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = ntAccent(str(group['color']));
    final body = Container(
      padding: EdgeInsets.symmetric(horizontal: onTap == null ? 8 : 12, vertical: onTap == null ? 3 : 7),
      decoration: BoxDecoration(
        color: on ? col.withValues(alpha: .16) : (onTap == null ? col.withValues(alpha: .1) : c.card),
        borderRadius: BorderRadius.circular(999),
        border: onTap == null ? null : Border.all(color: on ? col : c.line, width: on ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? LucideIcons.check : LucideIcons.folder, size: onTap == null ? 11 : 14, color: col),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              str(group['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: onTap == null ? 11.5 : 13.5, fontWeight: FontWeight.w700, color: onTap == null ? col : c.ink),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: body);
  }
}

// ---------------------------------------------------------------- "groups for this note" (ticks save at once)
// returns the group ids the note is in afterwards (null when nothing changed)
Future<Set<String>?> ntPickGroups(BuildContext context, NtCtx ctx, {required String nid, required Set<String> current}) =>
    showSheet<Set<String>>(context, (_) => _GroupsPicker(ctx: ctx, nid: nid, current: current));

class _GroupsPicker extends StatefulWidget {
  final NtCtx ctx;
  final String nid;
  final Set<String> current;
  const _GroupsPicker({required this.ctx, required this.nid, required this.current});
  @override
  State<_GroupsPicker> createState() => _GroupsPickerState();
}

class _GroupsPickerState extends State<_GroupsPicker> {
  NtCtx get ctx => widget.ctx;
  List<Json>? _groups;
  late final Set<String> _in = {...widget.current};
  final _q = TextEditingController();
  String _busy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ctx.run(() => ctx.a.groups());
    if (mounted) setState(() => _groups = objs(r?['data']).where((g) => g['deleted'] != true).toList());
  }

  Future<void> _toggle(Json g) async {
    final gid = str(g['_id']);
    setState(() => _busy = gid);
    final on = _in.contains(gid);
    final r = await ctx.run(() => on ? ctx.a.groupDrop(gid, widget.nid) : ctx.a.groupAdd(gid, widget.nid));
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (r != null) on ? _in.remove(gid) : _in.add(gid);
    });
  }

  Future<void> _create() async {
    final g = await ntCreateGroup(context, ctx, noteIds: [widget.nid]);
    if (g == null || !mounted) return;
    setState(() {
      _groups = [g, ...?_groups];
      _in.add(str(g['_id']));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final needle = _q.text.trim().toLowerCase();
    final list = (_groups ?? const <Json>[]).where((g) => _in.contains(str(g['_id'])) || needle.isEmpty || str(g['name']).toLowerCase().contains(needle)).toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) Navigator.pop(context, _in);
      },
      child: MSheet(
        title: ctx.m('groupsPickTitle'),
        footer: [
          Expanded(
            child: Btn(ctx.m('newGroupLink'), icon: LucideIcons.folderPlus, kind: BtnKind.ghost, onTap: ctx.readOnly ? null : _create),
          ),
          const SizedBox(width: 10),
          Expanded(child: Btn(ctx.m('close'), onTap: () => Navigator.pop(context, _in))),
        ],
        children: [
          Muted(ctx.m('groupsPickSub')),
          const SizedBox(height: 12),
          Field(controller: _q, hint: ctx.m('groupsSearch'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          if (_groups == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_groups!.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Muted(ctx.m('groupsNoneYet'), align: TextAlign.center))
          else if (list.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Muted(ctx.m('groupsNoMatch'), align: TextAlign.center))
          else
            for (final g in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _in.contains(str(g['_id'])) ? c.active : c.bg2,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _busy.isNotEmpty ? null : () => _toggle(g),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          NtGroupIcon(g),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(g['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  n(g['notes_count']) == 1 ? ctx.m('groupNote') : ctx.m('groupNotes', {'n': fmt(n(g['notes_count']))}),
                                  style: TextStyle(color: c.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          if (_busy == str(g['_id']))
                            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            NtCheckDot(on: _in.contains(str(g['_id']))),
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

class NtCheckDot extends StatelessWidget {
  final bool on;
  const NtCheckDot({super.key, required this.on});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.brand : Colors.transparent,
        border: Border.all(color: on ? c.brand : c.lineStrong, width: 2),
      ),
      child: on ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
    );
  }
}

// ---------------------------------------------------------------- create a group (name + colour → pay → made)
Future<Json?> ntCreateGroup(BuildContext context, NtCtx ctx, {List<String> noteIds = const []}) async {
  final form = await showSheet<(String, String)>(context, (_) => _GroupForm(ctx: ctx));
  if (form == null || !context.mounted) return null;
  final (name, colour) = form;
  final key = ntRandom(24); // one per attempt: a retry never pays twice
  final price = ctx.price('note_group');
  Json? made;
  Future<Json>? paying; // the purchase in flight (the sheet can be swiped away while it runs)
  await showSheet<bool>(
    context,
    (_) => BuySheet(
      stage: NtStage(icon: LucideIcons.folders, name: name, sub: ctx.bizName),
      badge: ctx.m('badge'),
      title: ctx.m('groupBuyTitle', {'name': name}),
      sub: ctx.m('groupBuySub'),
      perks: ctx.l('groupPerks'),
      price: price,
      buyLabel: ctx.m('buy', {'coins': fmt(price)}),
      doneTitle: name,
      doneSub: ctx.m('groupMade'),
      doneButton: ctx.t('app.continue'),
      buy: () => paying = ctx.a.createGroup(name: name, color: colour, noteIds: noteIds, key: key),
      onDone: (r) => made = obj(r['data']),
    ),
  );
  // closed while paying: wait for the answer, so the group (and the coins) show at once
  final inFlight = paying;
  if (inFlight != null && made == null) {
    try {
      made = obj((await inFlight)['data']);
    } catch (_) {}
  }
  if (made != null) await ctx.reload();
  return made;
}

class _GroupForm extends StatefulWidget {
  final NtCtx ctx;
  const _GroupForm({required this.ctx});
  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  final _name = TextEditingController();
  String _colour = 'default';
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final ok = _name.text.trim().isNotEmpty;
    return MSheet(
      title: ctx.m('newGroup'),
      footer: [
        Expanded(
          child: Btn(
            ctx.m('groupNext', {'coins': fmt(ctx.price('note_group'))}),
            lead: const CoinIcon(size: 18),
            onTap: ok ? () => Navigator.pop(context, (_name.text.trim().length > 80 ? _name.text.trim().substring(0, 80) : _name.text.trim(), _colour)) : null,
          ),
        ),
      ],
      children: [
        Field(label: ctx.m('groupName'), controller: _name, hint: ctx.m('groupNamePh'), maxLength: 80, autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        Text(ctx.m('groupColour'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in ntColours)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _colour = k),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: k == 'default' ? c.card : ntPaper(context, k),
                    border: Border.all(color: _colour == k ? ntAccent(k) : c.line, width: _colour == k ? 3 : 1.5),
                  ),
                  child: Icon(LucideIcons.folder, size: 18, color: ntAccent(k)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Muted(ctx.m('newGroupPrice', {'coins': fmt(ctx.price('note_group'))})),
      ],
    );
  }
}
