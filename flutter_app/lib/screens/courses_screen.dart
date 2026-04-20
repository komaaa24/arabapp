import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COURSES SCREEN
// ─────────────────────────────────────────────────────────────────────────────

/// XP va streak serverdan kelganda yoki lokal hisoblanganda chaqiriladi.
typedef OnXpEarned = void Function({required int xp, required int streak});

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, this.onXpEarned});
  final OnXpEarned? onXpEarned;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await ApiService.instance.getCourses();
      if (mounted) setState(() => _courses = courses);
    } catch (e) {
      if (mounted) setState(() => _error = 'Internet aloqasini tekshiring');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F766E),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Kurslar',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0E7490)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 20),
                      Text('🌙',
                          style:
                              TextStyle(fontSize: 36, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F766E))),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorWidget(message: _error!, onRetry: _load),
            )
          else if (_courses.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Hozircha kurs mavjud emas')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _CourseCard(
                      course: _courses[i], onXpEarned: widget.onXpEarned),
                  childCount: _courses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, this.onXpEarned});
  final Course course;
  final OnXpEarned? onXpEarned;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                LessonsScreen(course: course, onXpEarned: onXpEarned)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            course.level,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward_ios,
                            size: 12, color: Color(0xFF0F766E)),
                        const SizedBox(width: 4),
                        Text(
                          'Darslarni ko\'rish',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F766E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LESSONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key, required this.course, this.onXpEarned});
  final Course course;
  final OnXpEarned? onXpEarned;

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<Lesson> _lessons = [];
  Set<int> _completed = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = AuthService.instance.user?.id ?? '';
      final token = AuthService.instance.token;
      final syncResult = userId.isNotEmpty
          ? await ApiService.instance.syncQueuedLessonCompletions(
              userId: userId,
              token: token,
            )
          : null;

      final results = await Future.wait([
        ApiService.instance.getLessons(widget.course.id),
        ApiService.instance.getCompletedLessons(userId: userId),
      ]);
      if (syncResult != null) {
        widget.onXpEarned?.call(
          xp: syncResult['xp'] ?? 0,
          streak: syncResult['streak'] ?? 0,
        );
      }
      if (mounted) {
        setState(() {
          _lessons = results[0] as List<Lesson>;
          _completed = results[1] as Set<int>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Internet aloqasini tekshiring');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final userId = AuthService.instance.user?.id ?? '';
    final completed =
        await ApiService.instance.getCompletedLessons(userId: userId);
    if (mounted) setState(() => _completed = completed);
  }

  @override
  Widget build(BuildContext context) {
    final completedCount =
        _lessons.where((l) => _completed.contains(l.id)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        title: Text(widget.course.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : _error != null
              ? _ErrorWidget(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    // Progress banner
                    Container(
                      color: const Color(0xFF0F766E),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$completedCount / ${_lessons.length} dars',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '${_lessons.isEmpty ? 0 : (completedCount / _lessons.length * 100).round()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _lessons.isEmpty
                                  ? 0
                                  : completedCount / _lessons.length,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lessons list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _lessons.length,
                        itemBuilder: (ctx, i) {
                          final lesson = _lessons[i];
                          final isDone = _completed.contains(lesson.id);
                          // Birinchi dars yoki oldingi bajarilgan bo'lsa ochiladi
                          final isUnlocked =
                              i == 0 || _completed.contains(_lessons[i - 1].id);

                          return _LessonTile(
                            lesson: lesson,
                            index: i + 1,
                            isDone: isDone,
                            isUnlocked: isUnlocked,
                            onTap: isUnlocked
                                ? () async {
                                    await Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) => LessonPlayerScreen(
                                          lesson: lesson,
                                          onXpEarned: widget.onXpEarned,
                                        ),
                                      ),
                                    );
                                    _refresh();
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.index,
    required this.isDone,
    required this.isUnlocked,
    this.onTap,
  });

  final Lesson lesson;
  final int index;
  final bool isDone;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? const Color(0xFF10B981)
        : isUnlocked
            ? const Color(0xFF0F766E)
            : const Color(0xFFD1D5DB);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? const Color(0xFF10B981).withOpacity(0.4)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Raqam yoki holat
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check_circle, color: color, size: 22)
                      : !isUnlocked
                          ? Icon(Icons.lock_outline, color: color, size: 18)
                          : Text(
                              '$index',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontSize: 15,
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 14),

              // Sarlavha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (isDone)
                      const Text('Bajarildi ✓',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF10B981)))
                    else if (!isUnlocked)
                      const Text('Qulflangan',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))
                    else
                      Text(
                        '+${lesson.xpReward} XP',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF0F766E)),
                      ),
                  ],
                ),
              ),

              if (isUnlocked && !isDone)
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Color(0xFF0F766E)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LESSON PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key, required this.lesson, this.onXpEarned});
  final Lesson lesson;
  final OnXpEarned? onXpEarned;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  List<LessonStep> _steps = [];
  List<Exercise> _exercises = [];
  bool _loading = true;
  String? _error;

  int _currentIndex = 0;
  bool _showingExercises = false;
  int _exerciseIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _hearts = 3;
  int _earnedXp = 0; // local XP (fallback)
  int _correctAnswers = 0; // server score hisoblash uchun
  List<Map<String, dynamic>> _progressAnswers = [];

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlaying = false;
  bool _audioLoading = false;

  bool get _isLast => _showingExercises
      ? _exerciseIndex >= _exercises.length - 1
      : _currentIndex >= _steps.length - 1 && _exercises.isEmpty;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _audioPlaying = state == PlayerState.playing;
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            _audioLoading = false;
          }
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      setState(() => _audioLoading = true);
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _audioLoading = false);
    } catch (e) {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _audioPlaying = false);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.instance.getLessonSteps(widget.lesson.id),
        ApiService.instance.getExercises(widget.lesson.id),
      ]);
      if (mounted) {
        setState(() {
          _steps = (results[0] as List<LessonStep>)
              .where((step) => step.stepType != 'exercise')
              .toList();
          _exercises = results[1] as List<Exercise>;
          _loading = false;
        });
        // Birinchi step-dagi audio avtomatik ijro
        if (_steps.isNotEmpty && _steps[0].audioUrl != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _playAudio(_steps[0].audioUrl);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ma\'lumotlarni yuklab bo\'lmadi';
          _loading = false;
        });
      }
    }
  }

  void _next() {
    _stopAudio();
    setState(() {
      _selectedAnswer = null;
      _answered = false;

      if (!_showingExercises) {
        if (_currentIndex < _steps.length - 1) {
          _currentIndex++;
          // Yangi step-ga o'tganda audio avtomatik ijro
          final nextStep = _steps[_currentIndex];
          if (nextStep.audioUrl != null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _playAudio(nextStep.audioUrl);
            });
          }
        } else if (_exercises.isNotEmpty) {
          _showingExercises = true;
          _exerciseIndex = 0;
        } else {
          _complete();
        }
      } else {
        if (_exerciseIndex < _exercises.length - 1) {
          _exerciseIndex++;
        } else {
          _complete();
        }
      }
    });
  }

  void _checkAnswer() {
    if (_selectedAnswer == null || _answered) return;
    final exercise = _exercises[_exerciseIndex];
    final correct = _selectedAnswer == exercise.correctAnswer;
    setState(() {
      _answered = true;
      _progressAnswers = [
        ..._progressAnswers,
        {
          'id': exercise.id,
          'correct': correct,
        }
      ];
      if (correct) {
        _earnedXp += 5;
        _correctAnswers++;
      } else {
        _hearts = (_hearts - 1).clamp(0, 3);
      }
    });

    final userId = AuthService.instance.user?.id ?? '';
    final token = AuthService.instance.token;
    if (userId.isNotEmpty) {
      unawaited(ApiService.instance.submitAnswer(
        userId: userId,
        exerciseId: exercise.id,
        answer: _selectedAnswer!,
        correctAnswer: exercise.correctAnswer,
        token: token,
      ));
      unawaited(ApiService.instance.saveProgress(
        userId: userId,
        lessonId: widget.lesson.id,
        currentQuestion: _exerciseIndex + 1,
        correct: _correctAnswers,
        answers: _progressAnswers,
        token: token,
      ));
    }

    if (_hearts == 0) {
      Future.delayed(const Duration(milliseconds: 800), _showFailDialog);
    }
  }

  void _showFailDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💔 Yurak tugadi!'),
        content:
            const Text('Xatolar ko\'p bo\'ldi. Darsni qaytadan boshlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Chiqish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showingExercises = false;
                _currentIndex = 0;
                _exerciseIndex = 0;
                _hearts = 3;
                _earnedXp = 0;
                _correctAnswers = 0;
                _progressAnswers = [];
                _selectedAnswer = null;
                _answered = false;
              });
            },
            child:
                const Text('Qaytadan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _complete() async {
    final totalExercises = _exercises.length;
    final safeTotal = totalExercises < 0 ? 0 : totalExercises;
    final safeCorrect = _correctAnswers.clamp(0, safeTotal);
    final score = safeTotal > 0
        ? ((safeCorrect / safeTotal) * 100).round().clamp(0, 100)
        : 100;

    final userId = AuthService.instance.user?.id ?? '';

    // Lokal holat va score saqlanadi, API yiqilsa keyin qayta yuboriladi.
    await ApiService.instance.markLessonCompleted(
      widget.lesson.id,
      userId: userId,
      score: score,
    );
    await ApiService.instance.queueLessonCompletion(
      userId: userId,
      lessonId: widget.lesson.id,
      correct: safeCorrect,
      total: safeTotal,
    );
    final token = AuthService.instance.token;
    final serverResult = userId.isNotEmpty
        ? await ApiService.instance.syncQueuedLessonCompletions(
            userId: userId,
            token: token,
          )
        : null;

    final localXp = widget.lesson.xpReward + _earnedXp;
    final earnedXp = serverResult?['xp'] ?? localXp;
    final earnedStreak = serverResult?['streak'] ?? 0;
    widget.onXpEarned?.call(xp: earnedXp, streak: earnedStreak);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉',
                style: TextStyle(fontSize: 52), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Dars tugadi!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '+$earnedXp XP qo\'lga kiritdingiz',
              style: const TextStyle(color: Color(0xFF0F766E)),
              textAlign: TextAlign.center,
            ),
            if (score > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Ball: $score / 100',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // player
            },
            child: const Text('Davom etish',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          title:
              Text(widget.lesson.title, style: const TextStyle(fontSize: 15)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F766E))),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        body: _ErrorWidget(message: _error!, onRetry: _load),
      );
    }

    if (_steps.isEmpty && _exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          title: Text(widget.lesson.title),
        ),
        body: const Center(child: Text('Bu darsda hozircha ma\'lumot yo\'q')),
      );
    }

    final totalItems = _steps.length + _exercises.length;
    final doneItems =
        _showingExercises ? _steps.length + _exerciseIndex : _currentIndex;
    final progress = totalItems == 0 ? 0.0 : doneItems / totalItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        title: Text(widget.lesson.title, style: const TextStyle(fontSize: 15)),
        actions: [
          // Yuraklar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: List.generate(
                3,
                (i) => Icon(
                  i < _hearts ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 4,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _showingExercises
                ? _ExerciseView(
                    exercise: _exercises[_exerciseIndex],
                    selectedAnswer: _selectedAnswer,
                    answered: _answered,
                    onSelect: (a) {
                      if (!_answered) setState(() => _selectedAnswer = a);
                    },
                  )
                : _StepView(
                    step: _steps[_currentIndex],
                    isPlaying: _audioPlaying,
                    isLoading: _audioLoading,
                    onPlay: () => _playAudio(_steps[_currentIndex].audioUrl),
                    onStop: _stopAudio,
                  ),
          ),

          // Bottom button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _showingExercises
                  ? Column(
                      children: [
                        if (_answered)
                          _AnswerFeedback(
                            correct: _selectedAnswer ==
                                _exercises[_exerciseIndex].correctAnswer,
                            correctAnswer:
                                _exercises[_exerciseIndex].correctAnswer,
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _answered
                                  ? (_selectedAnswer ==
                                          _exercises[_exerciseIndex]
                                              .correctAnswer
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  : (_selectedAnswer != null
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFD1D5DB)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: _selectedAnswer == null
                                ? null
                                : _answered
                                    ? _next
                                    : _checkAnswer,
                            child: Text(
                              _answered
                                  ? (_isLast ? 'Tugatish' : 'Keyingi')
                                  : 'Tekshirish',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _next,
                        child: Text(
                          _isLast && _exercises.isEmpty
                              ? 'Tugatish'
                              : 'Davom etish',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step views
// ─────────────────────────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlay,
    required this.onStop,
  });
  final LessonStep step;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: step.stepType == 'letter'
          ? _LetterCard(
              step: step,
              isPlaying: isPlaying,
              isLoading: isLoading,
              onPlay: onPlay,
              onStop: onStop,
            )
          : _IntroCard(
              step: step,
              isPlaying: isPlaying,
              isLoading: isLoading,
              onPlay: onPlay,
              onStop: onStop,
            ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.step,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlay,
    required this.onStop,
  });
  final LessonStep step;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasAudio = step.audioUrl != null;
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0E7490)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('📖', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                step.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasAudio) ...[
                const SizedBox(height: 16),
                _AudioButton(
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  onPlay: onPlay,
                  onStop: onStop,
                  light: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(
            step.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.step,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlay,
    required this.onStop,
  });
  final LessonStep step;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasAudio = step.audioUrl != null;
    return Column(
      children: [
        const SizedBox(height: 12),
        // Arabic letter — katta doira
        if (step.arabicText != null && step.arabicText!.isNotEmpty)
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF0F766E).withOpacity(0.2),
                        blurRadius: 24,
                        spreadRadius: 4)
                  ],
                ),
                child: Center(
                  child: Text(
                    step.arabicText!,
                    style: const TextStyle(
                      fontSize: 80,
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w400,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              // Audio tugmasi harf doirasining pastki o'ng tomonida
              if (hasAudio)
                GestureDetector(
                  onTap: isPlaying ? onStop : onPlay,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF0F766E).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),

        // Title
        Text(
          step.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Transcription + audio
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (step.transcription != null && step.transcription!.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '/${step.transcription}/',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF0F766E),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Agar harf doirasi yo'q bo'lsa — bu yerda audio tugma
            if (hasAudio &&
                (step.arabicText == null || step.arabicText!.isEmpty)) ...[
              const SizedBox(width: 10),
              _AudioButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                onPlay: onPlay,
                onStop: onStop,
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Content
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(
            step.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Qayta tinglash tugmasi (pastda)
        if (hasAudio) ...[
          const SizedBox(height: 16),
          _AudioButton(
            isPlaying: isPlaying,
            isLoading: isLoading,
            onPlay: onPlay,
            onStop: onStop,
            label: isPlaying ? 'To\'xtatish' : 'Qayta tinglash',
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio button widget
// ─────────────────────────────────────────────────────────────────────────────

class _AudioButton extends StatelessWidget {
  const _AudioButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onPlay,
    required this.onStop,
    this.label,
    this.light = false,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final String? label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final bg = light
        ? Colors.white.withOpacity(0.25)
        : const Color(0xFF0F766E).withOpacity(0.1);
    final fg = light ? Colors.white : const Color(0xFF0F766E);

    return GestureDetector(
      onTap: isLoading ? null : (isPlaying ? onStop : onPlay),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            : const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPlaying
              ? (light
                  ? Colors.white.withOpacity(0.35)
                  : const Color(0xFF0F766E).withOpacity(0.18))
              : bg,
          borderRadius: BorderRadius.circular(label != null ? 30 : 50),
          border: Border.all(
            color: fg.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : _AnimatedAudioIcon(isPlaying: isPlaying, color: fg),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(label!,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedAudioIcon extends StatefulWidget {
  const _AnimatedAudioIcon({required this.isPlaying, required this.color});
  final bool isPlaying;
  final Color color;

  @override
  State<_AnimatedAudioIcon> createState() => _AnimatedAudioIconState();
}

class _AnimatedAudioIconState extends State<_AnimatedAudioIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.isPlaying) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedAudioIcon old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        widget.isPlaying
            ? Icons.volume_up_rounded
            : Icons.play_circle_filled_rounded,
        color: widget.color,
        size: 22,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise view
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseView extends StatelessWidget {
  const _ExerciseView({
    required this.exercise,
    required this.selectedAnswer,
    required this.answered,
    required this.onSelect,
  });

  final Exercise exercise;
  final String? selectedAnswer;
  final bool answered;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Savol',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Text(
              exercise.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Javobni tanlang',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...exercise.options.map(
            (option) => _OptionTile(
              option: option,
              isSelected: selectedAnswer == option,
              isCorrect: answered && option == exercise.correctAnswer,
              isWrong: answered &&
                  selectedAnswer == option &&
                  option != exercise.correctAnswer,
              onTap: answered ? null : () => onSelect(option),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    this.onTap,
  });

  final String option;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Color textColor;

    if (isCorrect) {
      borderColor = const Color(0xFF10B981);
      bgColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF065F46);
    } else if (isWrong) {
      borderColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B);
    } else if (isSelected) {
      borderColor = const Color(0xFF0F766E);
      bgColor = const Color(0xFFCCFBF1);
      textColor = const Color(0xFF0F766E);
    } else {
      borderColor = const Color(0xFFE5E7EB);
      bgColor = Colors.white;
      textColor = const Color(0xFF374151);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
            else if (isWrong)
              const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20),
          ],
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.correct, required this.correctAnswer});
  final bool correct;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: correct ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ),
      child: Row(
        children: [
          Text(
            correct ? '✅' : '❌',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correct
                  ? 'To\'g\'ri! Ajoyib!'
                  : 'To\'g\'ri javob: $correctAnswer',
              style: TextStyle(
                color:
                    correct ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Qayta urinish',
                  style: TextStyle(color: Colors.white)),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
