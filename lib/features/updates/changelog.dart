// System activity: what changed in each BizHub version (newest first), EN / KM.
// The same list as the website (bizhub/src/dashboard/client/updates/changelog.js) — change both together.
// status: live (on bizhubcambodia.com) | testing (UAT only, coming soon) · kind: new | better | fix | safe
class Change {
  final String kind, en, km;
  const Change(this.kind, this.en, this.km);
}

class Release {
  final String version, status, date, titleEn, titleKm, subEn, subKm;
  final List<Change> items;
  const Release({required this.version, required this.status, required this.date, required this.titleEn, required this.titleKm, required this.subEn, required this.subKm, required this.items});
}

const changelog = <Release>[
  Release(
    version: '1.5.5',
    status: 'testing',
    date: '2026-10',
    titleEn: 'Lower Flip Book prices',
    titleKm: 'តម្លៃសៀវភៅត្រឡប់ PDF ថោកជាងមុន',
    subEn: 'Two Flip Book PDF extras cost less.',
    subKm: 'មុខងារបន្ថែមពីររបស់សៀវភៅត្រឡប់ PDF មានតម្លៃថោកជាងមុន។',
    items: [
      Change('better', 'More book places: 1 coin per book — 5 more books for 5 coins (was 25).', 'កន្លែងសៀវភៅបន្ថែម៖ 1 កាក់ ក្នុងមួយក្បាល — សៀវភៅ 5 ក្បាលបន្ថែម 5 កាក់ (ពីមុន 25)។'),
      Change('better', 'Clickable pages: 25 coins, once, forever (was 60).', 'ទំព័រចុចបាន៖ 25 កាក់ ម្តង ជារៀងរហូត (ពីមុន 60)។'),
    ],
  ),
  Release(
    version: '1.5.0',
    status: 'testing',
    date: '2026-10',
    titleEn: 'Work as a team',
    titleKm: 'ធ្វើការជាក្រុម',
    subEn: 'Let your manager, partner or accountant into one business with their own BizHub account.',
    subKm: 'អនុញ្ញាតឱ្យអ្នកគ្រប់គ្រង ដៃគូ ឬគណនេយ្យករ ចូលអាជីវកម្មរបស់អ្នក ដោយប្រើគណនី BizHub ផ្ទាល់ខ្លួន។',
    items: [
      Change(
        'new',
        'Team for every business type: add people as Admin (can do everything) or View only (sees everything, changes nothing).',
        'ក្រុមការងារសម្រាប់គ្រប់ប្រភេទអាជីវកម្ម៖ បន្ថែមមនុស្សជា អ្នកគ្រប់គ្រង (ធ្វើបានគ្រប់យ៉ាង) ឬ មើលតែប៉ុណ្ណោះ (មើលឃើញទាំងអស់ មិនកែអ្វីទេ)។',
      ),
      Change(
        'new',
        'Add a member by their BizHub ID, or send an invite link (QR code, copy, or Telegram). A link works for one person and ends after 7 days.',
        'បន្ថែមសមាជិកតាមលេខ BizHub ID ឬផ្ញើតំណអញ្ជើញ (កូដ QR ចម្លង ឬ Telegram)។ តំណមួយប្រើបានតែម្នាក់ ហើយផុតកំណត់ក្រោយ 7 ថ្ងៃ។',
      ),
      Change(
        'new',
        'Team costs 5 coins per business per year. No limit on members, no cost per person.',
        'ក្រុមការងារតម្លៃ 5 កាក់ ក្នុងមួយអាជីវកម្ម ក្នុងមួយឆ្នាំ។ សមាជិកមិនកំណត់ ហើយមិនគិតថ្លៃតាមមនុស្សទេ។',
      ),
      Change('new', 'My BizHub ID on the Account page, with a QR code and a copy button.', 'លេខ BizHub ID របស់ខ្ញុំ នៅទំព័រគណនី មានកូដ QR និងប៊ូតុងចម្លង។'),
      Change(
        'new',
        'Businesses → Shared with me: accept or decline invites, open shared businesses, or leave a team.',
        'អាជីវកម្ម → ចែករំលែកជាមួយខ្ញុំ៖ ទទួល ឬបដិសេធការអញ្ជើញ បើកអាជីវកម្មដែលបានចែករំលែក ឬចាកចេញពីក្រុម។',
      ),
      Change('new', 'System activity (this page): what changed in each version.', 'សកម្មភាពក្នុងប្រព័ន្ធ (ទំព័រនេះ)៖ អ្វីដែលបានផ្លាស់ប្តូរក្នុងកំណែនីមួយៗ។'),
      Change(
        'safe',
        'Only the owner can buy coins, add-ons and themes for a business. Team members never pay.',
        'មានតែម្ចាស់ទេ ដែលអាចទិញកាក់ មុខងារបន្ថែម និងរចនាប័ទ្ម សម្រាប់អាជីវកម្ម។ សមាជិកក្រុមមិនដែលបង់ទេ។',
      ),
      Change('better', 'Every button and link on the website shows the hand when you point at it.', 'រាល់ប៊ូតុង និងតំណនៅលើគេហទំព័រ បង្ហាញរូបដៃ ពេលអ្នកដាក់កណ្ដុរលើវា។'),
      Change('better', 'Grey loading shapes on the new screens instead of a blank page.', 'រូបរាងពណ៌ប្រផេះពេលកំពុងផ្ទុក នៅលើអេក្រង់ថ្មីៗ ជំនួសទំព័រទទេ។'),
    ],
  ),
  Release(
    version: '1.0.0',
    status: 'live',
    date: '2026-10',
    titleEn: 'BizHub launch',
    titleKm: 'ការដាក់ឱ្យប្រើ BizHub',
    subEn: 'One account for all your businesses, on the web, Android and the POS apps.',
    subKm: 'គណនីតែមួយសម្រាប់អាជីវកម្មទាំងអស់របស់អ្នក នៅលើគេហទំព័រ Android និងកម្មវិធី POS។',
    items: [
      Change(
        'new',
        '13 business types: Restaurant, Mini Mart, Guest House, Attendance, Website Builder, Debt Book, Digital Note, Loyalty Stamp Card, Event Tickets, Menu QR Code, Flip Book PDF, QR Generator and Name card.',
        'ប្រភេទអាជីវកម្ម 13៖ ភោជនីយដ្ឋាន ម៉ាតតូច ផ្ទះសំណាក់ វត្តមាន បង្កើតគេហទំព័រ សៀវភៅបំណុល កំណត់ត្រាឌីជីថល កាតប្រមូលត្រា សំបុត្រកម្មវិធី ម៉ឺនុយកូដ QR សៀវភៅត្រឡប់ PDF បង្កើតកូដ QR និងនាមប័ណ្ណ។',
      ),
      Change(
        'new',
        'Dashboard with today\'s sales, the week\'s chart and best sellers across your businesses.',
        'ផ្ទាំងគ្រប់គ្រង បង្ហាញការលក់ថ្ងៃនេះ ក្រាហ្វប្រចាំសប្តាហ៍ និងទំនិញលក់ដាច់ ពីអាជីវកម្មទាំងអស់។',
      ),
      Change(
        'new',
        'Coins wallet: top up with KHQR on the website or Google Play in the app, then unlock business types, add-ons and themes.',
        'កាបូបកាក់៖ បញ្ចូលកាក់តាម KHQR នៅលើគេហទំព័រ ឬ Google Play ក្នុងកម្មវិធី រួចបើកប្រភេទអាជីវកម្ម មុខងារបន្ថែម និងរចនាប័ទ្ម។',
      ),
      Change('new', 'BizHub owner app on Google Play (iPhone version coming soon).', 'កម្មវិធី BizHub សម្រាប់ម្ចាស់ នៅលើ Google Play (កំណែ iPhone ឆាប់ៗនេះ)។'),
      Change('new', 'BizHub POS for staff: Android, Mac and Windows — download it from the BizHub website.', 'BizHub POS សម្រាប់បុគ្គលិក៖ Android, Mac និង Windows — ទាញយកពីគេហទំព័រ BizHub។'),
      Change('new', 'Sign up with email or phone, and log in on the app by scanning a QR code from your Account page.', 'ចុះឈ្មោះដោយអ៊ីមែល ឬលេខទូរស័ព្ទ ហើយចូលកម្មវិធីដោយស្កេនកូដ QR ពីទំព័រគណនី។'),
      Change('new', 'Chat with BizHub: ask our team anything from inside the app.', 'ជជែកជាមួយ BizHub៖ សួរក្រុមការងាររបស់យើងបានគ្រប់យ៉ាង ពីក្នុងកម្មវិធី។'),
      Change('new', 'Khmer and English, light and dark mode.', 'ភាសាខ្មែរ និងអង់គ្លេស ពន្លឺភ្លឺ និងងងឹត។'),
      Change('safe', 'Delete my account at any time from the Account page.', 'លុបគណនីរបស់ខ្ញុំបានគ្រប់ពេល ពីទំព័រគណនី។'),
    ],
  ),
];
