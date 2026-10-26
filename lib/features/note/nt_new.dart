import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_common.dart';
import 'nt_groups_pick.dart';

// "New note": ready-made templates (the API fills the text in the owner's language) + my templates,
// optionally the groups it goes in, and how it's shared (the web's TemplateChooser in NoteList.jsx).
// Returns the new note (the API's noteOut) and the groups it was added to.
Future<(Json, List<String>)?> ntNewNote(BuildContext context, NtCtx ctx, {List<String> preGroups = const []}) =>
    showSheet<(Json, List<String>)>(context, (_) => _NewNote(ctx: ctx, preGroups: preGroups));

class _NewNote extends StatefulWidget {
  final NtCtx ctx;
  final List<String> preGroups;
  const _NewNote({required this.ctx, required this.preGroups});
  @override
  State<_NewNote> createState() => _NewNoteState();
}

class _NewNoteState extends State<_NewNote> {
  NtCtx get ctx => widget.ctx;
  List<Json>? _groups;
  List<Json> _mine = const [];
  late final Set<String> _picked = {...widget.preGroups};
  String _level = ''; // '' = the template's own (sign-up / homework → sign-up list, the rest → closed)
  String _busy = '';
  final _gq = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctx.a.groups().then((r) => mounted ? setState(() => _groups = objs(r['data']).where((g) => g['deleted'] != true).toList()) : null, onError: (_) => mounted ? setState(() => _groups = const []) : null);
    ctx.a.templates().then((r) => mounted ? setState(() => _mine = objs(r['data'])) : null, onError: (_) {});
  }

  @override
  void dispose() {
    _gq.dispose();
    super.dispose();
  }

  Future<void> _make({String? template, String? mine}) async {
    if (_busy.isNotEmpty) return;
    setState(() => _busy = template ?? mine ?? '');
    try {
      final r = await ctx.a.create(template: template, myTemplate: mine, lang: ctx.lang, shareLevel: _level);
      final note = obj(r['data']);
      final added = <String>[];
      var failed = false;
      for (final gid in _picked) {
        try {
          await ctx.a.groupAdd(gid, str(note['_id']));
          added.add(gid);
        } catch (_) {
          failed = true;
        }
      }
      if (failed) ctx.notify(ctx.m('groupAddFail'));
      if (mounted) Navigator.pop(context, (note, added));
    } catch (e) {
      if (mounted) setState(() => _busy = '');
      ctx.fail(e);
    }
  }

  Future<void> _deleteMine(Json t) async {
    if (!await ntConfirm(context, ctx, ctx.m('tplDeleteSure'), str(t['name']))) return;
    final r = await ctx.run(() => ctx.a.templateDelete(str(t['_id'])));
    if (r != null && mounted) setState(() => _mine = _mine.where((x) => x['_id'] != t['_id']).toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final needle = _gq.text.trim().toLowerCase();
    final shownGroups = (_groups ?? const <Json>[]).where((g) => _picked.contains(str(g['_id'])) || needle.isEmpty || str(g['name']).toLowerCase().contains(needle)).toList();
    return MSheet(
      title: ctx.m('chooseTitle'),
      children: [
        Muted(ctx.m('chooseSub')),
        const SizedBox(height: 14),
        // how it's shared
        Text(ctx.m('shareAs'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        const SizedBox(height: 8),
        NtChips<String>(
          value: _level,
          onChanged: (v) => setState(() => _level = v),
          items: [('', ctx.x('levelAuto'), null), for (final k in ntLevels) (k, ctx.m('levelShort.$k'), null)],
        ),
        const SizedBox(height: 4),
        Text(ctx.m('shareAsSub'), style: TextStyle(color: c.muted, fontSize: 12.5)),
        // groups (optional)
        if ((_groups ?? const []).isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ctx.m('chooseGroups'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 8),
                Field(controller: _gq, hint: ctx.m('groupsSearch'), icon: LucideIcons.search, onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: shownGroups.isEmpty
                        ? Text(ctx.m('noGroupMatch'), style: TextStyle(color: c.muted, fontSize: 13))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g in shownGroups)
                                NtGroupChip(
                                  g,
                                  on: _picked.contains(str(g['_id'])),
                                  onTap: _busy.isNotEmpty
                                      ? null
                                      : () => setState(() {
                                          final id = str(g['_id']);
                                          _picked.contains(id) ? _picked.remove(id) : _picked.add(id);
                                        }),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // my templates
        if (_mine.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(ctx.m('tplMine'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 8),
          for (final t in _mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Tile(
                icon: LucideIcons.bookmark,
                colour: ntAccent(str(t['color'])),
                title: str(t['name']),
                sub: ctx.m('tplBlocks', {'n': n(t['blocks_count'])}),
                busy: _busy == str(t['_id']),
                onTap: () => _make(mine: str(t['_id'])),
                onLong: () => _deleteMine(t),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Text(_mine.isEmpty ? ctx.x('templates') : ctx.m('tplBuiltIn'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, box) {
            final two = box.maxWidth >= 340;
            final w = two ? (box.maxWidth - 10) / 2 : box.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final k in ctx.builtInTemplates)
                  SizedBox(
                    width: w,
                    child: _Tile(
                      icon: ntTemplateIcons[k] ?? LucideIcons.fileText,
                      colour: c.brand,
                      title: ctx.l('tpl.$k').firstOrNull ?? k,
                      sub: ctx.l('tpl.$k').length > 1 ? ctx.l('tpl.$k')[1] : '',
                      busy: _busy == k,
                      onTap: () => _make(template: k),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color colour;
  final String title, sub;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  const _Tile({required this.icon, required this.colour, required this.title, required this.sub, required this.busy, required this.onTap, this.onLong});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLong,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: colour.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                child: busy ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: colour)) : Icon(icon, size: 19, color: colour),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    if (sub.isNotEmpty) Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35)),
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
