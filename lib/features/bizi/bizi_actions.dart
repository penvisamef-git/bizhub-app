// Bizi commands in the app — the same rules as the website (bizhub/src/dashboard/bizi/actions.js): Bizi does things in
// every business from what is typed (or said), always asked first, and only where the person may change things.
//   commandOf("price coke 1.5") → BiziCommand(key: price, rest: coke, value: 1.5)
//   actionsOf(result, cmd)      → the buttons of a search result (what it waits for + what the command asks for)
//   bizActionsOf(business, cmd) → open / close a Telegram store, publish / unpublish a website
class BiziAction {
  final String key, method, path;
  final Map<String, dynamic> body;
  final List<String> verbs; // the commands it answers to (its own key, or others: "+24" = stock in)
  final num? v; // the number it uses (price, stock, amount, stamps)
  final String cur;
  const BiziAction(this.key, this.method, this.path, [this.body = const {}, this.verbs = const [], this.v, this.cur = '']);
  bool answers(BiziCommand? c) => c != null && (verbs.isEmpty ? [key] : verbs).contains(c.key);
}

class BiziCommand {
  final String key, rest, cur;
  final num? value;
  final bool all;
  const BiziCommand(this.key, this.rest, {this.value, this.cur = '', this.all = false});
  @override
  String toString() => 'BiziCommand($key, "$rest", $value, $cur${all ? ', all' : ''})';
}

// English words need spaces around them; Khmer is written together, so Khmer words count anywhere
RegExp _verb(String en, [String km = '']) => RegExp('(?:(?:^|\\s)(?:$en)(?=\\s|\$)${km.isEmpty ? '' : '|$km'})', caseSensitive: false);
// [key, words, what number it takes]  need = a number must be there · money / count = a number may be there
final _verbs = <(String, RegExp, String)>[
  ('unpublish', _verb('unpublish|take down|take offline', 'បិទការផ្សាយ|ឈប់ផ្សាយ'), ''),
  ('publish', _verb('publish|go live|put online', 'បោះពុម្ពផ្សាយ|ផ្សាយ'), ''),
  ('check_in', _verb('check ?in', 'ចូលស្នាក់|ឆែកអ៊ីន'), ''),
  ('check_out', _verb('check ?out', 'ចាកចេញ|ឆែកអៅ|ឆែកអោ'), ''),
  ('no_show', _verb('no ?show', 'មិនមកដល់'), ''),
  ('in_stock', _verb('back on sale|back in stock|in stock|on sale again', 'មានលក់វិញ|មានវិញ'), ''),
  ('sold_out', _verb('sold ?out|out of stock', 'អស់ស្តុក|លក់អស់|អស់'), ''),
  ('restock', _verb('restock|stock in|add stock', 'ចូលស្តុក|បន្ថែមស្តុក'), 'need'),
  ('stock', _verb('stock|count', 'រាប់ស្តុក|ស្តុក'), 'need'),
  ('price', _verb('price|new price', 'តម្លៃ|ថ្លៃ'), 'need'),
  ('owes', _verb('owes?|borrowed|borrows?|on credit', 'ជំពាក់|ខ្ចី'), 'need'),
  ('paid', _verb('paid|pay|pays', 'បានបង់|បង់'), 'money'),
  ('accept', _verb('accept', 'ទទួល'), ''),
  ('done', _verb('done|finish|finished|complete', 'បានបញ្ចប់|រួចរាល់'), ''),
  ('approve', _verb('approve', 'អនុម័ត'), ''),
  ('reject', _verb('reject|decline|refuse', 'បដិសេធ'), ''),
  ('cancel', _verb('cancel', 'បោះបង់|លុបចោល'), ''),
  ('unhide', _verb('unhide|show again', 'បង្ហាញវិញ|ឈប់លាក់'), ''),
  ('hide', _verb('hide', 'លាក់'), ''),
  ('dirty', _verb('dirty|needs cleaning', 'មិនស្អាត|កខ្វក់'), ''),
  ('clean', _verb('clean|cleaned', 'ស្អាត'), ''),
  ('stamp', _verb('stamps?|give stamps?', 'បោះត្រា|ផ្តល់ត្រា|ត្រា'), 'count'),
  ('store_close', _verb('close', 'បិទហាង'), ''),
  ('store_open', _verb('open', 'បើកហាង'), ''),
];
// commands about a whole business: nothing else has to be typed ("publish" = my website)
const _bizVerbs = {'publish', 'unpublish', 'store_open', 'store_close'};
// the businesses a business-wide command can be for
const bizKinds = <String, List<String>>{
  'store_open': ['tg_store'],
  'store_close': ['tg_store'],
  'publish': ['website'],
  'unpublish': ['website'],
};
final _filler = RegExp(r'(?:^|\s)(?:the|mark|set|as|to|of|for|please|pls|leave|room|ច្បាប់|បន្ទប់|សូម)(?=\s|$)', caseSensitive: false);
final _all = RegExp(r'(?:^|\s)(?:all|everywhere|every shop)(?=\s|$)|ទាំងអស់|គ្រប់ហាង', caseSensitive: false);
final _num = RegExp(r'(^|\s)(\+?)(\$?)(\d+(?:[.,]\d+)?)\s?(\$|usd|dollars?|៛|riels?|khr|រៀល|ដុល្លារ)?(?=\s|$)', caseSensitive: false);
final _plus = RegExp(r'(^|\s)\+(\d+(?:[.,]\d+)?)\s?(\$|usd|៛|riels?|khr|រៀល)?(?=\s|$)', caseSensitive: false);
const _kmDigits = '០១២៣៤៥៦៧៨៩';

num _numOf(String s) => RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s) ? num.parse(s.replaceAll(',', '')) : num.parse(s.replaceFirst(',', '.'));
String _curOf(String pre, String post) => pre.isNotEmpty || RegExp(r'^(\$|usd|dollars?|ដុល្លារ)$', caseSensitive: false).hasMatch(post)
    ? 'USD'
    : RegExp(r'^(៛|riels?|khr|រៀល)$', caseSensitive: false).hasMatch(post)
    ? 'KHR'
    : '';
String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
String _clean(String s) => _squash(s.replaceAll(_filler, ' '));
bool _enough(String rest) => rest.length >= 2 || RegExp(r'^#?\d+$').hasMatch(rest);

BiziCommand? commandOf(String raw) {
  var q = raw.replaceAllMapped(RegExp('[០-៩]'), (m) => '${_kmDigits.indexOf(m[0]!)}').trim();
  final all = _all.hasMatch(q);
  q = _squash(q.replaceAll(_all, ' '));
  for (final (key, re, takes) in _verbs) {
    if (!re.hasMatch(q)) continue;
    var rest = _squash(q.replaceAll(re, ' '));
    num? value;
    var cur = '';
    if (takes.isNotEmpty) {
      // the last number that isn't the thing itself ("#12", or the only thing left: "stamp 12" = card 12)
      final nums = _num.allMatches(rest).where((m) => !RegExp(r'#\s*$').hasMatch(rest.substring(0, m.start + m[1]!.length))).toList().reversed;
      for (final m in nums) {
        final left = _clean('${rest.substring(0, m.start)} ${rest.substring(m.end)}');
        if (!_enough(left)) continue;
        final n = _numOf(m[4]!);
        // a stamp count is small and said with a name ("stamp Dara 2"), never a piece of a phone number
        if (takes == 'count' && (n > 20 || m[3]!.isNotEmpty || (m[5] ?? '').isNotEmpty || !RegExp(r'[^\d\s#+]').hasMatch(left))) continue;
        value = n;
        cur = _curOf(m[3]!, m[5] ?? '');
        rest = left;
        break;
      }
      if (takes == 'need' && value == null) continue; // "low stock", "what price" — not a command
    }
    rest = _clean(rest);
    if (_enough(rest) || _bizVerbs.contains(key)) return BiziCommand(key, rest, value: value, cur: cur, all: all);
  }
  // "+24 coke", "Dara +2": more of it (stock in, stamps, what they owe)
  final p = _plus.firstMatch(q);
  if (p != null) {
    final rest = _clean('${q.substring(0, p.start)} ${q.substring(p.end)}');
    if (_enough(rest)) return BiziCommand('plus', rest, value: _numOf(p[2]!), cur: _curOf('', p[3] ?? ''), all: all);
  }
  return null;
}

String _s(Object? v) => v == null ? '' : '$v';

/// [it] is a search result as the server sends it (business_id, id, role, kind, category, status, flag, stock, leave…)
List<BiziAction> actionsOf(Map<String, dynamic> it, [BiziCommand? cmd]) {
  final bid = _s(it['business_id']);
  final id = _s(it['id']);
  if (bid.isEmpty || id.isEmpty || it['role'] == 'view') return const [];
  final out = <BiziAction>[];
  // always shown: what this thing is waiting for · typed: only when the command asks for it
  void add(BiziAction a, [bool typed = false]) {
    if (!typed || a.answers(cmd)) out.add(a);
  }

  final value = cmd?.value;
  final b = '/businesses/$bid';
  final kind = _s(it['kind']), cat = _s(it['category']), status = _s(it['status']), flag = _s(it['flag']);

  if (kind == 'order' && cat == 'tg_store') {
    final base = '$b/tgstore/orders/$id';
    if (status == 'new') add(BiziAction('accept', 'post', '$base/status', {'status': 'accepted'}));
    if (const ['accepted', 'ready', 'on_way'].contains(status)) add(BiziAction('done', 'post', '$base/status', {'status': 'done'}));
    if (flag == 'unpaid' && status != 'cancelled') add(BiziAction('paid', 'post', '$base/paid'));
    if (!const ['done', 'cancelled'].contains(status)) add(BiziAction('cancel', 'post', '$base/status', {'status': 'cancelled', 'reason': ''}), true);
  }
  if (kind == 'order' && cat == 'event') {
    final base = '$b/events/orders/$id';
    if (status == 'review') add(BiziAction('approve', 'post', '$base/approve'));
    if (status == 'review') add(BiziAction('reject', 'post', '$base/reject', {'reason': ''}), true);
    if (const ['pending', 'review'].contains(status)) add(BiziAction('cancel', 'post', '$base/cancel', {'reason': ''}), true);
  }

  if (kind == 'product') {
    final sold = flag == 'sold_out', hidden = flag == 'hidden';
    final path = switch (cat) {
      'tg_store' => '$b/tgstore/products/$id',
      'restaurant' => '$b/restaurant/items/$id',
      'menu_qr' => '$b/menuqr/items/$id',
      'mart' => '$b/mart/products/$id',
      _ => '',
    };
    if (path.isNotEmpty) {
      Map<String, dynamic> onSale(bool on) => cat == 'tg_store' ? {'sold_out': !on} : {'available': on};
      Map<String, dynamic> shown(bool on) => cat == 'tg_store' ? {'hidden': !on} : {'active': on};
      if (cat != 'mart') add(BiziAction(sold ? 'in_stock' : 'sold_out', 'put', path, onSale(sold)));
      add(hidden ? BiziAction('unhide', 'put', path, shown(true)) : BiziAction('hide', 'put', path, shown(false)), true);
      if (value != null && value >= 0 && cmd?.key == 'price') add(BiziAction('price', 'put', path, {'price': value}, const [], value));
      // stock: only for what counts its stock
      final tracked = it['stock'] != null;
      final whole = value != null && value == value.roundToDouble() && value <= 100000;
      if (tracked && whole && value > 0) {
        final inn = cat == 'mart'
            ? BiziAction(
                'restock',
                'post',
                '$b/mart/stock/in',
                {
                  'items': [
                    {'product_id': id, 'qty': value},
                  ],
                },
                const ['restock', 'plus'],
                value,
              )
            : BiziAction('restock', 'post', '$b/restaurant/stock/$id', {'kind': 'in', 'qty': value}, const ['restock', 'plus'], value);
        add(inn, true);
      }
      if (tracked && whole && value >= 0 && (cat == 'mart' || cat == 'restaurant')) {
        add(
          cat == 'mart'
              ? BiziAction('stock', 'post', '$b/mart/stock/count', {'product_id': id, 'count': value}, const [], value)
              : BiziAction('stock', 'post', '$b/restaurant/stock/$id', {'kind': 'count', 'qty': value}, const [], value),
          true,
        );
      }
    }
  }

  if (kind == 'stay' && cat == 'guest_house') {
    final base = '$b/guesthouse/stays/$id';
    if (status == 'booked') add(BiziAction('check_in', 'post', '$base/check-in'));
    if (status == 'in') add(BiziAction('check_out', 'post', '$base/check-out'));
    if (status == 'booked') add(BiziAction('cancel', 'post', '$base/cancel'), true);
    if (status == 'booked') add(BiziAction('no_show', 'post', '$base/no-show'), true);
  }
  if (kind == 'room' && cat == 'guest_house') {
    final path = '$b/guesthouse/rooms/$id/hk';
    if (flag == 'dirty' || flag == 'cleaning') {
      add(BiziAction('clean', 'put', path, {'state': 'ready'}));
    } else {
      add(BiziAction('dirty', 'put', path, {'state': 'dirty'}), true);
    }
  }

  final leave = it['leave'];
  if (kind == 'person' && cat == 'attendance' && leave is Map && _s(leave['id']).isNotEmpty) {
    final path = '$b/attendance/leave/${leave['id']}/decide';
    add(BiziAction('approve_leave', 'post', path, {'status': 'approved'}, const ['approve', 'approve_leave']));
    add(BiziAction('reject_leave', 'post', path, {'status': 'rejected'}, const ['reject', 'reject_leave']));
  }
  if (kind == 'person' && cat == 'debt_book' && value != null && value > 0) {
    final path = '$b/debt/customers/$id/entries';
    final c = cmd?.cur ?? '';
    Map<String, dynamic> body(String k) => {'kind': k, 'amount': value, if (c.isNotEmpty) 'currency': c};
    add(BiziAction('owes', 'post', path, body('debt'), const ['owes', 'plus'], value, c), true);
    add(BiziAction('pay_debt', 'post', path, body('pay'), const ['paid'], value, c), true);
  }
  if (kind == 'person' && cat == 'stamp_card') {
    final n = value != null && value == value.roundToDouble() && value >= 1 && value <= 20 ? value.toInt() : 1;
    add(BiziAction('stamp', 'post', '$b/stamps/members/$id/stamp', {'n': n}, const ['stamp', 'plus'], n));
  }
  return out;
}

/// a whole business ({_id, category, role}): only when asked ("close", "publish")
List<BiziAction> bizActionsOf(Map<String, dynamic> biz, BiziCommand? cmd) {
  final bid = _s(biz['business_id'] ?? biz['_id']);
  if (cmd == null || bid.isEmpty || biz['role'] == 'view') return const [];
  final cat = _s(biz['category']);
  return [
    if (cat == 'tg_store') ...[
      BiziAction('store_open', 'put', '/businesses/$bid/tgstore/settings', {'open': true}),
      BiziAction('store_close', 'put', '/businesses/$bid/tgstore/settings', {'open': false}),
    ],
    if (cat == 'website') ...[BiziAction('publish', 'post', '/businesses/$bid/website/publish'), BiziAction('unpublish', 'post', '/businesses/$bid/website/unpublish')],
  ].where((a) => a.answers(cmd)).toList();
}
