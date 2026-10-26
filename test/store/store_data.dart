// Sample data for the Google Play screenshots (test/store/store_shots_test.dart).
// Believable Cambodian businesses, in English and Khmer. No emoji (the test machine has no emoji font).
import 'dart:convert';
import 'dart:io';

import 'package:bizhub_admin/core/api.dart';

final _now = DateTime.now().toUtc();
String ago(Duration d) => _now.subtract(d).toIso8601String();
String inDays(int d) => _now.add(Duration(days: d)).toIso8601String();
String dayOf(int back) => _now
    .add(const Duration(hours: 7))
    .subtract(Duration(days: back))
    .toIso8601String()
    .substring(0, 10);

Json homepage() => Map<String, dynamic>.from(
  jsonDecode(File('test/store/fixtures/homepage.json').readAsStringSync())
      as Map,
);

Json bizPrices() {
  final d = homepage()['data'] as Map;
  final yearly =
      (d['yearly'] as List?)?.map((e) => '$e').toList() ??
      const [
        'restaurant',
        'attendance',
        'guest_house',
        'mart',
        'event',
        'digital_note',
        'stamp_card',
        'website',
        'menu_qr',
      ];
  return {
    'data': d['prices'],
    'days': {for (final k in yearly) k: 365},
  };
}

// the owner
Json me(String lang) => {
  'access_token': 't',
  'name': lang == 'km' ? 'សុខ ចាន់' : 'Sokha Chan',
  'email': 'sokha@bizhubcambodia.com',
  'coin_balance': 1250,
};

String _n(String lang, String en, String km) => lang == 'km' ? km : en;

List<Json> businesses(String lang) => [
  {
    '_id': 'b1',
    'name': _n(lang, 'Sokha Coffee', 'សុខា កាហ្វេ'),
    'category': 'restaurant',
    'status': true,
    'slug': 'sokha-coffee',
    'license': {'status': 'active', 'expires_at': inDays(240)},
  },
  {
    '_id': 'b2',
    'name': _n(lang, 'Lotus Mini Mart', 'ផ្សារទំនើប ឈូក'),
    'category': 'mart',
    'status': true,
    'slug': 'lotus-mart',
    'license': {'status': 'active', 'expires_at': inDays(310)},
  },
  {
    '_id': 'b3',
    'name': _n(lang, 'Riverside Guest House', 'ផ្ទះសំណាក់ មាត់ទន្លេ'),
    'category': 'guest_house',
    'status': true,
    'slug': 'riverside',
    'license': {'status': 'active', 'expires_at': inDays(180)},
  },
  {
    '_id': 'b4',
    'name': _n(lang, 'Sokha Chan', 'សុខ ចាន់'),
    'category': 'namecard',
    'status': true,
    'slug': 'sokha',
    'namecard': {'views': 1284},
    'license': {'status': 'forever'},
  },
  {
    '_id': 'b5',
    'name': _n(lang, 'Angkor Night Run 2026', 'រត់ពេលយប់ អង្គរ ២០២៦'),
    'category': 'event',
    'status': true,
    'slug': 'angkor-run',
    'license': {'status': 'active', 'expires_at': inDays(200)},
  },
  {
    '_id': 'b6',
    'name': _n(lang, 'Team notes', 'កំណត់ត្រាក្រុម'),
    'category': 'digital_note',
    'status': true,
    'slug': 'team-notes',
    'license': {'status': 'active', 'expires_at': inDays(330)},
  },
  {
    '_id': 'b7',
    'name': _n(lang, 'Sokha Coffee staff', 'បុគ្គលិក សុខា កាហ្វេ'),
    'category': 'attendance',
    'status': true,
    'slug': 'sokha-staff',
    'license': {'status': 'active', 'expires_at': inDays(150)},
  },
];

const _days = [
  312.0,
  355.5,
  298.0,
  401.25,
  446.0,
  520.75,
  488.0,
  365.0,
  389.5,
  412.0,
  470.25,
  538.0,
  602.5,
  486.5,
];

Json dashboard(String lang) {
  final biz = businesses(lang);
  return {
    'at': ago(const Duration(minutes: 1)),
    'coins': {
      'balance': 1250,
      'wallet': '65f1c0de9a7b4e21d3a8b7c4',
      'spent_30d': 180,
    },
    'businesses': biz,
    'sales': {
      'currency': 'USD',
      'today': 486.5,
      'bills_today': 64,
      'avg_today': 7.6,
      'yesterday': 412.0,
      'week': 2310.75,
      'bills_week': 301,
      'last_week': 1980.0,
      'month': 8450.25,
      'bills_month': 1122,
      'open_now': 5,
      'days': [
        for (var i = 0; i < 14; i++) {'day': dayOf(13 - i), 'sales': _days[i]},
      ],
      'week_start': dayOf(3),
      'by_business': [
        {
          'id': 'b1',
          'name': biz[0]['name'],
          'kind': 'restaurant',
          'currency': 'USD',
          'today': 268.5,
          'bills_today': 41,
          'yesterday': 230,
          'week': 1290,
          'bills_week': 188,
          'last_week': 1100,
          'month': 4800,
          'open_now': 4,
          'days': _days.map((d) => d * .55).toList(),
        },
        {
          'id': 'b2',
          'name': biz[1]['name'],
          'kind': 'mart',
          'currency': 'USD',
          'today': 158.0,
          'bills_today': 21,
          'yesterday': 132,
          'week': 760.75,
          'bills_week': 107,
          'last_week': 640,
          'month': 2850.25,
          'open_now': 0,
          'days': _days.map((d) => d * .32).toList(),
        },
        {
          'id': 'b3',
          'name': biz[2]['name'],
          'kind': 'guest_house',
          'currency': 'USD',
          'today': 60.0,
          'bills_today': 2,
          'yesterday': 50,
          'week': 260,
          'bills_week': 6,
          'last_week': 240,
          'month': 800,
          'open_now': 6,
          'days': _days.map((d) => d * .13).toList(),
        },
      ],
    },
    'top_items': [
      {
        'name_en': 'Iced latte',
        'name_km': 'ឡាតេទឹកកក',
        'qty': 86,
        'value': 215.0,
        'business': biz[0]['name'],
        'business_id': 'b1',
        'kind': 'restaurant',
      },
      {
        'name_en': 'Fish amok',
        'name_km': 'អាម៉ុកត្រី',
        'qty': 41,
        'value': 184.5,
        'business': biz[0]['name'],
        'business_id': 'b1',
        'kind': 'restaurant',
      },
      {
        'name_en': 'Kampot pepper 100 g',
        'name_km': 'ម្រេចកំពត ១០០ ក្រាម',
        'qty': 38,
        'value': 152.0,
        'business': biz[1]['name'],
        'business_id': 'b2',
        'kind': 'mart',
      },
      {
        'name_en': 'Palm sugar juice',
        'name_km': 'ទឹកត្នោត',
        'qty': 33,
        'value': 49.5,
        'business': biz[0]['name'],
        'business_id': 'b1',
        'kind': 'restaurant',
      },
    ],
    'attention': [],
    'now': [
      {
        'key': 'open_bills',
        'n': 4,
        'tab': {'restaurant': ''},
        'by': [
          {'id': 'b1', 'name': biz[0]['name'], 'kind': 'restaurant', 'n': 4},
        ],
      },
      {
        'key': 'in_house',
        'n': 6,
        'tab': {'guest_house': ''},
        'by': [
          {'id': 'b3', 'name': biz[2]['name'], 'kind': 'guest_house', 'n': 6},
        ],
      },
      {
        'key': 'waiting',
        'n': 3,
        'tab': {'mart': 'orders', 'guest_house': 'customers'},
        'by': [
          {'id': 'b2', 'name': biz[1]['name'], 'kind': 'mart', 'n': 2},
          {'id': 'b3', 'name': biz[2]['name'], 'kind': 'guest_house', 'n': 1},
        ],
      },
      {
        'key': 'staff_in',
        'n': 8,
        'of': 10,
        'late': 1,
        'not_in': 2,
        'tab': {'attendance': ''},
        'by': [
          {'id': 'b7', 'name': biz[6]['name'], 'kind': 'attendance', 'n': 8},
        ],
      },
    ],
  };
}

Json wallet(String lang) => {
  'data': {
    'balance': 1250,
    'transactions': [
      {
        '_id': 'x1',
        'type': 'card_redeem',
        'direction': 'in',
        'amount': 500,
        'balance_after': 1250,
        'created_date': ago(const Duration(hours: 2)),
        'note': '',
      },
      {
        '_id': 'x2',
        'type': 'spend',
        'direction': 'out',
        'amount': 75,
        'balance_after': 750,
        'created_date': ago(const Duration(days: 1, hours: 3)),
        'product': 'new_business',
        'service': 'event',
        'note':
            'New business: ${_n(lang, 'Angkor Night Run 2026', 'រត់ពេលយប់ អង្គរ ២០២៦')}',
        'business': {
          'name': _n(lang, 'Angkor Night Run 2026', 'រត់ពេលយប់ អង្គរ ២០២៦'),
          'category': 'event',
        },
      },
      {
        '_id': 'x3',
        'type': 'purchase',
        'direction': 'in',
        'amount': 500,
        'balance_after': 825,
        'created_date': ago(const Duration(days: 3)),
        'payment_method': 'Google Play',
        'order': {'no': 'CO-24117', 'coins': 500, 'bonus': 0},
        'note': '',
      },
      {
        '_id': 'x4',
        'type': 'spend',
        'direction': 'out',
        'amount': 15,
        'balance_after': 325,
        'created_date': ago(const Duration(days: 4)),
        'product': 'theme',
        'item': 'velvet',
        'note': 'Premium theme: velvet',
        'business': {
          'name': _n(lang, 'Sokha Chan', 'សុខ ចាន់'),
          'category': 'namecard',
        },
      },
      {
        '_id': 'x5',
        'type': 'spend',
        'direction': 'out',
        'amount': 10,
        'balance_after': 340,
        'created_date': ago(const Duration(days: 6)),
        'product': 'new_business',
        'service': 'digital_note',
        'note': 'New business: ${_n(lang, 'Team notes', 'កំណត់ត្រាក្រុម')}',
        'business': {
          'name': _n(lang, 'Team notes', 'កំណត់ត្រាក្រុម'),
          'category': 'digital_note',
        },
      },
      {
        '_id': 'x6',
        'type': 'signup_bonus',
        'direction': 'in',
        'amount': 200,
        'balance_after': 350,
        'created_date': ago(const Duration(days: 30)),
        'note': '',
      },
    ],
  },
  'pagination': {'totalPages': 1},
};

// the name card shown on its own (what customers see when they scan it)
Json card(String lang) => {
  'name': _n(lang, 'Sokha Chan', 'សុខ ចាន់'),
  'job_title': _n(lang, 'Owner', 'ម្ចាស់ហាង'),
  'company': _n(lang, 'Sokha Coffee', 'សុខា កាហ្វេ'),
  'bio': _n(
    lang,
    'Fresh Mondulkiri coffee, roasted in Phnom Penh every morning.',
    'កាហ្វេមណ្ឌលគិរីស្រស់ លីងនៅភ្នំពេញរៀងរាល់ព្រឹក។',
  ),
  'theme': 'harbor',
  'color': '#E0581A',
  'phone1': '012 345 678',
  'email': 'hello@sokhacoffee.com',
  'website': 'https://sokhacoffee.com',
  'telegram': '@sokhacoffee',
  'slug': 'sokha',
  'portfolio': true,
};

// a public event (Event Tickets)
Json event(String lang) => {
  'title': _n(lang, 'Angkor Night Run 2026', 'រត់ពេលយប់ អង្គរ ២០២៦'),
  'theme': 'gradient',
  'theme_colors': {'a': '#E0581A', 'b': '#F59E0B'},
  'starts_at': DateTime.utc(
    2026,
    11,
    14,
    11,
    30,
  ).toIso8601String(), // 18:30 in Cambodia
  'venue': _n(lang, 'Angkor Wat, Siem Reap', 'អង្គរវត្ត សៀមរាប'),
  'types': [
    {'name': _n(lang, '5 km Fun Run', 'រត់កម្សាន្ត ៥ គ.ម'), 'price': 12},
    {'name': _n(lang, '10 km Race', 'ប្រណាំង ១០ គ.ម'), 'price': 20},
  ],
};
