import 'dart:async';

import 'package:http/http.dart' as http;

class AudioResolver {
  AudioResolver._();

  static const recordedAudioBase = 'http://213.230.110.176:9009/sounds';
  static const ttsAudioBase = 'https://translate.google.com/translate_tts';

  static final Map<String, bool> _reachabilityCache = <String, bool>{};

  static const Map<int, List<String>> _recordedNameCandidates = {
    1: ['alif'],
    2: ['ba'],
    3: ['ta', 'taa'],
    4: ['tha', 'thaa'],
    5: ['jiim'],
    6: ['ha'],
    7: ['kha'],
    8: ['daal'],
    9: ['thaal'],
    10: ['ra'],
    11: ['zay'],
    12: ['siin'],
    13: ['shiin'],
    14: ['saad'],
    15: ['daad'],
    16: ['taa', 'ta'],
    17: ['thaa'],
    18: ['ayn'],
    19: ['ghayn'],
    20: ['fa'],
    21: ['qaf'],
    22: ['kaf'],
    23: ['lam'],
    24: ['miim'],
    25: ['nuun'],
    26: ['ha'],
    27: ['waw'],
    28: ['ya'],
  };

  static const Map<int, String> _soundTextMap = {
    1: 'اَ',
    2: 'بَ',
    3: 'تَ',
    4: 'ثَ',
    5: 'جَ',
    6: 'حَ',
    7: 'خَ',
    8: 'دَ',
    9: 'ذَ',
    10: 'رَ',
    11: 'زَ',
    12: 'سَ',
    13: 'شَ',
    14: 'صَ',
    15: 'ضَ',
    16: 'طَ',
    17: 'ظَ',
    18: 'عَ',
    19: 'غَ',
    20: 'فَ',
    21: 'قَ',
    22: 'كَ',
    23: 'لَ',
    24: 'مَ',
    25: 'نَ',
    26: 'هَ',
    27: 'وَ',
    28: 'يَ',
  };

  static const Map<String, int> _arabicLetterToId = {
    'ا': 1,
    'ب': 2,
    'ت': 3,
    'ث': 4,
    'ج': 5,
    'ح': 6,
    'خ': 7,
    'د': 8,
    'ذ': 9,
    'ر': 10,
    'ز': 11,
    'س': 12,
    'ش': 13,
    'ص': 14,
    'ض': 15,
    'ط': 16,
    'ظ': 17,
    'ع': 18,
    'غ': 19,
    'ف': 20,
    'ق': 21,
    'ك': 22,
    'ل': 23,
    'م': 24,
    'ن': 25,
    'ه': 26,
    'و': 27,
    'ي': 28,
  };

  static bool canResolveLessonStepAudio({
    String? providedUrl,
    String? arabicText,
    String? title,
    String? content,
    String? transcription,
  }) {
    if (_normalizeUrl(providedUrl) != null) return true;
    return _extractLetterId(
          arabicText: arabicText,
          title: title,
          content: content,
          transcription: transcription,
        ) !=
        null;
  }

  static Future<String?> resolveLetterNameAudio({
    required int letterId,
    String? arabicText,
  }) async {
    final urls = _candidateRecordedUrlsForLetterId(letterId);
    final reachable = await _firstReachableUrl(urls);
    if (reachable != null) return reachable;

    final fallbackId =
        letterId == 0 ? _extractLetterId(arabicText: arabicText) : letterId;
    if (fallbackId == null) return null;
    return ttsSoundUrlForLetterId(fallbackId);
  }

  static String? ttsSoundUrlForLetterId(int letterId) {
    final sound = _soundTextMap[letterId];
    if (sound == null || sound.isEmpty) return null;
    return '$ttsAudioBase?ie=UTF-8&client=tw-ob&tl=ar&q=${Uri.encodeQueryComponent(sound)}';
  }

  static Future<String?> resolveLessonStepAudio({
    String? providedUrl,
    String? arabicText,
    String? title,
    String? content,
    String? transcription,
  }) async {
    final normalizedProvided = _normalizeUrl(providedUrl);
    if (normalizedProvided != null && await _isReachable(normalizedProvided)) {
      return normalizedProvided;
    }

    final letterId = _extractLetterId(
      arabicText: arabicText,
      title: title,
      content: content,
      transcription: transcription,
    );
    if (letterId != null) {
      final resolved = await resolveLetterNameAudio(
        letterId: letterId,
        arabicText: arabicText,
      );
      if (resolved != null) return resolved;
    }

    return normalizedProvided;
  }

  static List<String> _candidateRecordedUrlsForLetterId(int letterId) {
    final names = _recordedNameCandidates[letterId] ?? const <String>[];
    return names
        .map((name) => '$recordedAudioBase/$name.mp3')
        .toList(growable: false);
  }

  static Future<String?> _firstReachableUrl(List<String> urls) async {
    for (final url in urls) {
      if (await _isReachable(url)) return url;
    }
    return null;
  }

  static Future<bool> _isReachable(String url) async {
    final cached = _reachabilityCache[url];
    if (cached != null) return cached;

    bool ok = false;
    try {
      final uri = Uri.parse(url);
      final head = await http.head(uri).timeout(const Duration(seconds: 5));
      ok = head.statusCode >= 200 && head.statusCode < 400;
      if (!ok && (head.statusCode == 403 || head.statusCode == 405)) {
        final get = await http.get(uri, headers: const {
          'Range': 'bytes=0-0'
        }).timeout(const Duration(seconds: 5));
        ok = get.statusCode >= 200 && get.statusCode < 400;
      }
    } catch (_) {
      ok = false;
    }

    _reachabilityCache[url] = ok;
    return ok;
  }

  static String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) return value;
    if (value.startsWith('/sounds/')) {
      return 'http://213.230.110.176:9009$value';
    }
    return null;
  }

  static int? _extractLetterId({
    String? arabicText,
    String? title,
    String? content,
    String? transcription,
  }) {
    for (final candidate in [arabicText, title, content, transcription]) {
      final letter = _extractArabicLetter(candidate);
      if (letter != null) return _arabicLetterToId[letter];
    }
    return null;
  }

  static String? _extractArabicLetter(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll('ـ', '');
    for (final rune in cleaned.runes) {
      final char = String.fromCharCode(rune);
      if (_arabicLetterToId.containsKey(char)) return char;
    }
    return null;
  }
}
