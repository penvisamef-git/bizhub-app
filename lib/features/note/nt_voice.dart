import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:record/record.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../mart/mart_kit.dart' show showSheet;
import 'nt_blocks.dart';
import 'nt_common.dart';
import 'nt_editor.dart';
import 'nt_extras_text.dart';

// Voice notes (note_voice): record up to 5 minutes (pause, go on, listen before saving), upload as voice: true →
// an "audio" block with a player (play / pause, position, 1× 1.5× 2×, download). The web's note/voice.jsx.

const ntVoiceMaxSecs = 300;

String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

// the toolbar button
Future<void> ntVoiceTool(NtEditorApi ed) async {
  final clip = await showSheet<NtClip>(ed.context, (_) => NtRecorder(ctx: ed.ctx));
  if (clip == null) return;
  // every step of the upload has its own time limit (and really stops): no outer timer that only stops waiting
  final f = await ed.attachBytes(clip.bytes, clip.name, voice: true);
  if (f == null) return;
  ed.insertAfter(NtBlock.blank('audio')..fileId = str(f['_id']), focus: true);
}

class NtClip {
  final List<int> bytes;
  final String name;
  final int secs;
  const NtClip(this.bytes, this.name, this.secs);
}

// ---------------------------------------------------------------- the recorder sheet
class NtRecorder extends StatefulWidget {
  final NtCtx ctx;
  final String initial; // tests: idle | recording | paused | done | denied
  final int initialSecs;
  const NtRecorder({super.key, required this.ctx, this.initial = 'idle', this.initialSecs = 0});
  @override
  State<NtRecorder> createState() => _NtRecorderState();
}

class _NtRecorderState extends State<NtRecorder> {
  AudioRecorder? _rec;
  late String _state = widget.initial; // idle | asking | recording | paused | done | denied | error
  late int _secs = widget.initialSecs;
  Timer? _timer;
  String? _path;
  List<int>? _bytes;
  AudioPlayer? _player;
  bool _playing = false;

  NtCtx get ctx => widget.ctx;

  @override
  void dispose() {
    _timer?.cancel();
    _rec?.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _state = 'asking');
    try {
      final rec = _rec ??= AudioRecorder();
      if (!await rec.hasPermission()) {
        if (mounted) setState(() => _state = 'denied');
        return;
      }
      _path = kIsWeb ? '' : '${Directory.systemTemp.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: _path!);
      _secs = 0;
      _bytes = null;
      if (!mounted) return;
      setState(() => _state = 'recording');
      _tick();
    } catch (_) {
      if (mounted) setState(() => _state = 'denied');
    }
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state != 'recording') return;
      setState(() => _secs++);
      if (_secs >= ntVoiceMaxSecs) _stop();
    });
  }

  Future<void> _pause() async {
    try {
      await _rec?.pause();
      _timer?.cancel();
      setState(() => _state = 'paused');
    } catch (_) {}
  }

  Future<void> _resume() async {
    try {
      await _rec?.resume();
      setState(() => _state = 'recording');
      _tick();
    } catch (_) {}
  }

  Future<void> _stop() async {
    _timer?.cancel();
    try {
      final path = await _rec?.stop();
      if (path == null || path.isEmpty) throw StateError('no file');
      _path = path;
      _bytes = await XFileReader.read(path);
      if (mounted) setState(() => _state = 'done');
    } catch (_) {
      if (mounted) setState(() => _state = 'error');
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      await _rec?.cancel();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _listen() async {
    var p = _player;
    if (p == null) {
      p = _player = AudioPlayer();
      // one listener for the player's whole life (not one more on every play)
      p.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
    if (_playing) {
      await p.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await p.play(kIsWeb ? UrlSource(_path!) : DeviceFileSource(_path!));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      ctx.notify(ntE(ctx, 'playErr'));
    }
  }

  void _save() {
    final b = _bytes;
    if (b == null || b.isEmpty) return;
    Navigator.pop(context, NtClip(b, 'voice-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}', _secs));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rec = _state == 'recording' || _state == 'paused';
    final left = ntVoiceMaxSecs - _secs;
    return PopScope(
      canPop: !rec,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.m('vcTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                switch (_state) {
                  'done' => ctx.m('vcDone'),
                  'asking' => ctx.m('vcAsking'),
                  'recording' => ntE(ctx, 'recording'),
                  'paused' => ntE(ctx, 'paused'),
                  _ => ctx.m('vcHint', {'n': ntVoiceMaxSecs ~/ 60}),
                },
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: 18),
              // the big round button + the time
              _MicDot(on: _state == 'recording', done: _state == 'done'),
              const SizedBox(height: 12),
              Text(
                _mmss(_secs),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              if (rec) Text(ctx.m('vcLeft', {'t': _mmss(left < 0 ? 0 : left)}), style: TextStyle(color: c.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              if (rec)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: _secs / ntVoiceMaxSecs, minHeight: 6, backgroundColor: c.bg2),
                ),
              if (_state == 'denied') ...[const SizedBox(height: 8), Alert(ntE(ctx, 'micOff'), tone: Tone.warn)],
              if (_state == 'error') ...[const SizedBox(height: 8), Alert(ctx.m('loadFail'), tone: Tone.danger)],
              const SizedBox(height: 18),
              ...switch (_state) {
                'recording' || 'paused' => [
                  Row(
                    children: [
                      Expanded(
                        child: Btn(_state == 'paused' ? ctx.m('vcResume') : ctx.m('vcPause'), kind: BtnKind.ghost, icon: _state == 'paused' ? LucideIcons.play : LucideIcons.pause, expand: true, onTap: _state == 'paused' ? _resume : _pause),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Btn(ctx.m('vcStop'), icon: LucideIcons.square, expand: true, onTap: _stop)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _cancel, child: Text(ctx.m('cancel'))),
                ],
                'done' => [
                  Btn(_playing ? ctx.m('vcPause') : ntE(ctx, 'preview'), kind: BtnKind.ghost, icon: _playing ? LucideIcons.pause : LucideIcons.play, expand: true, onTap: _listen),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Btn(ctx.m('vcAgain'), kind: BtnKind.ghost, icon: LucideIcons.rotateCcw, expand: true, onTap: _start)),
                      const SizedBox(width: 10),
                      Expanded(child: Btn(ctx.m('vcSave'), icon: LucideIcons.check, expand: true, onTap: _save)),
                    ],
                  ),
                ],
                'asking' => [const Center(child: CircularProgressIndicator())],
                _ => [Btn(ctx.m('vcStart'), icon: LucideIcons.mic, expand: true, onTap: _start), const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(context), child: Text(ctx.m('cancel')))],
              },
            ],
          ),
        ),
      ),
    );
  }
}

// reads a recorded file (separate so tests never touch the disk)
class XFileReader {
  static Future<List<int>> read(String path) => File(path).readAsBytes();
}

class _MicDot extends StatelessWidget {
  final bool on, done;
  const _MicDot({required this.on, required this.done});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.danger : (done ? c.goodBg : c.active),
        boxShadow: [if (on) BoxShadow(color: c.danger.withValues(alpha: .35), blurRadius: 24, spreadRadius: 6)],
      ),
      child: Icon(done ? LucideIcons.audioLines : LucideIcons.mic, size: 38, color: on ? Colors.white : (done ? c.good : c.brand)),
    );
  }
}

// ---------------------------------------------------------------- the player (an "audio" block)
class NtAudioBlock extends StatelessWidget {
  final NtBlockView view;
  const NtAudioBlock({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final f = view.file;
    if (f == null) return const SizedBox.shrink();
    return NtAudioPlayer(ctx: view.ctx, file: f, nid: view.nid);
  }
}

class NtAudioPlayer extends StatefulWidget {
  final NtCtx ctx;
  final Json file;
  final String nid, eid;
  const NtAudioPlayer({super.key, required this.ctx, required this.file, this.nid = '', this.eid = ''});
  @override
  State<NtAudioPlayer> createState() => _NtAudioPlayerState();
}

class _NtAudioPlayerState extends State<NtAudioPlayer> {
  AudioPlayer? _p; // made on the first tap (no audio engine until someone listens)
  final _subs = <StreamSubscription<Object?>>[];
  bool _playing = false, _loading = false;
  Duration _pos = Duration.zero, _len = Duration.zero;
  double _speed = 1;

  NtCtx get ctx => widget.ctx;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p?.dispose();
    super.dispose();
  }

  Future<String> _url() async {
    final u = str(widget.file['url']);
    if (u.isNotEmpty) return u;
    final r = widget.eid.isNotEmpty ? await ctx.a.entryDownload(widget.eid, str(widget.file['_id']), inline: true) : await ctx.a.download(widget.nid, str(widget.file['_id']), inline: true);
    return str(obj(r['data'])['url']);
  }

  Future<void> _toggle() async {
    var p = _p;
    if (p == null) {
      p = _p = AudioPlayer();
      _subs
        ..add(p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null))
        ..add(p.onDurationChanged.listen((d) => mounted ? setState(() => _len = d) : null))
        ..add(
          p.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _playing = false;
                _pos = Duration.zero;
              });
            }
          }),
        );
    }
    if (_playing) {
      await p.pause();
      setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      if (_pos == Duration.zero) {
        await p.play(UrlSource(await _url()));
      } else {
        await p.resume();
      }
      await p.setPlaybackRate(_speed);
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      ctx.notify(ntE(ctx, 'playErr'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextSpeed() {
    final next = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0);
    setState(() => _speed = next);
    _p?.setPlaybackRate(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = _len.inMilliseconds;
    final at = total == 0 ? 0.0 : (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    final accent = ntKindColour('audio');
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Material(
            color: accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _loading ? null : _toggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Icon(_playing ? LucideIcons.pause : LucideIcons.play, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // a wave-like progress line
                SizedBox(
                  height: 26,
                  child: LayoutBuilder(
                    builder: (_, box) => GestureDetector(
                      onTapDown: (d) {
                        if (total == 0 || box.maxWidth <= 0) return;
                        final x = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
                        _p?.seek(Duration(milliseconds: (x * total).round()));
                      },
                      child: CustomPaint(painter: _WavePainter(at, accent, c.lineStrong), child: const SizedBox.expand()),
                    ),
                  ),
                ),
                Text(
                  '${_mmss(_pos.inSeconds)}${total > 0 ? ' / ${_mmss(_len.inSeconds)}' : ''}  ·  ${str(widget.file['name'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: EdgeInsets.zero),
            onPressed: _nextSpeed,
            child: Text(
              '${_speed == 1.5 ? '1.5' : _speed.toStringAsFixed(0)}×',
              style: TextStyle(fontWeight: FontWeight.w800, color: c.ink),
            ),
          ),
          IconButton(
            tooltip: ctx.m('download'),
            onPressed: () => ntOpenFile(ctx, widget.file, nid: widget.nid, eid: widget.eid, inline: false),
            icon: Icon(LucideIcons.download, size: 18, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double at;
  final Color on, off;
  const _WavePainter(this.at, this.on, this.off);
  static const _h = [.35, .6, .45, .8, .55, .95, .4, .7, .38, .66, .5, .78, .32, .58, .44, .86, .52, .7, .4, .62, .36, .74, .48, .9, .42, .6, .34, .56];
  @override
  void paint(Canvas canvas, Size size) {
    final n = _h.length;
    final w = size.width / n;
    final p = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = w * i + w / 2;
      final h = size.height * _h[i] * .9;
      p
        ..strokeWidth = (w * .55).clamp(1.5, 4.0)
        ..color = (i + .5) / n <= at ? on : off;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.at != at || old.on != on;
}
