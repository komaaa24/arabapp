import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/courses_screen.dart';
import 'services/auth_service.dart';
import 'widgets/auth_widgets.dart';
import 'utils/audio_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final data = await AppData.load();
  final controller = ProgressController(prefs);
  await controller.initialize();
  await AuthService.instance.initialize();

  runApp(ArabicLearnerApp(data: data, controller: controller));
}

class ArabicLearnerApp extends StatefulWidget {
  const ArabicLearnerApp({
    super.key,
    required this.data,
    required this.controller,
  });

  final AppData data;
  final ProgressController controller;

  @override
  State<ArabicLearnerApp> createState() => _ArabicLearnerAppState();
}

class _ArabicLearnerAppState extends State<ArabicLearnerApp> {
  int _selectedTab = 0;

  void _jumpToTab(int index) {
    if (index < 0 || index > 3) return;
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, AuthService.instance]),
      builder: (context, _) {
        final auth = AuthService.instance;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Arab Tili',
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F5F0),
          ),
          home: auth.isAuthenticated
              ? Scaffold(
                  body: SafeArea(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        HomeScreen(
                          data: widget.data,
                          controller: widget.controller,
                          onOpenSection: _jumpToTab,
                        ),
                        CoursesScreen(
                          onXpEarned: ({required int xp, required int streak}) {
                            if (streak > 0) {
                              widget.controller
                                  .syncFromServer(xp: xp, streak: streak);
                            } else {
                              widget.controller.addXp(xp);
                            }
                          },
                        ),
                        AlphabetScreen(
                            data: widget.data, controller: widget.controller),
                        ProgressScreen(
                            data: widget.data, controller: widget.controller),
                      ],
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _selectedTab,
                    onDestinationSelected: _jumpToTab,
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Bosh'),
                      NavigationDestination(
                          icon: Icon(Icons.play_lesson_outlined),
                          selectedIcon: Icon(Icons.play_lesson),
                          label: 'Kurslar'),
                      NavigationDestination(
                          icon: Icon(Icons.menu_book_outlined),
                          selectedIcon: Icon(Icons.menu_book),
                          label: 'Alifbo'),
                      NavigationDestination(
                          icon: Icon(Icons.bar_chart_outlined),
                          selectedIcon: Icon(Icons.bar_chart),
                          label: 'Progress'),
                    ],
                  ),
                )
              : const _MandatoryAuthScreen(),
        );
      },
    );
  }
}

class _MandatoryAuthScreen extends StatelessWidget {
  const _MandatoryAuthScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 42,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Davom etish uchun Google bilan kiring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Darslar, progress va natijalar faqat ro\'yxatdan o\'tgan foydalanuvchilar uchun ochiladi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const GoogleSignInButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppData {
  const AppData({required this.arabicLetters});

  final List<Map<String, dynamic>> arabicLetters;

  static Future<AppData> load() async {
    final raw = await rootBundle.loadString('assets/data/arabic_data.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    List<Map<String, dynamic>> toMapList(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return AppData(
      arabicLetters: toMapList(json['arabicLetters']),
    );
  }
}

class QuizResult {
  const QuizResult({
    required this.date,
    required this.score,
    required this.total,
    required this.category,
  });

  final String date;
  final int score;
  final int total;
  final String category;

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'score': score,
      'total': total,
      'category': category,
    };
  }

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      date: '${json['date'] ?? ''}',
      score: _asInt(json['score']),
      total: max(1, _asInt(json['total'])),
      category: '${json['category'] ?? 'all'}',
    );
  }
}

class ProgressState {
  const ProgressState({
    required this.completedLetters,
    required this.completedWords,
    required this.quizResults,
    required this.xp,
    required this.streak,
    required this.lastVisit,
  });

  final List<int> completedLetters;
  final List<int> completedWords;
  final List<QuizResult> quizResults;
  final int xp;
  final int streak;
  final String? lastVisit;

  static const ProgressState initial = ProgressState(
    completedLetters: <int>[],
    completedWords: <int>[],
    quizResults: <QuizResult>[],
    xp: 0,
    streak: 0,
    lastVisit: null,
  );

  ProgressState copyWith({
    List<int>? completedLetters,
    List<int>? completedWords,
    List<QuizResult>? quizResults,
    int? xp,
    int? streak,
    String? lastVisit,
    bool clearLastVisit = false,
  }) {
    return ProgressState(
      completedLetters: completedLetters ?? this.completedLetters,
      completedWords: completedWords ?? this.completedWords,
      quizResults: quizResults ?? this.quizResults,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastVisit: clearLastVisit ? null : (lastVisit ?? this.lastVisit),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedLetters': completedLetters,
      'completedWords': completedWords,
      'quizResults': quizResults.map((e) => e.toJson()).toList(),
      'xp': xp,
      'streak': streak,
      'lastVisit': lastVisit,
    };
  }

  factory ProgressState.fromJson(Map<String, dynamic> json) {
    List<int> toIntList(dynamic value) {
      if (value is! List) return const [];
      return value.map((e) => _asInt(e)).toSet().toList(growable: false);
    }

    List<QuizResult> toQuizList(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => QuizResult.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return ProgressState(
      completedLetters: toIntList(json['completedLetters']),
      completedWords: toIntList(json['completedWords']),
      quizResults: toQuizList(json['quizResults']),
      xp: _asInt(json['xp']),
      streak: max(0, _asInt(json['streak'])),
      lastVisit: json['lastVisit'] == null ? null : '${json['lastVisit']}',
    );
  }
}

class ProgressController extends ChangeNotifier {
  ProgressController(this._prefs);

  static const _storageKey = 'arabicLearnerProgress';
  static const int xpPerLevel = 200;

  final SharedPreferences _prefs;
  ProgressState _state = ProgressState.initial;

  ProgressState get state => _state;

  Future<void> initialize() async {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _state = ProgressState.fromJson(json);
      } catch (_) {
        _state = ProgressState.initial;
      }
    }

    _updateDailyStreak();
    await _save();
    notifyListeners();
  }

  // Docs: level = floor(sqrt(total_xp / 10)), minimum 1
  int get level => max(1, sqrt(_state.xp / 10.0).floor());

  double get levelProgress {
    final lvl = level;
    final xpForCurrentLevel = (lvl * lvl * 10);
    final xpForNextLevel = ((lvl + 1) * (lvl + 1) * 10);
    final span = xpForNextLevel - xpForCurrentLevel;
    final progress = (_state.xp - xpForCurrentLevel) / span;
    return progress.clamp(0.0, 1.0);
  }

  int get xpToNextLevel {
    final lvl = level;
    final xpForNextLevel = ((lvl + 1) * (lvl + 1) * 10);
    return max(0, xpForNextLevel - _state.xp);
  }

  void markLetterCompleted(int id) {
    if (_state.completedLetters.contains(id)) return;
    final updated = <int>[..._state.completedLetters, id];
    _state = _state.copyWith(completedLetters: updated, xp: _state.xp + 10);
    _persistAndNotify();
  }

  void markWordCompleted(int id) {
    if (_state.completedWords.contains(id)) return;
    final updated = <int>[..._state.completedWords, id];
    _state = _state.copyWith(completedWords: updated, xp: _state.xp + 5);
    _persistAndNotify();
  }

  void addQuizResult(QuizResult result) {
    final earnedXp = ((result.score / max(1, result.total)) * 50).round();
    _state = _state.copyWith(
      quizResults: <QuizResult>[..._state.quizResults, result],
      xp: _state.xp + earnedXp,
    );
    _persistAndNotify();
  }

  void addXp(int amount) {
    if (amount <= 0) return;
    _state = _state.copyWith(xp: _state.xp + amount);
    _persistAndNotify();
  }

  /// Server javobidan XP, level, streak ni sinxronlashtiradi.
  /// complete_lesson API → {xp, level, streak}
  void syncFromServer({required int xp, required int streak}) {
    if (xp <= _state.xp && streak <= _state.streak) return;
    _state = _state.copyWith(
      xp: xp > _state.xp ? xp : _state.xp,
      streak: streak > 0 ? streak : _state.streak,
    );
    _persistAndNotify();
  }

  void resetProgress() {
    _state = ProgressState.initial;
    _persistAndNotify();
  }

  void _updateDailyStreak() {
    final now = DateTime.now();
    final today = _dateKey(now);
    if (_state.lastVisit == today) return;

    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final consecutive = _state.lastVisit == yesterday;
    _state = _state.copyWith(
      streak: consecutive ? _state.streak + 1 : 1,
      lastVisit: today,
    );
  }

  void _persistAndNotify() {
    unawaited(_save());
    notifyListeners();
  }

  Future<void> _save() async {
    final payload = _state.toJson();
    await _prefs.setString(_storageKey, jsonEncode(payload));
  }
}

class _AuthHeaderButton extends StatefulWidget {
  @override
  State<_AuthHeaderButton> createState() => _AuthHeaderButtonState();
}

class _AuthHeaderButtonState extends State<_AuthHeaderButton> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    return GestureDetector(
      onTap: () => AuthBottomSheet.show(context),
      child: user != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                const UserAvatarBadge(),
              ],
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text('Kirish',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.data,
    required this.controller,
    required this.onOpenSection,
  });

  final AppData data;
  final ProgressController controller;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final progress = controller.state;
    final lettersCompleted = progress.completedLetters.length;

    final sections = <_SectionInfo>[
      const _SectionInfo(
          'Kurslar', 'Online darslar', Icons.play_lesson, 1, Color(0xFF0F766E)),
      const _SectionInfo(
          'Alifbo', '28 ta arab harfi', Icons.menu_book, 2, Color(0xFF2563EB)),
      const _SectionInfo('Progress', 'Natijalar tarixi', Icons.bar_chart, 3,
          Color(0xFF059669)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                  Color(0xFF0E7490),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F766E),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              _greeting(),
                              style: const TextStyle(
                                color: Color(0xFFCCFBF1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Arab tilini o\'rganing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Har kuni oz-ozdan o\'rganib boring.',
                            style: TextStyle(
                              color: Color(0xFFCCFBF1),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    RepaintBoundary(
                      child: _AuthHeaderButton(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _heroMetricCard(
                        icon: Icons.school_rounded,
                        label: 'Daraja',
                        value: controller.level.toString(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _heroMetricCard(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Ketma-ket',
                        value: '${progress.streak} kun',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _heroMetricCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'XP',
                        value: '${progress.xp}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _StatCard(
                  label: 'Harflar',
                  value: '$lettersCompleted/${data.arabicLetters.length}',
                  icon: Icons.menu_book,
                  color: const Color(0xFF2563EB)),
              _StatCard(
                  label: 'XP',
                  value: '${progress.xp}',
                  icon: Icons.emoji_events,
                  color: const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Daraja ${controller.level} -> ${controller.level + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${progress.xp} XP',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  minHeight: 8,
                  value: controller.levelProgress,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keyingi darajagacha ${controller.xpToNextLevel} XP qoldi',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Bo\'limlar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ...sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpenSection(section.tabIndex),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: section.color.withValues(alpha: 0.12),
                        child: Icon(section.icon, color: section.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(section.subtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Color(0xFF9CA3AF)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _heroMetricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFCCFBF1),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Xayrli tong';
    if (hour < 17) return 'Xayrli kun';
    return 'Xayrli kech';
  }
}

class AlphabetScreen extends StatefulWidget {
  const AlphabetScreen(
      {super.key, required this.data, required this.controller});

  final AppData data;
  final ProgressController controller;

  @override
  State<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends State<AlphabetScreen> {
  String _search = '';
  ContentFilter _filter = ContentFilter.all;

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.state;
    final letters = widget.data.arabicLetters.where((letter) {
      final nameUz = '${letter['nameUz'] ?? ''}'.toLowerCase();
      final arabic = '${letter['arabic'] ?? ''}';
      final translit = '${letter['transliteration'] ?? ''}'.toLowerCase();
      final matchSearch = nameUz.contains(_search.toLowerCase()) ||
          arabic.contains(_search) ||
          translit.contains(_search.toLowerCase());
      final completed =
          progress.completedLetters.contains(_asInt(letter['id']));
      final matchFilter = switch (_filter) {
        ContentFilter.all => true,
        ContentFilter.learned => completed,
        ContentFilter.unlearned => !completed,
      };
      return matchSearch && matchFilter;
    }).toList(growable: false);

    final completedCount = progress.completedLetters.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(
            title: 'Arab Alifbosi',
            subtitle:
                '${widget.data.arabicLetters.length} ta harf · $completedCount ta o\'rganildi',
            icon: Icons.menu_book,
            color: const Color(0xFF2563EB),
            progressValue:
                completedCount / max(1, widget.data.arabicLetters.length),
            progressLabel:
                '$completedCount/${widget.data.arabicLetters.length}',
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Harf qidirish...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hammasi'),
                selected: _filter == ContentFilter.all,
                onSelected: (_) => setState(() => _filter = ContentFilter.all),
              ),
              ChoiceChip(
                label: const Text('O\'rganilgan'),
                selected: _filter == ContentFilter.learned,
                onSelected: (_) =>
                    setState(() => _filter = ContentFilter.learned),
              ),
              ChoiceChip(
                label: const Text('O\'rganilmagan'),
                selected: _filter == ContentFilter.unlearned,
                onSelected: (_) =>
                    setState(() => _filter = ContentFilter.unlearned),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (letters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                  child: Text('Harf topilmadi',
                      style: TextStyle(color: Color(0xFF6B7280)))),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: letters.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final letter = letters[index];
                final id = _asInt(letter['id']);
                final completed = progress.completedLetters.contains(id);
                return InkWell(
                  onTap: () => _openLetter(letter, completed),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: completed ? const Color(0xFFECFDF5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: completed
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${letter['arabic'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 34, fontFamily: 'serif')),
                        const SizedBox(height: 2),
                        Text('${letter['nameUz'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${letter['transliteration'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF6B7280))),
                        if (completed)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.check_circle,
                                size: 14, color: Color(0xFF059669)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openLetter(Map<String, dynamic> letter, bool completed) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _LetterDetailSheet(
          letter: letter,
          completed: completed,
          onComplete: () =>
              widget.controller.markLetterCompleted(_asInt(letter['id'])),
        );
      },
    );
  }
}

class _LetterDetailSheet extends StatefulWidget {
  const _LetterDetailSheet({
    required this.letter,
    required this.completed,
    required this.onComplete,
  });

  final Map<String, dynamic> letter;
  final bool completed;
  final VoidCallback onComplete;

  @override
  State<_LetterDetailSheet> createState() => _LetterDetailSheetState();
}

class _LetterDetailSheetState extends State<_LetterDetailSheet>
    with TickerProviderStateMixin {
  final _player = AudioPlayer();
  String? _playingType;
  bool _loading = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed && mounted) {
        setState(() => _playingType = null);
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<String?> _urlFor(String type) async {
    final id = _asInt(widget.letter["id"]);
    final arabicText = '${widget.letter["arabic"] ?? ''}';

    if (type == "sound") {
      return AudioResolver.ttsSoundUrlForLetterId(id);
    }

    return AudioResolver.resolveLetterNameAudio(
      letterId: id,
      arabicText: arabicText,
    );
  }

  Future<void> _tap(String type) async {
    if (_loading) return;
    if (_playingType == type) {
      await _player.stop();
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      if (mounted) setState(() => _playingType = null);
      return;
    }
    final url = await _urlFor(type);
    if (url == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _playingType = type;
      });
    }
    _pulseCtrl.repeat(reverse: true);
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      if (mounted) {
        setState(() {
          _playingType = null;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio yuklanmadi')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forms =
        Map<String, dynamic>.from(widget.letter['forms'] as Map? ?? const {});

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                ),
              ),
              child: Column(
                children: [
                  Text('${widget.letter['arabic'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 64,
                          color: Colors.white,
                          fontFamily: 'serif')),
                  Text('${widget.letter['name'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${widget.letter['nameUz'] ?? ''} \u00b7 /${widget.letter['transliteration'] ?? ''}/',
                      style: const TextStyle(color: Color(0xFFCCFBF1))),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AudioBtn(
                        label: 'Nomi',
                        sublabel: 'Harfning ismi',
                        type: 'name',
                        color: const Color(0xFF2563EB),
                        icon: Icons.record_voice_over_rounded,
                        playingType: _playingType,
                        loading: _loading,
                        pulseAnim: _pulseAnim,
                        onTap: _tap,
                      ),
                      const SizedBox(width: 12),
                      _AudioBtn(
                        label: 'Tovushi',
                        sublabel: 'Harfning ovozi',
                        type: 'sound',
                        color: const Color(0xFFD97706),
                        icon: Icons.spatial_audio_off_rounded,
                        playingType: _playingType,
                        loading: _loading,
                        pulseAnim: _pulseAnim,
                        onTap: _tap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const TabBar(
                    tabs: [
                      Tab(text: "O'rganish"),
                      Tab(text: 'Shakllar'),
                      Tab(text: 'Misol'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoBox(
                          title: 'Talaffuz',
                          text: '${widget.letter['pronunciation'] ?? ''}',
                          color: const Color(0xFFDBEAFE),
                          textColor: const Color(0xFF1D4ED8)),
                      const SizedBox(height: 10),
                      _InfoBox(
                          title: 'Izoh',
                          text: '${widget.letter['description'] ?? ''}',
                          color: const Color(0xFFFFEDD5),
                          textColor: const Color(0xFF9A3412)),
                      const SizedBox(height: 10),
                      _InfoBox(
                        title: 'Turi',
                        text: widget.letter['category'] == 'sun'
                            ? '\u2600 Quyosh harfi (Shamsiyya)'
                            : '\uD83C\uDF19 Oy harfi (Qamariyya)',
                        color: const Color(0xFFEDE9FE),
                        textColor: const Color(0xFF6D28D9),
                      ),
                    ],
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(16),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _formTile('Yakka', '${forms['isolated'] ?? ''}'),
                      _formTile('Boshlanish', '${forms['initial'] ?? ''}'),
                      _formTile("O'rta", '${forms['medial'] ?? ''}'),
                      _formTile('Oxiri', '${forms['final'] ?? ''}'),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Text('${widget.letter['exampleWord'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 42, fontFamily: 'serif')),
                            const SizedBox(height: 4),
                            Text('${widget.letter['exampleMeaning'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E))),
                            Text('/${widget.letter['exampleTranslit'] ?? ''}/',
                                style:
                                    const TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  widget.onComplete();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: widget.completed
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFF0F766E),
                ),
                child: Text(widget.completed
                    ? "O'rganilgan \u2713"
                    : "O'rgandim (+10 XP)"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formTile(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 34, fontFamily: 'serif')),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _AudioBtn extends StatelessWidget {
  const _AudioBtn({
    required this.label,
    required this.sublabel,
    required this.type,
    required this.color,
    required this.icon,
    required this.playingType,
    required this.loading,
    required this.pulseAnim,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final String type;
  final Color color;
  final IconData icon;
  final String? playingType;
  final bool loading;
  final Animation<double> pulseAnim;
  final Future<void> Function(String) onTap;

  bool get _isPlaying => playingType == type;
  bool get _isLoading => loading && playingType == type;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 134,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isPlaying ? color : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPlaying ? color : Colors.white54,
            width: _isPlaying ? 0 : 1.5,
          ),
          boxShadow: _isPlaying
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : _isPlaying
                    ? ScaleTransition(
                        scale: pulseAnim,
                        child: const Icon(Icons.stop_circle_rounded,
                            color: Colors.white, size: 24),
                      )
                    : Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(sublabel,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen(
      {super.key, required this.data, required this.controller});

  final AppData data;
  final ProgressController controller;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // (xp_threshold, icon, color, title)
  static const List<(int, IconData, Color, String)> medals = [
    (0, Icons.school_outlined, Color(0xFF10B981), 'Yangi boshlovchi'),
    (50, Icons.menu_book, Color(0xFF2563EB), 'O\'rganuvchi'),
    (200, Icons.search, Color(0xFF7C3AED), 'Izlanuvchi'),
    (500, Icons.bolt, Color(0xFFD97706), 'Mohir'),
    (1000, Icons.emoji_events, Color(0xFFB45309), 'Ustoz'),
    (2000, Icons.workspace_premium, Color(0xFF0F766E), 'Champion'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final lettersCompleted = state.completedLetters.length;

    final activeMedal = medals.lastWhere((item) => state.xp >= item.$1,
        orElse: () => medals.first);
    final medalIcon = activeMedal.$2;
    final medalTitle = activeMedal.$4;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SimpleTitle(
                  icon: Icons.bar_chart,
                  color: Color(0xFF0F766E),
                  title: 'Progressim',
                  subtitle: 'O\'rganish statistikasi',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Progressni tiklash'),
                        content: const Text(
                            'Barcha ma\'lumotlar o\'chadi. Davom etilsinmi?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Bekor')),
                          FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Ha, tiklash')),
                        ],
                      );
                    },
                  );

                  if (!context.mounted) return;
                  if (confirmed == true) {
                    widget.controller.resetProgress();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF059669)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(medalIcon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Text(medalTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Daraja ${widget.controller.level}  ·  ${state.streak} kun',
                    style: const TextStyle(color: Color(0xFFCCFBF1))),
                const SizedBox(height: 4),
                Text('${state.xp} XP',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: widget.controller.levelProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white24),
                const SizedBox(height: 4),
                Text(
                    'Daraja ${widget.controller.level + 1} gacha ${widget.controller.xpToNextLevel} XP',
                    style: const TextStyle(
                        color: Color(0xFFCCFBF1), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _StatCard(
                  label: 'Harflar',
                  value:
                      '$lettersCompleted/${widget.data.arabicLetters.length}',
                  icon: Icons.menu_book,
                  color: const Color(0xFF2563EB)),
              _StatCard(
                  label: 'XP',
                  value: '${state.xp}',
                  icon: Icons.emoji_events,
                  color: const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('O\'rganish progressi',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _progressLine('Alifbo', lettersCompleted,
                    widget.data.arabicLetters.length, const Color(0xFF2563EB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLine(String title, int value, int total, Color color) {
    final percent = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text('$value/$total (${(percent * 100).round()}%)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            color: color),
      ],
    );
  }
}

class _SimpleTitle extends StatelessWidget {
  const _SimpleTitle({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ],
    );
  }
}

class _SectionInfo {
  const _SectionInfo(
      this.title, this.subtitle, this.icon, this.tabIndex, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final int tabIndex;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progressValue,
    required this.progressLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progressValue;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('O\'rganish progressi',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              Text(progressLabel,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              color: color),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String title;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12, color: textColor, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

enum ContentFilter { all, learned, unlearned }

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse('$value') ?? 0;
}

bool _containsArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

List<Map<String, dynamic>> _toMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
