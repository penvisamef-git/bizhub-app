import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/format.dart' show fmt;
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'nt_common.dart';
import 'nt_more_text.dart';
import 'nt_more_ui.dart';
import 'nt_page.dart' show NtNav;

// Storage & plan (the web's StorageTab + the storage card of AddonsTab): the meter, the yearly plan, the +5 GB packs
// (yearly slots "slot-N": buy N at once, renew each one on its own date).

const _gb5 = 5 * 1073741824;

// the packs, by number (slot-1, slot-2 …)
List<Json> ntPacks(NtCtx ctx) {
  final list = objs(ctx.data['storage_slots']);
  int no(Json p) => int.tryParse(str(p['item']).split('-').last) ?? 0;
  list.sort((a, b) => no(a).compareTo(no(b)));
  return list;
}

class StorageSection extends StatelessWidget {
  final NtCtx ctx;
  final NtNav nav;
  const StorageSection({super.key, required this.ctx, required this.nav});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lic = ctx.license;
    final book = ctx.book;
    final mb = (n(book['file_limit']) > 0 ? n(book['file_limit']) : 20 * 1048576) ~/ 1048576;
    return RefreshIndicator(
      onRefresh: ctx.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ntHead(context, LucideIcons.hardDrive, ctx.m('storageTitle'), ctx.m('storageSub')),
          ntGap,
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NtStorageMeter(ctx: ctx, used: n(book['storage_used']), limit: n(book['storage_limit']) > 0 ? n(book['storage_limit']) : _gb5),
                const SizedBox(height: 10),
                Muted(ctx.m('perFile', {'mb': mb})),
                Muted(ctx.m('included')),
              ],
            ),
          ),
          ntGap,
          // the yearly plan
          Panel(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: c.active, borderRadius: BorderRadius.circular(15)),
                  child: Icon(LucideIcons.stickyNote, color: c.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctx.m('plan'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      if (lic['expires_at'] != null)
                        Text(
                          '${(lic['active'] == true ? ctx.m('planActive', {'date': ntDate(lic['expires_at'], ctx.lang)}) : ctx.m('planEnded', {'date': ntDate(lic['expires_at'], ctx.lang)}))}${lic['active'] == true && lic['days_left'] != null ? ' · ${ctx.m('planDays', {'n': lic['days_left']})}' : ''}',
                          style: TextStyle(color: lic['active'] == true ? c.good : c.danger, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Btn(ctx.m('renew', {'coins': fmt(ctx.price('digital_note'))}), lead: const CoinIcon(size: 18), expand: true, onTap: () => ctx.askBuy('digital_note')),
          ntGap,
          NtPacksCard(ctx: ctx),
        ],
      ),
    );
  }
}

// the +5 GB packs: what they are, how many to add (stepper), the packs you have (until … · renew)
class NtPacksCard extends StatefulWidget {
  final NtCtx ctx;
  final bool showMeter;
  const NtPacksCard({super.key, required this.ctx, this.showMeter = false});
  @override
  State<NtPacksCard> createState() => _NtPacksCardState();
}

class _NtPacksCardState extends State<NtPacksCard> {
  int _n = 1;
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = context.c;
    final packs = ntPacks(ctx);
    final active = packs.where((p) => p['active'] == true).length;
    final price = ctx.price('note_storage');
    final limit = n(ctx.book['storage_limit']) > 0 ? n(ctx.book['storage_limit']) : _gb5;
    // buying / renewing packs works after the plan ended too (the API allows it)
    return NtAddonCard(
      testKey: 'nt-packs',
      icon: LucideIcons.hardDrive,
      name: ctx.m('packsTitle'),
      price: '${fmt(price)} ${ctx.m('coins')} ${ctx.m('perPack')}',
      what: ctx.m('packsWhat'),
      on: active > 0,
      art: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showMeter) ...[NtStorageMeter(ctx: ctx, used: n(ctx.book['storage_used']), limit: limit), const SizedBox(height: 6), Muted(ctx.m('included')), const SizedBox(height: 12)],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(ctx.m('packs'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    NtStepper(value: _n, onChanged: (v) => setState(() => _n = v), max: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '+${_n * 5} GB · ${ntw(ctx, 'limitAfter', {'total': ntBytes(limit + _n * _gb5)})}',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: NtGoldBtn(ctx.m('packsAdd', {'gb': _n * 5, 'coins': fmt(_n * price)}), onTap: () => ctx.askBuy('note_storage', qty: _n)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(ctx.m('packsOwned'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (packs.isEmpty)
            Muted(ctx.m('packsNone'))
          else
            for (final p in packs)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: p['active'] == true ? c.goodBg : c.bg2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.hardDrive, size: 16, color: p['active'] == true ? c.good : c.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ctx.m('packLine', {'n': str(p['item']).split('-').last}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            Text(
                              p['active'] == true ? ctx.m('packUntil', {'date': ntDate(p['expires_at'], ctx.lang)}) : ctx.m('packEnded', {'date': ntDate(p['expires_at'], ctx.lang)}),
                              style: TextStyle(color: p['active'] == true ? c.muted : c.danger, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Btn(ctx.m('packRenew', {'coins': fmt(price)}), kind: BtnKind.ghost, small: true, onTap: () => ctx.askBuy('note_storage', item: str(p['item']))),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
