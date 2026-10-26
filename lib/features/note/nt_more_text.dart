import 'nt_common.dart';

// Digital Note, dashboard sections (groups, storage & plan, media, Telegram alerts, business profile, add-ons):
// the few app-only words. Everything else comes from the web texts (i18n "note.*" → ctx.m(…)).

const _words = <String, Map<String, String>>{
  'en': {
    'pickPhoto': 'Choose a photo',
    'takePhoto': 'Take a photo',
    'openTelegram': 'Open Telegram',
    'select': 'Select',
    'selectDone': 'Done',
    'limitNow': 'Your limit now: {limit}',
    'limitAfter': 'Your limit becomes {total}',
    'filesIn': 'Files',
    'notesIn': 'Notes',
    'viewsTotal': '{v} views · {p} people',
    'groupLook': 'Look',
    'openPage': 'Open the page',
    'openLink': 'Open link',
    'noPreview': 'No preview',
    'sendFirst': 'Share the group first to get its link.',
    'logoHint': 'A square picture looks best.',
    'packsCount': '{n} packs',
    'packsStepper': 'How many packs',
    'telegramTry': 'Press Start in the bot, then come back here.',
    'moreThemes': '{n} themes',
    'themeTapToSee': 'Tap a theme to see it big.',
    'deletedTag': 'Deleted',
    'emptyNote': 'Empty note',
  },
  'km': {
    'pickPhoto': 'ជ្រើសរូបថត',
    'takePhoto': 'ថតរូប',
    'openTelegram': 'បើក Telegram',
    'select': 'ជ្រើសរើស',
    'selectDone': 'រួចរាល់',
    'limitNow': 'ទំហំរបស់អ្នកឥឡូវ៖ {limit}',
    'limitAfter': 'ទំហំរបស់អ្នកនឹងក្លាយជា {total}',
    'filesIn': 'ឯកសារ',
    'notesIn': 'កំណត់ត្រា',
    'viewsTotal': '{v} ដងមើល · {p} នាក់',
    'groupLook': 'រូបរាង',
    'openPage': 'បើកទំព័រ',
    'openLink': 'បើកតំណ',
    'noPreview': 'គ្មានរូបមើលមុន',
    'sendFirst': 'ចែករំលែកក្រុមជាមុនសិន ដើម្បីទទួលបានតំណ។',
    'logoHint': 'រូបការ៉េមើលទៅស្អាតបំផុត។',
    'packsCount': '{n} កញ្ចប់',
    'packsStepper': 'ចំនួនកញ្ចប់',
    'telegramTry': 'ចុច Start ក្នុង bot រួចត្រឡប់មកទីនេះវិញ។',
    'moreThemes': '{n} រចនាប័ទ្ម',
    'themeTapToSee': 'ចុចលើរចនាប័ទ្ម ដើម្បីមើលធំ។',
    'deletedTag': 'បានលុប',
    'emptyNote': 'កំណត់ត្រាទទេ',
  },
};

// an app-only word of the dashboard sections ({n} style placeholders like the web texts)
String ntw(NtCtx ctx, String key, [Map<String, Object?> vars = const {}]) {
  var s = _words[ctx.km ? 'km' : 'en']?[key] ?? _words['en']![key] ?? key;
  vars.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
