import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'team_data.dart';
import 'team_parts.dart';
import 'team_text.dart';

// Account → My BizHub ID: what a business owner types to add me to their team (web: MyIdCard.jsx)
class MyIdCard extends ConsumerWidget {
  const MyIdCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(tProvider).lang;
    final c = context.c;
    final saved = str(ref.watch(sessionProvider)?.data['bizhub_id']);
    final id = ref.watch(myIdProvider).valueOrNull ?? saved;
    return Panel(
      key: const ValueKey('team-my-id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons.idCard, size: 18, color: c.brandInk),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tm(lang, 'myId'), style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 14),
          if (id.isEmpty)
            const Row(
              children: [
                Skel(w: 104, h: 104, r: 14),
                SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skel(w: 150, h: 26), SizedBox(height: 10), Skel(h: 11), SizedBox(height: 6), Skel(w: 120, h: 11)]),
                ),
              ],
            )
          else
            Row(
              children: [
                TeamQr(id, size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(id, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(tm(lang, 'myIdSub'), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          if (id.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Btn(
                    tm(lang, 'copyId'),
                    icon: LucideIcons.copy,
                    kind: BtnKind.ghost,
                    small: true,
                    expand: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: id));
                      if (context.mounted) toast(context, tm(lang, 'idCopied'));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Btn(
                    tm(lang, 'shareId'),
                    icon: LucideIcons.share2,
                    small: true,
                    expand: true,
                    onTap: () => SharePlus.instance.share(ShareParams(text: '${tm(lang, 'myId')}: $id')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
