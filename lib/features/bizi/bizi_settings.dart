import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'bizi_find.dart';

// Bizi settings (the gear on Bizi's screen) — the same as the website's: which alerts Bizi tells me about, the setup
// tips, the Monday report. Saved on the server (GET / PUT /api/user/bizi/prefs): the web, the app and Telegram agree.
class BiziSettingsView extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final Future<void> Function()? onChanged;
  final Widget Function(Json prefs, Future<void> Function(Json body) save)? more; // Bizi on Telegram goes here
  const BiziSettingsView({super.key, required this.onBack, this.onChanged, this.more});
  @override
  ConsumerState<BiziSettingsView> createState() => _BiziSettingsViewState();
}

class _BiziSettingsViewState extends ConsumerState<BiziSettingsView> {
  Json? _p;
  String _err = '';
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = obj((await ref.read(apiProvider).get('${Api.user}/bizi/prefs'))['data']);
      if (mounted) setState(() => _p = r);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _save(Json body) async {
    setState(() {
      _saved = false;
      _err = '';
    });
    try {
      final r = obj((await ref.read(apiProvider).put('${Api.user}/bizi/prefs', body))['data']);
      if (!mounted) return;
      setState(() {
        _p = r;
        _saved = true;
      });
      await widget.onChanged?.call();
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lang = ref.watch(tProvider).lang;
    String x(String k) => biziT(lang, k);
    final p = _p;
    final mute = (p?['mute'] as List? ?? const []).map((e) => '$e').toSet();
    void toggle(String k) => _save({
      'mute': mute.contains(k) ? (mute.toList()..remove(k)) : [...mute, k],
    });
    final alerts = ((obj(p?['keys'])['alerts'] as List?) ?? const []).map((e) => '$e').toList();
    return ListView(
      key: const ValueKey('bizi-settings'),
      padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.of(context).padding.bottom),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: Icon(LucideIcons.arrowLeft, size: 16, color: c.ink),
              label: Text(
                x('setBack'),
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(x('settings'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            AnimatedOpacity(
              opacity: _saved ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                x('setSaved'),
                style: TextStyle(color: c.brandInk, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
        if (_err.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_err, style: TextStyle(color: c.danger)),
          ),
        if (p == null && _err.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (p != null) ...[
          _Head(x('setTell')),
          for (final k in alerts) _Switch(key: ValueKey('bizi-mute-$k'), label: x('alertNames.$k'), on: !mute.contains(k), onChanged: () => toggle(k)),
          _Switch(key: const ValueKey('bizi-mute-tips'), label: x('setTips'), on: !mute.contains('tips'), onChanged: () => toggle('tips')),
          _Switch(key: const ValueKey('bizi-weekly'), label: x('setWeekly'), on: p['weekly'] != false, onChanged: () => _save({'weekly': p['weekly'] == false})),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Text(x('setNote'), style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
          if (widget.more != null) widget.more!(p, _save),
        ],
      ],
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: context.c.muted),
    ),
  );
}

class _Switch extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onChanged;
  const _Switch({super.key, required this.label, required this.on, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      value: on,
      activeTrackColor: c.brand,
      onChanged: (_) => onChanged(),
    );
  }
}
