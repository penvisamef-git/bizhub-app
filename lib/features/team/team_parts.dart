import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'team_data.dart';
import 'team_text.dart';

// Owner / Admin / View only / Waiting
class RoleBadge extends StatelessWidget {
  final String role;
  final String lang;
  const RoleBadge(this.role, {super.key, required this.lang});
  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'owner' => tm(lang, 'owner'),
      'admin' => tm(lang, 'admin'),
      'view' => tm(lang, 'view'),
      _ => tm(lang, 'waiting'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: roleBg(context, role), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: roleFg(context, role), fontSize: 12, fontWeight: FontWeight.w800, height: 1.3),
      ),
    );
  }
}

// a white QR (works in dark mode too)
class TeamQr extends StatelessWidget {
  final String data;
  final double size;
  const TeamQr(this.data, {super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.c.line),
    ),
    child: QrImageView(data: data, size: size, padding: EdgeInsets.zero, backgroundColor: Colors.white),
  );
}

// a business logo, or its first letter
class BizLogo extends StatelessWidget {
  final String name, logo;
  final double size;
  const BizLogo({super.key, required this.name, this.logo = '', this.size = 42});
  @override
  Widget build(BuildContext context) => Avatar(name: name, photo: logo, size: size);
}

// grey rows while a team list loads
class TeamSkeleton extends StatelessWidget {
  final int rows;
  final bool status;
  const TeamSkeleton({super.key, this.rows = 3, this.status = true});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (status) ...[const Skel(h: 46, r: 14), const SizedBox(height: 22), const Skel(w: 90, h: 11), const SizedBox(height: 10)],
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: List.generate(
            rows,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Skel(w: 42, h: 42, r: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(widthFactor: .6 - (i % 3) * .1, child: const Skel(h: 14)),
                        const SizedBox(height: 7),
                        FractionallySizedBox(widthFactor: .4 + (i % 2) * .1, child: const Skel(h: 11)),
                      ],
                    ),
                  ),
                  Skel(w: i == 0 ? 60 : 92, h: i == 0 ? 22 : 34, r: i == 0 ? 999 : 10),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<bool> teamConfirm(BuildContext context, {required String title, required String yes, required String no, bool danger = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      content: Text(title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(no)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: d.c.danger) : null,
          onPressed: () => Navigator.pop(d, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}
