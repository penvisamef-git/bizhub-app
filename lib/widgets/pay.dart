import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import 'ui.dart';

// Every payment with coins asks first (components/purchase/PayConfirm on the web)
Future<bool> confirmPay(BuildContext context, WidgetRef ref, {required num coins, required String what}) async {
  if (coins <= 0) return true;
  final t = ref.read(tProvider);
  final bal = ref.read(sessionProvider)?.coins ?? 0;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 56),
              const SizedBox(height: 14),
              Text(t('app.confirmPay', {'coins': fmt(coins)}), textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                t('app.confirmPaySub', {'what': what, 'after': fmt(bal - coins)}),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, height: 1.5),
              ),
              if (bal < coins) ...[const SizedBox(height: 12), Alert(t('messages.notEnoughCoins'))],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Btn(t('app.cancel'), kind: BtnKind.ghost, onTap: () => Navigator.pop(ctx, false)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Btn('${t('app.pay')} · ${fmt(coins)}', icon: LucideIcons.check, onTap: bal < coins ? null : () => Navigator.pop(ctx, true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}
