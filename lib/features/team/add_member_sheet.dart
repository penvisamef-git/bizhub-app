import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'team_data.dart';
import 'team_parts.dart';
import 'team_text.dart';

// Admin / View only, as a big tappable card (radio)
class RoleCard extends StatelessWidget {
  final String role, lang;
  final bool on;
  final VoidCallback onTap;
  const RoleCard({super.key, required this.role, required this.on, required this.lang, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: on ? c.active : c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('team-role-$role'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? c.brand : c.line, width: on ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(on ? LucideIcons.circleDot : LucideIcons.circle, size: 20, color: on ? c.brand : c.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tm(lang, role == 'admin' ? 'admin' : 'view'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(tm(lang, role == 'admin' ? 'adminDesc' : 'viewDesc'), style: Theme.of(context).textTheme.bodySmall),
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

// Add member (web: AddMemberModal.jsx): 1 · what can they do · 2 · by BizHub ID or an invite link (QR, copy, share)
class AddMemberSheet extends ConsumerStatefulWidget {
  final String businessId;
  final VoidCallback onChanged;
  const AddMemberSheet({super.key, required this.businessId, required this.onChanged});
  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  String _role = 'view', _mode = 'id', _error = '';
  final _id = TextEditingController();
  Json? _link;
  bool _busy = false, _copied = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  bool get _idOk => RegExp(r'^\d{6}$').hasMatch(_id.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _invite() async {
    if (!_idOk || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(apiProvider).post('${Api.user}/businesses/${widget.businessId}/team/members', {'bizhub_id': _id.text.trim(), 'role': _role});
      widget.onChanged();
      if (mounted) Navigator.pop(context, 'invited');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makeLink() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref.read(apiProvider).post('${Api.user}/businesses/${widget.businessId}/team/links', {'role': _role});
      widget.onChanged();
      if (mounted) setState(() => _link = obj(r['data']));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.network ? ref.read(tProvider)('app.offline') : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(tProvider).lang;
    final c = context.c;
    final url = _link == null ? '' : joinUrl(str(_link!['code']));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tm(lang, 'addTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _label(context, '1 · ${tm(lang, 'whatCan')}'),
            for (final r in const ['admin', 'view'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RoleCard(
                  role: r,
                  on: _role == r,
                  lang: lang,
                  onTap: () => setState(() {
                    _role = r;
                    _link = null; // a new link for the new role
                  }),
                ),
              ),
            const SizedBox(height: 8),
            _label(context, '2 · ${tm(lang, 'howAdd')}'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [_tab(context, 'id', tm(lang, 'byId')), _tab(context, 'link', tm(lang, 'byLink'))]),
            ),
            const SizedBox(height: 14),
            if (_error.isNotEmpty) ...[Alert(_error), const SizedBox(height: 12)],
            if (_mode == 'id') ...[
              Field(
                key: const ValueKey('team-bhid'),
                label: tm(lang, 'idLabel'),
                hint: tm(lang, 'idPh'),
                controller: _id,
                icon: LucideIcons.idCard,
                autofocus: false,
                maxLength: 12,
                onChanged: (_) => setState(() {}),
                onSubmit: (_) => _invite(),
              ),
              const SizedBox(height: 8),
              Muted(tm(lang, 'idHint')),
              const SizedBox(height: 16),
              Btn(tm(lang, 'sendInvite'), key: const ValueKey('team-send'), icon: LucideIcons.send, expand: true, busy: _busy, onTap: _idOk ? _invite : null),
            ] else if (_link == null) ...[
              Muted('${tm(lang, 'linkFor')} ${tm(lang, _role == 'admin' ? 'admin' : 'view')} · ${tm(lang, 'linkLife')}'),
              const SizedBox(height: 16),
              Btn(tm(lang, 'makeLink'), key: const ValueKey('team-make-link'), icon: LucideIcons.link2, expand: true, busy: _busy, onTap: _makeLink),
            ] else ...[
              Row(
                key: const ValueKey('team-link'),
                children: [
                  TeamQr(url, size: 104),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Muted(tm(lang, 'linkFor')),
                        Text(tm(lang, str(_link!['role']) == 'admin' ? 'admin' : 'view'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('${tm(lang, 'linkLife')} · ${tm(lang, 'endsOn', {'date': fmtDate(_link!['expires_at'], lang: lang)})}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Btn(
                      _copied ? tm(lang, 'copied') : tm(lang, 'copy'),
                      icon: LucideIcons.copy,
                      kind: BtnKind.ghost,
                      expand: true,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!mounted) return;
                        setState(() => _copied = true);
                        Future.delayed(const Duration(milliseconds: 1800), () => mounted ? setState(() => _copied = false) : null);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Btn(
                      tm(lang, 'share'),
                      icon: LucideIcons.share2,
                      expand: true,
                      onTap: () => SharePlus.instance.share(ShareParams(text: '${tm(lang, 'joinTitle')}: $url')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Text(s.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12, letterSpacing: .6)),
  );

  Widget _tab(BuildContext context, String key, String label) {
    final c = context.c;
    final on = _mode == key;
    return Expanded(
      child: Material(
        color: on ? c.card : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: ValueKey('team-tab-$key'),
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() {
            _mode = key;
            _error = '';
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? c.ink : c.muted),
            ),
          ),
        ),
      ),
    );
  }
}
