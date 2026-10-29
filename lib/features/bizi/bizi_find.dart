// Bizi in the app (v3.0.0): the search that needs no server — the same rules as the website
// (bizhub/src/dashboard/bizi/smart.js + help-find.js), so a word finds the same thing on the phone and the web.
//   biziT(lang, 'ph')                 → a Bizi text (EN / KM, from the web's bizi/text.js)
//   findHelp('how do I pair a POS?')  → the how-tos, best first
//   findPages(businesses, 'delivery') → the sections of my businesses whose names (or more words) have the words
import 'bizi_data.dart';

typedef Biz = Map<String, dynamic>;

// ---------------------------------------------------------------- the words
String biziT(String lang, String key, [Map<String, Object?> vars = const {}]) {
  Object? v = _text(lang);
  for (final k in key.split('.')) {
    v = v is Map ? v[k] : null;
  }
  if (v is! String) {
    if (lang != 'en') return biziT('en', key, vars);
    return key;
  }
  var s = v;
  vars.forEach((k, x) => s = s.replaceAll('{$k}', '${x ?? ''}'));
  return s;
}

// a list of words (the day names)
List<String> biziList(String lang, String key) {
  final v = _text(lang)[key] ?? _text('en')[key];
  return v is List ? v.map((e) => '$e').toList() : const [];
}

// is there a text for this key in this language (no English stand-in)?
bool biziHas(String lang, String key) {
  Object? v = _text(lang);
  for (final k in key.split('.')) {
    v = v is Map ? v[k] : null;
  }
  return v is String;
}

Map _text(String lang) => (biziData['text'] as Map)[lang] as Map? ?? (biziData['text'] as Map)['en'] as Map;

// ---------------------------------------------------------------- small typing mistakes
// one small typing mistake (a letter missing, extra, wrong or swapped)
bool near(String a, String b) {
  if (a == b) return true;
  if ((a.length - b.length).abs() > 1 || a.length < 4) return false;
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  String from(String s, int n) => n >= s.length ? '' : s.substring(n);
  return from(a, i + 1) == from(b, i + 1) ||
      from(a, i) == from(b, i + 1) ||
      from(a, i + 1) == from(b, i) ||
      (i + 1 < a.length && i + 1 < b.length && a[i] == b[i + 1] && a[i + 1] == b[i] && from(a, i + 2) == from(b, i + 2));
}

final _splitter = RegExp(r'[\s·,/&()\-]+');

// does the word appear in the text (inside a word = 2, or one mistake away from a whole word = 1)?
int hit(String word, String text, {bool fuzzy = true}) {
  if (text.contains(word)) return 2;
  if (!fuzzy || word.length < 4) return 0;
  return text.split(_splitter).any((t) => near(word, t)) ? 1 : 0;
}

List<String> words(String q) => q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

// ---------------------------------------------------------------- how-tos
class HelpHit {
  final Map a;
  final int score;
  const HelpHit(this.a, this.score);
  String get id => '${a['id']}';
  String q(String lang) => '${(a[lang] as Map?)?['q'] ?? (a['en'] as Map)['q']}';
  String open(String lang) => '${(a[lang] as Map?)?['open'] ?? ''}';
  List<String> steps(String lang) => (((a[lang] as Map?)?['steps'] ?? (a['en'] as Map)['steps']) as List).map((e) => '$e').toList();
}

List<Map> get helpList => (biziData['help'] as List).cast<Map>();

const _stop = {
  'how', 'do', 'does', 'did', 'i', 'we', 'you', 'to', 'a', 'an', 'the', 'my', 'our', 'can', 'could', 'should', 'where', 'what', 'which', 'when', 'why', 'is', 'are', 'am', 'it', 'its', 'in', 'on', //
  'at', 'for', 'of', 'with', 'from', 'be', 'get', 'make', 'use', 'using', 'want', 'need', 'please', 'help', 'me', 'there', 'this', 'that', 'any', 'some', 'way',
};
const _kmAsk = ['ដោយរបៀបណា', 'យ៉ាងដូចម្តេច', 'យ៉ាងម៉េច', 'ធ្វើម៉េច', 'ធ្វើយ៉ាងណា', 'នៅឯណា', 'នៅណា', 'របៀប', 'តើ', 'ខ្ញុំ', 'ចង់', 'អាច', 'បានទេ', 'ដើម្បី', 'យ៉ាងណា', '?', '？'];
final _question = RegExp(r'^(how|where|what|can|could|why|when|which|is|do|does|help)\b|\?\s*$|ធ្វើម៉េច|យ៉ាងម៉េច|របៀប|តើ|ដោយរបៀបណា|យ៉ាងដូចម្តេច|នៅឯណា', caseSensitive: false);
final _km = RegExp('[ក-៿]');
final _wordChars = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

// does the text look like a question? (then the answers go first)
bool isQuestion(String q) => _question.hasMatch(q.trim());
bool _isKm(String w) => _km.hasMatch(w);

String _textOf(Map a) => '${(a['en'] as Map)['q']} ${(a['km'] as Map)['q']} ${a['words']}'.toLowerCase();
List<String> _kmWords(Map a) => '${(a['km'] as Map)['q']} ${a['words']}'.split(RegExp(r'[\s·,/()?]+')).where((w) => _isKm(w) && w.length >= 2 && !_kmAsk.contains(w)).toList();

// the how-tos for the words, best first
List<HelpHit> findHelp(String raw, {int max = 3}) {
  final q = raw.toLowerCase().trim();
  if (q.length < 2) return const [];
  var rest = q;
  for (final k in _kmAsk) {
    rest = rest.split(k).join(' ');
  }
  final ws = rest.replaceAll(RegExp('[?!.,:;"“”\']'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !_stop.contains(w)).toList();
  final asked = isQuestion(q);
  final out = <HelpHit>[];
  for (final a in helpList) {
    final text = _textOf(a);
    final km = _kmWords(a);
    var score = 0;
    var found = 0;
    for (final w in ws) {
      // short words ("id", "qr", "pin") only as a whole word, else "id" would be in "paid"
      final h = w.length <= 3 && !_isKm(w) ? (text.split(_wordChars).contains(w) ? 2 : 0) : hit(w, text);
      if (h > 0) {
        found += 1;
        score += h == 2 ? 3 : 2;
      } else if (_isKm(w) && km.any((k) => k.length >= 3 && w.contains(k))) {
        found += 1; // Khmer written together: "ភ្ជាប់ម៉ាស៊ីនព្រីន" has "ម៉ាស៊ីនព្រីន" in it
      }
    }
    // the topic's Khmer words inside the whole question (longer = surer)
    for (final k in km) {
      if (q.contains(k)) score += (k.length ~/ 2).clamp(1, 6);
    }
    if (score == 0) continue;
    final need = asked ? (ws.length / 2).ceil() : ws.length;
    if (ws.isNotEmpty && found < need && score < 6) continue;
    out.add(HelpHit(a, score + (asked ? 2 : 0)));
  }
  out.sort((x, y) => y.score.compareTo(x.score));
  return out.take(max).toList();
}

// where a how-to's "Open" button goes: an app screen, or my first business of the right type (that section)
class HelpTarget {
  final String route; // an app screen ('/o/coins'), or '' for a business
  final Biz? business;
  final String tab;
  final bool add; // no business of that type yet → add one
  const HelpTarget({this.route = '', this.business, this.tab = '', this.add = false});
}

HelpTarget? targetOf(Map a, List<Biz> businesses) {
  if (a['href'] != null) return HelpTarget(route: '${a['href']}');
  final types = (a['types'] as List?)?.map((e) => '$e').toList();
  if (types == null) return null;
  Biz? b;
  for (final x in businesses) {
    if (types.contains(x['category']) && x['shared'] != true) {
      b = x;
      break;
    }
  }
  b ??= businesses.where((x) => types.contains(x['category'])).firstOrNull;
  if (b == null) return const HelpTarget(route: '/o/add', add: true);
  if (a['path'] == 'team') return HelpTarget(route: '/o/team/${b['_id']}', business: b);
  final tab = a['tab'] is Map ? '${(a['tab'] as Map)[b['category']] ?? ''}' : '${a['tab'] ?? ''}';
  return HelpTarget(business: b, tab: tab);
}

// ---------------------------------------------------------------- the sections of my businesses
class PageHit {
  final Biz business;
  final String tab, en, km;
  final int score;
  const PageHit(this.business, this.tab, this.en, this.km, this.score);
}

List<PageHit> findPages(List<Biz> list, String q, String Function(String type, String lang) typeName) {
  final ws = words(q);
  if (ws.isEmpty) return const [];
  final pages = biziData['pages'] as Map;
  final more = biziData['words'] as Map;
  final out = <PageHit>[];
  for (final b in list) {
    final type = '${b['category']}';
    final tName = '${typeName(type, 'en')} ${typeName(type, 'km')}'.toLowerCase();
    final name = '${b['name'] ?? ''}'.toLowerCase();
    for (final p in (pages[type] as List? ?? const [])) {
      final key = '${p[0]}', en = '${p[1]}', km = '${p[2]}';
      final label = '$en $km'.toLowerCase();
      final extra = '${more[key] ?? ''}'.toLowerCase();
      var score = 0;
      var named = false;
      for (final w in ws) {
        final inLabel = hit(w, label);
        final inMore = inLabel > 0 ? 0 : hit(w, extra);
        final inName = inLabel > 0 || inMore > 0 ? 0 : hit(w, '$name $tName');
        if (inLabel == 0 && inMore == 0 && inName == 0) {
          score = -1;
          break;
        }
        if (inLabel > 0 || inMore > 0) named = true;
        score += inLabel > 0 ? (en.toLowerCase().startsWith(w) || km.startsWith(w) ? 6 : 4) + inLabel : (inMore > 0 ? 2 : 1);
      }
      if (score < 0 || !named) continue; // the words must name the section, not only the business
      out.add(PageHit(b, key, en, km, score));
    }
  }
  out.sort((x, y) => y.score.compareTo(x.score));
  return out.take(8).toList();
}

// the smart-word chips for the empty box
List<(String, String)> suggestions(String lang) => (((biziData['suggest'] as Map)[lang] ?? (biziData['suggest'] as Map)['en']) as List).map((e) => ('${e[0]}', '${e[1]}')).toList();
