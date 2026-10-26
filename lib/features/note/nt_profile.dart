import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../owner/data.dart' show dashboardProvider;
import 'nt_common.dart';
import 'nt_more_text.dart';
import 'nt_more_ui.dart';
import 'nt_page.dart' show NtNav;

// Business profile (the web's ProfileTab): the name (PUT /businesses/:id, like everywhere in the app) and the logo
// (POST / DELETE /note/logo). Shown on the dashboard, in My businesses and on the pages people open.

class ProfileSection extends ConsumerStatefulWidget {
  final NtCtx ctx;
  final NtNav nav;
  const ProfileSection({super.key, required this.ctx, required this.nav});
  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  NtCtx get ctx => widget.ctx;
  late final _name = TextEditingController(text: ctx.bizName);
  String _busy = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final v = _name.text.trim();
    if (v.length < 2 || v.length > 100) return ctx.notify(ctx.m('nameBad'));
    setState(() => _busy = 'name');
    final r = await ctx.run(() => ctx.a.rename(v), ctx.m('profileSaved'));
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) {
      ref.invalidate(dashboardProvider); // My businesses shows the new name
      ctx.reload();
    }
  }

  Future<void> _pickLogo() async {
    final pick = await ntPickPicture(context, ctx, maxSize: 800);
    if (pick == null || !mounted) return;
    final (bytes, name, mime) = pick;
    if (bytes.length > 2 * 1048576) return ctx.notify(ctx.m('pictureBad')); // the API takes logos up to 2 MB
    setState(() => _busy = 'logo');
    final r = await ctx.run(() => ctx.a.logoUpload(bytes, name, mime), ctx.m('profileSaved'));
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) {
      ref.invalidate(dashboardProvider);
      ctx.reload();
    }
  }

  Future<void> _dropLogo() async {
    setState(() => _busy = 'drop');
    final r = await ctx.run(() => ctx.a.logoDelete(), ctx.m('profileSaved'));
    if (!mounted) return;
    setState(() => _busy = '');
    if (r != null) {
      ref.invalidate(dashboardProvider);
      ctx.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logo = ctx.logo;
    final shown = _name.text.trim().isEmpty ? (ctx.bizName.isEmpty ? ctx.m('badge') : ctx.bizName) : _name.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ntHead(context, LucideIcons.building2, ctx.m('profileTitle'), ctx.m('profileSub')),
        ntGap,
        // how it looks
        Panel(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: logo.isNotEmpty ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(LucideIcons.stickyNote, color: c.brand)) : Icon(LucideIcons.stickyNote, size: 28, color: c.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shown, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 4),
                    Chip2(ctx.m('badge'), icon: LucideIcons.stickyNote),
                  ],
                ),
              ),
            ],
          ),
        ),
        ntGap,
        // the logo
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.m('logo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Muted(ctx.m('logoSub')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: c.bg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _busy == 'logo'
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : logo.isNotEmpty
                        ? Image(image: netImage(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(LucideIcons.image, color: c.muted))
                        : Icon(LucideIcons.imagePlus, size: 28, color: c.muted),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Btn(logo.isNotEmpty ? ctx.m('changePicture') : ctx.m('addPicture'), icon: LucideIcons.imagePlus, small: true, busy: _busy == 'logo', onTap: _busy.isNotEmpty ? null : _pickLogo),
                        if (logo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Btn(ctx.m('removePicture'), icon: LucideIcons.x, kind: BtnKind.ghost, small: true, busy: _busy == 'drop', onTap: _busy.isNotEmpty ? null : _dropLogo),
                        ],
                        const SizedBox(height: 6),
                        Muted(ntw(ctx, 'logoHint')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ntGap,
        // the name
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Field(label: ctx.m('bizName'), controller: _name, hint: ctx.m('bizNamePh'), maxLength: 100, onChanged: (_) => setState(() {}), onSubmit: (_) => _saveName()),
              const SizedBox(height: 12),
              Btn(
                ctx.m('save'),
                icon: LucideIcons.check,
                expand: true,
                busy: _busy == 'name',
                onTap: _busy.isNotEmpty || _name.text.trim() == ctx.bizName || _name.text.trim().isEmpty ? null : _saveName,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
