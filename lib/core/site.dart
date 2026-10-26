import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'providers.dart';

// The public website settings (coins, prices, contact, payment methods) — GET /api/public/homepage.
class SiteInfo {
  final Json raw;
  const SiteInfo(this.raw);
  Json get coin => obj(raw['coin']);
  num get bonus => coin['signup_bonus'] is num ? coin['signup_bonus'] as num : 200;
  num get packCoins => coin['pack_coins'] is num ? coin['pack_coins'] as num : 100;
  num get packUsd => coin['pack_price_usd'] is num ? coin['pack_price_usd'] as num : 10;
  List<String> get payments {
    final m = raw['payment_methods'];
    return m is List && m.isNotEmpty ? m.map((e) => '$e').toList() : const ['KHQR', 'ABA', 'Card'];
  }

  Json get contact => obj(raw['contact']);
  List<String> get phones => (contact['phones'] is List) ? (contact['phones'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList() : const [];
  Json get prices => obj(raw['prices']);
  List<String> get yearly => raw['yearly'] is List ? (raw['yearly'] as List).map((e) => '$e').toList() : const [];

  // the {bonus} {pack} {price} {payments} placeholders the web texts use (useHomepageData.js):
  // Khmer digits in Khmer, "KHQR, ABA or Card"
  Map<String, Object?> vars(String lang) {
    final km = lang == 'km';
    String num(Object v) => km ? '$v'.replaceAllMapped(RegExp(r'\d'), (m) => '០១២៣៤៥៦៧៨៩'[int.parse(m[0]!)]) : '$v';
    final p = payments;
    final pay = p.length <= 1 ? p.join('') : '${p.sublist(0, p.length - 1).join(', ')} ${km ? 'ឬ' : 'or'} ${p.last}';
    return {'bonus': num(bonus), 'pack': num(packCoins), 'price': num(packUsd), 'payments': pay};
  }

  // the app screens (wallet, sign up) fill them like the web app does: plain numbers
  Map<String, Object?> get plainVars => {'bonus': bonus, 'pack': packCoins, 'price': packUsd, 'payments': payments.join(', ')};

  // service groups (Super admin → Business groups) as business types: [(key, label, [types])]
  // homepage keys guest / attend = business types guest_house / attendance; types not in a group go under "More"
  List<(String, String, List<String>)> bizGroups(String lang, List<String> types) {
    const typeOf = {'guest': 'guest_house', 'attend': 'attendance'};
    final raw0 = raw['groups'] is List && (raw['groups'] as List).isNotEmpty ? raw['groups'] as List : _defaultGroups;
    final out = <(String, String, List<String>)>[];
    final used = <String>{};
    for (final g in raw0) {
      final m = obj(g);
      final list = [
        for (final k in (m['types'] is List ? m['types'] as List : const [])) typeOf['$k'] ?? '$k',
      ].where((k) => types.contains(k) && used.add(k)).toList();
      final label = '${lang == 'km' ? (m['km'] ?? m['en']) : (m['en'] ?? m['km']) ?? m['key']}';
      if (list.isNotEmpty) out.add(('${m['key']}', label, list));
    }
    final rest = types.where((k) => !used.contains(k)).toList();
    if (rest.isNotEmpty) out.add(('more', lang == 'km' ? 'ផ្សេងៗ' : 'More', rest));
    return out;
  }

  // homepage texts the super admin changed → "home.<key>"
  Map<String, dynamic> homeTexts(String lang) {
    final x = obj(obj(raw['texts'])[lang]);
    return {for (final e in x.entries) if (e.value is String && (e.value as String).isNotEmpty) 'home.${e.key}': e.value};
  }
}

// same as the web (homepage/defaults.js groups) while the API has none
const _defaultGroups = [
  {'key': 'online', 'en': 'Online & QR', 'km': 'អនឡាញ & QR', 'types': ['namecard', 'website', 'menu_qr', 'qr_gen', 'stamp_card']},
  {'key': 'system', 'en': 'Management systems', 'km': 'ប្រព័ន្ធគ្រប់គ្រង', 'types': ['restaurant', 'mart', 'guest', 'tg_store', 'attend', 'event']},
  {'key': 'personal', 'en': 'Personal', 'km': 'ផ្ទាល់ខ្លួន', 'types': ['flipbook', 'debt_book', 'digital_note']},
];

final siteProvider = FutureProvider<SiteInfo>((ref) async {
  try {
    final r = await ref.read(apiProvider).get('${Api.public}/homepage');
    return SiteInfo(obj(r['data']));
  } catch (_) {
    return const SiteInfo({});
  }
});

// while loading (or offline) use the defaults
SiteInfo siteOf(WidgetRef ref) => ref.watch(siteProvider).valueOrNull ?? const SiteInfo({});
