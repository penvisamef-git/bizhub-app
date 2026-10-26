import 'package:flutter/material.dart';

// Telegram Store designs (v2.0) — the same as the web's src/tgstore/themes.js: 8 layouts × 15 colour sets = 120.
// A design = a layout + a palette, plus its own top, cards, buttons, background and corners.
class TsLayout {
  final String key, en, km;
  const TsLayout(this.key, this.en, this.km);
}

class TsPalette {
  final String key, en, km;
  final Color page, bg, ink, muted, line, accent;
  final bool dark;
  const TsPalette(this.key, this.en, this.km, this.page, this.bg, this.ink, this.muted, this.line, this.accent, {this.dark = false});
}

const tsLayouts = [
  TsLayout('grid', 'Grid', 'ក្រឡា'),
  TsLayout('list', 'List', 'បញ្ជី'),
  TsLayout('big', 'Big photos', 'រូបធំ'),
  TsLayout('compact', 'Compact', 'តូចៗ'),
  TsLayout('menu', 'Menu', 'ម៉ឺនុយ'),
  TsLayout('magazine', 'Magazine', 'ទស្សនាវដ្តី'),
  TsLayout('bubble', 'Bubble', 'មូល'),
  TsLayout('shelf', 'Shelf', 'ធ្នើ'),
];

const tsPalettes = [
  TsPalette('cream', 'Cream', 'ក្រែម', Color(0xFFF4F1EC), Color(0xFFFFFFFF), Color(0xFF1F1A16), Color(0xFF7A7068), Color(0xFFE8E2DA), Color(0xFFC4470F)),
  TsPalette('snow', 'Snow', 'ព្រិល', Color(0xFFF5F6F8), Color(0xFFFFFFFF), Color(0xFF111827), Color(0xFF6B7280), Color(0xFFE5E7EB), Color(0xFF2563EB)),
  TsPalette('paper', 'Paper', 'ក្រដាស', Color(0xFFFBF7EE), Color(0xFFFFFDF7), Color(0xFF2B2620), Color(0xFF857A6A), Color(0xFFEAE1CF), Color(0xFF8B5E34)),
  TsPalette('mint', 'Mint', 'ជីអង្កាម', Color(0xFFEAF7F1), Color(0xFFFFFFFF), Color(0xFF0F2E24), Color(0xFF5E7D71), Color(0xFFD3EBE0), Color(0xFF10A37F)),
  TsPalette('sky', 'Sky', 'មេឃ', Color(0xFFE9F4FD), Color(0xFFFFFFFF), Color(0xFF0B2540), Color(0xFF5B7590), Color(0xFFD5E7F6), Color(0xFF229ED9)),
  TsPalette('lilac', 'Lilac', 'ស្វាយ', Color(0xFFF3EFFB), Color(0xFFFFFFFF), Color(0xFF251A3D), Color(0xFF76699A), Color(0xFFE4DCF5), Color(0xFF7C3AED)),
  TsPalette('peach', 'Peach', 'ប៉ែស', Color(0xFFFFF1EA), Color(0xFFFFFFFF), Color(0xFF3A1F14), Color(0xFF9A6E5E), Color(0xFFF7DDD0), Color(0xFFF97316)),
  TsPalette('sand', 'Sand', 'ខ្សាច់', Color(0xFFF5EEDF), Color(0xFFFFFBF2), Color(0xFF3B3222), Color(0xFF8C7E62), Color(0xFFE6DAC1), Color(0xFFB7791F)),
  TsPalette('forest', 'Forest', 'ព្រៃ', Color(0xFFE8F0E5), Color(0xFFFAFDF8), Color(0xFF1B2E1A), Color(0xFF5F7A5C), Color(0xFFD2E1CD), Color(0xFF2F6B2F)),
  TsPalette('ocean', 'Ocean', 'សមុទ្រ', Color(0xFFE5EFF4), Color(0xFFFFFFFF), Color(0xFF0D2A38), Color(0xFF557687), Color(0xFFCFE1EA), Color(0xFF0E7490)),
  TsPalette('night', 'Night', 'យប់', Color(0xFF0F1115), Color(0xFF1A1D24), Color(0xFFF3F4F6), Color(0xFF9CA3AF), Color(0xFF2A2E37), Color(0xFFF59E0B), dark: true),
  TsPalette('coffee', 'Coffee', 'កាហ្វេ', Color(0xFF2A1E17), Color(0xFF3A2A20), Color(0xFFF5E9DC), Color(0xFFC2A992), Color(0xFF4D392C), Color(0xFFE0A96D), dark: true),
  TsPalette('rose', 'Rose', 'ផ្កាកុលាប', Color(0xFFFDEFF3), Color(0xFFFFFFFF), Color(0xFF3B1220), Color(0xFF9A6676), Color(0xFFF5D7E0), Color(0xFFE11D48)),
  TsPalette('lime', 'Lime', 'ក្រូចឆ្មារ', Color(0xFFF3F9E4), Color(0xFFFFFFFF), Color(0xFF1F2A0E), Color(0xFF6B7A4E), Color(0xFFE1EDC7), Color(0xFF65A30D)),
  TsPalette('charcoal', 'Charcoal', 'ធ្យូង', Color(0xFF1C1C1E), Color(0xFF2C2C2E), Color(0xFFFFFFFF), Color(0xFFA1A1A6), Color(0xFF3A3A3C), Color(0xFF34C759), dark: true),
];

const tsFreeThemes = ['grid-cream', 'list-snow', 'menu-paper'];
const tsDefaultTheme = 'grid-cream';
const _heads = ['soft', 'band', 'center', 'split', 'wave', 'cover'];
const _cards = ['shadow', 'outline', 'flat', 'glass', 'bold'];
const _buttons = ['square', 'round', 'pill', 'outline'];
const _patterns = ['none', 'dots', 'grid', 'stripes', 'waves', 'paper'];
const _radii = ['sharp', 'soft', 'round'];
const _noun = {
  'grid': ('Market', 'ផ្សារ'),
  'list': ('Diary', 'កំណត់ហេតុ'),
  'big': ('Gallery', 'វិចិត្រសាល'),
  'compact': ('Pocket', 'ហោប៉ៅ'),
  'menu': ('Bistro', 'ហាងម្ហូប'),
  'magazine': ('Journal', 'ទស្សនាវដ្តី'),
  'bubble': ('Candy', 'ស្ករគ្រាប់'),
  'shelf': ('Boutique', 'បូទិក'),
};

class TsTheme {
  final String key;
  final TsLayout layout;
  final TsPalette palette;
  final String head, card, button, pattern, radius;
  const TsTheme(this.key, this.layout, this.palette, this.head, this.card, this.button, this.pattern, this.radius);
  String name(String lang) {
    final nn = _noun[layout.key]!;
    return lang == 'km' ? '${nn.$2}${palette.km}' : '${palette.en} ${nn.$1}';
  }

  String kind(String lang) => lang == 'km' ? '${layout.km} · ${palette.km}' : '${layout.en} · ${palette.en}';
  double get corner => radius == 'sharp' ? 4 : (radius == 'soft' ? 10 : 18);
}

final List<TsTheme> tsThemes = [
  for (var li = 0; li < tsLayouts.length; li++)
    for (var pi = 0; pi < tsPalettes.length; pi++)
      TsTheme(
        '${tsLayouts[li].key}-${tsPalettes[pi].key}',
        tsLayouts[li],
        tsPalettes[pi],
        _heads[(li * 2 + pi) % _heads.length],
        _cards[(li + pi * 2) % _cards.length],
        _buttons[(li * 3 + pi) % _buttons.length],
        _patterns[(li + pi * 5) % _patterns.length],
        _radii[(li * 2 + pi) % _radii.length],
      ),
];

TsTheme tsThemeOf(String? key) => tsThemes.firstWhere((t) => t.key == key, orElse: () => tsThemes.firstWhere((t) => t.key == tsDefaultTheme));

Color? hexColor(String? v) {
  final s = (v ?? '').replaceAll('#', '');
  if (s.length != 6) return null;
  final x = int.tryParse(s, radix: 16);
  return x == null ? null : Color(0xFF000000 | x);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
