// Bizi quick actions in the app — the same rules as the website (bizhub/src/dashboard/bizi/actions.js):
//   actionsOf(result) → what can be done right from a search result (always asked first: "Mark #12 paid?")
//   verbOf("#12 paid") → (key: paid, rest: "#12") — the words that say what to do, and what to look for
class BiziAction {
  final String key, method, path;
  final Map<String, dynamic> body;
  const BiziAction(this.key, this.method, this.path, [this.body = const {}]);
}

final _verbs = <(String, RegExp)>[
  ('paid', RegExp(r'(^|\s)(paid|pay|បានបង់|បង់)(?=\s|$)', caseSensitive: false)),
  ('accept', RegExp(r'(^|\s)(accept|ទទួល)(?=\s|$)', caseSensitive: false)),
  ('done', RegExp(r'(^|\s)(done|finish|finished|complete|បានបញ្ចប់|រួចរាល់)(?=\s|$)', caseSensitive: false)),
  ('approve', RegExp(r'(^|\s)(approve|អនុម័ត)(?=\s|$)', caseSensitive: false)),
  ('in_stock', RegExp(r'(^|\s)(back on sale|back in stock|in stock|មានលក់វិញ|មានវិញ)(?=\s|$)', caseSensitive: false)),
  ('sold_out', RegExp(r'(^|\s)(sold out|soldout|អស់ស្តុក|អស់)(?=\s|$)', caseSensitive: false)),
];

// only together with something to do it to ("sold out" alone is the smart word)
({String key, String rest})? verbOf(String raw) {
  final q = raw.trim();
  for (final (key, re) in _verbs) {
    if (!re.hasMatch(q)) continue;
    final rest = q.replaceAll(re, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (rest.length >= 2 || RegExp(r'^#?\d+$').hasMatch(rest)) return (key: key, rest: rest);
  }
  return null;
}

List<BiziAction> actionsOf({required String category, required String kind, required String id, required String businessId, String status = '', String flag = ''}) {
  if (businessId.isEmpty || id.isEmpty) return const [];
  if (category == 'tg_store' && kind == 'order') {
    final base = '/businesses/$businessId/tgstore/orders/$id';
    return [
      if (status == 'new') BiziAction('accept', 'post', '$base/status', {'status': 'accepted'}),
      if (const ['accepted', 'ready', 'on_way'].contains(status)) BiziAction('done', 'post', '$base/status', {'status': 'done'}),
      if (flag == 'unpaid' && status != 'cancelled') BiziAction('paid', 'post', '$base/paid'),
    ];
  }
  if (category == 'tg_store' && kind == 'product') {
    final sold = flag == 'sold_out';
    return [
      BiziAction(sold ? 'in_stock' : 'sold_out', 'put', '/businesses/$businessId/tgstore/products/$id', {'sold_out': !sold}),
    ];
  }
  if (category == 'event' && kind == 'order' && status == 'review') return [BiziAction('approve', 'post', '/businesses/$businessId/events/orders/$id/approve')];
  return const [];
}
