import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_api.dart' show ntCode;
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_extras_text.dart';

// Sign-up form fields (note_form) for a sign-up list note: up to 20 fields (text, number, phone, email, date, choice,
// checkbox), required or not, choice options, a text length limit, the order. The web's FormFieldsDialog.

const ntFieldTypes = ['text', 'number', 'phone', 'email', 'date', 'choice', 'checkbox'];
const _typeIcons = <String, IconData>{
  'text': LucideIcons.textCursorInput,
  'number': LucideIcons.hash,
  'phone': LucideIcons.phone,
  'email': LucideIcons.atSign,
  'date': LucideIcons.calendar,
  'choice': LucideIcons.listChecks,
  'checkbox': LucideIcons.squareCheck,
};
IconData ntFieldIcon(String type) => _typeIcons[type] ?? LucideIcons.textCursorInput;

final _rnd = math.Random();
String _fid() => 'f${List.generate(6, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join()}';

class _Field {
  String id, label, type;
  bool required;
  List<TextEditingController> options;
  int? max;
  final TextEditingController labelCtl;
  _Field({required this.id, required this.label, required this.type, required this.required, required List<String> options, this.max})
    : options = [for (final o in options) TextEditingController(text: o)],
      labelCtl = TextEditingController(text: label);
  factory _Field.of(Json f) => _Field(
    id: str(f['id']).isEmpty ? _fid() : str(f['id']),
    label: str(f['label']),
    type: ntFieldTypes.contains(str(f['type'])) ? str(f['type']) : 'text',
    required: f['required'] == true,
    options: [for (final o in (f['options'] as List? ?? const [])) '$o'],
    max: f['max'] == null ? null : n(f['max']).toInt(),
  );
  Json toJson() => {
    'id': id,
    'label': labelCtl.text.trim(),
    'type': type,
    'required': required,
    'options': type == 'choice' ? [for (final o in options) o.text.trim()].where((o) => o.isNotEmpty).toList() : <String>[],
    if (type == 'text' && max != null) 'max': max,
  };
  void dispose() {
    labelCtl.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

// the ⋯ menu entry (sign-up list notes)
Future<void> ntFormTool(NtEditorApi ed) async {
  final fresh = await Navigator.of(ed.context).push<Json>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => NtFormPage(ctx: ed.ctx, note: ed.note)));
  if (fresh != null) ed.setNote({'form': fresh['form'] ?? fresh});
}

class NtFormPage extends StatefulWidget {
  final NtCtx ctx;
  final Json note;
  const NtFormPage({super.key, required this.ctx, required this.note});
  @override
  State<NtFormPage> createState() => _NtFormPageState();
}

class _NtFormPageState extends State<NtFormPage> {
  late final List<_Field> _fields = [for (final f in objs(obj(widget.note['form'])['fields'])) _Field.of(f)];
  bool _busy = false;
  String _err = '';
  NtCtx get ctx => widget.ctx;
  bool get _owned => ctx.form;

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _add(String type) async {
    if (!_owned) {
      await ctx.askBuy('note_form');
      if (mounted) setState(() {});
      return;
    }
    if (_fields.length >= 20) return;
    setState(() => _fields.add(_Field(id: _fid(), label: '', type: type, required: false, options: type == 'choice' ? [ctx.m('fxOpt1'), ctx.m('fxOpt2')] : [])));
  }

  Future<void> _save() async {
    final out = [for (final f in _fields) f.toJson()];
    if (out.any((f) => str(f['label']).isEmpty)) return setState(() => _err = ctx.m('fxNeedLabel'));
    if (out.any((f) => f['type'] == 'choice' && (f['options'] as List).isEmpty)) return setState(() => _err = ctx.m('fxNeedOptions'));
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final r = await ctx.a.update(str(widget.note['_id']), {
        'form': {'fields': out},
      });
      if (!mounted) return;
      ctx.notify(ctx.m('fxSaved'));
      final saved = obj(r['data']);
      Navigator.pop(context, {
        'form': saved['form'] ?? {'fields': out},
      });
    } catch (e) {
      if (ntCode(e) == 'need_form') ctx.askBuy('note_form');
      if (mounted) {
        setState(() {
          _busy = false;
          _err = ctx.errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.appBg,
      appBar: AppBar(
        backgroundColor: c.appBg,
        surfaceTintColor: Colors.transparent,
        title: Text(ctx.m('fxTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Btn(ctx.m('save'), small: true, icon: LucideIcons.check, busy: _busy, onTap: _save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Muted(ctx.m('fxSub')),
          const SizedBox(height: 12),
          if (!_owned) ...[NtLockLine(ctx: ctx, text: ctx.m('fxLocked'), product: 'note_form', onTap: () => _add('text')), const SizedBox(height: 12)],
          if (_fields.isEmpty)
            Panel(
              child: NtEmpty(icon: LucideIcons.listChecks, title: ctx.m('fxNone')),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // ignore: deprecated_member_use (onReorderItem is only in the newest Flutter; onReorder works on all)
            onReorder: (a, b) => setState(() => _fields.insert(b > a ? b - 1 : b, _fields.removeAt(a))),
            children: [for (final (i, f) in _fields.indexed) _card(i, f)],
          ),
          const SizedBox(height: 10),
          Text(ctx.m('fxAdd'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ntFieldTypes)
                ActionChip(
                  avatar: Icon(_owned ? ntFieldIcon(t) : LucideIcons.lock, size: 16),
                  label: Text(ctx.m('fxTypes.$t')),
                  onPressed: _fields.length >= 20 ? null : () => _add(t),
                ),
            ],
          ),
          if (_err.isNotEmpty) ...[const SizedBox(height: 12), Alert(_err, tone: Tone.danger)],
        ],
      ),
    );
  }

  Widget _card(int i, _Field f) {
    final c = context.c;
    return Container(
      key: ValueKey(f.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), boxShadow: c.cardShadow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Padding(padding: const EdgeInsets.fromLTRB(4, 14, 6, 0), child: Icon(LucideIcons.gripVertical, size: 18, color: c.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: f.labelCtl,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: ctx.m('fxLabel'), hintText: ctx.m('fxLabelPh'), counterText: '', isDense: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: f.type,
                  isDense: true,
                  decoration: InputDecoration(labelText: ctx.m('fxType'), isDense: true),
                  items: [
                    for (final t in ntFieldTypes)
                      DropdownMenuItem(
                        value: t,
                        child: Row(children: [Icon(ntFieldIcon(t), size: 16, color: c.muted), const SizedBox(width: 8), Text(ctx.m('fxTypes.$t'))]),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    f.type = v ?? 'text';
                    if (f.type == 'choice' && f.options.isEmpty) f.options = [TextEditingController(text: ctx.m('fxOpt1')), TextEditingController(text: ctx.m('fxOpt2'))];
                  }),
                ),
                if (f.type == 'choice') ...[
                  const SizedBox(height: 8),
                  for (final (k, o) in f.options.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circle, size: 12, color: c.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: o,
                              maxLength: 60,
                              decoration: InputDecoration(hintText: ctx.m('fxOption'), counterText: '', isDense: true),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => f.options.removeAt(k).dispose()),
                            icon: Icon(LucideIcons.x, size: 16, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  if (f.options.length < 30)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(onPressed: () => setState(() => f.options.add(TextEditingController())), icon: const Icon(LucideIcons.plus, size: 15), label: Text(ctx.m('fxAddOption'))),
                    ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Switch(value: f.required, onChanged: (v) => setState(() => f.required = v)),
                    const SizedBox(width: 4),
                    Text(ctx.m('fxRequired'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (f.type == 'text')
                      SizedBox(
                        width: 96,
                        child: TextFormField(
                          initialValue: f.max?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: ctx.m('fxMax'), hintText: '200', isDense: true),
                          onChanged: (v) => f.max = int.tryParse(v)?.clamp(1, 1000),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(tooltip: ntE(ctx, 'moveUp'), visualDensity: VisualDensity.compact, onPressed: i == 0 ? null : () => setState(() => _fields.insert(i - 1, _fields.removeAt(i))), icon: const Icon(LucideIcons.arrowUp, size: 17)),
              IconButton(tooltip: ntE(ctx, 'moveDown'), visualDensity: VisualDensity.compact, onPressed: i == _fields.length - 1 ? null : () => setState(() => _fields.insert(i + 1, _fields.removeAt(i))), icon: const Icon(LucideIcons.arrowDown, size: 17)),
              IconButton(tooltip: ctx.m('delete'), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _fields.removeAt(i).dispose()), icon: Icon(LucideIcons.trash2, size: 17, color: c.danger)),
            ],
          ),
        ],
      ),
    );
  }
}
