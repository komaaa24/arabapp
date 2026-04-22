import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_secrets.dart';

/// API model-lari

class Course {
  final int id;
  final String title;
  final String description;
  final String level;
  final String language;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.language,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: _int(j['id']),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        level: '${j['level'] ?? ''}',
        language: '${j['language'] ?? ''}',
      );
}

class Lesson {
  final int id;
  final int courseId;
  final String title;
  final int orderIndex;
  final int xpReward;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.xpReward,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: _int(j['id']),
        courseId: _int(j['course_id']),
        title: '${j['title'] ?? ''}',
        orderIndex: _int(j['order_index']),
        xpReward: _int(j['xp_reward']),
      );
}

class LessonStep {
  final int id;
  final int lessonId;
  final String stepType; // intro, letter, exercise
  final String title;
  final String content;
  final int orderIndex;
  final String? arabicText;
  final String? transcription;
  final String? audioUrl;

  const LessonStep({
    required this.id,
    required this.lessonId,
    required this.stepType,
    required this.title,
    required this.content,
    required this.orderIndex,
    this.arabicText,
    this.transcription,
    this.audioUrl,
  });

  factory LessonStep.fromJson(Map<String, dynamic> j) {
    // Audio URL ni tozalash — bo'sh fayl nomli URL-larni filtrlash
    String? fixAudio(dynamic raw) {
      if (raw == null) return null;
      final url = '$raw'.trim();
      if (url.isEmpty) return null;
      // Bo'sh fayl nomi: "/sounds/.mp3" → bekor qilish
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final filename = uri.pathSegments.lastOrNull ?? '';
      if (filename.isEmpty || filename == '.mp3') return null;
      return url;
    }

    return LessonStep(
      id: _int(j['id']),
      lessonId: _int(j['lesson_id']),
      stepType: '${j['step_type'] ?? 'intro'}'.toLowerCase(),
      title: '${j['title'] ?? ''}',
      content: '${j['content'] ?? ''}',
      orderIndex: _int(j['order_index']),
      arabicText: j['arabic_text'] as String?,
      transcription: j['transcription'] as String?,
      audioUrl: fixAudio(j['audio']) ??
          fixAudio(j['audio_letter']) ??
          fixAudio(j['audio_url']),
    );
  }
}

class Exercise {
  final int id;
  final String type;
  final String question;
  final String correctAnswer;
  final List<String> options;

  const Exercise({
    required this.id,
    required this.type,
    required this.question,
    required this.correctAnswer,
    required this.options,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: _int(j['id']),
        type: '${j['type'] ?? 'choice'}',
        question: '${j['question'] ?? ''}',
        correctAnswer: '${j['correct_answer'] ?? ''}',
        options: j['options'] is List
            ? List<String>.from((j['options'] as List).map((e) => '$e'))
            : [],
      );
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// API xizmat — caching va xato boshqarish bilan

class ApiService {
  static const _base = AppSecrets.phpBaseUrl;
  static const _cacheTtl = Duration(hours: 6);
  static final ApiService instance = ApiService._();
  ApiService._();

  // ─── Completed lessons (SharedPreferences) ───

  static const _completedKey = 'completed_lessons_v1';
  static const _completedScoresKey = 'completed_lesson_scores_v1';
  static const _pendingCompletionsKey = 'pending_lesson_completions_v1';

  Future<Set<int>> getCompletedLessons({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_completedLessonsKey(userId)) ?? [];
      return list.map((e) => int.tryParse(e) ?? 0).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<int, int>> getCompletedLessonScores({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_completedScoresStorageKey(userId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(_int(key), _int(value)));
    } catch (_) {
      return {};
    }
  }

  Future<void> markLessonCompleted(
    int lessonId, {
    required String userId,
    int? score,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_completedLessonsKey(userId)) ?? [];
      if (!list.contains('$lessonId')) {
        list.add('$lessonId');
        await prefs.setStringList(_completedLessonsKey(userId), list);
      }
      if (score != null) {
        final scores = await getCompletedLessonScores(userId: userId);
        scores[lessonId] = score.clamp(0, 100);
        await prefs.setString(
          _completedScoresStorageKey(userId),
          jsonEncode(scores),
        );
      }
    } catch (_) {}
  }

  Future<void> queueLessonCompletion({
    required String userId,
    required int lessonId,
    required int correct,
    required int total,
  }) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = await _getPendingLessonCompletions(userId);
      pending['$lessonId'] = {
        'user_id': userId,
        'lesson_id': lessonId,
        'correct': correct.clamp(0, total < 0 ? 0 : total),
        'total': total < 0 ? 0 : total,
      };
      await prefs.setString(
        _pendingCompletionsStorageKey(userId),
        jsonEncode(pending),
      );
    } catch (_) {}
  }

  Future<Map<String, int>?> syncQueuedLessonCompletions({
    required String userId,
    String? token,
  }) async {
    if (userId.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final pending = await _getPendingLessonCompletions(userId);
    if (pending.isEmpty) return null;

    final entries = pending.entries.toList()
      ..sort((a, b) => _int(a.key).compareTo(_int(b.key)));

    Map<String, int>? latest;
    var changed = false;

    for (final entry in entries) {
      final payload = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : <String, dynamic>{};
      final payloadUserId = '${payload['user_id'] ?? userId}';
      final lessonId = _int(payload['lesson_id'] ?? entry.key);
      final total = _int(payload['total']);
      final correct = _int(payload['correct']).clamp(0, total < 0 ? 0 : total);
      if (payloadUserId.isEmpty || lessonId <= 0) continue;

      final result = await notifyLessonCompleted(
        userId: payloadUserId,
        lessonId: lessonId,
        correct: correct,
        total: total,
        token: token,
      );
      if (result != null) {
        pending.remove(entry.key);
        latest = result;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString(
        _pendingCompletionsStorageKey(userId),
        jsonEncode(pending),
      );
    }

    return latest;
  }

  // ─── Endpoints ───

  Future<List<Course>> getCourses() async {
    final data = await _get('courses');
    return data.map(Course.fromJson).toList();
  }

  Future<List<Lesson>> getLessons(int courseId) async {
    final data = await _get('lessons', {'course_id': '$courseId'});
    final lessons = data.map(Lesson.fromJson).toList();
    lessons.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return lessons;
  }

  Future<List<LessonStep>> getLessonSteps(int lessonId) async {
    final data = await _get('lesson_steps', {'lesson_id': '$lessonId'});
    final steps = data.map(LessonStep.fromJson).toList();
    steps.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return steps;
  }

  Future<List<Exercise>> getExercises(int lessonId) async {
    final data = await _get('exercises', {'lesson_id': '$lessonId'});
    return data.map(Exercise.fromJson).toList();
  }

  Future<List<Lesson>> getAllLessons() async {
    final courses = await getCourses();
    final all = <Lesson>[];
    for (final course in courses) {
      all.addAll(await getLessons(course.id));
    }
    all.sort((a, b) {
      final byCourse = a.courseId.compareTo(b.courseId);
      if (byCourse != 0) return byCourse;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return all;
  }

  Future<void> saveProgress({
    required String userId,
    required int lessonId,
    required int currentQuestion,
    required int correct,
    required List<Map<String, dynamic>> answers,
    String? token,
  }) async {
    if (userId.isEmpty || lessonId <= 0) return;
    try {
      final uri = Uri.parse("$_base?route=save_progress");
      final payload = <String, dynamic>{
        'user_id': userId,
        'lesson_id': lessonId,
        'current_question': currentQuestion,
        'correct': correct,
        'answers': answers
            .map((item) => {
                  'id': _int(item['id']),
                  'correct': item['correct'] == true,
                })
            .toList(growable: false),
      };
      debugPrint('[Api] save_progress -> ${jsonEncode(payload)}');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('[Api] save_progress response: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('[Api] save_progress error: $e');
    }
  }

  // ─── Progress endpoints ───
  //
  // PHP kutgan format (Postman da ishlagan):
  //   POST {AppSecrets.phpBaseUrl}?route=complete_lesson
  //   Content-Type: application/json
  //   Body: { "user_id": "uuid", "lesson_id": 1, "correct": 2, "total": 5 }
  //
  //   POST {AppSecrets.phpBaseUrl}?route=answer
  //   Content-Type: application/json
  //   Body: { "user_id": "uuid", "exercise_id": 1, "answer": "ب" }

  /// Dars yakunlanganda serverga xabar beradi.
  /// POST ?route=complete_lesson
  /// Body: { "user_id": "...", "lesson_id": 1, "correct": 2, "total": 5 }
  Future<Map<String, int>?> notifyLessonCompleted({
    required String userId,
    required int lessonId,
    required int correct,
    required int total,
    String? token,
  }) async {
    if (userId.isEmpty) return null;
    try {
      final uri = Uri.parse("$_base?route=complete_lesson");
      final safeTotal = total < 0 ? 0 : total;
      final safeCorrect = correct.clamp(0, safeTotal);
      final body = jsonEncode({
        "user_id": userId,
        "lesson_id": lessonId,
        "correct": safeCorrect,
        "total": safeTotal,
      });
      debugPrint("[Api] notifyLessonCompleted -> $body");
      final res = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              if (token != null && token.isNotEmpty)
                "Authorization": "Bearer $token",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      debugPrint(
          "[Api] complete_lesson response: ${res.statusCode} ${res.body}");
      if (res.statusCode != 200 && res.statusCode != 201) return null;

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) return null;
      if (decoded['error'] != null) return null;
      final root = (decoded["data"] is Map)
          ? Map<String, dynamic>.from(decoded["data"] as Map)
          : Map<String, dynamic>.from(decoded);
      final xpRoot = root['xp'] is Map
          ? Map<String, dynamic>.from(root['xp'] as Map)
          : <String, dynamic>{};
      final levelRoot = root['level'] is Map
          ? Map<String, dynamic>.from(root['level'] as Map)
          : <String, dynamic>{};
      final progressRoot = root['progress'] is Map
          ? Map<String, dynamic>.from(root['progress'] as Map)
          : <String, dynamic>{};
      final lessonResult = root['lesson_result'] is Map
          ? Map<String, dynamic>.from(root['lesson_result'] as Map)
          : <String, dynamic>{};
      return {
        "xp": _int(xpRoot['total']),
        "xp_gained": _int(xpRoot['gained']),
        "streak": _int(root['streak']),
        "level": _int(levelRoot['current']),
        "completed_lessons": _int(progressRoot['completed_lessons']),
        "score": _int(lessonResult['score']),
      };
    } catch (e) {
      debugPrint("[Api] notifyLessonCompleted error: $e");
      return null;
    }
  }

  /// Mashq javobini serverga yuboradi.
  /// POST ?route=answer
  /// Body: { "user_id": "...", "exercise_id": 1, "answer": "ب", "correct": "ب" }
  Future<void> submitAnswer({
    required String userId,
    required int exerciseId,
    required String answer,
    required String correctAnswer,
    String? token,
  }) async {
    if (userId.isEmpty) return;
    try {
      final uri = Uri.parse("$_base?route=answer");
      final body = jsonEncode({
        "user_id": userId,
        "exercise_id": exerciseId,
        "answer": answer,
        "correct": correctAnswer,
      });
      debugPrint("[Api] submitAnswer -> $body");
      final res = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              if (token != null && token.isNotEmpty)
                "Authorization": "Bearer $token",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      debugPrint("[Api] answer response: ${res.statusCode} ${res.body}");
    } catch (e) {
      debugPrint("[Api] submitAnswer error: $e");
    }
  }

  // ─── Internal ───

  String _scopeUser(String? userId) {
    final normalized = (userId ?? '').trim();
    if (normalized.isEmpty) return 'guest';
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  String _completedLessonsKey(String? userId) =>
      '${_completedKey}_${_scopeUser(userId)}';

  String _completedScoresStorageKey(String? userId) =>
      '${_completedScoresKey}_${_scopeUser(userId)}';

  String _pendingCompletionsStorageKey(String? userId) =>
      '${_pendingCompletionsKey}_${_scopeUser(userId)}';

  Future<Map<String, dynamic>> _getPendingLessonCompletions(
      String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingCompletionsStorageKey(userId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _get(
    String route, [
    Map<String, String>? params,
  ]) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'route': route,
      ...?params,
    });
    final cacheKey = 'api_cache_${uri.toString()}';
    final cacheTimeKey = '${cacheKey}_ts';

    // Cache-dan o'qish
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      final ts = prefs.getInt(cacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (cached != null && age < _cacheTtl.inMilliseconds) {
        return _parseList(jsonDecode(cached));
      }
    } catch (_) {}

    // Tarmoqdan olish
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, body);
        await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        return _parseList(jsonDecode(body));
      }
    } catch (e) {
      debugPrint('ApiService error [$route]: $e');
    }

    // Eski cache-ni fallback sifatida qaytarish
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) return _parseList(jsonDecode(cached));
    } catch (_) {}

    return [];
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
