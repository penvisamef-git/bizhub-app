// "Powered by Cyber Tech System" (v3.3.0): the company behind BizHub, small and quiet at the bottom of More, the log in
// / sign up screens and System activity. Tapping the name opens ctscambodia.com in the browser. The website says the
// same (its name and link can be changed in Super admin → Homepage settings; the app keeps this copy).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers.dart';
import '../core/theme.dart';

const poweredName = 'Cyber Tech System';
const poweredUrl = 'https://ctscambodia.com/';
const _word = {'en': 'Powered by', 'km': 'ដំណើរការដោយ'};

// what a tap does (tests change it)
Future<void> Function(Uri) openPowered = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

class PoweredBy extends ConsumerStatefulWidget {
  final double size;
  final EdgeInsets padding;
  final Color? color; // on the log in screens: the public pages' muted colour
  const PoweredBy({super.key, this.size = 12.5, this.padding = const EdgeInsets.only(top: 14, bottom: 6), this.color});
  @override
  ConsumerState<PoweredBy> createState() => _PoweredByState();
}

class _PoweredByState extends ConsumerState<PoweredBy> {
  late final _tap = TapGestureRecognizer()..onTap = () => openPowered(Uri.parse(poweredUrl));

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(tProvider).lang;
    final word = _word[lang] ?? _word['en']!;
    return Padding(
      padding: widget.padding,
      child: Semantics(
        link: true,
        label: '$word $poweredName',
        child: Text.rich(
          key: const ValueKey('powered-by'),
          TextSpan(
            text: '$word ',
            children: [
              TextSpan(
                text: '$poweredName ↗',
                style: const TextStyle(fontWeight: FontWeight.w700),
                recognizer: _tap,
                mouseCursor: SystemMouseCursors.click,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: widget.size, color: widget.color ?? context.c.muted),
        ),
      ),
    );
  }
}
