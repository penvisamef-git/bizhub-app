import 'package:speech_to_text/speech_to_text.dart';

// Voice search for Bizi (free): the phone's own speech-to-text (Google on Android, Apple on iPhone), Khmer when the
// phone has it, otherwise English. The words go into Bizi's box as they come.
abstract class BiziVoice {
  // start listening; onWords(words, done) as the person speaks. false = no microphone / no permission / not here
  Future<bool> start(String lang, void Function(String words, bool done) onWords, {void Function()? onEnd});
  Future<void> stop();

  static BiziVoice instance = _PhoneVoice(); // tests put a fake one here
}

class _PhoneVoice implements BiziVoice {
  final _stt = SpeechToText();
  bool _ready = false;
  void Function()? _onEnd;

  @override
  Future<bool> start(String lang, void Function(String words, bool done) onWords, {void Function()? onEnd}) async {
    _onEnd = onEnd;
    try {
      if (!_ready) {
        _ready = await _stt.initialize(
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') _onEnd?.call();
          },
          onError: (_) => _onEnd?.call(),
        );
      }
      if (!_ready) return false;
      // Khmer when this phone can (km-KH / km_KH), else the phone's English
      final all = await _stt.locales();
      String? pick(String code) => all.where((l) => l.localeId.toLowerCase().replaceAll('-', '_').startsWith(code)).map((l) => l.localeId).firstOrNull;
      final locale = lang == 'km' ? (pick('km') ?? pick('en')) : (pick('en_us') ?? pick('en'));
      await _stt.listen(
        onResult: (r) => onWords(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: locale,
          partialResults: true,
          listenMode: ListenMode.search,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
