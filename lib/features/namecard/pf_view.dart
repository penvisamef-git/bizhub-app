import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/ui.dart';

import '../../core/i18n.dart';
import 'nc_card.dart' show hexColor, shade;
import 'recipes_data.dart';

part 'pf_recipes.dart';

// The personal web portfolio — phone layout of the web's PortfolioView.jsx (portfolio.css + portfolio-themes.css).
// data = { theme, color ("" = card colour), files[], headline, about, skills[], experience[], education[], projects[], certifications[], languages[] }
// card = the name card (name, photo, color, job_title, company, address, email, phone1, website, telegram, slug)
const pfFreeThemes = ['classic', 'minimal', 'sidebar'];
const pfPremiumThemes = ['midnight', 'magazine', 'glass', 'terminal', 'bento', 'executive', 'corporate', 'professional', 'enterprise'];
// + the 100 recipe themes (recipes_data.dart, drawn by pf_recipes.dart)
final pfRecipeThemes = pfRecipes.keys.toList();
final pfThemes = [...pfFreeThemes, ...pfPremiumThemes, ...pfRecipeThemes];

String get _serif => defaultTargetPlatform == TargetPlatform.iOS ? 'Georgia' : 'serif';
String get _mono => defaultTargetPlatform == TargetPlatform.iOS ? 'Menlo' : 'monospace';
const _sans = 'PlusJakartaSans';
const _kh = ['KantumruyPro'];
const _gold = Color(0xFFD9B45A);
const _gray = ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0]);

class _Pf {
  // page
  Color ink = const Color(0xFF15161A), muted = const Color(0xFF646A78), line = const Color(0xFFE9EBF0), paper = Colors.white, page = const Color(0xFFF4F5F8);
  Decoration? pageDeco;
  String font = _sans;
  // hero
  Decoration? heroDeco;
  Color heroInk = Colors.white;
  bool heroFx = true; // grid + light spots
  double fxGrid = 32;
  Color fxGridColor = Colors.white.withValues(alpha: .06);
  bool left = false;
  EdgeInsets heroMargin = EdgeInsets.zero;
  double heroRadius = 0;
  Border? heroBorder;
  // photo
  BorderRadius photoRadius = BorderRadius.circular(32);
  bool photoRound = false;
  Color photoBg = Colors.white.withValues(alpha: .2);
  Color? photoInk;
  Border? photoBorder = Border.all(color: Colors.white.withValues(alpha: .85), width: 4);
  List<BoxShadow> photoShadow = const [BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 18))];
  double photoTurn = -3;
  bool photoGray = false;
  Color? photoRing;
  double photoRingGap = 0;
  // name / role
  double nameSize = 24, nameSpacing = -0.5, nameHeight = 1.15;
  FontWeight nameWeight = FontWeight.w800;
  bool nameItalic = false, nameUpper = false;
  String? nameFont;
  Gradient? nameGrad;
  Color? roleColor;
  double roleSize = 16, roleSpacing = 0;
  FontWeight roleWeight = FontWeight.w600;
  bool roleItalic = false, roleUpper = false;
  String? roleFont;
  Color? roleBg;
  // contacts
  Color pillBg = Colors.white.withValues(alpha: .16), pillLine = Colors.white.withValues(alpha: .28);
  Color? pillInk;
  double pillRadius = 999;
  bool pillUnderline = false, pillPlain = false;
  String? pillFont;
  FontWeight pillWeight = FontWeight.w700;
  // main
  double mainTop = -28, mainGap = 16;
  // sections
  double secRadius = 20, secPadV = 18, secPadH = 18;
  List<BoxShadow> secShadow = const [BoxShadow(color: Color(0x08000000), offset: Offset(0, 1)), BoxShadow(color: Color(0x0F16171B), blurRadius: 30, offset: Offset(0, 10))];
  Border? secBorder;
  bool secLine = false; // only a line under it (minimal, magazine, professional)
  bool secBlur = false;
  List<Color>? secColors; // bento pastels
  bool secDots = false; // terminal window dots
  bool icon = true;
  Color? icBg, icInk;
  Border? icBorder;
  double icSize = 34, icRadius = 11;
  double h2Size = 18;
  FontWeight h2Weight = FontWeight.w800;
  bool h2Upper = false, h2Italic = false;
  double h2Spacing = 0;
  Color? h2Color;
  String h2Prefix = '';
  bool h2Number = false; // magazine 01 02 …
  bool h2Underline = false; // corporate
  // content
  late Color soft, softInk; // chips / dates
  Border? chipBorder;
  double chipRadius = 999;
  Color? aboutInk, pInk;
  double aboutSize = 15, aboutHeight = 1.75;
  bool dropCap = false;
  double pSize = 14;
  bool timeline = true;
  Color? dotBg, dotLine, tlLine;
  BorderRadius dotRadius = BorderRadius.circular(999);
  bool dotRing = true;
  List<BoxShadow>? dotGlow;
  bool whenPlain = false;
  double projRadius = 18;
  Color? projBg, projLine;
  Color? accent; // project link icon, small, list links
  double fileRadius = 14;
  Color? fileBg;
  Border? fileBorder;
  // the shell (professional: white sheet with a top colour bar)
  bool sheet = false;
  // recipe themes (pf_recipes.dart)
  Recipe? recipe;
  bool rDark = false, rColoured = true;
  Color? rAccent, rPatColor, rPhotoB, rRing;
  String rEdge = 'flat', rPat = 'none', rPhoto = 'circle', rTl = 'dots', rChip = 'soft';
  List<Color> rConfetti = const [];
  Color? secBg; // section background (default: paper)
  Color? secLeft; // a left colour bar on each section
  Color? h2Bar; // a short bar under the title
  Color? h2Pill; // the title inside a coloured pill
  Color? numColor;
  double numSize = 12, numGap = 14;
  Color? dotRingColor;
}

_Pf _pfLook(String theme, Color c, bool km) {
  final rc = pfRecipes[theme];
  if (rc != null) {
    final l = _pfRecipeLook(rc, c, km);
    l.fileBorder ??= Border.all(color: l.line);
    return l;
  }
  final dark = shade(c, -45), light = shade(c, 55), soft = shade(c, 90);
  final l = _Pf()
    ..soft = soft
    ..softInk = dark
    ..icBg = soft
    ..icInk = dark
    ..accent = dark
    ..heroDeco = BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [dark, c, Color.lerp(c, light, .5)!], stops: const [0, .7, 1]),
    );
  switch (theme) {
    case 'minimal':
      l
        ..page = Colors.white
        ..paper = Colors.white
        ..heroDeco = BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: l.line)),
        )
        ..heroInk = l.ink
        ..heroFx = false
        ..left = true
        ..photoTurn = 0
        ..photoRound = true
        ..photoBorder = null
        ..photoShadow = const []
        ..photoBg = soft
        ..photoInk = dark
        ..nameSpacing = -0.8
        ..roleColor = c
        ..pillInk = l.ink
        ..pillBg = Colors.transparent
        ..pillLine = l.line
        ..mainTop = 0
        ..mainGap = 0
        ..secShadow = const []
        ..secRadius = 0
        ..secPadV = 26
        ..secPadH = 4
        ..secLine = true
        ..icon = false
        ..h2Size = km ? 15 : 12.5
        ..h2Upper = !km
        ..h2Spacing = km ? 0 : 1.75
        ..h2Color = c;
    case 'sidebar':
      l
        ..heroDeco = BoxDecoration(color: dark)
        ..photoRound = true
        ..photoTurn = 0;
    case 'midnight':
      l
        ..ink = const Color(0xFFEEF0F6)
        ..muted = const Color(0xFF9AA0B4)
        ..line = Colors.white.withValues(alpha: .08)
        ..paper = Colors.white.withValues(alpha: .04)
        ..page = const Color(0xFF090B12)
        ..pageDeco = _Layers([
          RadialGradient(center: const Alignment(.6, -1), radius: .7, colors: [c.withValues(alpha: .35), c.withValues(alpha: 0)]),
          RadialGradient(center: const Alignment(-1, -.4), radius: .6, colors: [const Color(0xFF7C4DFF).withValues(alpha: .18), const Color(0x007C4DFF)]),
        ], const Color(0xFF090B12))
        ..heroDeco = null
        ..fxGrid = 40
        ..fxGridColor = Colors.white.withValues(alpha: .04)
        ..photoBorder = Border.all(color: c, width: 4)
        ..photoShadow = [BoxShadow(color: c.withValues(alpha: .25), spreadRadius: 6), BoxShadow(color: c.withValues(alpha: .55), blurRadius: 50)]
        ..nameGrad = LinearGradient(colors: [Colors.white, light])
        ..pillBg = Colors.white.withValues(alpha: .06)
        ..pillLine = Colors.white.withValues(alpha: .12)
        ..secBorder = Border.all(color: Colors.white.withValues(alpha: .08))
        ..secShadow = const []
        ..secBlur = true
        ..icBg = c.withValues(alpha: .22)
        ..icInk = light
        ..soft = c.withValues(alpha: .22)
        ..softInk = light
        ..dotBg = const Color(0xFF090B12)
        ..dotRing = false
        ..dotGlow = [BoxShadow(color: c, blurRadius: 12)]
        ..aboutInk = const Color(0xFFC9CDDB)
        ..pInk = const Color(0xFFC9CDDB)
        ..accent = light;
    case 'magazine':
      const ink = Color(0xFF141210);
      l
        ..page = const Color(0xFFF6F2EA)
        ..paper = Colors.transparent
        ..ink = ink
        ..muted = const Color(0xFF6B645A)
        ..line = const Color(0xFFD9D1C3)
        ..font = _serif
        ..heroDeco = const BoxDecoration(color: Color(0xFFF6F2EA))
        ..heroBorder = const Border(bottom: BorderSide(color: ink, width: 3))
        ..heroInk = ink
        ..heroFx = false
        ..left = true
        ..photoRadius = BorderRadius.circular(2)
        ..photoBorder = null
        ..photoTurn = 0
        ..photoGray = true
        ..photoShadow = [BoxShadow(color: c, offset: const Offset(10, 10))]
        ..nameWeight = FontWeight.w400
        ..nameSize = 46
        ..nameItalic = true
        ..nameHeight = 1
        ..nameSpacing = 0
        ..roleFont = _sans
        ..roleUpper = !km
        ..roleSpacing = km ? 0 : 2.2
        ..roleSize = km ? 15 : 12.5
        ..roleColor = dark
        ..pillInk = ink
        ..pillUnderline = true
        ..pillFont = _sans
        ..mainTop = 0
        ..mainGap = 0
        ..secShadow = const []
        ..secRadius = 0
        ..secPadV = 30
        ..secPadH = 0
        ..secLine = true
        ..icon = false
        ..h2Weight = FontWeight.w400
        ..h2Size = 28
        ..h2Italic = true
        ..h2Number = true
        ..aboutSize = 18
        ..aboutHeight = 1.7
        ..dropCap = true
        ..soft = Colors.transparent
        ..softInk = ink
        ..chipBorder = Border.all(color: ink)
        ..chipRadius = 0
        ..dotRadius = BorderRadius.zero
        ..dotLine = ink
        ..dotRing = false
        ..projRadius = 0
        ..projLine = ink;
    case 'glass':
      l
        ..ink = Colors.white
        ..muted = Colors.white.withValues(alpha: .8)
        ..line = Colors.white.withValues(alpha: .25)
        ..paper = Colors.white.withValues(alpha: .14)
        ..pageDeco = _Layers(
          [
            RadialGradient(center: const Alignment(-.7, -.6), radius: .55, colors: [light, light.withValues(alpha: 0)]),
            RadialGradient(center: const Alignment(.7, -.3), radius: .5, colors: [const Color(0xFFFF5FA2), const Color(0x00FF5FA2)]),
            RadialGradient(center: const Alignment(-.4, .6), radius: .55, colors: [const Color(0xFFFFB347), const Color(0x00FFB347)]),
            RadialGradient(center: const Alignment(.8, .8), radius: .55, colors: [const Color(0xFF7C4DFF), const Color(0x007C4DFF)]),
          ],
          null,
          base: LinearGradient(begin: const Alignment(-.34, -.94), end: const Alignment(.34, .94), colors: [dark, c]),
        )
        ..heroDeco = null
        ..heroFx = false
        ..secBorder = Border.all(color: Colors.white.withValues(alpha: .3))
        ..secShadow = const [BoxShadow(color: Color(0x1F000000), blurRadius: 40, offset: Offset(0, 10))]
        ..secBlur = true
        ..icBg = Colors.white.withValues(alpha: .22)
        ..icInk = Colors.white
        ..soft = Colors.white.withValues(alpha: .22)
        ..softInk = Colors.white
        ..dotBg = Colors.transparent
        ..dotLine = Colors.white
        ..aboutInk = Colors.white.withValues(alpha: .9)
        ..pInk = Colors.white.withValues(alpha: .9)
        ..projLine = Colors.white.withValues(alpha: .3)
        ..projBg = Colors.white.withValues(alpha: .08)
        ..accent = Colors.white;
    case 'terminal':
      l
        ..ink = const Color(0xFFD6F5E3)
        ..muted = const Color(0xFF7FA591)
        ..line = const Color(0x2478FFB4)
        ..paper = const Color(0xFF0D1411)
        ..page = const Color(0xFF070B09)
        ..pageDeco = const _Scan()
        ..font = _mono
        ..heroDeco = null
        ..heroBorder = const Border(bottom: BorderSide(color: Color(0x2478FFB4)))
        ..heroFx = false
        ..left = true
        ..photoRadius = BorderRadius.circular(6)
        ..photoBorder = Border.all(color: c)
        ..photoTurn = 0
        ..photoShadow = const []
        ..photoBg = const Color(0xFF0D1411)
        ..photoInk = light
        ..nameSize = 28
        ..nameWeight = FontWeight.w700
        ..nameSpacing = 0
        ..roleColor = light
        ..roleSize = 14
        ..pillRadius = 4
        ..pillBg = Colors.transparent
        ..pillLine = const Color(0x2478FFB4)
        ..pillInk = const Color(0xFFD6F5E3)
        ..pillWeight = FontWeight.w500
        ..secBorder = Border.all(color: const Color(0x2478FFB4))
        ..secRadius = 8
        ..secShadow = const []
        ..secDots = true
        ..icon = false
        ..h2Size = 15
        ..h2Color = light
        ..h2Prefix = '#'
        ..soft = c.withValues(alpha: .18)
        ..softInk = light
        ..chipRadius = 4
        ..dotRadius = BorderRadius.circular(2)
        ..dotBg = const Color(0xFF070B09)
        ..dotRing = false
        ..aboutInk = const Color(0xFFB5D6C3)
        ..pInk = const Color(0xFFB5D6C3)
        ..aboutSize = 13.5
        ..pSize = 13.5
        ..projRadius = 6
        ..accent = light;
    case 'bento':
      l
        ..page = const Color(0xFFF3EFE6)
        ..line = Colors.black.withValues(alpha: .08)
        ..heroMargin = const EdgeInsets.fromLTRB(14, 14, 14, 0)
        ..heroRadius = 34
        ..heroDeco = BoxDecoration(color: c, borderRadius: BorderRadius.circular(34))
        ..heroFx = false
        ..photoRadius = BorderRadius.circular(28)
        ..photoTurn = 4
        ..photoBorder = Border.all(color: Colors.white, width: 4)
        ..nameSize = 30
        ..nameSpacing = -1
        ..mainTop = 14
        ..mainGap = 14
        ..secRadius = 34
        ..secShadow = const []
        ..secBorder = Border.all(color: const Color(0xFF16171B), width: 2)
        ..secColors = [soft, const Color(0xFFFFF4C2), const Color(0xFFD9F7E3), const Color(0xFFFFE0E6), const Color(0xFFE3E8FF)]
        ..h2Size = 22
        ..h2Weight = FontWeight.w900
        ..h2Spacing = -.4
        ..icRadius = 999
        ..icBg = const Color(0xFF16171B)
        ..icInk = Colors.white
        ..soft = Colors.white
        ..softInk = const Color(0xFF16171B)
        ..chipBorder = Border.all(color: const Color(0xFF16171B), width: 2)
        ..dotLine = const Color(0xFF16171B)
        ..dotRing = false
        ..tlLine = const Color(0x4016171B)
        ..projBg = Colors.white
        ..projLine = const Color(0xFF16171B)
        ..projRadius = 20
        ..fileBg = Colors.white
        ..fileBorder = Border.all(color: const Color(0xFF16171B), width: 2)
        ..fileRadius = 20;
    case 'executive':
      l
        ..ink = const Color(0xFFF3EAD3)
        ..muted = const Color(0xFFA99F86)
        ..line = _gold.withValues(alpha: .2)
        ..paper = const Color(0xFF121110)
        ..page = const Color(0xFF0B0A09)
        ..font = _serif
        ..heroDeco = const BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.2, colors: [Color(0xFF221D13), Color(0xFF0B0A09)], stops: [0, .7]),
        )
        ..heroBorder = Border(bottom: BorderSide(color: _gold.withValues(alpha: .2)))
        ..heroFx = false
        ..photoBorder = Border.all(color: _gold, width: 2)
        ..photoRound = true
        ..photoTurn = 0
        ..photoRing = _gold.withValues(alpha: .45)
        ..photoRingGap = 6
        ..photoBg = const Color(0xFF1A1712)
        ..photoInk = _gold
        ..nameWeight = FontWeight.w400
        ..nameSpacing = .7
        ..nameGrad = const LinearGradient(colors: [Color(0xFFB8913A), Color(0xFFF6E3A1), Color(0xFFB8913A)], stops: [0, .45, 1])
        ..roleColor = _gold
        ..roleItalic = true
        ..roleWeight = FontWeight.w400
        ..pillBg = Colors.transparent
        ..pillLine = _gold.withValues(alpha: .4)
        ..pillInk = const Color(0xFFF3EAD3)
        ..pillRadius = 4
        ..pillFont = _sans
        ..secBorder = Border.all(color: _gold.withValues(alpha: .2))
        ..secRadius = 6
        ..secShadow = const []
        ..h2Weight = FontWeight.w400
        ..h2Size = 22
        ..h2Spacing = .4
        ..icBg = Colors.transparent
        ..icBorder = Border.all(color: _gold.withValues(alpha: .5))
        ..icRadius = 999
        ..icInk = _gold
        ..soft = Colors.transparent
        ..softInk = _gold
        ..chipBorder = Border.all(color: _gold.withValues(alpha: .4))
        ..chipRadius = 4
        ..dotBg = const Color(0xFF0B0A09)
        ..dotLine = _gold
        ..dotRing = false
        ..aboutInk = const Color(0xFFD7CEB6)
        ..pInk = const Color(0xFFD7CEB6)
        ..projRadius = 4
        ..accent = _gold;
    case 'corporate':
      const navy = Color(0xFF0F2742);
      l
        ..page = const Color(0xFFF3F5F8)
        ..ink = const Color(0xFF0F1D2E)
        ..muted = const Color(0xFF5B6878)
        ..line = const Color(0xFFE1E6ED)
        ..heroDeco = const BoxDecoration(color: navy)
        ..heroBorder = Border(bottom: BorderSide(color: c, width: 5))
        ..heroFx = false
        ..left = true
        ..photoRadius = BorderRadius.circular(8)
        ..photoTurn = 0
        ..photoBorder = Border.all(color: Colors.white, width: 3)
        ..nameWeight = FontWeight.w700
        ..nameSpacing = -.2
        ..roleColor = light
        ..pillRadius = 6
        ..pillBg = Colors.white.withValues(alpha: .08)
        ..mainTop = 20
        ..secRadius = 8
        ..secBorder = Border.all(color: const Color(0xFFE1E6ED))
        ..secShadow = const [BoxShadow(color: Color(0x0A0F1D2E), blurRadius: 2, offset: Offset(0, 1))]
        ..h2Size = 16
        ..h2Weight = FontWeight.w700
        ..h2Underline = true
        ..icRadius = 6
        ..icSize = 30
        ..icBg = navy
        ..icInk = Colors.white
        ..soft = const Color(0xFFEEF2F7)
        ..softInk = navy
        ..chipRadius = 4
        ..dotRadius = BorderRadius.circular(2)
        ..dotLine = navy
        ..dotRing = false
        ..projRadius = 6
        ..fileRadius = 6;
    case 'professional':
      l
        ..page = const Color(0xFFE9EBEF)
        ..paper = Colors.transparent
        ..ink = const Color(0xFF1D232C)
        ..muted = const Color(0xFF5D6673)
        ..line = const Color(0xFFE3E6EA)
        ..sheet = true
        ..heroDeco = const BoxDecoration(color: Colors.white)
        ..heroBorder = const Border(bottom: BorderSide(color: Color(0xFFE3E6EA)))
        ..heroInk = const Color(0xFF1D232C)
        ..heroFx = false
        ..left = true
        ..photoRound = true
        ..photoTurn = 0
        ..photoBorder = null
        ..photoShadow = const []
        ..photoBg = soft
        ..photoInk = dark
        ..nameFont = _serif
        ..nameWeight = FontWeight.w700
        ..nameUpper = !km
        ..nameSpacing = km ? 0 : 1.7
        ..roleColor = dark
        ..pillPlain = true
        ..pillInk = const Color(0xFF5D6673)
        ..mainTop = 0
        ..mainGap = 0
        ..secShadow = const []
        ..secRadius = 0
        ..secPadV = 22
        ..secPadH = 4
        ..secLine = true
        ..icon = false
        ..h2Size = km ? 15 : 13
        ..h2Upper = !km
        ..h2Spacing = km ? 0 : 2
        ..h2Color = dark
        ..timeline = false
        ..whenPlain = true
        ..soft = Colors.transparent
        ..softInk = const Color(0xFF1D232C)
        ..chipBorder = Border.all(color: const Color(0xFFE3E6EA))
        ..chipRadius = 4;
    case 'enterprise':
      const slate = Color(0xFF1F2A37);
      l
        ..page = const Color(0xFFECEFF3)
        ..ink = const Color(0xFF1B2430)
        ..muted = const Color(0xFF5F6B7A)
        ..line = const Color(0xFFDDE2E8)
        ..heroDeco = const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [slate, Color(0xFF2C3A4B)]),
        )
        ..heroFx = false
        ..photoRadius = BorderRadius.circular(14)
        ..photoTurn = 0
        ..photoBorder = Border.all(color: c, width: 3)
        ..roleBg = c
        ..roleSize = 14
        ..pillRadius = 4
        ..secRadius = 10
        ..secShadow = const []
        ..secBorder = Border(
          left: BorderSide(color: c, width: 5),
          top: const BorderSide(color: Color(0xFFDDE2E8)),
          right: const BorderSide(color: Color(0xFFDDE2E8)),
          bottom: const BorderSide(color: Color(0xFFDDE2E8)),
        )
        ..h2Size = km ? 15 : 13
        ..h2Upper = !km
        ..h2Spacing = km ? 0 : 1.6
        ..h2Color = const Color(0xFF5F6B7A)
        ..icRadius = 8
        ..icBg = slate
        ..icInk = Colors.white
        ..soft = slate
        ..softInk = Colors.white
        ..chipRadius = 4
        ..dotRadius = BorderRadius.circular(3)
        ..dotRing = false
        ..projRadius = 8
        ..fileRadius = 8;
  }
  l.photoInk ??= l.heroInk;
  l.dotLine ??= c;
  l.dotBg ??= Colors.white;
  l.tlLine ??= l.line;
  l.projLine ??= l.line;
  l.fileBg ??= soft;
  l.fileBorder ??= Border.all(color: l.line);
  l.aboutInk ??= theme == 'classic' || theme == 'sidebar' || theme == 'minimal' || theme == 'bento' ? const Color(0xFF2F333C) : l.ink;
  l.pInk ??= theme == 'classic' || theme == 'sidebar' || theme == 'minimal' || theme == 'bento' ? const Color(0xFF3A3F4A) : l.ink;
  return l;
}

// several gradients on top of each other (CSS background with many layers)
class _Layers extends Decoration {
  final List<Gradient> layers;
  final Color? color;
  final Gradient? base;
  final bool box; // radial layers sized to the box (not the first screen)
  final Color? stripes; // repeating 45° stripes 10 px on / 12 px off (recipe "stripe" hero)
  const _Layers(this.layers, this.color, {this.base, this.box = false, this.stripes});
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _LayersPainter(this);
}

class _LayersPainter extends BoxPainter {
  final _Layers d;
  _LayersPainter(this.d);
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final r = offset & (cfg.size ?? Size.zero);
    if (d.color != null) canvas.drawRect(r, Paint()..color = d.color!);
    if (d.base != null) canvas.drawRect(r, Paint()..shader = d.base!.createShader(r));
    // radial layers sized to the first screen, like background-attachment: fixed
    final view = d.box ? r : Rect.fromLTWH(r.left, r.top, r.width, r.width * 2.1);
    for (final g in d.layers) {
      canvas.drawRect(r, Paint()..shader = g.createShader(view));
    }
    if (d.stripes != null) {
      canvas.save();
      canvas.clipRect(r);
      final p = Paint()
        ..color = d.stripes!
        ..strokeWidth = 10;
      for (double x = -r.height; x < r.width + r.height; x += 22 * 1.414) {
        final o = r.topLeft + Offset(x, 0);
        canvas.drawLine(o + const Offset(0, 0), o + Offset(r.height, r.height), p);
      }
      canvas.restore();
    }
  }
}

class _Scan extends Decoration {
  const _Scan();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _ScanPainter();
}

class _ScanPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size ?? Size.zero;
    canvas.drawRect(offset & size, Paint()..color = const Color(0xFF070B09));
    final p = Paint()..color = Colors.white.withValues(alpha: .02);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy + y, size.width, 1), p);
    }
  }
}

String _initial(String? name) {
  final s = (name ?? '').trim();
  return s.isEmpty ? '?' : String.fromCharCodes(s.runes.take(1)).toUpperCase();
}

String _host(String v) => v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/$'), '');

class PfView extends StatefulWidget {
  final Map data;
  final Map card;
  final T t;
  final bool preview; // editor: show the "write something" hint when empty
  final void Function(String url)? onLink;
  const PfView({super.key, required this.data, required this.card, required this.t, this.preview = true, this.onLink});
  @override
  State<PfView> createState() => _PfViewState();
}

class _PfViewState extends State<PfView> with SingleTickerProviderStateMixin {
  AnimationController? _blink;

  String get _theme => pfThemes.contains(widget.data['theme']) ? '${widget.data['theme']}' : 'classic';

  void _sync() {
    if (_theme == 'terminal' && _blink == null) {
      _blink = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    } else if (_theme != 'terminal' && _blink != null) {
      _blink!.dispose();
      _blink = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PfView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _blink?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _blink;
    if (b == null) return _build(context, true);
    return AnimatedBuilder(animation: b, builder: (ctx, _) => _build(ctx, b.value < .5));
  }

  Widget _build(BuildContext context, bool cursorOn) {
    final data = widget.data, card = widget.card, t = widget.t;
    final theme = _theme;
    String s(Map m, String k) => '${m[k] ?? ''}'.trim();
    final colorHex = s(data, 'color').isNotEmpty ? s(data, 'color') : s(card, 'color');
    final c = hexColor(colorHex);
    final l = _pfLook(theme, c, t.km);
    List<Map> rows(String k) => ((data[k] as List?) ?? const []).whereType<Map>().toList();
    final skills = ((data['skills'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    final files = rows('files');
    bool has(String k) => k == 'skills' ? skills.isNotEmpty : rows(k).isNotEmpty;
    final role = s(data, 'headline').isNotEmpty ? s(data, 'headline') : [s(card, 'job_title'), s(card, 'company')].where((x) => x.isNotEmpty).join(' · ');
    final empty = s(data, 'about').isEmpty && !['experience', 'education', 'skills', 'projects', 'certifications', 'languages', 'files'].any(has);

    TextStyle ts({double size = 14, FontWeight w = FontWeight.w400, Color? color, double? h, double ls = 0, String? font, bool italic = false}) => TextStyle(
      fontFamily: font ?? l.font,
      fontFamilyFallback: _kh,
      fontSize: size,
      fontWeight: w,
      color: color ?? l.ink,
      height: h,
      letterSpacing: ls,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
    final cross = l.left ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final align = l.left ? TextAlign.left : TextAlign.center;

    // ---------------------------------------------------------------- hero
    Widget photo() {
      const size = 92.0;
      final inner = s(card, 'photo').isNotEmpty
          ? Image(image: netImage(s(card, 'photo')), fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, _, _) => const SizedBox.shrink())
          : Center(
              child: Text(
                _initial(s(card, 'name')),
                style: ts(size: 36, w: FontWeight.w800, color: l.photoInk, font: _sans),
              ),
            );
      if (l.recipe != null) {
        final full = s(card, 'photo').isNotEmpty
            ? Image(image: netImage(s(card, 'photo')), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink())
            : Center(
                child: Text(
                  _initial(s(card, 'name')),
                  style: ts(size: 36, w: FontWeight.w800, color: l.photoInk, font: _sans),
                ),
              );
        return _rPhotoBox(l, full);
      }
      final radius = l.photoRound ? BorderRadius.circular(size) : l.photoRadius;
      Widget p = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: l.photoBg, borderRadius: radius, border: l.photoBorder, boxShadow: l.photoShadow),
        child: ClipRRect(
          borderRadius: radius,
          child: l.photoGray && s(card, 'photo').isNotEmpty ? ColorFiltered(colorFilter: _gray, child: inner) : inner,
        ),
      );
      if (l.photoRing != null) {
        final g = l.photoRingGap + 1;
        p = SizedBox(
          width: size,
          height: size,
          child: OverflowBox(
            maxWidth: size + g * 2 + 2,
            maxHeight: size + g * 2 + 2,
            child: Container(
              padding: EdgeInsets.all(g),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: l.photoRing!),
              ),
              child: p,
            ),
          ),
        );
      }
      if (l.photoTurn != 0) p = Transform.rotate(angle: l.photoTurn * 3.14159 / 180, child: p);
      return p;
    }

    Widget name() {
      var text = s(card, 'name').isEmpty ? 'Your name' : s(card, 'name');
      if (l.nameUpper) text = text.toUpperCase();
      final style = ts(size: l.nameSize, w: l.nameWeight, h: l.nameHeight, ls: l.nameSpacing, color: l.heroInk, italic: l.nameItalic, font: l.nameFont);
      Widget w;
      if (theme == 'terminal') {
        w = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '~\$ whoami',
              style: ts(size: 13, w: FontWeight.w500, color: l.muted),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  TextSpan(
                    text: '_',
                    style: TextStyle(color: cursorOn ? c : Colors.transparent),
                  ),
                ],
              ),
              style: style.copyWith(color: l.ink),
            ),
          ],
        );
      } else {
        w = Text(text, style: style, textAlign: align);
      }
      if (l.nameGrad != null) w = ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (r) => l.nameGrad!.createShader(Offset.zero & r.size), child: w);
      return w;
    }

    Widget roleText() {
      final txt = l.roleUpper ? role.toUpperCase() : role;
      final style = ts(
        size: l.roleSize,
        w: l.roleWeight,
        ls: l.roleSpacing,
        italic: l.roleItalic,
        font: l.roleFont,
        color: l.roleBg != null ? Colors.white : (l.roleColor ?? l.heroInk.withValues(alpha: .92)),
      );
      Widget w = theme == 'terminal'
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '// ',
                    style: TextStyle(color: l.roleColor!.withValues(alpha: .6)),
                  ),
                  TextSpan(text: role),
                ],
              ),
              style: style,
            )
          : Text(txt, style: style, textAlign: align);
      if (l.roleBg != null) {
        w = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(color: l.roleBg, borderRadius: BorderRadius.circular(4)),
          child: w,
        );
      }
      return Padding(padding: const EdgeInsets.only(top: 8), child: w);
    }

    Widget contacts() {
      final list = <(IconData, String, String)>[
        if (s(card, 'email').isNotEmpty) (LucideIcons.mail, 'mailto:${s(card, 'email')}', s(card, 'email')),
        if (s(card, 'phone1').isNotEmpty) (LucideIcons.phone, 'tel:${s(card, 'phone1').replaceAll(RegExp(r'[^\d+]'), '')}', s(card, 'phone1')),
        if (s(card, 'website').isNotEmpty) (LucideIcons.globe, s(card, 'website'), _host(s(card, 'website'))),
        if (s(card, 'telegram').isNotEmpty) (LucideIcons.send, 'https://t.me/${s(card, 'telegram').replaceFirst('@', '')}', s(card, 'telegram')),
      ];
      if (list.isEmpty) return const SizedBox.shrink();
      final ink = l.pillInk ?? Colors.white;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(
          alignment: l.left ? WrapAlignment.start : WrapAlignment.center,
          spacing: l.pillPlain ? 16 : 8,
          runSpacing: l.pillPlain ? 4 : 8,
          children: [
            for (final (icon, href, text) in list)
              GestureDetector(
                onTap: widget.onLink == null ? null : () => widget.onLink!(href),
                child: Container(
                  padding: l.pillPlain
                      ? const EdgeInsets.symmetric(vertical: 2)
                      : (l.pillUnderline ? const EdgeInsets.symmetric(horizontal: 2, vertical: 4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  decoration: l.pillPlain
                      ? null
                      : l.pillUnderline
                      ? BoxDecoration(
                          border: Border(bottom: BorderSide(color: ink)),
                        )
                      : BoxDecoration(
                          color: l.pillBg,
                          borderRadius: BorderRadius.circular(l.pillRadius),
                          border: Border.all(color: l.pillLine),
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: ink),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style: ts(size: 13.5, w: l.pillPlain ? FontWeight.w600 : l.pillWeight, color: ink, font: l.pillFont),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final heroIn = Padding(
      padding: EdgeInsets.fromLTRB(16, 28, 16, (l.mainTop < 0 ? 46 : (theme == 'professional' ? 28 : 46)) + (_rHeroEdge[l.rEdge] ?? 0)),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          photo(),
          const SizedBox(height: 18),
          name(),
          if (role.isNotEmpty) roleText(),
          if (s(card, 'address').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.mapPin, size: 14, color: l.heroInk.withValues(alpha: .85)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(s(card, 'address'), style: ts(size: 13.5, color: l.heroInk.withValues(alpha: .85))),
                  ),
                ],
              ),
            ),
          contacts(),
        ],
      ),
    );

    Widget hero = Container(
      width: double.infinity,
      margin: l.heroMargin,
      foregroundDecoration: l.heroBorder == null ? null : BoxDecoration(border: l.heroBorder),
      decoration: l.heroDeco,
      clipBehavior: l.heroRadius > 0 ? Clip.antiAlias : Clip.none,
      child: Stack(
        children: [
          if (l.recipe != null && l.rPat != 'none')
            Positioned.fill(
              child: CustomPaint(painter: _RPat(l.rPat, l.rPatColor!, l.rConfetti)),
            ),
          if (l.heroFx)
            Positioned.fill(
              child: _HeroFx(grid: l.fxGrid, color: l.fxGridColor, spots: theme != 'midnight'),
            ),
          if (theme == 'bento') ...[
            Positioned(
              right: -70,
              top: -70,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(color: Color(0xFFFFD54A), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: -120,
              bottom: -120,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle),
              ),
            ),
          ],
          if (theme == 'enterprise') ...[const Positioned.fill(child: CustomPaint(painter: _Stripes())), Positioned(left: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: c))],
          heroIn,
        ],
      ),
    );

    final edge = _rHeroEdge[l.rEdge] ?? 0;
    if (l.recipe != null && edge > 0) hero = ClipPath(clipper: _REdgeClip(l.rEdge, edge), child: hero);

    // ---------------------------------------------------------------- sections
    var secIndex = 0;
    Widget section(IconData icon, String title, Widget body, {int? pastel}) {
      final n = ++secIndex;
      final bg = l.secColors != null ? l.secColors![((pastel ?? n) - 1) % 5] : (l.secBg ?? l.paper);
      final h2Style = ts(size: l.h2Size, w: l.h2Weight, color: l.h2Color ?? l.ink, ls: l.h2Spacing, italic: l.h2Italic);
      Widget head = Row(
        children: [
          if (l.icon) ...[
            Container(
              width: l.icSize,
              height: l.icSize,
              decoration: BoxDecoration(color: l.icBg, borderRadius: BorderRadius.circular(l.icRadius), border: l.icBorder),
              child: Icon(icon, size: 18, color: l.icInk),
            ),
            const SizedBox(width: 10),
          ],
          if (l.h2Number) ...[
            Text(
              n.toString().padLeft(2, '0'),
              style: ts(size: l.numSize, w: FontWeight.w800, color: l.numColor ?? c, font: l.recipe != null ? null : _sans),
            ),
            SizedBox(width: l.numGap),
          ],
          if (l.h2Prefix.isNotEmpty) ...[Text(l.h2Prefix, style: h2Style.copyWith(color: l.muted)), const SizedBox(width: 10)],
          Expanded(child: Text(l.h2Upper ? title.toUpperCase() : title, style: h2Style)),
        ],
      );
      if (l.h2Pill != null) {
        head = Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: l.h2Pill, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(title, style: ts(size: 13, w: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      }
      if (l.h2Bar != null) {
        head = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: l.h2Bar, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        );
      }
      if (l.h2Underline) {
        head = Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: l.line)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              head,
              Positioned(left: 0, bottom: -13, width: 48, height: 3, child: ColoredBox(color: c)),
            ],
          ),
        );
      }
      Widget inside = Padding(
        padding: EdgeInsets.fromLTRB(l.secPadH + (l.secLeft != null ? 5 : 0), l.secDots ? 44 : l.secPadV, l.secPadH, l.secPadV),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (l.secDots)
              const Positioned(left: 0, top: -28, child: Row(children: [_Dot(Color(0xFFFF5F57)), SizedBox(width: 6), _Dot(Color(0xFFFEBC2E)), SizedBox(width: 6), _Dot(Color(0xFF28C840))])),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, const SizedBox(height: 16), body]),
          ],
        ),
      );
      if (l.secLeft != null) {
        inside = Stack(
          children: [
            inside,
            Positioned(left: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: l.secLeft!)),
          ],
        );
      }
      Widget box = Container(
        width: double.infinity,
        clipBehavior: l.secLeft != null ? Clip.antiAlias : Clip.none,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: l.secLine ? null : BorderRadius.circular(l.secRadius),
          border: l.secLine ? Border(bottom: BorderSide(color: l.line)) : l.secBorder,
          boxShadow: l.secShadow,
        ),
        child: inside,
      );
      if (l.secBlur) {
        box = ClipRRect(
          borderRadius: BorderRadius.circular(l.secRadius),
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: box),
        );
      }
      return box;
    }

    Widget pill(String text) => l.recipe != null
        ? _rChip(l, c, text, ts(size: 13.5, w: FontWeight.w700))
        : Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: l.soft, borderRadius: BorderRadius.circular(l.chipRadius), border: l.chipBorder),
      child: Text(
        text,
        style: ts(size: 13.5, w: theme == 'terminal' ? FontWeight.w500 : FontWeight.w700, color: l.softInk, font: theme == 'magazine' || theme == 'executive' ? _sans : null),
      ),
    );

    Widget when(String text) => l.whenPlain
        ? Text(
            text,
            style: ts(size: 12.5, w: FontWeight.w600, color: l.muted),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: l.soft, borderRadius: BorderRadius.circular(l.chipRadius), border: l.chipBorder),
            child: Text(
              text,
              style: ts(size: 12.5, w: theme == 'terminal' ? FontWeight.w500 : FontWeight.w700, color: l.softInk, font: theme == 'magazine' || theme == 'executive' ? _sans : null),
            ),
          );

    Widget timeline(List<Map> list, String main, String Function(Map) sub) {
      final items = <Widget>[];
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        final last = i == list.length - 1;
        final period = [s(r, 'start'), r['current'] == true ? t('pf.present') : s(r, 'end')].where((x) => x.isNotEmpty).join(' – ');
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(s(r, main), style: ts(size: 15.5, w: FontWeight.w800)),
                  if (period.isNotEmpty) when(period),
                ],
              ),
            ),
            if (sub(r).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  sub(r),
                  style: ts(size: 14, w: FontWeight.w600, color: l.muted),
                ),
              ),
            if (s(r, 'description').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s(r, 'description'),
                  style: ts(size: l.pSize, color: l.pInk, h: 1.65),
                ),
              ),
          ],
        );
        if (l.recipe != null && l.rTl == 'bars') {
          items.add(
            Container(
              margin: EdgeInsets.only(bottom: last ? 0 : 18),
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c, width: 3)),
              ),
              child: content,
            ),
          );
          continue;
        }
        if (l.recipe != null && l.rTl == 'cards') {
          items.add(
            Container(
              margin: EdgeInsets.only(bottom: last ? 0 : 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: l.ink.withValues(alpha: .04), borderRadius: BorderRadius.circular(14)),
              child: content,
            ),
          );
          continue;
        }
        if (!l.timeline) {
          items.add(
            Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20),
              child: content,
            ),
          );
          continue;
        }
        items.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Stack(
                    children: [
                      if (!last) Positioned(left: 6, top: 16, bottom: 0, width: 2, child: ColoredBox(color: l.tlLine!)),
                      Positioned(
                        left: 0,
                        top: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: l.dotBg,
                            borderRadius: l.dotRadius,
                            border: Border.all(color: l.dotLine!, width: 3),
                            boxShadow: l.dotGlow ?? (l.dotRing ? [BoxShadow(color: l.dotRingColor ?? l.soft, spreadRadius: 4)] : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 20),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
    }

    Widget listRows(List<Widget> children) => Column(
      children: [
        for (var i = 0; i < children.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: i == 0
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: l.line)),
                  ),
            child: children[i],
          ),
      ],
    );

    final sections = <Widget>[];
    if (empty && widget.preview) {
      sections.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          decoration: BoxDecoration(
            color: l.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: l.line, width: 2),
          ),
          child: Text(
            t('pf.aboutPh'),
            textAlign: TextAlign.center,
            style: ts(size: 14, color: l.muted),
          ),
        ),
      );
    }
    if (s(data, 'about').isNotEmpty) {
      final about = s(data, 'about');
      sections.add(
        section(
          LucideIcons.userRound,
          t('pf.about'),
          l.dropCap
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: String.fromCharCodes(about.runes.take(1)),
                        style: TextStyle(fontSize: 58, height: .9, color: c),
                      ),
                      TextSpan(text: String.fromCharCodes(about.runes.skip(1))),
                    ],
                  ),
                  style: ts(size: l.aboutSize, color: l.aboutInk, h: l.aboutHeight),
                )
              : Text(
                  about,
                  style: ts(size: l.aboutSize, color: l.aboutInk, h: l.aboutHeight),
                ),
        ),
      );
    }
    if (has('experience')) {
      sections.add(
        section(LucideIcons.briefcaseBusiness, t('pf.experience'), timeline(rows('experience'), 'title', (r) => [s(r, 'company'), s(r, 'location')].where((x) => x.isNotEmpty).join(' · '))),
      );
    }
    if (has('education')) {
      sections.add(section(LucideIcons.graduationCap, t('pf.education'), timeline(rows('education'), 'school', (r) => [s(r, 'degree'), s(r, 'field')].where((x) => x.isNotEmpty).join(' · '))));
    }
    if (has('skills')) {
      sections.add(section(LucideIcons.sparkles, t('pf.skills'), Wrap(spacing: 8, runSpacing: 8, children: [for (final x in skills) pill(x)])));
    }
    if (has('projects')) {
      sections.add(
        section(
          LucideIcons.globe,
          t('pf.projects'),
          Column(
            children: [
              for (final p in rows('projects'))
                GestureDetector(
                  onTap: s(p, 'link').isEmpty || widget.onLink == null ? null : () => widget.onLink!(s(p, 'link')),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: l.projBg,
                      borderRadius: BorderRadius.circular(l.projRadius),
                      border: Border.all(color: l.projLine!, width: theme == 'bento' ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(s(p, 'title'), style: ts(size: 15, w: FontWeight.w700)),
                            ),
                            if (s(p, 'link').isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(LucideIcons.externalLink, size: 14, color: theme == 'classic' || theme == 'sidebar' || theme == 'minimal' ? c : l.accent),
                            ],
                          ],
                        ),
                        if (s(p, 'description').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(s(p, 'description'), style: ts(size: 13.5, color: theme == 'glass' || theme == 'terminal' || theme == 'executive' ? l.pInk : l.muted, h: 1.6)),
                          ),
                        if (s(p, 'link').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _host(s(p, 'link')),
                              style: ts(size: 12, w: FontWeight.w700, color: l.accent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // certificates + languages: their own count for the bento colours (they sit in .pf-two on the web)
    var twoIndex = 0;
    if (has('certifications')) {
      sections.add(
        section(
          LucideIcons.award,
          t('pf.certifications'),
          listRows([
            for (final x in rows('certifications'))
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: s(x, 'link').isEmpty || widget.onLink == null ? null : () => widget.onLink!(s(x, 'link')),
                          child: Text(
                            s(x, 'name'),
                            style: ts(
                              size: 14,
                              w: s(x, 'link').isNotEmpty ? FontWeight.w800 : FontWeight.w700,
                              color: s(x, 'link').isNotEmpty ? l.accent : l.ink,
                            ).copyWith(decoration: s(x, 'link').isNotEmpty ? TextDecoration.underline : null, decorationColor: l.accent),
                          ),
                        ),
                        if (s(x, 'issuer').isNotEmpty) Text(s(x, 'issuer'), style: ts(size: 12.5, color: l.muted)),
                      ],
                    ),
                  ),
                  if (s(x, 'year').isNotEmpty)
                    Text(
                      s(x, 'year'),
                      style: ts(size: 12.5, w: FontWeight.w700, color: l.muted),
                    ),
                ],
              ),
          ]),
          pastel: ++twoIndex,
        ),
      );
      secIndex--; // not counted with the main list (CSS nth-of-type inside .pf-two)
    }
    if (has('languages')) {
      sections.add(
        section(
          LucideIcons.languages,
          t('pf.languages'),
          listRows([
            for (final x in rows('languages'))
              Row(
                children: [
                  Expanded(
                    child: Text(s(x, 'name'), style: ts(size: 14, w: FontWeight.w700)),
                  ),
                  if (s(x, 'level').isNotEmpty)
                    Text(
                      s(x, 'level'),
                      style: ts(size: 12.5, w: FontWeight.w700, color: l.muted),
                    ),
                ],
              ),
          ]),
          pastel: ++twoIndex,
        ),
      );
      secIndex--;
    }
    if (files.isNotEmpty) {
      sections.add(
        section(
          LucideIcons.folderOpen,
          t('pf.documents'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .98,
            children: [
              for (final f in files)
                GestureDetector(
                  onTap: widget.onLink == null || s(f, 'url').isEmpty ? null : () => widget.onLink!(s(f, 'url')),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          decoration: BoxDecoration(color: l.fileBg, borderRadius: BorderRadius.circular(l.fileRadius), border: l.fileBorder),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              s(f, 'thumb').isNotEmpty
                                  ? Image(image: netImage(
                                      s(f, 'thumb')),
                                      fit: BoxFit.cover,
                                      alignment: s(f, 'kind') == 'pdf' ? Alignment.topCenter : Alignment.center,
                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                    )
                                  : Icon(LucideIcons.fileText, size: 28, color: shade(c, -45)),
                              if (s(f, 'kind') == 'pdf')
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFD93025), borderRadius: BorderRadius.circular(6)),
                                    child: const Text(
                                      'PDF',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s(f, 'title').isNotEmpty ? s(f, 'title') : (s(f, 'kind') == 'pdf' ? 'PDF' : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(size: 13.5, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          pastel: secIndex + 1,
        ),
      );
    }

    final mainCol = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[if (i > 0) SizedBox(height: l.mainGap), sections[i]],
        ],
      ),
    );

    Widget shell = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        if (l.mainTop < 0) _Up(by: -l.mainTop, child: mainCol) else ...[SizedBox(height: l.mainTop), mainCol],
      ],
    );
    if (l.sheet) {
      shell = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: c, width: 8)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 60, offset: Offset(0, 20))],
        ),
        child: shell,
      );
    }
    return DecoratedBox(
      decoration: l.pageDeco ?? BoxDecoration(color: l.page),
      child: shell,
    );
  }
}

// moves the sections up over the hero (margin-top: -28px)
class _Up extends StatelessWidget {
  final double by;
  final Widget child;
  const _Up({required this.by, required this.child});
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, -by),
    child: Padding(padding: EdgeInsets.only(bottom: 0), child: child),
  );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _HeroFx extends StatelessWidget {
  final double grid;
  final Color color;
  final bool spots;
  const _HeroFx({required this.grid, required this.color, required this.spots});
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.transparent], stops: [.4, 1]).createShader(r),
    child: CustomPaint(painter: _FxPaint(grid, color, spots), size: Size.infinite),
  );
}

class _FxPaint extends CustomPainter {
  final double grid;
  final Color color;
  final bool spots;
  _FxPaint(this.grid, this.color, this.spots);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (spots) {
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(.7, -.8),
            radius: .4,
            colors: [Colors.white.withValues(alpha: .22), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.width)),
      );
      canvas.drawRect(
        r,
        Paint()..shader = RadialGradient(center: const Alignment(-.8, 1.2), radius: .5, colors: [Colors.black.withValues(alpha: .25), Colors.black.withValues(alpha: 0)]).createShader(r),
      );
    }
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += grid) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    for (double y = 0; y < size.height; y += grid) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_FxPaint o) => o.color != color || o.grid != grid;
}

class _Stripes extends CustomPainter {
  const _Stripes();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 12 / 1.414;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double d = -size.height; d < size.width + size.height; d += 24 * 1.414) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Stripes o) => false;
}
