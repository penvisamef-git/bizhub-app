import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/ui.dart';
import 'recipes_data.dart';

export 'recipes_data.dart' show Recipe, cardRecipes;

part 'nc_recipes.dart';

// The digital name card — same look as the web (namecard/CardView.jsx + cardview.css + cardview-premium.css).
// card = { name, job_title, company, bio, photo, cover, theme, color, phone1, phone2, email, website, address,
//          telegram, facebook, extras: [{label, value}], slug, portfolio }
const freeThemes = ['classic', 'modern', 'minimal', 'bold', 'gradient', 'elegant'];
const oldPremiumThemes = ['aurora', 'neon', 'glass', 'luxury', 'split', 'wave', 'polaroid', 'sunset', 'mono', 'retro', 'nature', 'tech'];
// + the 100 recipe themes (recipes_data.dart, same list as the web and the API)
final premiumThemes = [...oldPremiumThemes, ...cardRecipes.keys];
final allThemes = [...freeThemes, ...premiumThemes];
const cardColors = ['#E0581A', '#D93025', '#C2185B', '#7B1FA2', '#1A73E8', '#00897B', '#2E7D32', '#16171B'];

Color hexColor(String? hex, [Color fallback = const Color(0xFFE0581A)]) {
  final h = (hex ?? '').replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? h : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// lighter / darker version of a colour (same maths as shade() on the web)
Color shade(Color c, double percent) {
  int f(int v) => (v + (percent / 100) * (percent > 0 ? 255 - v : v)).round().clamp(0, 255);
  final argb = c.toARGB32();
  return Color.fromARGB(255, f((argb >> 16) & 255), f((argb >> 8) & 255), f(argb & 255));
}

String _initial(String? name) {
  final s = (name ?? '').trim();
  return s.isEmpty ? '?' : String.fromCharCodes(s.runes.take(1)).toUpperCase();
}

String _tel(String v) => v.replaceAll(RegExp(r'[^\d+]'), '');
String _tg(String v) => v.trim().replaceFirst(RegExp(r'^@'), '').replaceFirst(RegExp(r'^https?://(t\.me|telegram\.me)/', caseSensitive: false), '');
String _host(String v) => v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/$'), '');

class NcContact {
  final String key, href, text;
  const NcContact(this.key, this.href, this.text);
}

// every contact line: key, link, shown text (same order as the web)
List<NcContact> contactsOf(Map card) {
  String s(String k) => '${card[k] ?? ''}'.trim();
  return [
    if (s('phone1').isNotEmpty) NcContact('phone1', 'tel:${_tel(s('phone1'))}', s('phone1')),
    if (s('phone2').isNotEmpty) NcContact('phone2', 'tel:${_tel(s('phone2'))}', s('phone2')),
    if (s('email').isNotEmpty) NcContact('email', 'mailto:${s('email')}', s('email')),
    if (s('website').isNotEmpty) NcContact('website', s('website'), _host(s('website'))),
    if (s('telegram').isNotEmpty) NcContact('telegram', 'https://t.me/${_tg(s('telegram'))}', '@${_tg(s('telegram'))}'),
    if (s('facebook').isNotEmpty) NcContact('facebook', s('facebook'), _host(s('facebook')).replaceFirst(RegExp(r'^(www\.)?facebook\.com/', caseSensitive: false), '')),
    if (s('address').isNotEmpty) NcContact('address', 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(s('address'))}', s('address')),
  ];
}

const _fbIcon = '<svg viewBox="0 0 24 24"><path fill="#000" d="M13.5 21v-7.5h2.6l.4-3h-3V8.6c0-.9.3-1.5 1.6-1.5h1.6V4.4c-.3 0-1.2-.1-2.3-.1-2.3 0-3.9 1.4-3.9 4v2.2H8v3h2.5V21h3Z"/></svg>';

Widget _contactIcon(String key, Color color) => switch (key) {
  'phone1' || 'phone2' => Icon(LucideIcons.phone, size: 18, color: color),
  'email' => Icon(LucideIcons.mail, size: 18, color: color),
  'website' => Icon(LucideIcons.globe, size: 18, color: color),
  'telegram' => Icon(LucideIcons.send, size: 18, color: color),
  'facebook' => SvgPicture.string(_fbIcon, width: 18, height: 18, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
  _ => Icon(LucideIcons.mapPin, size: 18, color: color),
};

String get _serif => defaultTargetPlatform == TargetPlatform.iOS ? 'Georgia' : 'serif';
String get _mono => defaultTargetPlatform == TargetPlatform.iOS ? 'Menlo' : 'monospace';
String get _hand => defaultTargetPlatform == TargetPlatform.iOS ? 'Bradley Hand' : 'cursive';
const _sans = 'PlusJakartaSans';
const _kh = ['KantumruyPro'];

const _grayscale = ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0]);

// ======================================================================================================== card
class NcCard extends StatefulWidget {
  final Map card;
  final Map<String, String> fieldLabels; // phone1 → "Phone"…
  final String yourName, viewPortfolio;
  final bool compact; // theme picker tiles: no contacts, no motion
  final bool km;
  final void Function(NcContact)? onContact;
  const NcCard({super.key, required this.card, this.fieldLabels = const {}, this.yourName = 'Your name', this.viewPortfolio = 'View portfolio', this.compact = false, this.km = false, this.onContact});
  @override
  State<NcCard> createState() => _NcCardState();
}

const _moving = {'aurora', 'neon', 'glass', 'luxury', 'wave', 'tech'};

class _NcCardState extends State<NcCard> with SingleTickerProviderStateMixin {
  AnimationController? _a;

  String get _theme => allThemes.contains(widget.card['theme']) ? '${widget.card['theme']}' : 'classic';

  void _sync() {
    final move = !widget.compact && _moving.contains(_theme);
    if (move && _a == null) {
      _a = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
    } else if (!move && _a != null) {
      _a!.dispose();
      _a = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(NcCard old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _a?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = cardRecipes[_theme];
    if (recipe != null) return _RcBody(widget: widget, r: recipe);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final a = _a;
    if (a == null || reduce) return _NcBody(widget: widget, theme: _theme, t: 0);
    return AnimatedBuilder(
      animation: a,
      builder: (_, _) => _NcBody(widget: widget, theme: _theme, t: a.value),
    );
  }
}

// the theme's look (cardview.css variables + per-theme rules)
class _Look {
  Color bg = Colors.white, ink = const Color(0xFF16171B), muted = const Color(0xFF6A6E7A);
  Gradient? bgGrad;
  CustomPainter? bgPaint;
  bool left = false;
  double radius = 28;
  Border? border;
  List<BoxShadow> shadow = const [BoxShadow(color: Color(0x2416171B), blurRadius: 60, offset: Offset(0, 20))];
  EdgeInsets outer = EdgeInsets.zero;
  String font = _sans;
  // cover
  double coverH = 170;
  EdgeInsets coverMargin = EdgeInsets.zero;
  BorderRadius coverRadius = BorderRadius.zero;
  BorderRadius? coverImageRadius; // only when there is a cover photo
  EdgeInsets? coverImageMargin;
  Decoration? coverDeco; // without a photo
  bool coverImage = true; // tech: never shows the photo
  double coverImageOpacity = 1;
  bool coverGray = false;
  // body
  double shift = 60; // photo margin-top: -60px (the body moves up)
  double bodyTop = 0;
  EdgeInsets bodyPad = const EdgeInsets.fromLTRB(28, 0, 28, 24);
  Decoration? bodyDeco;
  bool bodyBlur = false;
  // photo
  double photo = 120, photoBorder = 5, photoFont = 48;
  BorderRadius? photoRadius; // null = round
  Color? photoBorderColor;
  late Color photoBg, photoInk;
  List<BoxShadow> photoShadow = const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))];
  double photoTurn = 0;
  Color? ringColor;
  double ringGap = 0;
  bool photoGray = false;
  // name & role
  double nameSize = 26, nameSpacing = 0, nameTop = 10, nameHeight = 1.2;
  FontWeight nameWeight = FontWeight.w800;
  String? nameFont;
  bool nameUpper = false;
  List<Shadow>? nameGlow;
  late Color roleColor;
  double roleSize = 15, roleSpacing = 0;
  FontWeight roleWeight = FontWeight.w700;
  bool roleItalic = false, roleUpper = false;
  Color? roleBg;
  Border? roleBorder;
  EdgeInsets rolePad = EdgeInsets.zero;
  double roleRadius = 999;
  String roleAround = '';
  Color? roleAroundColor;
  String rolePrefix = '';
  Gradient? roleGrad;
  Color? roleMark; // mono: highlighter line
  double bioSize = 14.5;
  // contacts
  late Color tile, tileInk, icInk;
  Color? icBg;
  Gradient? icGrad;
  double tileRadius = 16;
  BorderRadius? tileRadii;
  double icRadius = 12;
  BorderRadius? icRadii;
  Border? tileBorder;
  Border? icBorder;
  bool tileLine = false; // only a line under each row
  Color tileLineColor = const Color(0xFFEEF0F3);
  double tileLineWidth = 1;
  List<BoxShadow> tileShadow = const [];
  bool tileTilt = false;
  bool smallUpper = false;
  // extras + portfolio button
  Color? extrasBorder;
  double extrasWidth = 1, extrasRadius = 16;
  bool extrasDashed = true;
  Color? btn;
  Gradient? btnGrad;
  late Color btnInk;
  double btnRadius = 999;
  Border? btnBorder;
  List<BoxShadow>? btnShadow;
  List<Shadow>? btnGlow;
}

_Look _lookOf(String theme, Color c, bool km) {
  final dark = shade(c, -35), light = shade(c, 55), soft = shade(c, 88);
  final l = _Look()
    ..photoBg = soft
    ..photoInk = dark
    ..roleColor = c
    ..tile = soft
    ..icBg = c
    ..icInk = Colors.white
    ..btn = c
    ..btnInk = Colors.white
    ..coverDeco = BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, light]),
    );
  void after() => l.tileInk = l.ink;

  switch (theme) {
    case 'modern':
      l
        ..bg = const Color(0xFF111215)
        ..ink = const Color(0xFFF4F5F7)
        ..muted = const Color(0xFFA3A7B3)
        ..left = true
        ..coverH = 200
        ..shift = 70
        ..photo = 104
        ..photoBorder = 0
        ..photoRadius = BorderRadius.circular(24)
        ..photoShadow = [BoxShadow(color: c, spreadRadius: 3)]
        ..nameSize = 28
        ..roleColor = light
        ..rolePad = const EdgeInsets.only(left: 12)
        ..roleBorder = Border(left: BorderSide(color: c, width: 3))
        ..roleRadius = 0
        ..tile = Colors.white.withValues(alpha: .06);
    case 'minimal':
      l
        ..left = true
        ..shadow = const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1)), BoxShadow(color: Color(0x1416171B), blurRadius: 40, offset: Offset(0, 12))]
        ..coverH = 8
        ..coverDeco = BoxDecoration(color: c)
        ..coverImage = false
        ..shift = 0
        ..bodyTop = 40
        ..photo = 84
        ..photoBorder = 0
        ..photoShadow = const []
        ..photoFont = 34
        ..nameTop = 22
        ..nameSize = 30
        ..nameWeight = FontWeight.w700
        ..nameSpacing = -0.6
        ..roleWeight = FontWeight.w600
        ..roleUpper = !km
        ..roleSpacing = km ? 0 : 1
        ..roleSize = km ? 14 : 12.5
        ..tile = Colors.transparent
        ..tileLine = true
        ..icBg = soft
        ..icInk = dark;
    case 'bold':
      l
        ..bg = c
        ..ink = Colors.white
        ..muted = Colors.white.withValues(alpha: .86)
        ..coverH = 150
        ..coverDeco = null
        ..coverImageOpacity = .9
        ..photoBorderColor = Colors.white
        ..photoBg = dark
        ..photoInk = Colors.white
        ..nameSize = 32
        ..nameSpacing = -0.6
        ..roleColor = Colors.white
        ..roleBg = Colors.black.withValues(alpha: .18)
        ..rolePad = const EdgeInsets.symmetric(horizontal: 14, vertical: 5)
        ..tile = Colors.black.withValues(alpha: .16)
        ..icBg = Colors.white
        ..icInk = c
        ..btn = Colors.white
        ..btnInk = dark;
    case 'gradient':
      l
        ..bg = Colors.transparent
        ..bgGrad = LinearGradient(begin: const Alignment(-0.34, -0.94), end: const Alignment(0.34, 0.94), colors: [dark, c, light], stops: const [0, .45, 1])
        ..outer = const EdgeInsets.fromLTRB(16, 20, 16, 0)
        ..coverH = 130
        ..coverRadius = const BorderRadius.vertical(top: Radius.circular(22))
        ..coverDeco = BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        )
        ..bodyDeco = BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        )
        ..bodyPad = const EdgeInsets.fromLTRB(28, 0, 28, 28)
        ..photoBorderColor = Colors.white;
    case 'elegant':
      l
        ..bg = const Color(0xFFF7F3EC)
        ..ink = const Color(0xFF2B2620)
        ..muted = const Color(0xFF6F665B)
        ..font = _serif
        ..border = Border.all(color: const Color(0x0F000000))
        ..coverH = 150
        ..coverMargin = const EdgeInsets.fromLTRB(14, 14, 14, 0)
        ..coverRadius = const BorderRadius.vertical(top: Radius.circular(20))
        ..photoRadius = BorderRadius.circular(18)
        ..photoBorder = 4
        ..photoBorderColor = const Color(0xFFF7F3EC)
        ..ringColor = c
        ..ringGap = 3
        ..nameWeight = FontWeight.w400
        ..nameSize = 30
        ..nameSpacing = .3
        ..roleItalic = true
        ..roleWeight = FontWeight.w400
        ..roleAround = '—'
        ..tile = Colors.white.withValues(alpha: .6)
        ..tileBorder = Border.all(color: const Color(0x0F000000))
        ..icRadius = 999;
    // ------------------------------------------------------------------ premium
    case 'aurora':
      l
        ..bg = const Color(0xFF0A0D1C)
        ..ink = const Color(0xFFF5F7FF)
        ..muted = const Color(0xFFB4B9D6)
        ..tile = Colors.white.withValues(alpha: .07)
        ..btnGrad = LinearGradient(colors: [c, const Color(0xFF7C4DFF)])
        ..coverH = 150
        ..coverDeco = null
        ..coverImageMargin = const EdgeInsets.fromLTRB(14, 14, 14, 0)
        ..coverImageRadius = BorderRadius.circular(22)
        ..coverImageOpacity = .85
        ..photoBorder =
            4 // the spinning colour ring
        ..photoBg = const Color(0xFF0A0D1C)
        ..photoInk = Colors.white
        ..roleColor = light
        ..tileBorder = Border.all(color: Colors.white.withValues(alpha: .08));
    case 'neon':
      l
        ..bg = const Color(0xFF050507)
        ..ink = Colors.white
        ..muted = const Color(0xFF9A9CAB)
        ..bgPaint = _GridPaint(28, Colors.white.withValues(alpha: .035))
        ..border = Border.all(color: c, width: 2)
        ..shadow = [BoxShadow(color: c, spreadRadius: 1), BoxShadow(color: c.withValues(alpha: .55), blurRadius: 30)]
        ..coverH = 120
        ..coverDeco = null
        ..coverImageMargin = const EdgeInsets.fromLTRB(12, 12, 12, 0)
        ..coverImageRadius = BorderRadius.circular(18)
        ..photoBg = const Color(0xFF050507)
        ..photoInk = light
        ..photoBorder = 3
        ..photoBorderColor = c
        ..photoShadow = [BoxShadow(color: c, blurRadius: 18)]
        ..nameGlow = [Shadow(color: c, blurRadius: 8), Shadow(color: c, blurRadius: 22)]
        ..nameSpacing = .5
        ..roleColor = light
        ..roleUpper = !km
        ..roleSpacing = km ? 0 : 2.2
        ..roleSize = km ? 14 : 12
        ..tile = Colors.transparent
        ..tileBorder = Border.all(color: c.withValues(alpha: .6))
        ..icBg = Colors.transparent
        ..icInk = light
        ..icBorder = Border.all(color: c)
        ..btn = Colors.transparent
        ..btnInk = light
        ..btnBorder = Border.all(color: c, width: 2)
        ..btnShadow = [BoxShadow(color: c.withValues(alpha: .55), blurRadius: 16)]
        ..btnGlow = [Shadow(color: c, blurRadius: 6)];
    case 'glass':
      l
        ..bg = Colors.transparent
        ..ink = Colors.white
        ..muted = Colors.white.withValues(alpha: .85)
        ..bgGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [dark, c, light], stops: const [0, .6, 1])
        ..outer = const EdgeInsets.fromLTRB(16, 18, 16, 0)
        ..coverH = 120
        ..coverRadius = const BorderRadius.vertical(top: Radius.circular(24))
        ..coverDeco = BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: .35)),
            left: BorderSide(color: Colors.white.withValues(alpha: .35)),
            right: BorderSide(color: Colors.white.withValues(alpha: .35)),
          ),
        )
        ..bodyDeco = BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .35)),
            left: BorderSide(color: Colors.white.withValues(alpha: .35)),
            right: BorderSide(color: Colors.white.withValues(alpha: .35)),
          ),
        )
        ..bodyBlur = true
        ..bodyPad = const EdgeInsets.fromLTRB(28, 0, 28, 26)
        ..photoBorderColor = Colors.white.withValues(alpha: .6)
        ..photoBg = Colors.white.withValues(alpha: .3)
        ..photoInk = Colors.white
        ..roleColor = Colors.white.withValues(alpha: .92)
        ..tile = Colors.white.withValues(alpha: .16)
        ..icBg = Colors.white.withValues(alpha: .25)
        ..tileBorder = Border.all(color: Colors.white.withValues(alpha: .25))
        ..btn = Colors.white
        ..btnInk = dark;
    case 'luxury':
      const gold = Color(0xFFD9B45A);
      l
        ..bg = const Color(0xFF0D0D0F)
        ..ink = const Color(0xFFF3EAD3)
        ..muted = const Color(0xFFA99F86)
        ..bgGrad = const RadialGradient(center: Alignment.topCenter, radius: 1.2, colors: [Color(0xFF1D1A14), Color(0xFF0D0D0F)], stops: [0, .7])
        ..font = _serif
        ..coverH = 140
        ..coverDeco = null
        ..coverImageMargin = const EdgeInsets.fromLTRB(20, 20, 20, 0)
        ..coverImageRadius = BorderRadius.circular(14)
        ..photoBorder = 2
        ..photoBorderColor = gold
        ..ringColor = gold.withValues(alpha: .5)
        ..ringGap = 5
        ..photoBg = const Color(0xFF1A1712)
        ..photoInk = gold
        ..nameWeight = FontWeight.w400
        ..nameSize = 30
        ..nameSpacing = 1.2
        ..roleColor = gold
        ..roleWeight = FontWeight.w400
        ..roleItalic = true
        ..roleAround = '◆'
        ..tile = gold.withValues(alpha: .07)
        ..tileBorder = Border.all(color: gold.withValues(alpha: .25))
        ..tileRadius = 6
        ..icBg = Colors.transparent
        ..icInk = gold
        ..icBorder = Border.all(color: gold.withValues(alpha: .5))
        ..icRadius = 999
        ..btnGrad = const LinearGradient(colors: [Color(0xFFB8913A), Color(0xFFF6E3A1), Color(0xFFB8913A)], stops: [0, .45, 1])
        ..btnInk = const Color(0xFF1A1408)
        ..btnRadius = 6;
    case 'split':
      l
        ..left = true
        ..tile = const Color(0xFFF4F5F7)
        ..coverH = 230
        ..coverDeco = BoxDecoration(
          gradient: LinearGradient(begin: const Alignment(-0.87, -0.5), end: const Alignment(0.87, 0.5), colors: [dark, c]),
        )
        ..shift = 150
        ..photo = 128
        ..photoRadius = BorderRadius.circular(28)
        ..photoTurn = -4
        ..photoBorder = 6
        ..photoShadow = const [BoxShadow(color: Color(0x38000000), blurRadius: 34, offset: Offset(0, 16))]
        ..nameSize = 32
        ..nameSpacing = -0.6
        ..nameTop = 16
        ..roleColor = Colors.white
        ..roleBg = c
        ..rolePad = const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
        ..roleRadius = 8
        ..icRadius = 10;
    case 'wave':
      l
        ..coverH = 210
        ..coverDeco = BoxDecoration(
          gradient: LinearGradient(begin: const Alignment(-0.34, -0.94), end: const Alignment(0.34, 0.94), colors: [light, c], stops: const [0, .7]),
        )
        ..shift = 80
        ..photoBorderColor = Colors.white
        ..tileRadius = 999
        ..icRadius = 999;
    case 'polaroid':
      l
        ..bg = const Color(0xFFF2EDE4)
        ..ink = const Color(0xFF2A2723)
        ..muted = const Color(0xFF6C665C)
        ..tile = Colors.white
        ..coverH = 70
        ..coverDeco = null
        ..coverImage = false
        ..shift = 20
        ..nameTop = 18
        ..nameFont = _hand
        ..nameSize = 30
        ..nameWeight = FontWeight.w700
        ..roleColor = dark
        ..tileRadius = 4
        ..tileShadow = const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))]
        ..tileTilt = true
        ..btnRadius = 6;
    case 'sunset':
      l
        ..bg = const Color(0xFFFFF8F1)
        ..ink = const Color(0xFF2B1A1A)
        ..muted = const Color(0xFF7A5D58)
        ..tile = Colors.white
        ..icGrad = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8A3D), Color(0xFFE8457C)])
        ..btnGrad = const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFE8457C), Color(0xFF7B3FE4)])
        ..coverH = 220
        ..photoBorderColor = const Color(0xFFFFF8F1)
        ..roleGrad = const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFE8457C)]);
    case 'mono':
      const ink = Color(0xFF0A0A0A);
      l
        ..ink = ink
        ..muted = const Color(0xFF555555)
        ..tile = Colors.transparent
        ..icBg = ink
        ..btn = ink
        ..left = true
        ..border = Border.all(color: ink, width: 3)
        ..shadow = const []
        ..radius = 6
        ..coverH = 180
        ..coverDeco = const BoxDecoration(color: ink)
        ..coverGray = true
        ..photoRadius = BorderRadius.zero
        ..photoBorder = 3
        ..photoBorderColor = ink
        ..photoBg = Colors.white
        ..photoInk = ink
        ..photoShadow = [BoxShadow(color: c, offset: const Offset(8, 8))]
        ..photoGray = true
        ..shift = 50
        ..nameSize = km ? 32 : 40
        ..nameHeight = km ? 1.3 : 1
        ..nameUpper = !km
        ..nameSpacing = km ? 0 : -1.2
        ..nameWeight = FontWeight.w900
        ..nameTop = 20
        ..roleColor = ink
        ..roleMark = light
        ..tileLine = true
        ..tileLineColor = ink
        ..tileLineWidth = 2
        ..tileRadius = 0
        ..icRadius = 0
        ..extrasBorder = ink
        ..extrasWidth = 2
        ..extrasRadius = 0
        ..extrasDashed = false
        ..btnRadius = 0
        ..btnShadow = [BoxShadow(color: c, offset: const Offset(6, 6))];
    case 'retro':
      const ink = Color(0xFF241C15);
      l
        ..bg = const Color(0xFFFFF4DC)
        ..ink = ink
        ..muted = const Color(0xFF6B5A49)
        ..tile = Colors.white
        ..border = Border.all(color: ink, width: 3)
        ..shadow = const [BoxShadow(color: ink, offset: Offset(10, 10))]
        ..radius = 24
        ..coverH = 160
        ..photoBorder = 3
        ..photoBorderColor = ink
        ..photoShadow = const [BoxShadow(color: ink, offset: Offset(5, 5))]
        ..photoBg = const Color(0xFFFFD25E)
        ..photoInk = ink
        ..nameSize = 32
        ..nameWeight = FontWeight.w900
        ..roleColor = ink
        ..roleBg = const Color(0xFFFFD25E)
        ..roleBorder = Border.all(color: ink, width: 2)
        ..rolePad = const EdgeInsets.symmetric(horizontal: 12, vertical: 3)
        ..tileBorder = Border.all(color: ink, width: 2)
        ..tileShadow = const [BoxShadow(color: ink, offset: Offset(3, 3))]
        ..icBorder = Border.all(color: ink, width: 2)
        ..btnBorder = Border.all(color: ink, width: 3)
        ..btnShadow = const [BoxShadow(color: ink, offset: Offset(5, 5))];
    case 'nature':
      l
        ..bg = const Color(0xFFF4F0E4)
        ..ink = const Color(0xFF23301F)
        ..muted = const Color(0xFF5F6B55)
        ..tile = Colors.white.withValues(alpha: .7)
        ..coverH = 120
        ..coverDeco = null
        ..coverImageMargin = const EdgeInsets.fromLTRB(16, 16, 16, 0)
        ..coverImageRadius = const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40), bottomRight: Radius.circular(40), bottomLeft: Radius.circular(8))
        ..photo = 130
        ..photoBorderColor = const Color(0xFFF4F0E4)
        ..nameFont = _serif
        ..nameWeight = FontWeight.w700
        ..roleColor = dark
        ..tileRadii = const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22), bottomRight: Radius.circular(22), bottomLeft: Radius.circular(6))
        ..icRadii = const BorderRadius.only(topLeft: Radius.circular(19), topRight: Radius.circular(19), bottomRight: Radius.circular(19), bottomLeft: Radius.circular(4.5));
    case 'tech':
      l
        ..bg = const Color(0xFF0B0F14)
        ..ink = const Color(0xFFD8F3FF)
        ..muted = const Color(0xFF7F97A8)
        ..tile = Colors.white.withValues(alpha: .03)
        ..icBg = Colors.transparent
        ..icInk = light
        ..font = _mono
        ..left = true
        ..radius = 14
        ..bgPaint = _TechPaint(c.withValues(alpha: .1))
        ..coverH = 38
        ..coverImage = false
        ..coverDeco = BoxDecoration(
          color: const Color(0xFF121821),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .08))),
        )
        ..shift = 0
        ..bodyTop = 26
        ..photoRadius = BorderRadius.circular(8)
        ..photoBorder = 1
        ..photoBorderColor = c
        ..photoBg = const Color(0xFF0B0F14)
        ..photoInk = light
        ..photoShadow = [const BoxShadow(color: Color(0xFF0B0F14), spreadRadius: 4), BoxShadow(color: c.withValues(alpha: .4), spreadRadius: 5)]
        ..nameSize = 24
        ..nameWeight = FontWeight.w700
        ..roleColor = light
        ..roleWeight = FontWeight.w500
        ..roleSize = 13
        ..rolePrefix = '// '
        ..bioSize = 13
        ..tileRadius = 6
        ..tileBorder = Border(
          left: BorderSide(color: c, width: 3),
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
          right: BorderSide(color: Colors.white.withValues(alpha: .08)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
        )
        ..icBorder = Border.all(color: c.withValues(alpha: .5))
        ..icRadius = 6
        ..smallUpper = true
        ..btnRadius = 6
        ..btnShadow = [BoxShadow(color: c, spreadRadius: 1), BoxShadow(color: c.withValues(alpha: .35), blurRadius: 22)];
  }
  l.photoBorderColor ??= l.bg == Colors.transparent ? Colors.white : l.bg;
  after();
  return l;
}

class _NcBody extends StatelessWidget {
  final NcCard widget;
  final String theme;
  final double t; // 0…1, loops (28 s)
  const _NcBody({required this.widget, required this.theme, required this.t});

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final c = hexColor('${card['color'] ?? ''}');
    final dark = shade(c, -35), light = shade(c, 55), soft = shade(c, 88);
    final l = _lookOf(theme, c, widget.km);
    final compact = widget.compact;
    String s(String k) => '${card[k] ?? ''}'.trim();
    final role = [s('job_title'), s('company')].where((x) => x.isNotEmpty).join(' · ');
    final cover = s('cover'), photo = s('photo');
    final contacts = compact ? <NcContact>[] : contactsOf(card);
    final extras = compact ? <Map>[] : ((card['extras'] as List?) ?? const []).whereType<Map>().where((x) => '${x['label'] ?? ''}'.isNotEmpty || '${x['value'] ?? ''}'.isNotEmpty).toList();
    final align = l.left ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = l.left ? TextAlign.left : TextAlign.center;
    final wave = math.sin(t * 2 * math.pi * 2); // −1…1, about 14 s per swing (like 14s alternate)
    TextStyle ts({double size = 14, FontWeight w = FontWeight.w400, Color? color, double? h, double ls = 0, String? font, bool italic = false, List<Shadow>? glow}) => TextStyle(
      fontFamily: font ?? l.font,
      fontFamilyFallback: _kh,
      fontSize: size,
      fontWeight: w,
      color: color ?? l.ink,
      height: h,
      letterSpacing: ls,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      shadows: glow,
    );

    // ---------------------------------------------------------------- cover
    Widget coverBox() {
      final hasImg = cover.isNotEmpty && l.coverImage;
      Widget box;
      if (hasImg) {
        Widget img = Image(image: netImage(cover), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink());
        if (l.coverGray) img = ColorFiltered(colorFilter: _grayscale, child: img);
        final r = l.coverImageRadius ?? l.coverRadius;
        box = ClipRRect(
          borderRadius: r,
          child: Opacity(opacity: l.coverImageOpacity, child: img),
        );
        if (theme == 'bold') {
          box = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.transparent], stops: [.55, 1]).createShader(b),
            child: box,
          );
        }
      } else {
        box = switch (theme) {
          'sunset' => CustomPaint(painter: _SunsetSky(), size: Size.infinite),
          'retro' => CustomPaint(painter: _RetroStripes(c, dark, light), size: Size.infinite),
          'tech' => Container(
            decoration: l.coverDeco,
            child: const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 14, top: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [_Dot(Color(0xFFFF5F57)), SizedBox(width: 6), _Dot(Color(0xFFFEBC2E)), SizedBox(width: 6), _Dot(Color(0xFF28C840))]),
              ),
            ),
          ),
          _ => l.coverDeco == null ? const SizedBox.shrink() : DecoratedBox(decoration: l.coverDeco!, child: const SizedBox.expand()),
        };
      }
      if (theme == 'modern') {
        box = Stack(
          fit: StackFit.expand,
          children: [
            box,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00111215), Color(0xFF111215)], stops: [.3, 1]),
              ),
            ),
          ],
        );
      }
      if (theme == 'split') box = ClipPath(clipper: _SplitClip(), child: box);
      if (theme == 'wave') box = ClipPath(clipper: _WaveClip(), child: box);
      if (theme == 'retro') {
        box = DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: l.ink, width: 3)),
          ),
          child: box,
        );
      }
      final margin = hasImg ? (l.coverImageMargin ?? l.coverMargin) : l.coverMargin;
      return Padding(
        padding: margin,
        child: SizedBox(height: l.coverH, width: double.infinity, child: box),
      );
    }

    // ---------------------------------------------------------------- photo
    Widget photoBox() {
      final size = theme == 'polaroid' ? 230.0 : l.photo;
      final inner = photo.isNotEmpty
          ? Image(image: netImage(photo), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink())
          : Center(
              child: Text(
                _initial(s('name')),
                style: ts(size: theme == 'polaroid' ? 80 : l.photoFont, w: FontWeight.w800, color: theme == 'polaroid' ? c : l.photoInk, font: _sans),
              ),
            );
      Widget p;
      if (theme == 'polaroid') {
        p = SizedBox(
          width: 230,
          height: 260,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 230,
                height: 260,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 52),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 30, offset: Offset(0, 14))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(color: soft, child: inner),
                ),
              ),
              Positioned(
                top: -12,
                left: 70,
                child: Transform.rotate(
                  angle: 4 * math.pi / 180,
                  child: Container(
                    width: 90,
                    height: 26,
                    decoration: BoxDecoration(
                      color: light.withValues(alpha: .7),
                      boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        return Transform.rotate(angle: -3 * math.pi / 180, child: p);
      }
      if (theme == 'aurora') {
        // spinning colour ring (conic gradient), the picture inside does not turn
        final turn = t * 2 * math.pi * 3.5; // one turn ≈ 8 s
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Transform.rotate(
                angle: turn,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [c, const Color(0xFF7C4DFF), const Color(0xFF00D4B0), c]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: ColoredBox(color: l.photoBg, child: inner),
                ),
              ),
            ],
          ),
        );
      }
      final round = l.photoRadius == null && theme != 'nature';
      final radius = theme == 'nature'
          ? const BorderRadius.only(topLeft: Radius.elliptical(80.6, 62.4), topRight: Radius.elliptical(49.4, 78), bottomRight: Radius.elliptical(71.5, 52), bottomLeft: Radius.elliptical(58.5, 67.6))
          : l.photoRadius;
      var shadow = l.photoShadow;
      if (theme == 'neon') shadow = [BoxShadow(color: c, blurRadius: 18 + 10 * (wave * .5 + .5))];
      Widget pic = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: l.photoBg,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : radius,
          border: l.photoBorder > 0 ? Border.all(color: l.photoBorderColor!, width: l.photoBorder) : null,
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: round ? BorderRadius.circular(size) : (radius ?? BorderRadius.zero),
          child: l.photoGray && photo.isNotEmpty ? ColorFiltered(colorFilter: _grayscale, child: inner) : inner,
        ),
      );
      if (l.ringColor != null) {
        final gap = l.ringGap + 1;
        pic = Container(
          padding: EdgeInsets.all(gap),
          decoration: BoxDecoration(
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular((radius?.topLeft.x ?? 0) + gap),
            border: Border.all(color: l.ringColor!, width: 1),
          ),
          child: pic,
        );
        // keep the layout size like CSS outline (drawn outside the box)
        pic = SizedBox(
          width: size,
          height: size,
          child: OverflowBox(maxWidth: size + gap * 2 + 2, maxHeight: size + gap * 2 + 2, child: pic),
        );
      }
      if (l.photoTurn != 0) pic = Transform.rotate(angle: l.photoTurn * math.pi / 180, child: pic);
      return pic;
    }

    // ---------------------------------------------------------------- name + role
    Widget nameText() {
      var text = s('name').isEmpty ? widget.yourName : s('name');
      if (l.nameUpper) text = text.toUpperCase();
      final base = ts(size: l.nameSize, w: l.nameWeight, h: l.nameHeight, ls: l.nameSpacing, font: l.nameFont, glow: l.nameGlow);
      Widget w;
      if (theme == 'tech') {
        final on = (t * 28).floor().isEven; // blinking cursor, 1 s
        w = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '> ',
                style: TextStyle(color: c),
              ),
              TextSpan(text: text),
              TextSpan(
                text: '_',
                style: TextStyle(color: on ? c : Colors.transparent),
              ),
            ],
          ),
          style: base,
          textAlign: textAlign,
        );
      } else if (theme == 'retro') {
        w = Stack(
          children: [
            Transform.translate(
              offset: const Offset(3, 3),
              child: Text(
                text,
                style: base.copyWith(color: l.ink),
                textAlign: textAlign,
              ),
            ),
            Text(
              text,
              textAlign: textAlign,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = l.ink,
              ),
            ),
            Text(
              text,
              style: base.copyWith(color: c),
              textAlign: textAlign,
            ),
          ],
        );
      } else if (theme == 'luxury') {
        const g1 = Color(0xFFB8913A), g2 = Color(0xFFF6E3A1);
        final shift = t * 28 / 5 % 1; // one sweep ≈ 5 s
        w = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => LinearGradient(
            colors: const [g1, g2, g1, g2, g1, g2],
            stops: const [0, .2, .3, .5, .7, 1],
            transform: _SlideX(-shift),
            tileMode: TileMode.repeated,
          ).createShader(Rect.fromLTWH(0, 0, b.width * 2, b.height)),
          child: Text(
            text,
            style: base.copyWith(color: Colors.white),
            textAlign: textAlign,
          ),
        );
      } else {
        w = Text(text, style: base, textAlign: textAlign);
      }
      if (theme == 'polaroid') w = Transform.rotate(angle: -1.5 * math.pi / 180, child: w);
      return Padding(
        padding: EdgeInsets.only(top: l.nameTop + 8), // margin-top + the body's 8px gap
        child: w,
      );
    }

    Widget roleText() {
      final txt = '${l.rolePrefix}${l.roleUpper ? role.toUpperCase() : role}';
      final style = ts(size: l.roleSize, w: l.roleWeight, color: l.roleColor, ls: l.roleSpacing, italic: l.roleItalic);
      Widget w;
      if (l.roleAround.isNotEmpty) {
        final mark = TextStyle(color: theme == 'elegant' ? c : l.roleColor, fontStyle: FontStyle.normal, fontSize: theme == 'luxury' ? 8 : null);
        w = Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l.roleAround}  ', style: mark),
              TextSpan(text: txt),
              TextSpan(text: '  ${l.roleAround}', style: mark),
            ],
          ),
          style: style,
          textAlign: textAlign,
        );
      } else if (theme == 'tech') {
        w = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '// ',
                style: TextStyle(color: l.roleColor.withValues(alpha: .6)),
              ),
              TextSpan(text: role),
            ],
          ),
          style: style,
          textAlign: textAlign,
        );
      } else {
        w = Text(txt, style: style, textAlign: textAlign);
      }
      if (l.roleGrad != null) {
        w = ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (b) => l.roleGrad!.createShader(Offset.zero & b.size), child: w);
      }
      if (l.roleMark != null) {
        w = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, l.roleMark!, l.roleMark!],
              stops: const [0, .58, .58, 1],
            ),
          ),
          child: w,
        );
      }
      if (l.roleBg != null || l.roleBorder != null || l.rolePad != EdgeInsets.zero) {
        w = Container(
          padding: l.rolePad,
          decoration: BoxDecoration(
            color: l.roleBg,
            border: l.roleBorder,
            borderRadius: l.roleBorder is Border && (l.roleBorder as Border).left.width > 0 && l.roleBg == null ? null : BorderRadius.circular(l.roleRadius),
          ),
          child: w,
        );
      }
      return w;
    }

    // ---------------------------------------------------------------- contacts / extras / portfolio button
    Widget contactRow(NcContact x, int i) {
      final label = widget.fieldLabels[x.key] ?? x.key;
      final icRadius = l.icRadii ?? BorderRadius.circular(l.icRadius);
      Widget row = Container(
        padding: EdgeInsets.fromLTRB(l.tileLine ? 0 : 9, 9, 12, 9),
        decoration: BoxDecoration(
          color: l.tile,
          borderRadius: l.tileLine ? null : (l.tileRadii ?? BorderRadius.circular(l.tileRadius)),
          border: l.tileLine
              ? Border(
                  bottom: BorderSide(color: l.tileLineColor, width: l.tileLineWidth),
                )
              : l.tileBorder,
          boxShadow: l.tileShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: l.icGrad == null ? l.icBg : null, gradient: l.icGrad, borderRadius: icRadius, border: l.icBorder),
              alignment: Alignment.center,
              child: theme == 'neon'
                  ? DecoratedBox(
                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: c.withValues(alpha: .6), blurRadius: 6)]),
                      child: _contactIcon(x.key, l.icInk),
                    )
                  : _contactIcon(x.key, l.icInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.smallUpper ? label.toUpperCase() : label,
                    style: ts(size: 11, w: FontWeight.w700, color: l.tileInk.withValues(alpha: .65), ls: l.smallUpper ? 1.1 : 0),
                  ),
                  Text(
                    x.text,
                    style: ts(size: 14, w: FontWeight.w700, color: l.tileInk, h: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (l.tileTilt) row = Transform.rotate(angle: (i.isEven ? -0.6 : 0.6) * math.pi / 180, child: row);
      if (theme == 'aurora') {
        row = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: row),
        );
      }
      return GestureDetector(onTap: widget.onContact == null ? null : () => widget.onContact!(x), child: row);
    }

    Widget extrasBox() {
      final line = l.extrasBorder ?? l.ink.withValues(alpha: .18);
      final rows = <Widget>[];
      for (var i = 0; i < extras.length; i++) {
        final x = extras[i];
        rows.add(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: i == 0
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: l.ink.withValues(alpha: .1))),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${x['label'] ?? ''}',
                  style: ts(size: 13.5, w: FontWeight.w600, color: l.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${x['value'] ?? ''}',
                    textAlign: TextAlign.right,
                    style: ts(size: 13.5, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final box = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: rows),
      );
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: l.extrasDashed
            ? CustomPaint(painter: _DashedBox(line, l.extrasRadius), child: box)
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: line, width: l.extrasWidth),
                  borderRadius: BorderRadius.circular(l.extrasRadius),
                ),
                child: box,
              ),
      );
    }

    Widget portfolioBtn() {
      final shadow = l.btnShadow ?? [BoxShadow(color: (l.btn ?? c).withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))];
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: l.btnGrad == null ? l.btn : null,
            gradient: l.btnGrad,
            borderRadius: BorderRadius.circular(l.btnRadius),
            border: l.btnBorder,
            boxShadow: l.btn == Colors.transparent && l.btnShadow == null ? null : shadow,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.briefcaseBusiness, size: 18, color: l.btnInk),
              const SizedBox(width: 8),
              Text(
                widget.viewPortfolio,
                style: ts(size: 15, w: FontWeight.w800, color: l.btnInk, glow: l.btnGlow, ls: theme == 'luxury' ? .9 : 0),
              ),
            ],
          ),
        ),
      );
    }

    // ---------------------------------------------------------------- body
    final bodyChildren = <Widget>[
      photoBox(),
      nameText(),
      if (role.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: roleText()),
      if (s('bio').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
            s('bio'),
            textAlign: textAlign,
            style: ts(size: l.bioSize, color: l.muted, h: 1.65),
          ),
        ),
      if (contacts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(
            children: [
              for (var i = 0; i < contacts.length; i++) ...[if (i > 0) const SizedBox(height: 8), contactRow(contacts[i], i)],
            ],
          ),
        ),
      if (extras.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: extrasBox()),
      if (!compact && card['portfolio'] == true && s('slug').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: portfolioBtn()),
    ];

    // photo margin-top: -Npx → the content moves up, the body's own box (gradient / glass panel) stays under the cover
    Widget body = Padding(
      padding: l.bodyPad.copyWith(top: l.bodyPad.top + l.bodyTop),
      child: _Overlap(
        shift: l.shift,
        child: Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: bodyChildren),
      ),
    );
    if (l.bodyDeco != null) {
      body = DecoratedBox(decoration: l.bodyDeco!, child: body);
      if (l.bodyBlur) {
        body = Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: const SizedBox.expand()),
              ),
            ),
            body,
          ],
        );
      }
    }

    // the body starts where the photo overlaps the cover (photo margin-top: -Npx)
    final column = Padding(
      padding: l.outer,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [coverBox(), body, const SizedBox(height: 24)]),
    );

    // ---------------------------------------------------------------- decoration layer (premium)
    List<Widget> fx(double w) {
      switch (theme) {
        case 'aurora':
          Widget blob(Color col, double left, double top, double bw, double bh, double op, double phase) {
            final p = math.sin((t * 2 + phase) * math.pi * 2) * .5 + .5;
            return Positioned(
              left: left + 60 * p,
              top: top + 40 * p,
              child: Transform.scale(
                scale: 1 + .25 * p,
                child: Container(
                  width: bw,
                  height: bh,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        col.withValues(alpha: op),
                        col.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return [blob(c, -80, -120, 340, 340, .75, 0), blob(const Color(0xFF7C4DFF), w - 200, -60, 340, 340, .75, .36), blob(const Color(0xFF00D4B0), 30, 120, 260, 200, .4, .64)];
        case 'glass':
          Widget ball(Color col, double? left, double? right, double? top, double? bottom, double size, double phase) {
            final p = math.sin((t * 3 + phase) * math.pi * 2) * .5 + .5;
            return Positioned(
              left: left == null ? null : left + 20 * p,
              right: right == null ? null : right - 20 * p,
              top: top == null ? null : top - 30 * p,
              bottom: bottom == null ? null : bottom + 30 * p,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-0.4, -0.4), colors: [Color.lerp(col, Colors.white, .45)!, col], stops: const [0, .6]),
                ),
              ),
            );
          }
          return [ball(light, -60, null, 40, null, 200, 0), ball(const Color(0xFFFFB347), null, -40, 300, null, 150, .44), ball(const Color(0xFFFF5FA2), 40, null, null, 60, 110, .78)];
        case 'nature':
          Widget leaf(Color col, double op, {double? left, double? right, double? top, double? bottom, required double bw, required double bh}) => Positioned(
            left: left,
            right: right,
            top: top,
            bottom: bottom,
            child: Container(
              width: bw,
              height: bh,
              decoration: BoxDecoration(
                color: col.withValues(alpha: op),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(bw * .62, bh * .48),
                  topRight: Radius.elliptical(bw * .38, bh * .6),
                  bottomRight: Radius.elliptical(bw * .55, bh * .4),
                  bottomLeft: Radius.elliptical(bw * .45, bh * .52),
                ),
              ),
            ),
          );
          return [
            leaf(light, .55, top: -110, right: -90, bw: 300, bh: 260),
            leaf(c, .25, top: 60, left: -120, bw: 220, bh: 200),
            leaf(const Color(0xFFB9C99A), .45, bottom: -60, right: -50, bw: 180, bh: 180),
          ];
        case 'wave':
          return [Positioned(left: 0, right: 0, top: 120, height: 120, child: CustomPaint(painter: _Waves(t)))];
        default:
          return const [];
      }
    }

    // sunset hills sit over the cover, under the body
    final hills = theme == 'sunset'
        ? Positioned(
            left: 0,
            right: 0,
            top: 150,
            height: 80,
            child: IgnorePointer(child: CustomPaint(painter: _Hills(c, dark))),
          )
        : null;

    final radius = BorderRadius.circular(l.radius);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, minHeight: 560),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth.isFinite ? box.maxWidth : 420.0;
          Widget stacked;
          if (hills != null) {
            // cover → hills → body (body on top)
            stacked = Stack(
              children: [
                Padding(
                  padding: l.outer,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [coverBox()]),
                ),
                hills,
                Padding(
                  padding: l.outer,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: l.coverH),
                      body,
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          } else {
            stacked = column;
          }
          return Container(
            constraints: const BoxConstraints(minHeight: 560),
            decoration: BoxDecoration(color: l.bgGrad == null ? l.bg : null, gradient: l.bgGrad, borderRadius: radius, border: l.border, boxShadow: l.shadow),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  if (l.bgPaint != null) Positioned.fill(child: CustomPaint(painter: l.bgPaint)),
                  if (theme == 'neon') Positioned.fill(child: IgnorePointer(child: _InnerGlow(c))),
                  ...fx(w),
                  stacked,
                  if (theme == 'luxury')
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD9B45A).withValues(alpha: .45)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// moves the body up by `shift` (CSS negative margin) without leaving a gap below
class _Overlap extends SingleChildRenderObjectWidget {
  final double shift;
  const _Overlap({required this.shift, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverlap(shift);
  @override
  void updateRenderObject(BuildContext context, _RenderOverlap r) => r.shift = shift;
}

class _RenderOverlap extends RenderShiftedBox {
  double _shift;
  _RenderOverlap(this._shift) : super(null);
  set shift(double v) {
    if (v == _shift) return;
    _shift = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints, parentUsesSize: true);
    (c.parentData as BoxParentData).offset = Offset(0, -_shift);
    size = constraints.constrain(Size(c.size.width, math.max(0, c.size.height - _shift)));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child!;
    final off = (c.parentData as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: off,
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _InnerGlow extends StatelessWidget {
  final Color c;
  const _InnerGlow(this.c);
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(radius: 1.1, colors: [Colors.transparent, c.withValues(alpha: .18)], stops: const [.75, 1]),
    ),
  );
}

class _SlideX extends GradientTransform {
  final double f;
  const _SlideX(this.f);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * f, 0, 0);
}

// ---------------------------------------------------------------------------------------------------- painters
class _GridPaint extends CustomPainter {
  final double step;
  final Color color;
  _GridPaint(this.step, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPaint o) => o.color != color;
}

class _TechPaint extends CustomPainter {
  final Color grid;
  _TechPaint(this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    final scan = Paint()..color = Colors.white.withValues(alpha: .025);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    _GridPaint(22, grid).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_TechPaint o) => o.grid != grid;
}

class _SunsetSky extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7B3FE4), Color(0xFFE8457C), Color(0xFFFF8A3D), Color(0xFFFFC36B)],
          stops: [0, .45, .8, 1],
        ).createShader(r),
    );
    final sun = Offset(size.width / 2, size.height * .92);
    canvas.drawCircle(sun, 70, Paint()..color = const Color(0x59FFE07A));
    canvas.drawCircle(sun, 46, Paint()..color = const Color(0xFFFFE07A));
  }

  @override
  bool shouldRepaint(_SunsetSky o) => false;
}

class _Hills extends CustomPainter {
  final Color c, dark;
  _Hills(this.c, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void hill(double left, double width, double height, Paint p) {
      final rect = Rect.fromLTWH(left, h - height, width, height);
      canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: Radius.elliptical(width / 2, height / 2), topRight: Radius.elliptical(width / 2, height / 2)), p);
    }

    hill(-0.2 * w, .8 * w, 60, Paint()..color = dark.withValues(alpha: .85));
    hill(w - .9 * w + .25 * w, .9 * w, 72, Paint()..color = c.withValues(alpha: .9));
    canvas.drawRect(Rect.fromLTWH(0, h - 26, w, 26), Paint()..color = const Color(0xFFFFF8F1));
  }

  @override
  bool shouldRepaint(_Hills o) => o.c != c;
}

class _RetroStripes extends CustomPainter {
  final Color c, dark, light;
  _RetroStripes(this.c, this.dark, this.light);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 70), Paint()..color = c); // background-color shows above the stripes
    canvas.drawRect(Rect.fromLTWH(0, 70, size.width, size.height - 70), Paint()..color = const Color(0xFFFFF4DC));
    // repeating bands from y = 70: 18 gap, 12 dark, 6 gap, 12 colour, 6 gap, 12 light (66 px)
    final bands = [(18.0, 12.0, dark), (36.0, 12.0, c), (54.0, 12.0, light)];
    for (double start = 70; start < size.height; start += 66) {
      for (final (o, hgt, col) in bands) {
        canvas.drawRect(Rect.fromLTWH(0, start + o, size.width, hgt), Paint()..color = col);
      }
    }
  }

  @override
  bool shouldRepaint(_RetroStripes o) => o.c != c;
}

class _Waves extends CustomPainter {
  final double t;
  _Waves(this.t);
  Path _wave(Size s) {
    // one 800×120 tile = two card widths (M0 60c100-40 200 40 400 0s300-40 400 0v60H0z)
    final sx = s.width / 400, sy = s.height / 120;
    return Path()
      ..moveTo(0, 60 * sy)
      ..cubicTo(100 * sx, 20 * sy, 200 * sx, 100 * sy, 400 * sx, 60 * sy)
      ..cubicTo(600 * sx, 20 * sy, 700 * sx, 20 * sy, 800 * sx, 60 * sy)
      ..lineTo(800 * sx, 120 * sy)
      ..lineTo(0, 120 * sy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _wave(size);
    void layer(double speed, double op, double dy) {
      final dx = ((t * 28 / speed) % 1) * size.width;
      canvas.save();
      canvas.translate(-size.width + dx, dy);
      canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: op));
      canvas.restore();
    }

    layer(9, .08, 0);
    layer(14, .05, 14);
  }

  @override
  bool shouldRepaint(_Waves o) => o.t != t;
}

class _SplitClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height * .62)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

class _WaveClip extends CustomClipper<Path> {
  // M0 0h400v160c-50 30-100 40-150 20S120 130 70 150 20 190 0 180z  (viewBox 400×210)
  @override
  Path getClip(Size s) {
    final x = s.width / 400, y = s.height / 210;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(400 * x, 0)
      ..lineTo(400 * x, 160 * y)
      ..cubicTo(350 * x, 190 * y, 300 * x, 200 * y, 250 * x, 180 * y)
      ..cubicTo(200 * x, 160 * y, 120 * x, 130 * y, 70 * x, 150 * y)
      ..cubicTo(20 * x, 170 * y, 20 * x, 190 * y, 0, 180 * y)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

class _DashedBox extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBox(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(.5), Radius.circular(radius)));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox o) => o.color != color;
}
