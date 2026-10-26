import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// The log in / sign up frame of the web (homepage/auth/AuthShell.jsx): logo, EN/ខ្មែរ, light/dark, then the form.
class AuthShell extends ConsumerWidget {
  final List<Widget> children;
  final Widget? back;
  const AuthShell({super.key, required this.children, this.back});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final lang = ref.watch(prefsProvider).lang;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget seg(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => ref.read(prefsProvider.notifier).setLang(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: on ? c.pubInk : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: on ? c.pubBg : c.pubMuted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.pubBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  ?back,
                  if (back == null) const Logo(height: 28),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: c.pubChip, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [seg('en', 'EN'), seg('km', 'ខ្មែរ')]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.pubLine),
                    ),
                    child: IconButton(
                      onPressed: () => ref.read(prefsProvider.notifier).setTheme(dark ? ThemeMode.light : ThemeMode.dark),
                      icon: Icon(dark ? LucideIcons.sun : LucideIcons.moon, size: 20, color: c.pubInk),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title, sub;
  const AuthTitle(this.title, this.sub, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final km = Localizations.localeOf(context).languageCode == 'km';
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: km ? 28 : 32, fontWeight: FontWeight.w800, color: c.pubInk, height: km ? 1.4 : 1.1, letterSpacing: km ? 0 : -1),
          ),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(fontSize: 16, color: c.pubMuted, height: 1.5)),
        ],
      ),
    );
  }
}

// btn-primary of the public pages (brick orange, full width)
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const AuthButton(this.label, {super.key, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: c.pubBrand,
          foregroundColor: c.pubOnBrand,
          disabledBackgroundColor: c.pubBrand.withValues(alpha: .6),
          disabledForegroundColor: c.pubOnBrand,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: c.pubOnBrand)), const SizedBox(width: 10)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class AuthLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const AuthLink(this.text, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(
        text,
        style: TextStyle(color: context.c.pubBrand, fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    ),
  );
}

// "Don't have an account? Create account"
class AuthSwitch extends StatelessWidget {
  final String q, link;
  final VoidCallback onTap;
  const AuthSwitch(this.q, this.link, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(q, style: TextStyle(color: context.c.pubMuted, fontSize: 15)),
        AuthLink(link, onTap),
      ],
    ),
  );
}

// phone number with +855 (Cambodia) in front, like PhoneInput on the web
class PhoneField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool invalid, enabled;
  final ValueChanged<String>? onChanged;
  final Widget? below;
  const PhoneField({super.key, required this.label, required this.controller, this.hint, this.invalid = false, this.enabled = true, this.onChanged, this.below});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Field(
          label: label,
          controller: controller,
          public: true,
          invalid: invalid,
          enabled: enabled,
          keyboard: TextInputType.phone,
          autofill: const [AutofillHints.telephoneNumberNational],
          hint: '012 345 678',
          onChanged: onChanged,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.phone, size: 18, color: c.pubMuted),
                const SizedBox(width: 8),
                Text(
                  '🇰🇭 +855',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.pubInk, fontSize: 15),
                ),
                Container(width: 1, height: 22, margin: const EdgeInsets.only(left: 10), color: c.pubLine),
              ],
            ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(hint!, style: TextStyle(color: c.pubMuted, fontSize: 13)),
          ),
        ?below,
      ],
    );
  }

  // what the person typed → +855…; a number starting with + is kept as is
  static String? e164(String typed) => normalizePhone(typed.trim().startsWith('+') ? typed : '+855 ${typed.trim().replaceFirst(RegExp(r'^0+'), '')}');
}

// "Available" / "This number already has an account"
class CheckNote extends StatelessWidget {
  final String status; // "" | checking | ok | taken
  final String okText, takenText;
  final List<Widget> links;
  const CheckNote({super.key, required this.status, required this.okText, required this.takenText, this.links = const []});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (status.isEmpty) return const SizedBox.shrink();
    if (status == 'checking') {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.pubMuted)),
        ),
      );
    }
    final ok = status == 'ok';
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Icon(ok ? LucideIcons.circleCheck : LucideIcons.circleX, size: 15, color: ok ? c.good : c.danger),
          Text(
            ok ? okText : takenText,
            style: TextStyle(color: ok ? c.good : c.danger, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          if (!ok) ...links,
        ],
      ),
    );
  }
}

// Google's "G" (same paths as the web's GoogleIcon)
const _gIcon =
    '<svg viewBox="0 0 48 48"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>';

// "Continue with Google" (btn-google on the web)
class GoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const GoogleButton(this.label, {super.key, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.pubBg,
          foregroundColor: c.pubInk,
          side: BorderSide(color: c.pubLineStrong),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: c.pubMuted)) : SvgPicture.string(_gIcon, width: 20, height: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// "Log in with QR code" — same look as the Google button; opens the camera (qr_login_page.dart)
class QrButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const QrButton(this.label, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.pubBg,
          foregroundColor: c.pubInk,
          side: BorderSide(color: c.pubLineStrong),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.scanQrCode, size: 20, color: c.pubBrand),
            const SizedBox(width: 12),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// ───── or ─────
class OrLine extends StatelessWidget {
  final String text;
  const OrLine(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.pubLine)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(text, style: TextStyle(color: c.pubMuted, fontSize: 14)),
          ),
          Expanded(child: Divider(color: c.pubLine)),
        ],
      ),
    );
  }
}

// "Check your email" (mail-sent on the web)
class MailSent extends StatelessWidget {
  final String title, sub, hint;
  final Widget? below;
  const MailSent({super.key, required this.title, required this.sub, required this.hint, this.below});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: c.limeBg, shape: BoxShape.circle),
          child: Icon(LucideIcons.mailCheck, size: 32, color: c.limeInk),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.pubInk),
        ),
        const SizedBox(height: 10),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15.5, color: c.pubMuted, height: 1.55),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.pubMuted, height: 1.5),
        ),
        ?below,
      ],
    );
  }
}
