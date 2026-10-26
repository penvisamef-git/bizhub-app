import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/color_pick.dart' show pickColor;
import '../../widgets/ui.dart';
import '../restaurant/rest_common.dart' show SwitchRow;
import '../restaurant/rest_online.dart' show shareWidgets;
import 'ts_common.dart';
import 'ts_setup.dart' show TsInput;
import 'ts_themes.dart' show hexColor, colorHex;

// Share & Telegram (TsSetup.jsx ShareTab + TsPay.jsx ChannelCard / LinkCard / StyledQr)
class ShareTab extends StatefulWidget {
  final TsCtx ctx;
  const ShareTab({super.key, required this.ctx});
  @override
  State<ShareTab> createState() => _ShareTabState();
}

class _ShareTabState extends State<ShareTab> {
  TsCtx get ctx => widget.ctx;
  final _qrKey = GlobalKey();
  Json? _link;
  String _busy = '';

  Future<Json?> _run(String key, Future<Json> Function() fn, [String? ok]) async {
    setState(() => _busy = key);
    final r = await ctx.run(fn, ok);
    if (mounted) setState(() => _busy = '');
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = ctx.store;
    final tg = ctx.telegram;
    final main = ctx.mainLink;
    final ro = ctx.readOnly;
    final styled = ctx.on('ts_link');
    final qr = obj(s['qr']);
    final logo = str(s['logo']);
    Widget linkBox(IconData icon, String label, String url, List<Widget> acts) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: acts),
        ],
      ),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        Muted(ctx.m('shareSub')),
        const SizedBox(height: 12),
        TsCard(
          title: ctx.m('qrTitle'),
          icon: LucideIcons.qrCode,
          sub: ctx.m('qrSub'),
          children: [
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: TsQr(
                  main,
                  size: 190,
                  fg: styled ? (hexColor(str(qr['fg'])) ?? const Color(0xFF1F1A16)) : const Color(0xFF1F1A16),
                  bg: styled ? (hexColor(str(qr['bg'])) ?? Colors.white) : Colors.white,
                  logo: styled && qr['logo'] == true ? logo : '',
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (str(ctx.links['telegram']).isNotEmpty)
              linkBox(LucideIcons.send, ctx.m('tgLink'), str(ctx.links['telegram']), [
                Btn(ctx.m('copyLink'), icon: LucideIcons.copy, small: true, kind: BtnKind.ghost, onTap: () => tsCopy(context, str(ctx.links['telegram']), ctx.m('copied'))),
                Btn('Telegram', icon: LucideIcons.externalLink, small: true, kind: BtnKind.ghost, onTap: () => tsOpen(str(ctx.links['telegram']))),
              ])
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Alert(ctx.m('tgNotReady'), tone: Tone.warn),
              ),
            linkBox(LucideIcons.externalLink, ctx.m('webLink'), ctx.webLink, [
              Btn(ctx.m('copyLink'), icon: LucideIcons.copy, small: true, kind: BtnKind.ghost, onTap: () => tsCopy(context, ctx.webLink, ctx.m('copied'))),
              Btn(ctx.m('download'), icon: LucideIcons.download, small: true, kind: BtnKind.ghost, onTap: () => shareWidgets([_qrKey], (_) => '${s['slug']}-qr.png')),
              Btn(ctx.m('openStore'), icon: LucideIcons.externalLink, small: true, kind: BtnKind.ghost, onTap: () => tsOpen(ctx.webLink)),
            ]),
          ],
        ),
        TsCard(
          title: ctx.m('staff'),
          icon: LucideIcons.messageSquare,
          sub: ctx.m('staffSub'),
          children: [
            if (tg['configured'] != true)
              Alert(ctx.m('tgNotReady'), tone: Tone.warn)
            else if (tg['connected'] == true)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TsPill(ctx.m('connected', {'name': str(tg['chat_name']).isEmpty ? 'Telegram' : tg['chat_name']}), tone: Tone.good),
                  Btn(
                    ctx.m('test'),
                    icon: LucideIcons.send,
                    small: true,
                    kind: BtnKind.ghost,
                    busy: _busy == 'test',
                    onTap: ro || _busy.isNotEmpty ? null : () => _run('test', () => ctx.api.post('${ctx.base}/telegram/test'), ctx.m('saved')),
                  ),
                  Btn(
                    ctx.m('disconnect'),
                    icon: LucideIcons.unplug,
                    small: true,
                    kind: BtnKind.ghost,
                    onTap: ro || _busy.isNotEmpty
                        ? null
                        : () async {
                            final r = await _run('off', () => ctx.api.delete('${ctx.base}/telegram'));
                            if (r != null) {
                              ctx.put({
                                'telegram': {...ctx.telegram, 'connected': false, 'chat_name': ''},
                              });
                            }
                          },
                  ),
                ],
              )
            else ...[
              Muted(ctx.m('notConnected')),
              const SizedBox(height: 8),
              if (_link == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    ctx.m('connect'),
                    icon: LucideIcons.send,
                    small: true,
                    busy: _busy == 'link',
                    onTap: ro || _busy.isNotEmpty
                        ? null
                        : () async {
                            final r = await _run('link', () => ctx.api.post('${ctx.base}/telegram/link'));
                            if (r != null) setState(() => _link = obj(r['data']));
                          },
                  ),
                )
              else ...[
                Muted(ctx.m('connectHint')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(ctx.m('connectGroup'), icon: LucideIcons.users, small: true, onTap: () => tsOpen(str(_link!['group_url']))),
                    Btn(ctx.m('connectMe'), icon: LucideIcons.send, small: true, kind: BtnKind.ghost, onTap: () => tsOpen(str(_link!['url']))),
                    Btn(
                      ctx.m('refresh'),
                      small: true,
                      kind: BtnKind.ghost,
                      onTap: () async {
                        await ctx.reload();
                        if (mounted) setState(() => _link = null);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        _ChannelCard(ctx: ctx, link: main),
        _LinkCard(ctx: ctx),
        if (obj(s['dine_in'])['on'] == true) _TablesCard(ctx: ctx),
      ],
    );
  }
}

// the post for the owner's channel (their own words)
class _ChannelCard extends StatefulWidget {
  final TsCtx ctx;
  final String link;
  const _ChannelCard({required this.ctx, required this.link});
  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  TsCtx get ctx => widget.ctx;
  late String _text = str(ctx.store['channel_text']).isNotEmpty ? str(ctx.store['channel_text']) : ctx.m('channelText');
  int _v = 0;
  bool _busy = false;

  Future<void> _save(String value) async {
    setState(() => _busy = true);
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'channel_text': value == ctx.m('channelText') ? '' : value}), ctx.m('saved'));
    if (mounted) setState(() => _busy = false);
    if (r != null) ctx.put({'store': obj(obj(r['data'])['store'])});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final saved = str(ctx.store['channel_text']).isNotEmpty ? str(ctx.store['channel_text']) : ctx.m('channelText');
    final out = _text.replaceAll('{name}', ctx.shopName).replaceAll('{link}', widget.link);
    return TsCard(
      title: ctx.m('channel'),
      icon: LucideIcons.send,
      sub: ctx.m('channelSub'),
      children: [
        TsInput(key: ValueKey('ch$_v'), value: _text, maxLength: 600, maxLines: 4, onChanged: ctx.readOnly ? null : (v) => setState(() => _text = v)),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(ctx.m('channelEdit'), style: TextStyle(fontSize: 12.5, color: c.muted)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(14)),
          child: SelectableText(out),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Btn(ctx.m('copyText'), icon: LucideIcons.copy, small: true, kind: BtnKind.ghost, onTap: () => tsCopy(context, out, ctx.m('copied'))),
            Btn(ctx.m('save'), small: true, busy: _busy, onTap: ctx.readOnly || _busy || _text == saved ? null : () => _save(_text)),
            if (str(ctx.store['channel_text']).isNotEmpty)
              Btn(
                ctx.m('reset'),
                icon: LucideIcons.rotateCcw,
                small: true,
                kind: BtnKind.ghost,
                onTap: ctx.readOnly || _busy
                    ? null
                    : () {
                        setState(() {
                          _text = ctx.m('channelText');
                          _v++;
                        });
                        _save(ctx.m('channelText'));
                      },
              ),
            Btn(
              ctx.t('app.share'),
              icon: LucideIcons.share2,
              small: true,
              kind: BtnKind.ghost,
              onTap: () => SharePlus.instance.share(ShareParams(text: out)),
            ),
          ],
        ),
      ],
    );
  }
}

// own link name + QR style (ts_link)
class _LinkCard extends StatefulWidget {
  final TsCtx ctx;
  const _LinkCard({required this.ctx});
  @override
  State<_LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<_LinkCard> {
  TsCtx get ctx => widget.ctx;
  late String _slug = str(ctx.store['slug']);
  late Json _qr = {
    'fg': str(obj(ctx.store['qr'])['fg']).isEmpty ? '#1F1A16' : str(obj(ctx.store['qr'])['fg']),
    'bg': str(obj(ctx.store['qr'])['bg']).isEmpty ? '#FFFFFF' : str(obj(ctx.store['qr'])['bg']),
    'logo': obj(ctx.store['qr'])['logo'] == true,
  };
  String _busy = '';

  Future<void> _saveLink() async {
    setState(() => _busy = 'link');
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/link', {'slug': _slug}), ctx.m('saved'));
    if (mounted) setState(() => _busy = '');
    if (r != null) {
      ctx.put({
        'store': {...ctx.store, 'slug': obj(r['data'])['slug']},
        'links': obj(obj(r['data'])['links']),
      });
    }
  }

  Future<void> _saveQr(Json next) async {
    setState(() {
      _qr = next;
      _busy = 'qr';
    });
    final r = await ctx.run(() => ctx.api.put('${ctx.base}/settings', {'qr': next}));
    if (mounted) setState(() => _busy = '');
    if (r != null) ctx.put({'store': obj(obj(r['data'])['store'])});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ro = ctx.readOnly;
    final logo = str(ctx.store['logo']);
    Widget swatch(String label, String key) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: ro
          ? null
          : () async {
              final picked = await pickColor(context, hexColor(str(_qr[key])) ?? Colors.black, ctx.m('save'), ctx.m('cancel'));
              if (picked != null) _saveQr({..._qr, key: colorHex(picked)});
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: hexColor(str(_qr[key])),
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
    return TsCard(
      title: ctx.m('ownLink'),
      icon: LucideIcons.link2,
      sub: ctx.m('ownLinkSub'),
      children: [
        if (!ctx.on('ts_link'))
          TsLocked(ctx: ctx, addon: 'ts_link', small: true)
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TsInput(
                  label: ctx.m('linkName'),
                  value: _slug,
                  maxLength: 30,
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 4, top: 2),
                    child: Text('/t/', style: TextStyle(color: c.muted)),
                  ),
                  onChanged: ro ? null : (v) => setState(() => _slug = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '')),
                ),
              ),
              const SizedBox(width: 8),
              Btn(ctx.m('saveLink'), small: true, busy: _busy == 'link', onTap: ro || _busy.isNotEmpty || _slug == str(ctx.store['slug']) || _slug.length < 3 ? null : _saveLink),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(ctx.m('linkHint'), style: TextStyle(fontSize: 12.5, color: c.muted)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [swatch(ctx.m('qrColour'), 'fg'), swatch(ctx.m('qrBg'), 'bg')]),
          SwitchRow(title: ctx.m('qrLogo'), value: _qr['logo'] == true, onChanged: ro || logo.isEmpty ? null : (v) => _saveQr({..._qr, 'logo': v})),
          Center(
            child: TsQr(ctx.mainLink, size: 150, fg: hexColor(str(_qr['fg'])) ?? Colors.black, bg: hexColor(str(_qr['bg'])) ?? Colors.white, logo: _qr['logo'] == true ? logo : ''),
          ),
        ],
      ],
    );
  }
}

// one QR per table: the table number is filled in for the customer
class _TablesCard extends StatefulWidget {
  final TsCtx ctx;
  const _TablesCard({required this.ctx});
  @override
  State<_TablesCard> createState() => _TablesCardState();
}

class _TablesCardState extends State<_TablesCard> {
  final Map<int, GlobalKey> _keys = {};
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final count = n(obj(ctx.store['dine_in'])['tables']).toInt().clamp(1, 300);
    final shown = count.clamp(1, 60);
    for (var i = 1; i <= shown; i++) {
      _keys.putIfAbsent(i, GlobalKey.new);
    }
    return TsCard(
      title: ctx.m('tableQrs'),
      icon: LucideIcons.qrCode,
      sub: ctx.m('tableQrsSub'),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 1; i <= shown; i++)
              RepaintBoundary(
                key: _keys[i],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TsQr('${ctx.webLink}?table=$i', size: 84),
                      const SizedBox(height: 4),
                      Text(
                        ctx.m('table', {'n': i}),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      Text(
                        ctx.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn('${ctx.m('print')} ($shown)', icon: LucideIcons.printer, small: true, onTap: () => shareWidgets([for (var i = 1; i <= shown; i++) _keys[i]!], (i) => 'table-${i + 1}.png')),
        ),
      ],
    );
  }
}
