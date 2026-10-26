import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import 'ui.dart';

// The 8 colours of the web (namecard/CardView.jsx COLORS) + "Custom" (hue / lightness / #hex)
const brandColors = ['#E0581A', '#D93025', '#C2185B', '#7B1FA2', '#1A73E8', '#00897B', '#2E7D32', '#16171B'];

Color hexToColor(String? hex, [Color fallback = const Color(0xFFE0581A)]) {
  final h = (hex ?? '').replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? h : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

String colorToHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class ColorRow extends StatelessWidget {
  final String value; // #RRGGBB
  final ValueChanged<String>? onChanged; // null = read only
  final String customLabel, saveLabel, cancelLabel;
  final List<String> colors;
  const ColorRow({super.key, required this.value, required this.onChanged, required this.customLabel, required this.saveLabel, required this.cancelLabel, this.colors = brandColors});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value.toUpperCase();
    final custom = !colors.contains(v) && v.isNotEmpty;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final col in colors)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(col),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hexToColor(col),
                shape: BoxShape.circle,
                border: Border.all(color: v == col ? c.ink : Colors.transparent, width: 2.5),
              ),
              child: v == col ? const Icon(LucideIcons.check, size: 18, color: Colors.white) : null,
            ),
          ),
        GestureDetector(
          onTap: onChanged == null
              ? null
              : () async {
                  final picked = await pickColor(context, hexToColor(value), saveLabel, cancelLabel);
                  if (picked != null) onChanged!(colorToHex(picked));
                },
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 4, right: 12),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: custom ? c.ink : c.line, width: custom ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: custom ? hexToColor(value) : null,
                    gradient: custom ? null : const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                  ),
                ),
                const SizedBox(width: 8),
                Text(customLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<Color?> pickColor(BuildContext context, Color start, String saveLabel, String cancelLabel) {
  var hsl = HSLColor.fromColor(start);
  final hex = TextEditingController(text: colorToHex(start));
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        final now = hsl.toColor();
        void update(HSLColor v) => set(() {
          hsl = v;
          hex.text = colorToHex(v.toColor());
        });
        Widget slider(List<Color> colors, double value, ValueChanged<double> onChanged) => LayoutBuilder(
          builder: (_, box) {
            void at(Offset p) => onChanged((p.dx / box.maxWidth).clamp(0.0, 1.0));
            return GestureDetector(
              onPanDown: (d) => at(d.localPosition),
              onPanUpdate: (d) => at(d.localPosition),
              child: SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                    Positioned(
                      left: (value.clamp(0.0, 1.0) * box.maxWidth - 14).clamp(0.0, box.maxWidth - 28),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: now, borderRadius: BorderRadius.circular(16)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Field(
                      controller: hex,
                      maxLength: 7,
                      onChanged: (v) {
                        final h = v.startsWith('#') ? v : '#$v';
                        if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(h)) set(() => hsl = HSLColor.fromColor(hexToColor(h)));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              slider(
                [for (var h = 0; h <= 360; h += 60) HSLColor.fromAHSL(1, h.toDouble() % 360, .75, .5).toColor()],
                hsl.hue / 360,
                (v) => update(hsl.withHue(v * 360 % 360).withSaturation(hsl.saturation < .2 ? .7 : hsl.saturation)),
              ),
              const SizedBox(height: 14),
              slider([Colors.black, hsl.withLightness(.5).toColor(), Colors.white], hsl.lightness, (v) => update(hsl.withLightness(v.clamp(.05, .95)))),
              const SizedBox(height: 22),
              Btn(saveLabel, onTap: () => Navigator.pop(ctx, now)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(cancelLabel, style: TextStyle(color: c.muted)),
              ),
            ],
          ),
        );
      },
    ),
  );
}
