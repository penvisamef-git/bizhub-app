import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'rest_common.dart';
import 'rest_sections.dart' show FormText;

// Floor & tables (the web's TablesTab): takeaway only, zones, quick add A1–A10, tables
class TablesSection extends StatefulWidget {
  final RestCtx ctx;
  const TablesSection({super.key, required this.ctx});
  @override
  State<TablesSection> createState() => _TablesSectionState();
}

class _TablesSectionState extends State<TablesSection> {
  List<Json>? _zones, _tables;
  Json _quick = {'prefix': 'A', 'from': 1, 'to': 10, 'seats': 4, 'zone_id': ''};
  bool _busy = false;
  RestCtx get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([ctx.api.get('${ctx.base}/zones'), ctx.api.get('${ctx.base}/tables')]);
      if (mounted) {
        setState(() {
          _zones = objs(r[0]['data']);
          _tables = objs(r[1]['data']);
        });
      }
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _noTables(bool on) async {
    try {
      final r = await ctx.api.put('${ctx.base}/settings', {'no_tables': on});
      ctx.setSettings(obj(r['data']), r['setup'] == null ? null : obj(r['setup']));
    } catch (e) {
      ctx.fail(e);
    }
  }

  Future<void> _runQuick() async {
    setState(() => _busy = true);
    try {
      final r = await ctx.api.post('${ctx.base}/tables/bulk', {..._quick, 'zone_id': str(_quick['zone_id']).isEmpty ? null : _quick['zone_id']});
      setState(() => _tables = objs(r['data']));
      ctx.notify('${ctx.r('tablesAdded', {'n': n(r['added'])})}${n(r['skipped']) > 0 ? ' · ${ctx.r('tablesSkipped', {'n': n(r['skipped'])})}' : ''}');
      ctx.reload();
    } catch (e) {
      ctx.fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTable(Json row) async {
    final ok = await showEditor<bool>(
      context,
      builder: (_) => _TableEditor(ctx: ctx, row: row, zones: _zones!),
    );
    if (ok == true) {
      _load();
      ctx.reload();
    }
  }

  Future<void> _editZone(Json row) async {
    final ok = await showEditor<bool>(
      context,
      builder: (_) => _ZoneEditor(ctx: ctx, row: row),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final noTables = ctx.settings['no_tables'] == true;
    final zones = _zones, tables = _tables;
    if (zones == null || tables == null) return const Padding(padding: EdgeInsets.all(16), child: SkelList(rows: 4));
    bool inZone(Json t, Json z) => str(t['zone_id']) == str(z['_id']);
    final groups = <(Json?, List<Json>)>[
      for (final z in zones) (z, tables.where((t) => inZone(t, z)).toList()),
      (null, tables.where((t) => str(t['zone_id']).isEmpty || !zones.any((z) => inZone(t, z))).toList()),
    ].where((g) => g.$1 != null || g.$2.isNotEmpty).toList();
    final q = _quick;
    final zoneOptions = [('', ctx.r('noZone')), for (final z in zones) (str(z['_id']), str(z['name']))];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RestHead(ctx.r('tabs.tables'), sub: ctx.r('tablesSub')),
              SwitchRow(title: ctx.r('noTables'), sub: ctx.r('noTablesHint'), value: noTables, onChanged: ro ? null : _noTables),
            ],
          ),
        ),
        if (!noTables) ...[
          gap14,
          // ---------- zones ----------
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(
                  ctx.r('zones'),
                  trailing: Btn(ctx.r('addZone'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _editZone({})),
                ),
                if (zones.isEmpty) Muted('${ctx.r('zonePh')}, VIP…'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in zones)
                      ActionChip(
                        onPressed: ro ? null : () => _editZone(z),
                        backgroundColor: c.bg2,
                        side: BorderSide(color: c.line),
                        shape: const StadiumBorder(),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(str(z['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            Text(
                              '${tables.where((t) => inZone(t, z)).length}',
                              style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.pencil, size: 12, color: c.muted),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          gap14,
          // ---------- quick add ----------
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(ctx.r('quickAdd'), sub: ctx.r('quickAddHint')),
                Row(
                  children: [
                    Expanded(
                      child: FormText(label: ctx.r('prefix'), value: str(q['prefix']), maxLength: 10, enabled: !ro, onChanged: (v) => setState(() => _quick = {...q, 'prefix': v})),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FormText(
                        label: ctx.r('seats'),
                        value: '${q['seats']}',
                        maxLength: 2,
                        keyboard: TextInputType.number,
                        enabled: !ro,
                        onChanged: (v) => setState(() => _quick = {...q, 'seats': int.tryParse(v) ?? v}),
                      ),
                    ),
                  ],
                ),
                gap14,
                Row(
                  children: [
                    Expanded(
                      child: FormText(
                        label: ctx.r('from'),
                        value: '${q['from']}',
                        maxLength: 3,
                        keyboard: TextInputType.number,
                        enabled: !ro,
                        onChanged: (v) => setState(() => _quick = {...q, 'from': int.tryParse(v) ?? v}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FormText(
                        label: ctx.r('to'),
                        value: '${q['to']}',
                        maxLength: 3,
                        keyboard: TextInputType.number,
                        enabled: !ro,
                        onChanged: (v) => setState(() => _quick = {...q, 'to': int.tryParse(v) ?? v}),
                      ),
                    ),
                  ],
                ),
                gap14,
                SelectField<String>(label: ctx.r('zones'), value: str(q['zone_id']), options: zoneOptions, onChanged: ro ? null : (v) => setState(() => _quick = {...q, 'zone_id': v})),
                const SizedBox(height: 16),
                Btn(
                  _busy ? ctx.r('saving') : '${ctx.r('makeTables')} · ${q['prefix']}${q['from']}–${q['prefix']}${q['to']}',
                  icon: LucideIcons.wandSparkles,
                  busy: _busy,
                  expand: true,
                  onTap: _busy || ro ? null : _runQuick,
                ),
              ],
            ),
          ),
          gap14,
          // ---------- tables ----------
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RestHead(
                  '${ctx.r('tabs.tables')} · ${tables.length}',
                  trailing: Btn(ctx.r('addTable'), icon: LucideIcons.plus, kind: BtnKind.ghost, small: true, onTap: ro ? null : () => _editTable({})),
                ),
                if (tables.isEmpty) Muted(ctx.r('noTablesYet')),
                for (final (z, list) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      z == null ? ctx.r('noZone') : str(z['name']),
                      style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                    children: [
                      for (final t in list)
                        Material(
                          color: t['active'] == false ? c.bg2 : c.active,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: ro ? null : () => _editTable(t),
                            child: Opacity(
                              opacity: t['active'] == false ? .5 : 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    str(t['name']),
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.brandInk),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.armchair, size: 12, color: c.muted),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${t['seats']}',
                                        style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TableEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  final List<Json> zones;
  const _TableEditor({required this.ctx, required this.row, required this.zones});
  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  late final _name = TextEditingController(text: str(widget.row['name']));
  late final _seats = TextEditingController(text: '${widget.row['seats'] ?? 4}');
  late String _zone = str(widget.row['zone_id']);
  late bool _active = widget.row['active'] != false;
  bool _busy = false;
  RestCtx get ctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    _seats.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EditorFrame(
    title: _isNew ? ctx.r('addTable') : ctx.r('editTable'),
    cancel: ctx.r('cancel'),
    save: ctx.r('save'),
    busy: _busy,
    canSave: _name.text.trim().isNotEmpty,
    onSave: () => _run(() async {
      final data = {'name': _name.text, 'seats': int.tryParse(_seats.text) ?? 4, 'zone_id': _zone.isEmpty ? null : _zone, 'active': _active};
      if (_isNew) {
        await ctx.api.post('${ctx.base}/tables', data);
      } else {
        await ctx.api.put('${ctx.base}/tables/${widget.row['_id']}', data);
      }
    }),
    delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: _busy ? null : () => _run(() => ctx.api.delete('${ctx.base}/tables/${widget.row['_id']}'))),
    children: [
      Field(label: ctx.r('tableName'), controller: _name, maxLength: 20, autofocus: _isNew, onChanged: (_) => setState(() {})),
      gap14,
      Field(label: ctx.r('seats'), controller: _seats, maxLength: 2, keyboard: TextInputType.number),
      gap14,
      SelectField<String>(
        label: ctx.r('zones'),
        value: _zone,
        options: [('', ctx.r('noZone')), for (final z in widget.zones) (str(z['_id']), str(z['name']))],
        onChanged: (v) => setState(() => _zone = v),
      ),
      const SizedBox(height: 6),
      SwitchRow(title: ctx.r('active'), value: _active, onChanged: (v) => setState(() => _active = v)),
    ],
  );
}

class _ZoneEditor extends StatefulWidget {
  final RestCtx ctx;
  final Json row;
  const _ZoneEditor({required this.ctx, required this.row});
  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  late final _name = TextEditingController(text: str(widget.row['name']));
  bool _busy = false;
  RestCtx get ctx => widget.ctx;
  bool get _isNew => widget.row['_id'] == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ctx.fail(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EditorFrame(
    title: _isNew ? ctx.r('addZone') : ctx.r('edit'),
    cancel: ctx.r('cancel'),
    save: ctx.r('save'),
    busy: _busy,
    canSave: _name.text.trim().isNotEmpty,
    onSave: () => _run(() async {
      if (_isNew) {
        await ctx.api.post('${ctx.base}/zones', {'name': _name.text});
      } else {
        await ctx.api.put('${ctx.base}/zones/${widget.row['_id']}', {'name': _name.text});
      }
    }),
    delete: _isNew ? null : DeleteConfirm(ctx: ctx, onDelete: _busy ? null : () => _run(() => ctx.api.delete('${ctx.base}/zones/${widget.row['_id']}'))),
    children: [Field(label: ctx.r('zoneName'), hint: ctx.r('zonePh'), controller: _name, maxLength: 40, autofocus: _isNew, onChanged: (_) => setState(() {}))],
  );
}
