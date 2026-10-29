// Bizi commands in the app: the same answers as the website (bizhub/tool/test-bizi-commands.mjs) — what is typed turns
// into the right action for every business type (EN + KM).   flutter test test/bizi_actions_test.dart
import 'package:bizhub_admin/features/bizi/bizi_actions.dart';
import 'package:bizhub_admin/features/bizi/bizi_find.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _c(BiziCommand? c) => c == null ? {} : {'key': c.key, 'rest': c.rest, if (c.value != null) 'value': c.value, if (c.cur.isNotEmpty) 'cur': c.cur, if (c.all) 'all': true};

void main() {
  test('what people type → the command', () {
    final cases = <String, Map<String, Object?>>{
      '#12 paid': {'key': 'paid', 'rest': '#12'},
      'accept #12': {'key': 'accept', 'rest': '#12'},
      'cancel #12': {'key': 'cancel', 'rest': '#12'},
      'sold out iced coffee': {'key': 'sold_out', 'rest': 'iced coffee'},
      'iced coffee back on sale': {'key': 'in_stock', 'rest': 'iced coffee'},
      'price coke 1.5': {'key': 'price', 'rest': 'coke', 'value': 1.5},
      'price of coke to 1,5\$': {'key': 'price', 'rest': 'coke', 'value': 1.5, 'cur': 'USD'},
      'price rice 10,000': {'key': 'price', 'rest': 'rice', 'value': 10000},
      'coke +24': {'key': 'plus', 'rest': 'coke', 'value': 24},
      'restock coke 24': {'key': 'restock', 'rest': 'coke', 'value': 24},
      'stock coke 30': {'key': 'stock', 'rest': 'coke', 'value': 30},
      'hide coke': {'key': 'hide', 'rest': 'coke'},
      'unhide coke': {'key': 'unhide', 'rest': 'coke'},
      'check in Dara': {'key': 'check_in', 'rest': 'Dara'},
      'checkout Dara': {'key': 'check_out', 'rest': 'Dara'},
      'Dara no show': {'key': 'no_show', 'rest': 'Dara'},
      'mark room 101 as clean': {'key': 'clean', 'rest': '101'},
      'room 102 dirty': {'key': 'dirty', 'rest': '102'},
      'approve leave Sophea': {'key': 'approve', 'rest': 'Sophea'},
      'Dara owes 10\$': {'key': 'owes', 'rest': 'Dara', 'value': 10, 'cur': 'USD'},
      'Dara paid 5000 riel': {'key': 'paid', 'rest': 'Dara', 'value': 5000, 'cur': 'KHR'},
      'Dara paid 5': {'key': 'paid', 'rest': 'Dara', 'value': 5},
      '012 345 678 owes 10': {'key': 'owes', 'rest': '012 345 678', 'value': 10},
      'stamp Dara': {'key': 'stamp', 'rest': 'Dara'},
      'stamp Dara 2': {'key': 'stamp', 'rest': 'Dara', 'value': 2},
      'stamp 012 345 678': {'key': 'stamp', 'rest': '012 345 678'},
      'Dara +2': {'key': 'plus', 'rest': 'Dara', 'value': 2},
      'close': {'key': 'store_close', 'rest': ''},
      'publish': {'key': 'publish', 'rest': ''},
      'coke sold out everywhere': {'key': 'sold_out', 'rest': 'coke', 'all': true},
      'កូកាអស់ស្តុក': {'key': 'sold_out', 'rest': 'កូកា'},
      'កូកា អស់ស្តុក ទាំងអស់': {'key': 'sold_out', 'rest': 'កូកា', 'all': true},
      'តម្លៃ កូកា ១.៥': {'key': 'price', 'rest': 'កូកា', 'value': 1.5},
      'ដារ៉ា ជំពាក់ ១០០០០៛': {'key': 'owes', 'rest': 'ដារ៉ា', 'value': 10000, 'cur': 'KHR'},
      'ឆែកអៅ ដារ៉ា': {'key': 'check_out', 'rest': 'ដារ៉ា'},
      'បន្ទប់ 101 មិនស្អាត': {'key': 'dirty', 'rest': '101'},
      'អនុម័តច្បាប់ សុភា': {'key': 'approve', 'rest': 'សុភា'},
      'បិទហាង': {'key': 'store_close', 'rest': ''},
    };
    for (final e in cases.entries) {
      expect(_c(commandOf(e.key)), e.value, reason: e.key);
    }
    for (final q in ['low stock', 'what price', 'iced coffee', 'Dara', '012 345 678', 'price', 'sold out']) {
      expect(commandOf(q), isNull, reason: q);
    }
  });

  test('each business type → its action (the same calls as the website)', () {
    BiziAction? first(Map<String, dynamic> it, String q) {
      final cmd = commandOf(q);
      return actionsOf({'business_id': 'b1', 'id': 'r1', 'role': 'owner', ...it}, cmd).where((a) => a.answers(cmd)).firstOrNull;
    }

    List<String> keys(Map<String, dynamic> it, [String? q]) => actionsOf({'business_id': 'b1', 'id': 'r1', 'role': 'owner', ...it}, q == null ? null : commandOf(q)).map((a) => a.key).toList();
    Map<String, dynamic> p(String cat, [Map<String, dynamic> more = const {}]) => {'kind': 'product', 'category': cat, 'flag': '', 'stock': null, ...more};

    expect(keys({'kind': 'order', 'category': 'tg_store', 'status': 'new', 'flag': 'unpaid'}), ['accept', 'paid']);
    expect(keys({'kind': 'order', 'category': 'tg_store', 'status': 'new', 'flag': 'unpaid'}, 'cancel #12'), ['accept', 'paid', 'cancel']);
    var a = first(p('restaurant'), 'price coke 2.5')!;
    expect([a.method, a.path], ['put', '/businesses/b1/restaurant/items/r1']);
    expect(a.body, {'price': 2.5});
    expect(first(p('restaurant'), 'sold out coke')!.body, {'available': false});
    expect(first(p('menu_qr', {'flag': 'sold_out'}), 'coke back on sale')!.path, '/businesses/b1/menuqr/items/r1');
    expect(first(p('tg_store'), 'hide coke')!.body, {'hidden': true});
    expect(first(p('mart', {'flag': 'hidden'}), 'unhide coke')!.body, {'active': true});
    expect(keys(p('mart')).contains('sold_out'), isFalse);
    a = first(p('mart', {'stock': 3}), 'coke +24')!;
    expect(a.path, '/businesses/b1/mart/stock/in');
    expect(a.body, {
      'items': [
        {'product_id': 'r1', 'qty': 24},
      ],
    });
    expect(first(p('mart', {'stock': 3}), 'stock coke 30')!.body, {'product_id': 'r1', 'count': 30});
    expect(first(p('restaurant', {'stock': 0}), 'restock coke 12')!.body, {'kind': 'in', 'qty': 12});
    expect(first(p('mart'), 'coke +24'), isNull, reason: "doesn't count its stock");
    expect(keys({'kind': 'order', 'category': 'event', 'status': 'review'}, 'reject #0042'), ['approve', 'reject']);
    expect(keys({'kind': 'stay', 'category': 'guest_house', 'status': 'booked'}), ['check_in']);
    expect(first({'kind': 'stay', 'category': 'guest_house', 'status': 'in'}, 'check out Dara')!.path, '/businesses/b1/guesthouse/stays/r1/check-out');
    expect(first({'kind': 'room', 'category': 'guest_house', 'flag': 'dirty'}, 'room 101 clean')!.body, {'state': 'ready'});
    final staff = {
      'kind': 'person',
      'category': 'attendance',
      'leave': {'id': 'L1', 'from': '2026-11-02', 'to': '2026-11-03'},
    };
    expect(keys(staff), ['approve_leave', 'reject_leave']);
    expect(first(staff, 'approve leave Sophea')!.path, '/businesses/b1/attendance/leave/L1/decide');
    final debt = {'kind': 'person', 'category': 'debt_book'};
    expect(first(debt, 'Dara owes 10\$')!.body, {'kind': 'debt', 'amount': 10, 'currency': 'USD'});
    expect(first(debt, 'Dara paid 5000៛')!.body, {'kind': 'pay', 'amount': 5000, 'currency': 'KHR'});
    expect(first(debt, 'Dara paid 5')!.body, {'kind': 'pay', 'amount': 5});
    expect(keys(debt), isEmpty);
    expect(first({'kind': 'person', 'category': 'stamp_card'}, 'Dara +2')!.body, {'n': 2});
    expect(actionsOf({'business_id': 'b1', 'id': 'r1', 'role': 'view', 'kind': 'order', 'category': 'tg_store', 'status': 'new'}, commandOf('accept #1')), isEmpty, reason: 'View only');
    expect(bizActionsOf({'_id': 'b1', 'category': 'tg_store', 'role': 'owner'}, commandOf('close')).single.body, {'open': false});
    expect(bizActionsOf({'_id': 'b1', 'category': 'website', 'role': 'owner'}, commandOf('publish')).single.path, '/businesses/b1/website/publish');
    expect(bizActionsOf({'_id': 'b1', 'category': 'website', 'role': 'view'}, commandOf('publish')), isEmpty);
  });

  test('every action has its words (EN + KM), from the website', () {
    const all = [
      'accept', 'done', 'paid', 'sold_out', 'in_stock', 'approve', 'cancel', 'reject', 'hide', 'unhide', 'price', 'restock', 'stock', 'check_in', //
      'check_out', 'no_show', 'clean', 'dirty', 'approve_leave', 'reject_leave', 'owes', 'pay_debt', 'stamp', 'store_open', 'store_close', 'publish', 'unpublish',
    ];
    for (final lang in ['en', 'km']) {
      for (final k in all) {
        for (final set in ['act', 'actAsk', 'actOk']) {
          expect(biziHas(lang, '$set.$k'), isTrue, reason: '$lang $set.$k');
        }
      }
      for (final k in ['actAll', 'actAllAsk', 'actAllOk', 'actAllSome', 'actNone', 'dirty', 'cleaning', 'leave']) {
        expect(biziHas(lang, k), isTrue, reason: '$lang $k');
      }
    }
    expect(biziT('en', 'actAsk.price', {'t': 'Coke', 'v': r'$1.50'}), r'Change the price of “Coke” to $1.50?');
  });
}
