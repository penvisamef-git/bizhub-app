import 'dart:async';
import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../admin/admin_parts.dart';

// "Chat with BizHub" (dashboard/support): the owner's SupportPage, the super admin's InboxPage + thread,
// sharing the bubbles + composer (ChatParts.jsx)

// ---------------------------------------------------------------- time helpers (Asia/Phnom_Penh)
DateTime? _kh(Object? v) {
  final d = DateTime.tryParse(str(v));
  return d?.toUtc().add(const Duration(hours: 7));
}

String _hm(Object? v) {
  final d = _kh(v);
  return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _day(Object? v) {
  final d = _kh(v);
  return d == null ? '' : '${d.year}-${d.month}-${d.day}';
}

String _when(Object? v, String lang) {
  final d = _kh(v);
  if (d == null) return '';
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  if (d.year == now.year && d.month == now.month && d.day == now.day) return _hm(v);
  return fmtDate(d.toIso8601String(), lang: lang).replaceAll(RegExp(r' \d{4}$'), '');
}

String _kb(num b) => b > 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB' : '${(b / 1024).round().clamp(1, 1 << 30)} KB';

void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

// keep older pages already loaded when the newest page comes back from a poll
List<Json> _merge(List<Json> cur, List<Json> fresh) {
  if (cur.isEmpty) return fresh;
  final ids = {for (final m in fresh) str(m['_id'])};
  final first = DateTime.tryParse(str(fresh.firstOrNull?['created_date'])) ?? DateTime(0);
  return [...cur.where((m) => !ids.contains(str(m['_id'])) && (DateTime.tryParse(str(m['created_date'])) ?? DateTime(0)).isBefore(first)), ...fresh];
}

// ---------------------------------------------------------------- a file waiting to be sent
class ChatFile {
  final List<int> bytes;
  final String name;
  const ChatFile(this.bytes, this.name);
  bool get image => RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(name);
  String get type {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };
  }
}

FormData chatForm(String text, List<ChatFile> files) => FormData.fromMap({
  'text': text,
  'files': [for (final f in files) MultipartFile.fromBytes(f.bytes, filename: f.name, contentType: DioMediaType.parse(f.type))],
});

// ---------------------------------------------------------------- the conversation (Bubbles)
class ChatList extends StatelessWidget {
  final List<Json> messages;
  final String mine; // "customer" or "admin"
  final bool more;
  final VoidCallback? onOlder;
  final String? emptyHello;
  final String themName, themPhoto;
  final bool themLogo; // customers see the BizHub logo
  final Object? seenAt;
  const ChatList({
    super.key,
    required this.messages,
    required this.mine,
    this.more = false,
    this.onOlder,
    this.emptyHello,
    required this.themName,
    this.themPhoto = '',
    this.themLogo = false,
    this.seenAt,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(tProvider);
        final c = context.c;
        final lastMine = messages.lastWhere((m) => m['from'] == mine && str(m['kind']).isEmpty, orElse: () => const {});
        final seenD = DateTime.tryParse(str(seenAt));
        final lastD = DateTime.tryParse(str(lastMine['created_date']));
        final seen = lastMine.isNotEmpty && seenD != null && lastD != null && !seenD.isBefore(lastD);
        final today = _day(DateTime.now().toUtc().toIso8601String());
        // newest at the bottom: build top→bottom then show reversed so the list starts at the end
        final items = <Widget>[];
        if (more) {
          items.add(
            Center(
              child: TextButton(onPressed: onOlder, child: Text(t('support.older'))),
            ),
          );
        }
        if (messages.isEmpty && emptyHello != null) items.add(_Bubble(own: false, avatar: _av(), who: themName, children: [_text(emptyHello!, false, c)]));
        var day = '';
        for (var i = 0; i < messages.length; i++) {
          final m = messages[i];
          final d = _day(m['created_date']);
          if (d != day) {
            items.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(child: Chip2(d == today ? t('support.today') : fmtDate(m['created_date'], lang: t.lang))),
              ),
            );
          }
          final prev = i > 0 ? messages[i - 1] : null;
          final first = prev == null || prev['from'] != m['from'] || _day(prev['created_date']) != d;
          day = d;
          final own = m['from'] == mine;
          final sys = str(m['kind']).isNotEmpty;
          final files = objs(m['files']);
          items.add(
            _Bubble(
              own: own,
              sys: sys,
              avatar: own ? null : (first ? _av() : const SizedBox(width: 32)),
              who: !own && first ? (themName.isNotEmpty ? themName : str(m['by_name'])) : '',
              time: _hm(m['created_date']),
              tick: own && identical(m, lastMine) ? (seen ? LucideIcons.checkCheck : LucideIcons.check) : null,
              children: [
                for (final f in files) _FileView(f: f, own: own),
                if (str(m['text']).isNotEmpty) _text(str(m['text']), own, c),
              ],
            ),
          );
          if (own && identical(m, lastMine)) {
            items.add(
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: Text(
                  seen ? t('support.seen') : t('support.sent'),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11.5, color: seen ? c.brandInk : c.muted, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
        }
        final rev = items.reversed.toList();
        return ListView.builder(reverse: true, padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), itemCount: rev.length, itemBuilder: (_, i) => rev[i]);
      },
    );
  }

  Widget _av() => themLogo
      ? Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Logo(iconOnly: true, height: 22),
        )
      : Avatar(name: themName, photo: themPhoto, size: 32);

  Widget _text(String s, bool own, C c) => SelectableText(s, style: TextStyle(color: own ? Colors.white : c.ink, fontSize: 15, height: 1.4));
}

class _Bubble extends StatelessWidget {
  final bool own, sys;
  final Widget? avatar;
  final String who, time;
  final IconData? tick;
  final List<Widget> children;
  const _Bubble({required this.own, this.sys = false, this.avatar, this.who = '', this.time = '', this.tick, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .74),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
      decoration: BoxDecoration(
        gradient: own && !sys ? c.gradient : null,
        color: own && !sys ? null : (sys ? c.chip : c.card),
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(own ? 18 : 6), bottomRight: Radius.circular(own ? 6 : 18)),
        boxShadow: own ? null : c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (who.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                who,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.brandInk),
              ),
            ),
          for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 3), child: w),
          if (time.isNotEmpty)
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 11, color: own && !sys ? Colors.white70 : c.muted)),
                  if (tick != null) ...[const SizedBox(width: 3), Icon(tick, size: 13, color: Colors.white70)],
                ],
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: own ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (avatar != null) ...[avatar!, const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _FileView extends StatelessWidget {
  final Json f;
  final bool own;
  const _FileView({required this.f, required this.own});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = str(f['url']);
    final type = str(f['type']);
    final fg = own ? Colors.white : c.ink;
    if (type.startsWith('image/')) {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(child: Image(image: netImage(url))),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: netImage(url),
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(width: 220, height: 80, color: c.chip, alignment: Alignment.center, child: const Icon(LucideIcons.imageOff)),
          ),
        ),
      );
    }
    final voice = type.startsWith('audio/');
    if (voice) return _VoicePlayer(url: url, own: own);
    return InkWell(
      onTap: () => _open(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: own ? Colors.white.withValues(alpha: .18) : c.bg2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(voice ? LucideIcons.circlePlay : LucideIcons.fileText, size: 22, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (_, ref, _) => Text(
                      voice ? ref.watch(tProvider)('support.voice') : str(f['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  Text(_kb(n(f['size'])), style: TextStyle(color: own ? Colors.white70 : c.muted, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// a voice message: play / pause, progress, time (plays inside the app)
class _VoicePlayer extends StatefulWidget {
  final String url;
  final bool own;
  const _VoicePlayer({required this.url, required this.own});
  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _p = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero, _len = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      _p.onPlayerStateChanged.listen((s) => mounted ? setState(() => _state = s) : null),
      _p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null),
      _p.onDurationChanged.listen((d) => mounted ? setState(() => _len = d) : null),
      _p.onPlayerComplete.listen((_) => mounted ? setState(() => _pos = Duration.zero) : null),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) return await _p.pause();
      if (_state == PlayerState.paused) return await _p.resume();
      await _p.play(UrlSource(widget.url));
    } catch (_) {
      setState(() => _failed = true);
      _open(widget.url); // this phone can't play it here: open it in the phone's player
    }
  }

  String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = widget.own ? Colors.white : c.ink;
    final playing = _state == PlayerState.playing;
    final v = _len.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / _len.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(color: widget.own ? Colors.white.withValues(alpha: .18) : c.bg2, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            visualDensity: VisualDensity.compact,
            icon: Icon(_failed ? LucideIcons.externalLink : (playing ? LucideIcons.pause : LucideIcons.play), color: fg, size: 20),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(value: v, minHeight: 4, color: fg, backgroundColor: fg.withValues(alpha: .25)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _mmss(playing || _pos > Duration.zero ? _pos : _len),
            style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- write + attach + emoji + send (Composer)
const _emoji = [
  '😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😘', '😎', '🤩', '🤔', '😅', '😢', '😭', '😡', '😴', //
  '🙏', '👍', '👎', '👌', '👏', '🙌', '💪', '🤝', '❤️', '🧡', '💛', '💚', '💙', '💜', '🔥', '✨', //
  '🎉', '🎁', '✅', '❌', '⚠️', '❓', '💰', '🪙', '📱', '💻', '🧾', '📦', '🚚', '☕', '🍜', '⏰',
];

class Composer extends ConsumerStatefulWidget {
  final Future<void> Function(String text, List<ChatFile> files) onSend;
  final bool disabled;
  const Composer({super.key, required this.onSend, this.disabled = false});
  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _files = <ChatFile>[];
  bool _busy = false, _emojiOn = false;
  String _error = '';
  // voice message (up to 2 minutes)
  final _rec = AudioRecorder();
  Timer? _recTimer;
  int? _recSecs; // null = not recording

  @override
  void dispose() {
    _recTimer?.cancel();
    _rec.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _startRec() async {
    final t = ref.read(tProvider);
    setState(() => _error = '');
    try {
      if (!await _rec.hasPermission()) return setState(() => _error = t('support.micDenied'));
      final path = kIsWeb ? '' : '${Directory.systemTemp.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
      setState(() => _recSecs = 0);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recSecs = (_recSecs ?? 0) + 1);
        if ((_recSecs ?? 0) >= 120) _stopRec(true);
      });
    } catch (_) {
      setState(() => _error = t('support.micDenied'));
    }
  }

  Future<void> _stopRec(bool send) async {
    _recTimer?.cancel();
    final secs = _recSecs ?? 0;
    setState(() => _recSecs = null);
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    if (!send || path == null || path.isEmpty || secs < 1) return;
    try {
      final bytes = await XFile(path).readAsBytes();
      final name = 'voice-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}';
      setState(() => _busy = true);
      await widget.onSend('', [ChatFile(bytes, name)]);
    } on ApiError catch (e) {
      _error = e.network ? ref.read(tProvider)('app.offline') : e.message;
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add(List<ChatFile> list) {
    final t = ref.read(tProvider);
    final ok = list.where((f) => f.bytes.length <= 10 * 1024 * 1024).toList();
    setState(() {
      _error = ok.length < list.length ? t('support.hint') : '';
      _files.addAll(ok);
      if (_files.length > 5) _files.removeRange(5, _files.length);
    });
  }

  Future<void> _attach() async {
    final t = ref.read(tProvider);
    final what = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(LucideIcons.image), title: Text(t('app.chatPhotos')), onTap: () => Navigator.pop(ctx, 'photo')),
            ListTile(leading: const Icon(LucideIcons.camera), title: Text(t('app.chatCamera')), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(LucideIcons.paperclip), title: Text(t('app.chatFile')), subtitle: Text(t('support.hint')), onTap: () => Navigator.pop(ctx, 'file')),
          ],
        ),
      ),
    );
    if (what == null) return;
    if (what == 'file') {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip', 'mp3', 'm4a', 'wav', 'ogg'],
      );
      final out = <ChatFile>[];
      for (final f in picked.take(5)) {
        out.add(ChatFile(await f.xFile.readAsBytes(), f.name));
      }
      _add(out);
      return;
    }
    final pick = ImagePicker();
    final imgs = what == 'camera' ? [?await pick.pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85)] : await pick.pickMultiImage(maxWidth: 2000, imageQuality: 85, limit: 5);
    final out = <ChatFile>[];
    for (final x in imgs) {
      final name = x.name.contains('.') ? x.name : '${x.name}.jpg';
      out.add(ChatFile(await x.readAsBytes(), name));
    }
    _add(out);
  }

  void _addEmoji(String e) {
    final v = _text.value;
    final at = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : v.text.length;
    final next = v.text.replaceRange(at, end, e);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + e.length),
    );
    setState(() {});
  }

  Future<void> _go() async {
    if (_busy || (_text.text.trim().isEmpty && _files.isEmpty)) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.onSend(_text.text.trim(), List.of(_files));
      _text.clear();
      _files.clear();
      _emojiOn = false;
    } on ApiError catch (e) {
      _error = e.network ? ref.read(tProvider)('app.offline') : e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final canSend = _text.text.trim().isNotEmpty || _files.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: c.card, boxShadow: c.popShadow),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_files.isNotEmpty)
                SizedBox(
                  height: 70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < _files.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 6),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  color: c.bg2,
                                  alignment: Alignment.center,
                                  child: _files[i].image
                                      ? Image.memory(Uint8List.fromList(_files[i].bytes), width: 64, height: 64, fit: BoxFit.cover)
                                      : Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(LucideIcons.fileText, size: 20, color: c.muted),
                                              Text(
                                                _files[i].name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10, color: c.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: GestureDetector(
                                  onTap: () => setState(() => _files.removeAt(i)),
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: c.solid,
                                    child: Icon(LucideIcons.x, size: 13, color: c.onSolid),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Alert(_error)),
              if (_emojiOn)
                SizedBox(
                  height: 150,
                  child: GridView.count(
                    crossAxisCount: 8,
                    children: [
                      for (final e in _emoji)
                        InkWell(
                          onTap: () => _addEmoji(e),
                          borderRadius: BorderRadius.circular(10),
                          child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                        ),
                    ],
                  ),
                ),
              if (_recSecs != null)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _stopRec(false),
                      tooltip: t('support.cancel'),
                      icon: Icon(LucideIcons.trash2, color: c.danger),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${t('support.recording')} ${_recSecs! ~/ 60}:${(_recSecs! % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
                      child: IconButton(
                        onPressed: () => _stopRec(true),
                        tooltip: t('support.stopSend'),
                        icon: const Icon(LucideIcons.send, size: 19, color: Colors.white),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: widget.disabled ? null : () => setState(() => _emojiOn = !_emojiOn),
                      tooltip: t('support.emoji'),
                      icon: Icon(LucideIcons.smile, color: _emojiOn ? c.brandInk : c.muted),
                    ),
                    IconButton(
                      onPressed: widget.disabled || _busy || _files.length >= 5 ? null : _attach,
                      tooltip: t('support.attach'),
                      icon: Icon(LucideIcons.paperclip, color: c.muted),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        enabled: !widget.disabled,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        onTap: () => _emojiOn ? setState(() => _emojiOn = false) : null,
                        style: TextStyle(fontSize: 15.5, color: c.ink),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: t('support.placeholder'),
                          isDense: true,
                          filled: true,
                          fillColor: c.bg2,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
                      child: IconButton(
                        // nothing written: the button records a voice message
                        onPressed: _busy || widget.disabled ? null : (canSend ? _go : _startRec),
                        tooltip: canSend ? t('support.send') : t('support.record'),
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                            : Icon(canSend ? LucideIcons.send : LucideIcons.mic, size: 19, color: Colors.white),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar of a chat screen
class _ChatHead extends StatelessWidget {
  final Widget avatar;
  final String title, sub;
  final List<Widget> actions;
  const _ChatHead({required this.avatar, required this.title, required this.sub, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(color: c.card, boxShadow: c.cardShadow),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(
            children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(LucideIcons.arrowLeft), tooltip: MaterialLocalizations.of(context).backButtonTooltip),
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                    ),
                    if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _onlineLogo(C c) => Stack(
  clipBehavior: Clip.none,
  children: [
    Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: c.line),
      ),
      child: const Logo(iconOnly: true, height: 28),
    ),
    Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          shape: BoxShape.circle,
          border: Border.all(color: c.card, width: 2),
        ),
      ),
    ),
  ],
);

// a poll that only runs while the app is in front
mixin _Poll<W extends ConsumerStatefulWidget> on ConsumerState<W>, WidgetsBindingObserver {
  Timer? _timer;
  bool _front = true;
  Duration get every;
  Future<void> poll();
  void startPoll() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(every, (_) {
      if (_front && mounted) poll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _front = s == AppLifecycleState.resumed;
    if (_front) poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ---------------------------------------------------------------- owner: Chat with BizHub (SupportPage.jsx)
class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});
  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> with WidgetsBindingObserver, _Poll {
  List<Json>? _msgs;
  bool _more = false;
  Json _hotline = {};
  Object? _seenAt;
  String _error = '';

  @override
  Duration get every => const Duration(seconds: 8);
  @override
  Future<void> poll() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    startPoll();
  }

  Future<void> _load() async {
    try {
      final d = obj((await ref.read(apiProvider).get('${Api.user}/support'))['data']);
      if (!mounted) return;
      setState(() {
        _msgs = _merge(_msgs ?? const [], objs(d['messages']));
        _more = _more || d['more'] == true;
        _hotline = obj(d['hotline']);
        _seenAt = d['seen_at'];
        _error = '';
      });
    } on ApiError catch (e) {
      if (mounted && _msgs == null) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    }
  }

  Future<void> _older() async {
    final d = obj((await ref.read(apiProvider).get('${Api.user}/support', {'before': _msgs?.firstOrNull?['created_date']}))['data']);
    setState(() {
      _msgs = [...objs(d['messages']), ...?_msgs];
      _more = d['more'] == true;
    });
  }

  void _contacts() {
    final t = ref.read(tProvider);
    final h = _hotline;
    final tg = str(h['telegram']).replaceAll(RegExp(r'^https?://t\.me/', caseSensitive: false), '').replaceAll(RegExp(r'^@'), '');
    final phone = str(h['phone']);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('support.contact'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (phone.isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.phone), title: Text(phone), onTap: () => _open('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}')),
              if (tg.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.send), title: Text('@$tg'), onTap: () => _open('https://t.me/$tg')),
              if (str(h['email']).isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.mail), title: Text(str(h['email'])), onTap: () => _open('mailto:${h['email']}')),
              if (str(h['hours']).isNotEmpty) Muted('${t('coin.hours')}: ${h['hours']}'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final hasHot = str(_hotline['phone']).isNotEmpty || str(_hotline['telegram']).isNotEmpty || str(_hotline['email']).isNotEmpty;
    return Scaffold(
      backgroundColor: c.appBg,
      body: Column(
        children: [
          _ChatHead(
            avatar: _onlineLogo(c),
            title: t('support.support'),
            sub: t('support.online'),
            actions: [if (hasHot) IconButton(onPressed: _contacts, icon: const Icon(LucideIcons.phone), tooltip: t('support.contact'))],
          ),
          Expanded(
            child: _msgs == null
                ? (_error.isNotEmpty
                      ? Center(
                          child: Padding(padding: const EdgeInsets.all(20), child: Alert(_error)),
                        )
                      : const ChatSkel())
                : ChatList(messages: _msgs!, mine: 'customer', more: _more, onOlder: _older, emptyHello: t('support.hello'), themName: t('support.support'), themLogo: true, seenAt: _seenAt),
          ),
          Composer(
            disabled: _msgs == null,
            onSend: (text, files) async {
              final r = await ref.read(apiProvider).post('${Api.user}/support', chatForm(text, files));
              setState(() => _msgs = [...?_msgs, obj(r['data'])]);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- super admin: Inbox (InboxPage.jsx)
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});
  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> with WidgetsBindingObserver, _Poll {
  List<Json>? _rows;
  String _q = '';
  bool _unread = false;

  @override
  Duration get every => const Duration(seconds: 10);
  @override
  Future<void> poll() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    startPoll();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('${Api.admin}/support', {'q': _q, 'unread': _unread ? '1' : ''});
      if (mounted) setState(() => _rows = objs(r['data']));
    } on ApiError {
      if (mounted) setState(() => _rows ??= []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    return Scaffold(
      backgroundColor: c.appBg,
      body: Column(
        children: [
          _ChatHead(
            avatar: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.active, shape: BoxShape.circle),
              child: Icon(LucideIcons.inbox, color: c.brandInk, size: 20),
            ),
            title: t('support.inbox'),
            sub: t('support.inboxSub'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: c.brand,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 14, 16, 32 + MediaQuery.of(context).padding.bottom),
                children: [
                  SearchBox(
                    hint: t('support.search'),
                    onSearch: (v) {
                      _q = v;
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  Segs(
                    items: [('all', t('support.all')), ('unread', t('support.unreadOnly'))],
                    value: _unread ? 'unread' : 'all',
                    onTap: (v) {
                      setState(() => _unread = v == 'unread');
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: _rows == null
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: SkelList())
                        : _rows!.isEmpty
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Muted(t('support.noChats')))
                        : Column(children: [for (var i = 0; i < _rows!.length; i++) _row(_rows![i], t, c, i == _rows!.length - 1)]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Json th, T t, C c, bool last) {
    final who = obj(th['customer_id']);
    final name = str(who['name']).isNotEmpty ? str(who['name']) : (str(who['email']).isNotEmpty ? str(who['email']) : '—');
    final unread = n(th['unread_admin']).toInt();
    return ListRow(
      name: name,
      sub: '${th['last_from'] == 'admin' ? '↩ ' : ''}${str(th['last_text']).isEmpty ? '…' : str(th['last_text'])}',
      lead: Avatar(name: name, photo: photoUrl(who['photo']), size: 42),
      last: last,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _when(th['last_at'], t.lang),
            style: TextStyle(fontSize: 11.5, color: unread > 0 ? c.brandInk : c.muted, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w500),
          ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      onTap: () async {
        await context.push('/a/inbox/${th['_id']}');
        _load();
        ref.invalidate(badgesProvider);
      },
    );
  }
}

// one conversation (InboxPage.jsx Thread)
class InboxThreadPage extends ConsumerStatefulWidget {
  final String id;
  const InboxThreadPage({super.key, required this.id});
  @override
  ConsumerState<InboxThreadPage> createState() => _InboxThreadPageState();
}

class _InboxThreadPageState extends ConsumerState<InboxThreadPage> with WidgetsBindingObserver, _Poll {
  Json? _d;
  List<Json> _msgs = [];
  bool _more = false;
  String _error = '';

  @override
  Duration get every => const Duration(seconds: 8);
  @override
  Future<void> poll() => _load();

  String get _path => '${Api.admin}/support/${widget.id}';

  @override
  void initState() {
    super.initState();
    _load(first: true);
    startPoll();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final d = obj((await ref.read(apiProvider).get(_path))['data']);
      if (!mounted) return;
      setState(() {
        _d = d;
        _msgs = _merge(_msgs, objs(d['messages']));
        if (first) _more = d['more'] == true;
      });
      if (first) ref.invalidate(badgesProvider);
    } on ApiError catch (e) {
      if (mounted && _d == null) setState(() => _error = e.message);
    }
  }

  Future<void> _older() async {
    final d = obj((await ref.read(apiProvider).get(_path, {'before': _msgs.firstOrNull?['created_date']}))['data']);
    setState(() {
      _msgs = [...objs(d['messages']), ..._msgs];
      _more = d['more'] == true;
    });
  }

  void _info() {
    final t = ref.read(tProvider);
    final d = _d!;
    final cu = obj(obj(d['thread'])['customer_id']);
    final more = obj(d['customer']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final c = ctx.c;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .92,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  Avatar(name: str(cu['name']), photo: photoUrl(cu['photo']), size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(cu['name']).isNotEmpty ? str(cu['name']) : str(cu['email']), style: Theme.of(ctx).textTheme.titleLarge),
                        Muted(t('support.since', {'date': fmtDate(cu['created_date'] ?? obj(d['thread'])['created_date'], lang: t.lang)})),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (str(cu['phone']).isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.phone), title: Text(str(cu['phone'])), onTap: () => _open('tel:${cu['phone']}')),
              if (str(cu['email']).isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(LucideIcons.mail), title: Text(str(cu['email'])), onTap: () => _open('mailto:${cu['email']}')),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const CoinIcon(size: 26),
                    const SizedBox(width: 10),
                    Text(fmt(more['coins']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(width: 6),
                    Muted(t('support.coins')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('${t('support.businesses')} (${objs(more['businesses']).length})', style: Theme.of(ctx).textTheme.titleMedium),
              for (final b in objs(more['businesses']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: TypeIcon(str(b['category']), size: 36),
                  title: Text(str(b['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.or('sa.categoryNames.${b['category']}', str(b['category']))),
                ),
              if (objs(more['orders']).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(t('support.lastOrders'), style: Theme.of(ctx).textTheme.titleMedium),
                for (final o in objs(more['orders']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${o['no']} · ${fmt(o['total_coins'])} · ${usd(o['usd'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Chip2(
                      t.or('support.status.${o['status']}', str(o['status'])),
                      tone: switch (str(o['status'])) {
                        'approved' => Tone.good,
                        'rejected' => Tone.danger,
                        'pending' => Tone.warn,
                        _ => Tone.muted,
                      },
                    ),
                    onTap: o['status'] == 'pending'
                        ? () {
                            Navigator.pop(ctx);
                            context.push('/a/orders');
                          }
                        : null,
                  ),
              ],
              if (str(cu['_id']).isNotEmpty) ...[
                const SizedBox(height: 14),
                Btn(
                  t('support.customer'),
                  icon: LucideIcons.userRound,
                  kind: BtnKind.ghost,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/a/customer/${cu['_id']}');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final cu = obj(obj(_d?['thread'])['customer_id']);
    final name = str(cu['name']).isNotEmpty ? str(cu['name']) : str(cu['email']);
    return Scaffold(
      backgroundColor: c.appBg,
      body: Column(
        children: [
          _ChatHead(
            avatar: Avatar(name: name, photo: photoUrl(cu['photo']), size: 42),
            title: name.isEmpty ? t('support.inbox') : name,
            sub: [str(cu['email']), str(cu['phone'])].where((e) => e.isNotEmpty).join(' · '),
            actions: [if (_d != null) IconButton(onPressed: _info, icon: const Icon(LucideIcons.info), tooltip: t('support.customer'))],
          ),
          Expanded(
            child: _d == null
                ? (_error.isNotEmpty
                      ? Center(
                          child: Padding(padding: const EdgeInsets.all(20), child: Alert(_error)),
                        )
                      : const ChatSkel())
                : ChatList(messages: _msgs, mine: 'admin', more: _more, onOlder: _older, themName: name, themPhoto: photoUrl(cu['photo']), seenAt: _d!['seen_at']),
          ),
          Composer(
            disabled: _d == null,
            onSend: (text, files) async {
              final r = await ref.read(apiProvider).post(_path, chatForm(text, files));
              setState(() => _msgs = [..._msgs, obj(r['data'])]);
            },
          ),
        ],
      ),
    );
  }
}

// a chat while it loads: grey message bubbles on both sides (them on the left with a photo, me on the right)
class ChatSkel extends StatelessWidget {
  const ChatSkel({super.key});
  static const _rows = [(false, .62, 2), (true, .44, 1), (false, .38, 1), (true, .58, 2), (false, .5, 1)];
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, box) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: [
          for (final (me, w, lines) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!me) ...[const Skel(w: 30, h: 30, r: 15), const SizedBox(width: 8)],
                  Container(
                    width: box.maxWidth * w,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: me ? c.active : c.bg2,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(me ? 18 : 6),
                        bottomRight: Radius.circular(me ? 6 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < lines; i++) ...[if (i > 0) const SizedBox(height: 6), Skel(h: 12, w: i == lines - 1 && lines > 1 ? box.maxWidth * w * .5 : null)],
                        const SizedBox(height: 6),
                        const Align(alignment: Alignment.centerRight, child: Skel(w: 36, h: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
