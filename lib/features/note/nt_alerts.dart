import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show Segmented, SwitchRow;
import 'nt_common.dart';
import 'nt_more_ui.dart';
import 'nt_page.dart' show NtNav;

// Telegram alerts (note_telegram, yearly — the web's AlertsTab): link the owner's chat (or a team group) with the
// BizHub bot, send a test, choose what to get (replies now / every 15 min / off, sign-ups, edits, "I've read it",
// checklist reminders, the 8:00 summary, the language), unlink. Not unlocked: what it does + the unlock button.

class AlertsSection extends StatefulWidget {
  final NtCtx ctx;
  final NtNav nav;
  const AlertsSection({super.key, required this.ctx, required this.nav});
  @override
  State<AlertsSection> createState() => _AlertsSectionState();
}

class _AlertsSectionState extends State<AlertsSection> {
  NtCtx get ctx => widget.ctx;
  late Json _tg = {...ctx.telegram};
  String _busy = '';
  bool _waiting = false;
  Timer? _poll, _stop;
  bool _polling = false; // waiting for the bot (one question at a time)

  @override
  void didUpdateWidget(AlertsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.ctx.data, ctx.data) && _busy.isEmpty) _tg = {...ctx.telegram};
  }

  @override
  void dispose() {
    _polling = false;
    _poll?.cancel();
    _stop?.cancel();
    super.dispose();
  }

  // after "Connect": ask every 3 s until the bot says the chat is linked (at most 15 min). One question at a time
  // (the next one waits for the answer), with the light Telegram-state call (an older API: the book read)
  void _wait() {
    _poll?.cancel();
    _stop?.cancel();
    _polling = true;
    setState(() => _waiting = true);
    _poll = Timer(const Duration(seconds: 3), _ask);
    _stop = Timer(const Duration(minutes: 15), () {
      _polling = false;
      _poll?.cancel();
      if (mounted) setState(() => _waiting = false);
    });
  }

  Future<void> _ask() async {
    if (!_polling || !mounted) return;
    Json tg = const {};
    try {
      try {
        tg = obj((await ctx.a.tgState())['data']);
      } on ApiError catch (e) {
        if (e.status != 404) rethrow;
        tg = obj(obj((await ctx.a.book())['data'])['telegram']);
      }
    } catch (_) {}
    if (!_polling || !mounted) return;
    if (tg['connected'] == true) {
      _polling = false;
      _stop?.cancel();
      setState(() {
        _tg = tg;
        _waiting = false;
      });
      ctx.reload();
      return;
    }
    _poll = Timer(const Duration(seconds: 3), _ask);
  }

  Future<void> _link({bool group = false}) async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.a.tgLink());
    if (!mounted) return;
    setState(() => _busy = '');
    if (r == null) return;
    final d = obj(r['data']);
    final url = str(group ? d['group_url'] : d['url']);
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // no Telegram / no browser: the link is still copied so it can be opened by hand
      await Clipboard.setData(ClipboardData(text: url));
      ctx.notify(ctx.m('copied'));
    }
    if (!mounted) return;
    _wait();
  }

  Future<void> _test() async {
    setState(() => _busy = 'test');
    final r = await ctx.run(() => ctx.a.tgTest(), ctx.m('tgSentOk'));
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (r != null && r['data'] is Map) _tg = obj(r['data']);
    });
  }

  Future<void> _off() async {
    if (!await ntConfirm(context, ctx, ctx.m('tgDisconnect'), ctx.m('tgChatSub'), yes: ctx.m('tgDisconnect'))) return;
    setState(() => _busy = 'off');
    final r = await ctx.run(() => ctx.a.tgOff());
    if (!mounted) return;
    setState(() {
      _busy = '';
      if (r != null) _tg = r['data'] is Map ? obj(r['data']) : {..._tg, 'connected': false};
    });
    ctx.reload();
  }

  Future<void> _save(Json patch) async {
    final before = _tg;
    setState(() => _tg = {..._tg, ...patch});
    final r = await ctx.run(() => ctx.a.tgSave(patch));
    if (!mounted) return;
    setState(() => _tg = r == null ? before : (r['data'] is Map ? obj(r['data']) : _tg));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lic = obj(ctx.addons['note_telegram']);
    if (!ctx.tg) return _Locked(ctx: ctx);
    final on = _tg['connected'] == true;
    final ro = ctx.readOnly;
    final mode = _tg['replies'] == false ? 'off' : (_tg['replies_batch'] == true ? 'batch' : 'now');
    Widget sw(String key, String title, String sub) => SwitchRow(
      title: title,
      sub: sub,
      value: _tg[key] != false && (key != 'edits' || _tg[key] == true),
      onChanged: ro || !on ? null : (v) => _save({key: v}),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ntHead(
          context,
          LucideIcons.bellRing,
          ctx.m('alertsTitle'),
          ctx.m('alertsSub'),
          actions: [
            if (lic['expires_at'] != null)
              NtPill(
                lic['active'] == true ? ctx.m('planActive', {'date': ntDate(lic['expires_at'], ctx.lang)}) : ctx.m('planEnded', {'date': ntDate(lic['expires_at'], ctx.lang)}),
                on: lic['active'] == true,
                bad: lic['active'] != true,
                icon: LucideIcons.calendarClock,
              ),
            Btn(ctx.m('renew', {'coins': fmt(ctx.price('note_telegram'))}), kind: BtnKind.ghost, small: true, onTap: ro ? null : () => ctx.askBuy('note_telegram')),
          ],
        ),
        ntGap,
        // the chat
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('tgChat'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 4),
              Muted(ctx.m('tgChatSub')),
              const SizedBox(height: 12),
              if (_tg['configured'] == false)
                Alert(ctx.m('tgNotConfigured'), tone: Tone.warn)
              else if (on) ...[
                Row(
                  children: [
                    Chip2(ctx.m('tgConnected', {'name': str(_tg['chat_name']).isEmpty ? 'Telegram' : str(_tg['chat_name'])}), tone: Tone.good, icon: LucideIcons.check),
                  ],
                ),
                const SizedBox(height: 12),
                Btn(ctx.m('tgTest'), icon: LucideIcons.send, expand: true, busy: _busy == 'test', onTap: _busy.isNotEmpty || ro ? null : _test),
                const SizedBox(height: 8),
                Btn(ctx.m('tgDisconnect'), icon: LucideIcons.unplug, kind: BtnKind.ghost, expand: true, busy: _busy == 'off', onTap: _busy.isNotEmpty || ro ? null : _off),
              ] else ...[
                Btn(ctx.m('tgConnect'), icon: LucideIcons.send, expand: true, busy: _busy == 'link', onTap: _busy.isNotEmpty || ro ? null : () => _link()),
                const SizedBox(height: 8),
                Btn(ctx.m('tgGroup'), icon: LucideIcons.users, kind: BtnKind.ghost, expand: true, onTap: _busy.isNotEmpty || ro ? null : () => _link(group: true)),
                if (_waiting) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(child: Muted(ctx.m('tgWaiting'))),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Muted(ctx.m('tgHow')),
              ],
            ],
          ),
        ),
        ntGap,
        // what to send
        Opacity(
          opacity: on ? 1 : .6,
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ctx.m('tgWhatH'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                if (!on) ...[const SizedBox(height: 4), Muted(ctx.m('tgConnectFirst'))],
                const SizedBox(height: 12),
                Text(ctx.m('tgReplies'), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(ctx.m('tgRepliesSub'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                Segmented<String>(
                  value: mode,
                  options: [for (final k in ['now', 'batch', 'off']) (k, ctx.m('tgRepliesOpts.$k'))],
                  onChanged: ro || !on ? null : (k) => _save(k == 'off' ? {'replies': false} : {'replies': true, 'replies_batch': k == 'batch'}),
                ),
                const SizedBox(height: 6),
                sw('signups', ctx.m('tgSignups'), ctx.m('tgSignupsSub')),
                sw('edits', ctx.m('tgEdits'), ctx.m('tgEditsSub')),
                sw('acks', ctx.m('tgAcks'), ctx.m('tgAcksSub')),
                sw('reminders', ctx.m('tgReminders'), ctx.m('tgRemindersSub')),
                sw('daily', ctx.m('tgDaily'), ctx.m('tgDailySub')),
                const SizedBox(height: 6),
                Text(ctx.m('tgLang'), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(ctx.m('tgLangSub'), style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                Segmented<String>(
                  value: str(_tg['lang']).isEmpty ? 'km' : str(_tg['lang']),
                  options: const [('km', 'ខ្មែរ'), ('en', 'English')],
                  onChanged: ro || !on ? null : (k) => _save({'lang': k}),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// not unlocked: an example of the messages, what it does, the unlock button
class _Locked extends StatelessWidget {
  final NtCtx ctx;
  const _Locked({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      key: const ValueKey('nt-alerts-locked'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ntHead(context, LucideIcons.bellRing, ctx.m('alertsTitle'), ctx.m('alertsSub')),
        ntGap,
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NtTelegramArt(ctx: ctx),
              const SizedBox(height: 16),
              Text(ctx.m('tgCard'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              for (final p in ctx.l('tgPerks'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.check, size: 16, color: c.good),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p, style: const TextStyle(height: 1.4))),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Center(
                child: NtGoldBtn(ctx.m('tgUnlock', {'coins': fmt(ctx.price('note_telegram'))}), onTap: ctx.readOnly ? null : () => ctx.askBuy('note_telegram')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// three example Telegram messages (the web's V4Stage "note_telegram")
class NtTelegramArt extends StatelessWidget {
  final NtCtx ctx;
  const NtTelegramArt({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    Widget msg(String title, String body, {bool right = false}) => Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF168ACD)),
            ),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 13, color: Color(0xFF16171B))),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD9EBF6), Color(0xFFC3DDEE)]),
      ),
      child: Column(
        children: [
          msg('🔔 ${ctx.m('tgEx1Title')}', ctx.m('tgEx1')),
          msg('🧾 ${ctx.m('tgEx2Title')}', ctx.m('tgEx2')),
          msg('⏰ ${ctx.m('tgEx3Title')}', ctx.m('tgEx3')),
        ],
      ),
    );
  }
}
