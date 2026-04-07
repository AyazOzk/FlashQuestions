import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../core/localization.dart';
import '../core/ui_components.dart';
import 'home_page.dart';
import 'settings_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  final List<Question> _questions = [];
  bool _loaded = false;
  int _streakDays = 0;
  bool _todayActive = false;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    QuestionStore.load().then((list) {
      setState(() {
        _questions.addAll(list);
        _loaded = true;
      });
    });
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    final lastSolved = prefs.getString('last_solved_date');
    int streak = prefs.getInt('streak_days') ?? 0;

    // Reset the streak if the user missed a day.
    if (lastSolved != null && lastSolved != today && lastSolved != yesterday) {
      streak = 0;
    }

    setState(() {
      _streakDays = streak;
      _todayActive = lastSolved == today;
    });
  }

  Future<void> _onQuestionSolved() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    final lastSolved = prefs.getString('last_solved_date');
    int streak = prefs.getInt('streak_days') ?? 0;

    if (lastSolved != today) {
      streak = (lastSolved == yesterday) ? streak + 1 : 1;
      await prefs.setString('last_solved_date', today);
      await prefs.setInt('streak_days', streak);
    }

    setState(() {
      _streakDays = streak;
      _todayActive = true;
    });
    _save();
  }

  Future<void> _save() => QuestionStore.save(_questions);

  void _add(Question q) {
    setState(() => _questions.add(q));
    _save();
  }

  void _delete(String id) {
    final q = _questions.firstWhere((x) => x.id == id);
    // Clean up associated image files so they don't orphan on disk.
    for (final path in [q.photoPath, q.solutionPhotoPath]) {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
    setState(() => _questions.removeWhere((x) => x.id == id));
    _save();
  }

  void _deleteAll() {
    for (final q in _questions) {
      for (final path in [q.photoPath, q.solutionPhotoPath]) {
        if (path != null) {
          try {
            File(path).deleteSync();
          } catch (_) {}
        }
      }
    }
    setState(() => _questions.clear());
    _save();
  }

  void _refresh() {
    setState(() {});
    _save();
  }

  Future<void> _import(List<Question> incoming) async {
    setState(() {
      for (final q in incoming) {
        if (!_questions.any((existing) => existing.id == q.id)) {
          _questions.add(q);
        }
      }
    });
    _save();
    await _loadStreak();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const CupertinoPageScaffold(
        backgroundColor: kBg,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return Stack(
      children: [
        const RepaintBoundary(child: BgDecor()),
        CupertinoTabScaffold(
          backgroundColor: Colors.transparent,
          tabBar: CupertinoTabBar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            activeColor: kAccent,
            inactiveColor: kSubtext,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 0.5)),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: 'Home'.t,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings_rounded),
                label: 'Settings'.t,
              ),
            ],
          ),
          tabBuilder: (ctx, i) => i == 0
              ? HomePage(
                  questions: _questions,
                  streakDays: _streakDays,
                  streakActive: _todayActive,
                  onAdd: _add,
                  onDelete: _delete,
                  onRefresh: _refresh,
                  onQuestionSolved: _onQuestionSolved,
                )
              : SettingsPage(
                  questions: _questions,
                  onImport: _import,
                  onDeleteAll: _deleteAll,
                ),
        ),
      ],
    );
  }
}
