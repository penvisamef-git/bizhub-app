// Words for the in-app coin shop (Google Play on Android, App Store on iPhone). App-only, en + km.
// A key with an '@apple' twin uses the twin on iPhone.
const _w = <String, Map<String, String>>{
  'en': {
    'title': 'Buy coins',
    'sub': 'Coins work for every business: name cards, themes, add-ons, storage and more.',
    'balance': 'Your coins',
    'free': '+{n} free',
    'pct': '{n}% free',
    'total': '{n} coins',
    'buy': 'Buy',
    'pending': 'Payment pending. Your coins are added as soon as it is paid.',
    'added': '+{n} coins added to your wallet',
    'cancelled': 'Purchase cancelled.',
    'failed': "The purchase couldn't be completed. You were not charged twice — try again.",
    'checking': 'Adding your coins…',
    'unavailable': "Buying coins isn't available on this device right now. Make sure Google Play is installed and signed in.",
    'notSetup': "Buying coins in the app isn't open yet.",
    'noPacks': 'No coin packs right now.',
    'retry': 'Try again',
    'secure': 'Paid securely with Google Play',
    'secure@apple': 'Paid securely with the App Store',
    'unavailable@apple': "Buying coins isn't available on this iPhone right now. Check that you are signed in to the App Store and that In-App Purchases are allowed in Screen Time.",
    'bestValue': 'Best value',
  },
  'km': {
    'title': 'ទិញកាក់',
    'sub': 'កាក់ប្រើបានសម្រាប់គ្រប់អាជីវកម្ម៖ កាតឈ្មោះ រចនាប័ទ្ម មុខងារបន្ថែម ទំហំផ្ទុក និងច្រើនទៀត។',
    'balance': 'កាក់របស់អ្នក',
    'free': '+{n} ឥតគិតថ្លៃ',
    'pct': '{n}% ឥតគិតថ្លៃ',
    'total': '{n} កាក់',
    'buy': 'ទិញ',
    'pending': 'ការទូទាត់កំពុងរង់ចាំ។ កាក់នឹងចូលភ្លាមៗពេលបង់រួច។',
    'added': '+{n} កាក់ បានបញ្ចូលទៅកាបូបរបស់អ្នក',
    'cancelled': 'បានបោះបង់ការទិញ។',
    'failed': 'មិនអាចបញ្ចប់ការទិញបានទេ។ អ្នកមិនត្រូវបានគិតប្រាក់ពីរដងទេ — សូមព្យាយាមម្តងទៀត។',
    'checking': 'កំពុងបញ្ចូលកាក់…',
    'unavailable': 'មិនអាចទិញកាក់នៅលើឧបករណ៍នេះបានទេឥឡូវនេះ។ សូមប្រាកដថាមាន Google Play ហើយបានចូលគណនី។',
    'notSetup': 'ការទិញកាក់ក្នុងកម្មវិធីមិនទាន់បើកនៅឡើយទេ។',
    'noPacks': 'មិនមានកញ្ចប់កាក់ទេឥឡូវនេះ។',
    'retry': 'ព្យាយាមម្តងទៀត',
    'secure': 'បង់ប្រាក់ដោយសុវត្ថិភាពតាម Google Play',
    'secure@apple': 'បង់ប្រាក់ដោយសុវត្ថិភាពតាម App Store',
    'unavailable@apple': 'មិនអាចទិញកាក់នៅលើ iPhone នេះបានទេឥឡូវនេះ។ សូមប្រាកដថាបានចូល App Store ហើយការទិញក្នុងកម្មវិធីត្រូវបានអនុញ្ញាតក្នុង Screen Time។',
    'bestValue': 'តម្លៃល្អបំផុត',
  },
};

// the words for one store ('google' | 'apple')
String cpwFor(String store, String lang, String key, [Map<String, Object>? v]) => cpw(lang, store == 'apple' && _w['en']!.containsKey('$key@apple') ? '$key@apple' : key, v);

String cpw(String lang, String key, [Map<String, Object>? v]) {
  var s = _w[lang == 'km' ? 'km' : 'en']![key] ?? _w['en']![key] ?? key;
  v?.forEach((k, x) => s = s.replaceAll('{$k}', '$x'));
  return s;
}
