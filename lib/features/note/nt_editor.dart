import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show MSheet, showSheet;
import 'nt_api.dart';
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_groups_pick.dart';
import 'nt_share.dart';

// One note: the block editor (the web's NoteEditor.jsx + note/blocks.jsx) with autosave (1.5 s after typing, with
// base_version → 409 = someone else saved first: "load theirs" / "keep mine"), files, colour, groups and sharing.
// The other tabs of a note (replies, seen by, files, history, confirmed) come from ntNoteTabs.
//
// EXTENDING (phase 2):
//   ntToolActions   buttons in the bottom toolbar (style, emoji, sticker, sign / draw, voice, due & who) — they get an
//                   NtEditorApi to read / change the blocks
//   ntNoteMenu      entries in the ⋯ menu (look, save as template, PDF export, form fields…)
//   ntNoteTabs      the tabs of a note (replace a placeholder: ntSetNoteTab('entries', …))
//   ntBlockBelow    a line under a block (e.g. "📅 Friday · 👤 Dara" under a checklist item)

const _sentinel = '​'; // kept at the start of every text field: Backspace on an empty line can be seen

Future<void> ntOpenNote(BuildContext context, NtCtx ctx, String nid, {Json? first, String? fromGroup}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NtEditorPage(ctx: ctx, nid: nid, first: first, fromGroup: fromGroup)));

// ---------------------------------------------------------------- extension points
abstract class NtEditorApi {
  BuildContext get context;
  NtCtx get ctx;
  String get nid;
  Json get note; // the note as the server last sent it (share, files, form…)
  List<NtBlock> get blocks;
  List<Json> get files;
  int get current; // the selected block (-1 = none)
  bool get readOnly;
  NtBlock? get currentBlock;
  void insertAfter(NtBlock b, {bool focus = true}); // after the selected block (or at the end)
  void replaceBlock(int index, NtBlock b);
  void changed(); // a block was changed in place: save soon
  void setNote(Json note); // e.g. after a share / form save
  Future<Json?> attachBytes(List<int> bytes, String name, {bool sign = false, bool voice = false}); // → the file (or null)
  Future<void> refresh();
  void insertText(String text); // at the caret of the selected text block (an emoji)
  void rebuild(); // after a block / note field was changed in place by a tool
  void fileRemoved(Json saved, String fid); // a file was deleted: drop its blocks here too (the server note = saved)
  Future<void> flush(); // send the changes not saved yet, now (e.g. before "Save as template")
}

// a look around the whole editor body (the note paper: lined, grid…)
typedef NtBackdrop = Widget Function(NtEditorApi ed, Widget child);
final ntEditorBackdrops = <NtBackdrop>[];

class NtToolAction {
  final String key;
  final IconData icon;
  final String label; // a note.* text key
  final String? needs; // the add-on (shows a lock without it; tapping opens its unlock sheet)
  final bool Function(NtEditorApi ed)? visible;
  final Future<void> Function(NtEditorApi ed) run;
  const NtToolAction({required this.key, required this.icon, required this.label, this.needs, this.visible, required this.run});
}

final ntToolActions = <NtToolAction>[];
void ntRegisterTool(NtToolAction a) => ntToolActions
  ..removeWhere((x) => x.key == a.key)
  ..add(a);

class NtNoteAction {
  final String key;
  final IconData icon;
  final String label;
  final String? needs;
  final bool Function(NtEditorApi ed)? visible;
  final Future<void> Function(NtEditorApi ed) run;
  const NtNoteAction({required this.key, required this.icon, required this.label, this.needs, this.visible, required this.run});
}

final ntNoteMenu = <NtNoteAction>[];
void ntRegisterNoteAction(NtNoteAction a) => ntNoteMenu
  ..removeWhere((x) => x.key == a.key)
  ..add(a);

typedef NtTabBuilder = Widget Function(NtEditorApi ed);

class NtNoteTab {
  final String key;
  final IconData icon;
  final String Function(NtEditorApi ed) label;
  final bool Function(NtEditorApi ed) visible;
  NtTabBuilder? builder; // null = "comes in the next update"
  NtNoteTab(this.key, this.icon, this.label, {bool Function(NtEditorApi ed)? visible, this.builder}) : visible = visible ?? ((_) => true);
}

final ntNoteTabs = <NtNoteTab>[
  NtNoteTab('note', LucideIcons.fileText, (ed) => ed.ctx.m('noteTabs.note')),
  NtNoteTab('entries', LucideIcons.messageSquareText, (ed) => obj(ed.note['share'])['level'] == 'collect' ? ed.ctx.m('collectTab') : ed.ctx.m('noteTabs.entries')),
  NtNoteTab('acks', LucideIcons.circleCheckBig, (ed) => ed.ctx.m('ackTab'), visible: (ed) => obj(ed.note['share'])['ack'] == true),
  NtNoteTab('seen', LucideIcons.users, (ed) => ed.ctx.m('noteTabs.seen')),
  NtNoteTab('files', LucideIcons.paperclip, (ed) => ed.ctx.m('noteTabs.files')),
  NtNoteTab('history', LucideIcons.history, (ed) => ed.ctx.m('noteTabs.history')),
];
void ntSetNoteTab(String key, NtTabBuilder builder) => ntNoteTabs.firstWhere((t) => t.key == key).builder = builder;

typedef NtBelowBuilder = Widget? Function(NtEditorApi? ed, NtBlockView v);
final ntBlockBelow = <NtBelowBuilder>[];

// ---------------------------------------------------------------- the page
class NtEditorPage extends StatefulWidget {
  final NtCtx ctx;
  final String nid;
  final Json? first;
  final String? fromGroup;
  final String tab;
  const NtEditorPage({super.key, required this.ctx, required this.nid, this.first, this.fromGroup, this.tab = 'note'});
  @override
  State<NtEditorPage> createState() => NtEditorState();
}

class _Ed {
  final TextEditingController text;
  final FocusNode focus;
  _Ed(String v) : text = TextEditingController(text: '$_sentinel$v'), focus = FocusNode();
  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class NtEditorState extends State<NtEditorPage> implements NtEditorApi {
  @override
  NtCtx get ctx => widget.ctx;
  @override
  String get nid => widget.nid;

  Json? _note;
  String _error = '';
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  List<NtBlock> _blocks = [];
  final _eds = <String, _Ed>{};
  int _version = 0;
  String _baseKey = ''; // what the server had at _version
  int _current = -1;
  Set<String> _groupIds = {};
  int _entriesNew = 0;
  late String _tab = widget.tab;

  // saving
  Timer? _debounce, _retry, _poll;
  bool _dirty = false, _saving = false, _again = false, _stopped = false;
  String _status = 'idle'; // idle | dirty | saving | saved | error | conflict
  Json? _conflict;

  bool _disposed = false;

  // uploads
  String _upload = ''; // '' or "Uploading 40%"

  @override
  Json get note => _note ?? const {};
  @override
  List<NtBlock> get blocks => _blocks;
  @override
  List<Json> get files => objs(note['files']);
  @override
  int get current => _current;
  @override
  NtBlock? get currentBlock => _current >= 0 && _current < _blocks.length ? _blocks[_current] : null;
  @override
  bool get readOnly => ctx.readOnly || note['deleted'] == true;

  @override
  void initState() {
    super.initState();
    if (widget.first != null) _take(widget.first!, groupIds: const {});
    _load();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    _title.addListener(_titleChanged);
  }

  @override
  void dispose() {
    _disposed = true; // the last save below may fail: then no retry timer, no sheets (the page is gone)
    _debounce?.cancel();
    _retry?.cancel();
    _poll?.cancel();
    if (_dirty && !_stopped && !readOnly) _save(); // last changes go out even when leaving
    _title.dispose();
    _titleFocus.dispose();
    for (final e in _eds.values) {
      e.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- loading
  Future<void> _load() async {
    try {
      final r = await ctx.a.note(nid);
      if (!mounted) return;
      final d = obj(r['data']);
      final fresh = obj(d['note']);
      setState(() {
        _entriesNew = n(d['entries_new']).toInt();
        _groupIds = {for (final g in (d['group_ids'] as List? ?? const [])) '$g'};
        _error = '';
      });
      // typed already (opened from the cached first copy)? keep the text, take the newer version only when it says the same
      if (_note == null || (!_dirty && !_saving)) {
        _take(fresh);
      } else if (_saving && n(fresh['version']).toInt() > _version) {
        // a save is on its way: it meets the newer version itself (409 → the conflict banner), the typing stays
      } else if (ntContentKey(str(fresh['title']), ntBlocksOf(fresh['blocks'])) == _baseKey) {
        _version = n(fresh['version']).toInt();
        setState(() => _note = {...fresh, 'blocks': note['blocks']});
      } else {
        setState(() {
          _conflict = fresh;
          _status = 'conflict';
        });
      }
    } catch (e) {
      if (mounted && _note == null) setState(() => _error = ctx.errText(e));
    }
  }

  void _take(Json fresh, {Set<String>? groupIds}) {
    // the old line editors may still be on screen this frame: let them go after it
    final old = _eds.values.toList();
    _eds.clear();
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final e in old) {
          e.dispose();
        }
      });
    }
    setState(() {
      _note = fresh;
      _blocks = ntBlocksOf(fresh['blocks']);
      _title.removeListener(_titleChanged);
      _title.text = str(fresh['title']);
      _title.addListener(_titleChanged);
      _version = n(fresh['version']).toInt();
      _baseKey = ntContentKey(_title.text, _blocks);
      _dirty = false;
      _conflict = null;
      if (_status == 'conflict' || _status == 'dirty') _status = 'idle';
      if (groupIds != null) _groupIds = groupIds;
    });
  }

  // every 20 s: someone else may have changed it (a guest at "edit together")
  Future<void> _check() async {
    if (_saving || _note == null || _conflict != null) return;
    try {
      final r = await ctx.a.note(nid);
      if (!mounted) return;
      final d = obj(r['data']);
      final fresh = obj(d['note']);
      setState(() => _entriesNew = n(d['entries_new']).toInt());
      if (n(fresh['version']).toInt() <= _version) return setState(() => _note = {...note, 'share': fresh['share'], 'files': fresh['files']});
      // checked again after the wait: typing or a save may have started meanwhile — never replace what's being typed
      if (_saving) return; // the save on its way meets the newer version (409 → the conflict banner)
      if (!_dirty && !(_debounce?.isActive ?? false)) return _take(fresh);
      if (ntContentKey(str(fresh['title']), ntBlocksOf(fresh['blocks'])) == _baseKey) {
        _version = n(fresh['version']).toInt();
      } else {
        setState(() {
          _conflict = fresh;
          _status = 'conflict';
        });
      }
    } catch (_) {}
  }

  @override
  Future<void> refresh() => _load();

  @override
  void fileRemoved(Json saved, String fid) {
    if (!mounted) return;
    final v = n(saved['version']).toInt();
    setState(() {
      _blocks.removeWhere((b) => const ['file', 'draw', 'audio'].contains(b.t) && b.fileId == fid);
      _note = {...note, 'files': saved['files'], 'share': saved['share']};
    });
    // only this delete moved the version (it took the file's blocks out): take it, keep any typing → no false conflict.
    // more than that changed meanwhile: the usual check decides (a refresh, or the conflict banner when typing)
    if (v == _version + 1) {
      _version = v;
      _baseKey = ntContentKey(str(saved['title']), ntBlocksOf(saved['blocks']));
    } else if (v > _version) {
      _load();
    }
  }

  @override
  Future<void> flush() async {
    if (readOnly || _stopped || _conflict != null) return;
    if (!_dirty && !(_debounce?.isActive ?? false) && !_saving) return;
    _debounce?.cancel();
    // a save is on its way: wait for it (and the one it starts after, for changes made meanwhile)
    for (var i = 0; i < 50 && _saving; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_dirty) await _save();
  }

  @override
  void rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void insertText(String text) {
    if (readOnly) return;
    final b = currentBlock;
    if (b == null || !b.isText) {
      // no line selected: a new plain line with the text
      insertAfter(NtBlock.blank()..text = text);
      return;
    }
    final e = _edOf(b);
    final v = e.text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final at = sel.start.clamp(1, v.text.length);
    final end = sel.end.clamp(at, v.text.length);
    final next = v.text.replaceRange(at, end, text);
    e.text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: at + text.length));
    b.text = next.substring(1);
    changed();
  }

  @override
  void setNote(Json fresh) => setState(() => _note = {...note, ...fresh, 'blocks': note['blocks'], 'title': note['title']});

  // ---------------------------------------------------------------- saving
  void _titleChanged() {
    if (_note == null || _title.text == str(note['title']) && !_dirty) return;
    changed();
  }

  @override
  void changed() {
    if (readOnly) return;
    _dirty = true;
    if (_status != 'conflict') setState(() => _status = 'dirty');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _save);
  }

  Future<void> _save() async {
    if (_stopped || _conflict != null || readOnly) return;
    if (_saving) {
      _again = true;
      return;
    }
    _debounce?.cancel();
    _retry?.cancel();
    _saving = true;
    _dirty = false;
    final sentKey = ntContentKey(_title.text, _blocks);
    if (mounted && !_disposed) setState(() => _status = 'saving');
    try {
      final r = await ctx.a.update(nid, {'title': _title.text, 'blocks': ntBlocksJson(_blocks), 'base_version': _version});
      final saved = obj(r['data']);
      _version = n(saved['version']).toInt();
      _baseKey = sentKey;
      if (mounted && !_disposed) {
        setState(() {
          _note = {...saved, 'blocks': ntBlocksJson(_blocks), 'title': _title.text};
          _status = _dirty ? 'dirty' : 'saved';
        });
      }
    } catch (e) {
      final code = ntCode(e);
      if (code == 'conflict') {
        _dirty = true;
        if (mounted && !_disposed) {
          setState(() {
            _conflict = e is ApiError ? obj(e.body['data']) : null;
            _status = 'conflict';
          });
        }
      } else if (code == 'too_large') {
        _dirty = true;
        _stopped = true; // no endless retries: the owner has to shorten it
        if (mounted && !_disposed) setState(() => _status = 'error');
        if (!_disposed) ctx.notify(ctx.m('tooLarge'));
      } else if (code == 'locked' || code.startsWith('need_')) {
        _dirty = true;
        if (mounted && !_disposed) setState(() => _status = 'error');
        if (!_disposed) ctx.fail(e);
      } else {
        _dirty = true;
        if (mounted && !_disposed) setState(() => _status = 'error');
        // try again in a while — only while the note is open (after leaving, the last try was the last)
        if (!_disposed) _retry = Timer(const Duration(seconds: 8), _save);
      }
    } finally {
      _saving = false;
      if (_again && mounted && !_disposed) {
        _again = false;
        if (_dirty) _save();
      }
    }
  }

  void _loadTheirs() {
    final c = _conflict;
    if (c == null) return;
    _take(c);
    setState(() => _status = 'idle');
  }

  void _keepMine() {
    final c = _conflict;
    if (c == null) return;
    _version = n(c['version']).toInt();
    _baseKey = ntContentKey(str(c['title']), ntBlocksOf(c['blocks']));
    setState(() {
      _conflict = null;
      _status = 'dirty';
    });
    _stopped = false;
    _save();
  }

  // ---------------------------------------------------------------- blocks
  _Ed _edOf(NtBlock b) => _eds.putIfAbsent(b.id, () {
    final e = _Ed(b.text);
    e.text.addListener(() => _guardCaret(e));
    e.focus.addListener(() {
      if (e.focus.hasFocus) {
        final i = _blocks.indexWhere((x) => x.id == b.id);
        if (i != _current && mounted) setState(() => _current = i);
      }
    });
    return e;
  });

  // the caret never goes before the hidden first character
  void _guardCaret(_Ed e) {
    final s = e.text.selection;
    if (s.isValid && s.isCollapsed && s.baseOffset == 0 && e.text.text.startsWith(_sentinel)) {
      e.text.selection = const TextSelection.collapsed(offset: 1);
    }
  }

  void _focus(int i, {int? at, bool end = false}) {
    if (i < 0 || i >= _blocks.length) return;
    setState(() => _current = i);
    final b = _blocks[i];
    if (!b.isText) return;
    final e = _edOf(b);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      e.focus.requestFocus();
      final len = e.text.text.length;
      final pos = end ? len : ((at ?? 0) + 1).clamp(1, len);
      e.text.selection = TextSelection.collapsed(offset: pos);
    });
  }

  void _onText(NtBlock b, String raw) {
    final i = _blocks.indexWhere((x) => x.id == b.id);
    if (i < 0) return;
    final e = _edOf(b);
    // Backspace at the very start (the hidden character was deleted)
    if (!raw.startsWith(_sentinel)) {
      final rest = raw;
      if (i > 0 && _blocks[i - 1].isText) {
        final prev = _blocks[i - 1];
        final join = prev.text.length;
        prev.text = '${prev.text}$rest';
        _edOf(prev).text.value = TextEditingValue(text: '$_sentinel${prev.text}', selection: TextSelection.collapsed(offset: join + 1));
        setState(() {
          _blocks.removeAt(i);
          _eds.remove(b.id)?.dispose();
        });
        _focus(i - 1, at: join);
      } else {
        // first line (or after a picture): stay, but a list item / heading becomes plain text
        e.text.value = TextEditingValue(text: '$_sentinel$rest', selection: const TextSelection.collapsed(offset: 1));
        if (b.t != 'p' && b.t != 'callout') setState(() => b.t = 'p');
        if (i > 0 && !_blocks[i - 1].isText) setState(() => _current = i - 1);
      }
      changed();
      return;
    }
    var text = raw.substring(1);
    // Enter: split the line (an empty list item / checkbox / quote becomes plain text)
    final nl = text.indexOf('\n');
    if (nl >= 0) {
      final before = text.substring(0, nl);
      final after = text.substring(nl + 1).replaceAll('\n', ' ');
      if (before.isEmpty && after.isEmpty && ['bullet', 'check', 'quote'].contains(b.t)) {
        b.text = '';
        e.text.value = const TextEditingValue(text: _sentinel, selection: TextSelection.collapsed(offset: 1));
        setState(() => b.t = 'p');
        changed();
        return;
      }
      b.text = before;
      e.text.value = TextEditingValue(text: '$_sentinel$before', selection: TextSelection.collapsed(offset: before.length + 1));
      final next = NtBlock.blank(['bullet', 'check'].contains(b.t) ? b.t : 'p')..text = after;
      if (b.t == 'check' || b.t == 'bullet') next.style = {...b.style};
      setState(() => _blocks.insert(i + 1, next));
      _focus(i + 1);
      changed();
      return;
    }
    // shortcuts on a plain line: "- " list, "[] " checkbox, "# " heading, "> " quote, "---" line (style pack)
    if (b.t == 'p') {
      final rules = <String, String>{'- ': 'bullet', '* ': 'bullet', '[] ': 'check', '[ ] ': 'check', '# ': 'h', '> ': 'quote'};
      for (final r in rules.entries) {
        if (text.startsWith(r.key)) {
          text = text.substring(r.key.length);
          e.text.value = TextEditingValue(text: '$_sentinel$text', selection: TextSelection.collapsed(offset: text.length + 1));
          setState(() => b.t = r.value);
          break;
        }
      }
    }
    b.text = text;
    changed();
  }

  void _setType(String t) {
    final b = currentBlock;
    if (b == null || !b.isText || readOnly) return;
    setState(() => b.t = b.t == t ? 'p' : t);
    changed();
    _focus(_current, end: true);
  }

  @override
  void insertAfter(NtBlock nb, {bool focus = true}) {
    final at = (_current >= 0 ? _current + 1 : _blocks.length).clamp(0, _blocks.length);
    setState(() {
      // an empty plain line under the caret is replaced instead of left behind
      final cur = currentBlock;
      if (cur != null && cur.t == 'p' && cur.text.isEmpty && !nb.isText) {
        _blocks[_current] = nb;
        _eds.remove(cur.id)?.dispose();
      } else {
        _blocks.insert(at, nb);
      }
      if (!nb.isText && _blocks.last.id == nb.id) _blocks.add(NtBlock.blank());
    });
    changed();
    final i = _blocks.indexWhere((x) => x.id == nb.id);
    if (focus) {
      nb.isText ? _focus(i, end: true) : setState(() => _current = i);
    }
  }

  @override
  void replaceBlock(int index, NtBlock b) {
    if (index < 0 || index >= _blocks.length) return;
    setState(() {
      final old = _blocks[index];
      if (old.id != b.id) _eds.remove(old.id)?.dispose();
      _blocks[index] = b;
    });
    changed();
  }

  void _move(int d) {
    final i = _current;
    final j = i + d;
    if (i < 0 || j < 0 || j >= _blocks.length) return;
    setState(() {
      final b = _blocks.removeAt(i);
      _blocks.insert(j, b);
      _current = j;
    });
    changed();
  }

  void _removeCurrent() {
    final i = _current;
    if (i < 0) return;
    setState(() {
      final b = _blocks.removeAt(i);
      _eds.remove(b.id)?.dispose();
      if (_blocks.isEmpty) _blocks.add(NtBlock.blank());
      _current = (i - 1).clamp(0, _blocks.length - 1);
    });
    changed();
  }

  // ---------------------------------------------------------------- files
  @override
  Future<Json?> attachBytes(List<int> bytes, String name, {bool sign = false, bool voice = false}) async {
    if (readOnly) return null;
    if (bytes.length > ctx.fileLimit) {
      ctx.notify(ctx.m('tooBig', {'mb': ctx.fileLimit ~/ 1048576}));
      return null;
    }
    try {
      final f = await ntAttachFile(
        ctx.a,
        nid,
        bytes,
        name,
        sign: sign,
        voice: voice,
        fileLimit: ctx.fileLimit,
        onStep: (step, p) {
          if (!mounted) return;
          setState(
            () => _upload = switch (step) {
              'prepare' => ctx.m('padStepPrepare'),
              'upload' => ctx.m('uploading', {'p': (p * 100).round()}),
              _ => ctx.m('padStepAttach'),
            },
          );
        },
      );
      if (!mounted) return f;
      setState(() {
        _upload = '';
        _note = {
          ...note,
          'files': [...files.where((x) => str(x['_id']) != str(f['_id'])), f],
        };
      });
      ctx.reload();
      return f;
    } catch (e) {
      if (mounted) setState(() => _upload = '');
      ctx.fail(e);
      return null;
    }
  }

  Future<void> _attach() async {
    if (readOnly || _upload.isNotEmpty) return;
    final src = await showSheet<String>(
      context,
      (s) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.image), title: Text(ctx.x('photo')), onTap: () => Navigator.pop(s, 'gallery')),
            ListTile(leading: const Icon(LucideIcons.camera), title: Text(ctx.x('camera')), onTap: () => Navigator.pop(s, 'camera')),
            ListTile(leading: const Icon(LucideIcons.paperclip), title: Text(ctx.x('anyFile')), onTap: () => Navigator.pop(s, 'file')),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (src == null) return;
    List<int>? bytes;
    String name = '';
    if (src == 'file') {
      final f = await FilePicker.pickFile(type: FileType.any);
      if (f == null) return;
      bytes = await f.xFile.readAsBytes();
      name = f.name;
    } else {
      final x = await ImagePicker().pickImage(source: src == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 88);
      if (x == null) return;
      bytes = await x.readAsBytes();
      name = x.name.isNotEmpty ? x.name : 'photo.jpg';
    }
    final f = await attachBytes(bytes, name);
    if (f == null || !mounted) return;
    insertAfter(NtBlock.blank('file')..fileId = str(f['_id']));
  }

  // ---------------------------------------------------------------- note settings
  Future<void> _colour() async {
    final pick = await showSheet<String>(
      context,
      (s) => MSheet(
        title: ctx.m('colour'),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final k in ntColours)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(s, k),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ntPaper(s, k),
                          border: Border.all(color: str(note['color']) == k ? ntAccent(k) : s.c.line, width: str(note['color']) == k ? 3 : 1.5),
                        ),
                        child: str(note['color']) == k ? Icon(LucideIcons.check, color: ntAccent(k)) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ctx.m('colours.$k'), style: TextStyle(fontSize: 12, color: s.c.muted)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    if (pick == null || pick == str(note['color'])) return;
    final r = await ctx.run(() => ctx.a.update(nid, {'color': pick}));
    if (r != null && mounted) setState(() => _note = {...note, 'color': pick});
  }

  Future<void> _groups() async {
    final after = await ntPickGroups(context, ctx, nid: nid, current: _groupIds);
    if (after != null && mounted) setState(() => _groupIds = after);
  }

  Future<void> _share() async {
    final fresh = await ntShareNote(context, ctx, note, groupCount: _groupIds.length);
    if (fresh != null && mounted) setNote(fresh);
  }

  Future<void> _menu() async {
    final items = ntNoteMenu.where((a) => a.visible?.call(this) ?? true).toList();
    final pick = await showSheet<String>(
      context,
      (s) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.palette), title: Text(ctx.m('colour')), onTap: () => Navigator.pop(s, '_colour')),
            ListTile(leading: const Icon(LucideIcons.folders), title: Text(ctx.m('groupsBtn')), onTap: () => Navigator.pop(s, '_groups')),
            ListTile(leading: const Icon(LucideIcons.externalLink), title: Text(ctx.m('openLink')), onTap: () => Navigator.pop(s, '_open')),
            for (final a in items)
              ListTile(
                leading: Icon(a.icon),
                title: Text(ctx.m(a.label)),
                trailing: a.needs != null && !ctx.owned(a.needs!) ? Icon(LucideIcons.lock, size: 15, color: s.c.muted) : null,
                onTap: () => Navigator.pop(s, a.key),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case '_colour':
        return _colour();
      case '_groups':
        return _groups();
      case '_open':
        await ntLaunch(ctx, ntUrl(obj(note['share'])['path']));
        return;
    }
    final a = items.firstWhere((x) => x.key == pick);
    if (a.needs != null && !ctx.owned(a.needs!)) {
      await ctx.askBuy(a.needs!);
      return;
    }
    await a.run(this);
  }

  Future<void> _tool(NtToolAction a) async {
    if (a.needs != null && !ctx.owned(a.needs!)) {
      await ctx.askBuy(a.needs!);
      return;
    }
    await a.run(this);
  }

  // ---------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_note == null) {
      return Scaffold(
        backgroundColor: c.appBg,
        appBar: AppBar(backgroundColor: c.appBg, surfaceTintColor: Colors.transparent),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _error.isNotEmpty ? LoadError(text: _error, retry: ctx.m('retry'), onRetry: _load) : const SkelList(rows: 5),
        ),
      );
    }
    final tabs = ntNoteTabs.where((t) => t.visible(this)).toList();
    if (!tabs.any((t) => t.key == _tab)) _tab = 'note';
    final tab = tabs.firstWhere((t) => t.key == _tab);
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        if (_dirty) _save();
      },
      child: Scaffold(
        backgroundColor: ntPaper(context, str(note['color'])) == c.card ? c.appBg : ntPaper(context, str(note['color'])),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _top(),
              _tabsBar(tabs),
              if (_conflict != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Alert(
                    ctx.m('conflict'),
                    tone: Tone.warn,
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Btn(ctx.m('conflictReload'), small: true, icon: LucideIcons.refreshCw, onTap: _loadTheirs),
                        Btn(ctx.m('conflictKeep'), small: true, kind: BtnKind.ghost, onTap: _keepMine),
                      ],
                    ),
                  ),
                ),
              if (readOnly && note['deleted'] != true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Alert(ctx.m('locked'), tone: Tone.warn),
                ),
              Expanded(child: tab.key == 'note' ? _editor() : (tab.builder?.call(this) ?? NtTabSoon(ctx: ctx, title: tab.label(this), icon: tab.icon))),
              if (tab.key == 'note' && !readOnly) _toolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _top() {
    final c = context.c;
    final share = obj(note['share']);
    final status = switch (_status) {
      'saving' => ctx.m('saving'),
      'saved' => ctx.m('saved'),
      'error' => ctx.m('notSaved'),
      'dirty' => ctx.m('saving'),
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Row(
        children: [
          RoundBtn(LucideIcons.arrowLeft, size: 42, tip: widget.fromGroup != null ? ctx.m('backToGroup') : ctx.m('back'), onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.fromGroup != null) Text(ctx.m('backToGroup'), style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NtLevelBadge(ctx: ctx, level: str(share['level']), pin: share['has_pin'] == true),
                    if (_groupIds.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.folder, size: 13, color: c.muted),
                          const SizedBox(width: 2),
                          Text('${_groupIds.length}', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    if (status.isNotEmpty)
                      Text(
                        status,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _status == 'error' ? c.danger : c.muted, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Btn(ctx.m('share'), icon: LucideIcons.share2, small: true, onTap: _share),
          IconButton(
            tooltip: ctx.m('groupsBtn'),
            onPressed: _groups,
            icon: Icon(LucideIcons.folders, size: 20, color: c.ink),
          ),
          IconButton(
            onPressed: _menu,
            icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: c.ink),
          ),
        ],
      ),
    );
  }

  Widget _tabsBar(List<NtNoteTab> tabs) {
    final c = context.c;
    return SizedBox(
      height: 46,
      child: ListView(
        key: const ValueKey('nt-note-tabs'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          for (final t in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: t.key == _tab ? c.card : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_dirty) _save();
                    setState(() => _tab = t.key);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 15, color: t.key == _tab ? c.brand : c.muted),
                        const SizedBox(width: 6),
                        Text(
                          t.label(this),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: t.key == _tab ? c.ink : c.muted),
                        ),
                        if (t.key == 'entries' && _entriesNew > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              '$_entriesNew',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                        if (t.key == 'files' && files.isNotEmpty) ...[const SizedBox(width: 6), Text('${files.length}', style: TextStyle(color: c.muted, fontSize: 12))],
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

  Widget _editor() {
    final c = context.c;
    if (readOnly) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(_title.text.isEmpty ? ctx.m('untitled') : _title.text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          NtReadBlocks(ctx: ctx, blocks: _blocks, files: files, nid: nid),
        ],
      );
    }
    // built under the backdrops (a night paper gives the text its dark look too)
    Widget body = Builder(
      builder: (context) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // a tap below the last line goes to the end
        if (_blocks.isNotEmpty && _blocks.last.isText) _focus(_blocks.length - 1, end: true);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          TextField(
            controller: _title,
            focusNode: _titleFocus,
            maxLines: null,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _focus(0, end: true),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: ctx.m('titlePh'),
              hintStyle: TextStyle(color: c.muted.withValues(alpha: .7)),
            ),
          ),
          const SizedBox(height: 4),
          for (final (i, b) in _blocks.indexed) _row(context, i, b),
        ],
      ),
    ),
    );
    for (final d in ntEditorBackdrops) {
      body = d(this, body);
    }
    return body;
  }

  Widget _row(BuildContext context, int i, NtBlock b) {
    final c = context.c;
    final on = i == _current;
    final view = NtBlockView(context, ctx, b, files, i, nid: nid);
    Widget body;
    if (!b.isText) {
      body = GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _current = i);
        },
        child: ntBlockView(view),
      );
    } else {
      final e = _edOf(b);
      final style = ntTextStyle(context, b);
      final field = TextField(
        controller: e.text,
        focusNode: e.focus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textAlign: ntAlign(b),
        style: style,
        onChanged: (v) => _onText(b, v),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          hintText: on && b.text.isEmpty ? _hint(b.t) : null,
          hintStyle: TextStyle(color: c.muted.withValues(alpha: .7), fontSize: style.fontSize, fontWeight: FontWeight.w400, fontStyle: FontStyle.normal),
        ),
      );
      final hl = ntHighlight(context, b.style['bg']);
      body = switch (b.t) {
        'bullet' => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 6 + ntFontSize(b) * .62, right: 10, left: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
              ),
            ),
            Expanded(child: field),
          ],
        ),
        'check' => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: NtCheckBox(
                on: b.done,
                onTap: () {
                  setState(() => b.done = !b.done);
                  changed();
                },
              ),
            ),
            Expanded(child: field),
          ],
        ),
        'quote' => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.brand, width: 3)),
          ),
          child: field,
        ),
        'callout' => NtCallout(view: view, child: field),
        _ => field,
      };
      if (hl != null && b.t != 'callout') {
        body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: hl, borderRadius: BorderRadius.circular(6)),
          child: body,
        );
      }
    }
    final below = [for (final f in ntBlockBelow) f(this, view)].whereType<Widget>().toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: !b.isText && on ? Border.all(color: c.brand, width: 2) : null,
      ),
      padding: !b.isText ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [body, ...below]),
    );
  }

  String _hint(String t) => switch (t) {
    'h' => ctx.m('headingPh'),
    'bullet' => ctx.m('bulletPh'),
    'check' => ctx.m('checkPh'),
    'quote' => ctx.m('quotePh'),
    'callout' => ctx.m('calloutPh'),
    _ => ctx.m('blockPh'),
  };

  Widget _toolbar() {
    final c = context.c;
    final b = currentBlock;
    final tools = ntToolActions.where((a) => a.visible?.call(this) ?? true).toList();
    Widget btn(IconData icon, String tip, VoidCallback? onTap, {bool on = false, bool lock = false}) => Tooltip(
      message: tip,
      child: Material(
        color: on ? c.active : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: onTap == null ? c.muted.withValues(alpha: .5) : (on ? c.brandInk : c.ink)),
                if (lock) Positioned(right: 5, top: 5, child: Icon(LucideIcons.lock, size: 10, color: c.muted)),
              ],
            ),
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_upload.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_upload, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                for (final k in ntBlockKinds.values.where((k) => k.inTypeBar)) btn(k.icon, ctx.m(k.label), b != null && b.isText && b.t != 'callout' ? () => _setType(k.type) : null, on: b?.t == k.type),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), color: c.line),
                btn(LucideIcons.paperclip, ctx.m('attach'), _upload.isEmpty ? _attach : null),
                for (final a in tools) btn(a.icon, ctx.m(a.label), () => _tool(a), lock: a.needs != null && !ctx.owned(a.needs!)),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), color: c.line),
                btn(LucideIcons.arrowUp, ctx.m('moveUp'), b != null && _current > 0 ? () => _move(-1) : null),
                btn(LucideIcons.arrowDown, ctx.m('moveDown'), b != null && _current < _blocks.length - 1 ? () => _move(1) : null),
                btn(LucideIcons.trash2, ctx.m('removeBlock'), b != null && (_blocks.length > 1 || b.text.isNotEmpty || !b.isText) ? _removeCurrent : null),
                btn(LucideIcons.keyboardOff, ctx.x('hideKeyboard'), () => FocusScope.of(context).unfocus()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// a note tab that comes in the next update
class NtTabSoon extends StatelessWidget {
  final NtCtx ctx;
  final String title;
  final IconData icon;
  const NtTabSoon({super.key, required this.ctx, required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: [
      Panel(
        child: NtEmpty(icon: icon, title: title, sub: ctx.x('soon')),
      ),
    ],
  );
}

// copy a text and say so (used by share / files)
Future<void> ntCopy(NtCtx ctx, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  ctx.notify(ctx.m('copied'));
}
