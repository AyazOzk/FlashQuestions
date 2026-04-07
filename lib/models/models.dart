import 'package:flutter/material.dart';
import '../core/localization.dart';

class SubjectInfo {
  final String id, name, short;
  final Color color;
  final IconData icon;

  const SubjectInfo(this.id, this.name, this.short, this.color, this.icon);
}

Map<String, SubjectInfo> get subjectMap => {
  'math':        SubjectInfo('math',        'math'.t,        'Mat', const Color(0xFF0A84FF), Icons.calculate_outlined),
  'physics':     SubjectInfo('physics',     'physics'.t,     'Phy', const Color(0xFF5E5CE6), Icons.bolt_outlined),
  'chemistry':   SubjectInfo('chemistry',   'chemistry'.t,   'Che', const Color(0xFFFF9F0A), Icons.science_outlined),
  'biology':     SubjectInfo('biology',     'biology'.t,     'Bio', const Color(0xFF30D158), Icons.eco_outlined),
  'nativeLang':  SubjectInfo('nativeLang',  'nativeLang'.t,  'Nat', const Color(0xFFFF375F), Icons.text_fields_outlined),
  'literature':  SubjectInfo('literature',  'literature'.t,  'Lit', const Color(0xFFBF5AF2), Icons.menu_book_outlined),
  'history':     SubjectInfo('history',     'history'.t,     'His', const Color(0xFFFF453A), Icons.history_edu_outlined),
  'geography':   SubjectInfo('geography',   'geography'.t,   'Geo', const Color(0xFF64D2FF), Icons.map_outlined),
  'philosophy':  SubjectInfo('philosophy',  'philosophy'.t,  'Phi', const Color(0xFF8E8E93), Icons.lightbulb_outline),
  'foreignLang': SubjectInfo('foreignLang', 'foreignLang'.t, 'For', const Color(0xFF32ADE6), Icons.language_outlined),
};

Map<String, (String, Color)> get difficultyMap => {
  'easy':   ('easy'.t,   const Color(0xFF30D158)),
  'medium': ('medium'.t, const Color(0xFFFF9F0A)),
  'hard':   ('hard'.t,   const Color(0xFFFF453A)),
};

SubjectInfo getSubjectInfo(String id) {
  return subjectMap[id] ?? SubjectInfo(
    id,
    id,
    id.length >= 3 ? id.substring(0, 3).toUpperCase() : id,
    const Color(0xFF8E8E93),
    Icons.bookmark_border,
  );
}

(String, Color) getDifficultyInfo(String id) {
  return difficultyMap[id] ?? (id, const Color(0xFF8E8E93));
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class Question {
  final String id;
  String subject;
  String difficulty;
  String title;
  List<String> tags;
  String answer;
  String note;
  String? photoPath;
  String? solutionPhotoPath;
  bool isOpenEnded;
  int correct, wrong, repetition;
  DateTime nextReview;

  // SM-2-inspired spaced repetition intervals (in days).
  static const _intervals = {1: 1, 2: 3, 3: 8, 4: 20, 5: 50, 6: 125};

  Question({
    String? id,
    required this.subject,
    required this.difficulty,
    this.title = '',
    this.tags = const [],
    required this.answer,
    this.note = '',
    this.photoPath,
    this.solutionPhotoPath,
    this.isOpenEnded = false,
    this.correct = 0,
    this.wrong = 0,
    this.repetition = 1,
    DateTime? nextReview,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        nextReview = nextReview ?? _today().add(const Duration(days: 1));

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'difficulty': difficulty,
    'title': title,
    'tags': tags,
    'answer': answer,
    'note': note,
    'photoPath': photoPath,
    'solutionPhotoPath': solutionPhotoPath,
    'isOpenEnded': isOpenEnded,
    'correct': correct,
    'wrong': wrong,
    'repetition': repetition,
    'nextReview': nextReview.toIso8601String(),
  };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'],
    subject: j['subject'] ?? 'math',
    difficulty: j['difficulty'] ?? 'medium',
    title: j['title'] ?? '',
    tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    answer: j['answer'] ?? 'A',
    note: j['note'] ?? '',
    photoPath: j['photoPath'],
    solutionPhotoPath: j['solutionPhotoPath'],
    isOpenEnded: j['isOpenEnded'] ?? false,
    correct: j['correct'] ?? 0,
    wrong: j['wrong'] ?? 0,
    repetition: j['repetition'] ?? 1,
    nextReview: j['nextReview'] != null ? DateTime.parse(j['nextReview']) : _today(),
  );

  void markAnswer(bool isCorrect) {
    if (isCorrect) {
      correct++;
      repetition++;
      nextReview = _today().add(Duration(days: _intervals[repetition] ?? 200));
    } else {
      wrong++;
      repetition = 0;
      nextReview = _today().add(const Duration(days: 1));
    }
  }
}
