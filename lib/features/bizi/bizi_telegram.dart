import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'bizi_find.dart';

// Bizi on Telegram, at the top of Bizi settings (the same as the website): connect the owner's own Telegram chat
// with the BizHub bot (a t.me link → Start; this screen sees it by itself), then the morning summary / alerts /
// Monday report switches, a test message, disconnect. POST /api/user/bizi/telegram/link · /test · DELETE.
class BiziTelegramSection extends ConsumerStatefulWidget {
  final Json prefs;
  final Future<void> Function(Json body) save;
  final Future<void> Function() reload;
  final Future<void> Function(Uri url)? open; // tests: no real Telegram
  const BiziTelegramSection({super.key, required this.prefs, required this.save, required this.reload, this.open});
  @override
  ConsumerState<BiziTelegramSection> createState() => _BiziTelegramSectionState();
}

class _BiziTelegramSectionState extends ConsumerState<BiziTelegramSection> with WidgetsBindingObserver {
  bool _waiting = false;
  String _msg = '';
  Timer? _poll;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  // back from Telegram → look at once
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _waiting) widget.reload();
  }

  @override
  void didUpdateWidget(BiziTelegramSection old) {
    super.didUpdateWidget(old);
    if (_waiting && obj(widget.prefs['tg'])['connected'] == true) {
      _poll?.cancel();
      _waiting = false;
    }
  }

  Future<void> _connect() async {
    final lang = ref.read(tProvider).lang;
    setState(() => _msg = '');
    try {
      final r = obj((await ref.read(apiProvider).post('${Api.user}/bizi/telegram/link', {'lang': lang}))['data']);
      final url = Uri.parse(str(r['url']));
      await (widget.open ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(url);
      if (!mounted) return;
      setState(() => _waiting = true);
      _until = DateTime.now().add(const Duration(minutes: 15));
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted || DateTime.now().isAfter(_until!)) {
          _poll?.cancel();
          if (mounted) setState(() => _waiting = false);
          return;
        }
        widget.reload();
      });
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  Future<void> _test() async {
    final lang = ref.read(tProvider).lang;
    try {
      await ref.read(apiProvider).post('${Api.user}/bizi/telegram/test');
      if (mounted) setState(() => _msg = biziT(lang, 'tgSent'));
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  Future<void> _off() async {
    try {
      await ref.read(apiProvider).delete('${Api.user}/bizi/telegram');
      await widget.reload();
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = ref.watch(tProvider).lang;
    String x(String k, [Map<String, Object?> v = const {}]) => biziT(lang, k, v);
    final tg = obj(widget.prefs['tg']);
    const blue = Color(0xFF0369A1);
    Widget sw(String key, String label, String field) => SwitchListTile.adaptive(
      key: ValueKey(key),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      value: tg[field] != false,
      activeTrackColor: c.brand,
      onChanged: (v) => widget.save({
        'tg': {field: v},
      }),
    );
    return Container(
      key: const ValueKey('bizi-tg'),
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
            child: Text(
              x('tgHead').toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: c.muted),
            ),
          ),
          if (tg['configured'] == false)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(x('tgNotReady'), style: TextStyle(color: c.muted)),
            )
          else if (tg['connected'] != true) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(x('tgSub'), style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.45)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Btn(x('tgConnect'), key: const ValueKey('bizi-tg-connect'), icon: LucideIcons.send, small: true, onTap: _connect),
            ),
            if (_waiting)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Text(x('tgWaiting'), style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                key: const ValueKey('bizi-tg-on'),
                children: [
                  Icon(LucideIcons.send, size: 16, color: c.dark ? const Color(0xFF7DD3FC) : blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      x('tgConnected', {'name': str(tg['chat_name']).isEmpty ? 'Telegram' : tg['chat_name']}),
                      style: TextStyle(fontWeight: FontWeight.w800, color: c.dark ? const Color(0xFF7DD3FC) : blue),
                    ),
                  ),
                ],
              ),
            ),
            sw('bizi-tg-morning', x('tgMorning'), 'morning'),
            sw('bizi-tg-alerts', x('tgAlerts'), 'alerts'),
            sw('bizi-tg-weekly', x('tgWeekly'), 'weekly'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Btn(x('tgTest'), key: const ValueKey('bizi-tg-test'), kind: BtnKind.ghost, small: true, onTap: _test),
                  TextButton(
                    onPressed: _off,
                    child: Text(
                      x('tgOff'),
                      style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(_msg, style: TextStyle(color: c.muted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
