import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/localization.dart';
import '../core/ui_components.dart';
import '../widgets/question_widgets.dart';
import 'review_page.dart';

class HomePage extends StatefulWidget {
  final List<Question> questions;
  final int streakDays;
  final bool streakActive;
  final void Function(Question) onAdd;
  final void Function(String) onDelete;
  final VoidCallback onRefresh, onQuestionSolved;

  const HomePage({
    super.key,
    required this.questions,
    required this.streakDays,
    required this.streakActive,
    required this.onAdd,
    required this.onDelete,
    required this.onRefresh,
    required this.onQuestionSolved,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _filterSubject;
  String? _filterDifficulty;
  String? _filterTag;
  String _searchQuery = '';

  void _openForm(BuildContext ctx, {Question? question}) {
    final customSubjects = widget.questions
        .map((q) => q.subject)
        .toSet()
        .difference(subjectMap.keys.toSet())
        .toList();
    final customDiffs = widget.questions
        .map((q) => q.difficulty)
        .toSet()
        .difference(difficultyMap.keys.toSet())
        .toList();
    final allTags = widget.questions.expand((q) => q.tags).toSet().toList();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionForm(
        question: question,
        availableCustomSubjects: customSubjects,
        availableCustomDifficulties: customDiffs,
        availableTags: allTags,
        onSave: widget.onAdd,
        onUpdate: (_) => widget.onRefresh(),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String id) {
    showCupertinoDialog(
      context: ctx,
      builder: (c) => CupertinoAlertDialog(
        title: Text('Delete Question'.t),
        content: Text('Are you sure you want to delete this question?'.t),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(c);
              widget.onDelete(id);
            },
            child: Text('Delete'.t),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel'.t),
          ),
        ],
      ),
    );
  }

  Map<String, int> get _stats {
    final map = <String, int>{};
    for (final q in widget.questions) {
      map[q.subject] = (map[q.subject] ?? 0) + 1;
    }
    return map;
  }

  void _openFilterDialog() {
    final customSubjects = widget.questions
        .map((q) => q.subject)
        .toSet()
        .difference(subjectMap.keys.toSet())
        .toList();
    final customDiffs = widget.questions
        .map((q) => q.difficulty)
        .toSet()
        .difference(difficultyMap.keys.toSet())
        .toList();
    final allTags = widget.questions.expand((q) => q.tags).toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _FilterDialog(
        currentSubject: _filterSubject,
        currentDifficulty: _filterDifficulty,
        currentTag: _filterTag,
        customSubjects: customSubjects,
        customDiffs: customDiffs,
        allTags: allTags,
        onFilter: (s, d, t) => setState(() {
          _filterSubject = s;
          _filterDifficulty = d;
          _filterTag = t;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.questions
        .where((q) =>
            (_filterSubject == null || q.subject == _filterSubject) &&
            (_filterDifficulty == null || q.difficulty == _filterDifficulty) &&
            (_filterTag == null || q.tags.contains(_filterTag)) &&
            (_searchQuery.isEmpty ||
                q.title.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList()
        .reversed
        .toList();

    final hasFilter = _filterSubject != null ||
        _filterDifficulty != null ||
        _filterTag != null ||
        _searchQuery.isNotEmpty;

    // childCount: 1 header + N cards (or 1 placeholder when empty/no results)
    final childCount = widget.questions.isEmpty
        ? 1
        : (filtered.isEmpty ? 2 : filtered.length + 1);

    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 0.5),
            ),
            largeTitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 32),
                const SizedBox(width: 10),
                const Text(
                  'Flash Questions',
                  style: TextStyle(color: kText, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
              ],
            ),
            trailing: CircleBtn(icon: Icons.add, onTap: () => _openForm(context)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        _StatsCard(
                          total: widget.questions.length,
                          stats: _stats,
                          streak: widget.streakDays,
                          streakActive: widget.streakActive,
                        ),
                        const SizedBox(height: 16),
                        if (widget.questions.isNotEmpty) ...[
                          GlassBtn(
                            label: 'Review Questions',
                            icon: Icons.play_arrow_rounded,
                            onTap: () {
                              final allTags = widget.questions
                                  .expand((q) => q.tags)
                                  .toSet()
                                  .toList();
                              final customSubjects = widget.questions
                                  .map((q) => q.subject)
                                  .toSet()
                                  .difference(subjectMap.keys.toSet())
                                  .toList();
                              final customDiffs = widget.questions
                                  .map((q) => q.difficulty)
                                  .toSet()
                                  .difference(difficultyMap.keys.toSet())
                                  .toList();

                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                useSafeArea: true,
                                builder: (_) => ReviewDialog(
                                  questions: widget.questions,
                                  allTags: allTags,
                                  customSubjects: customSubjects,
                                  customDiffs: customDiffs,
                                  onQuestionSolved: widget.onQuestionSolved,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          CupertinoSearchTextField(
                            backgroundColor: Colors.white.withValues(alpha: 0.65),
                            placeholder: 'Search by title...'.t,
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.list_alt_outlined, size: 14, color: kSubtext),
                              const SizedBox(width: 6),
                              Text(
                                '${filtered.length} ${'questions listed'.t}',
                                style: const TextStyle(
                                  color: kSubtext,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _openFilterDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: hasFilter
                                        ? kAccent.withValues(alpha: 0.1)
                                        : Colors.white.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: hasFilter ? kAccent : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.filter_list_rounded,
                                          size: 16, color: hasFilter ? kAccent : kText),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Filter'.t,
                                        style: TextStyle(
                                          color: hasFilter ? kAccent : kText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (widget.questions.isEmpty)
                          _EmptyState(onTap: () => _openForm(context)),
                      ],
                    );
                  }

                  if (filtered.isEmpty && index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No questions found matching these filters.'.t,
                          style: const TextStyle(color: kSubtext, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }

                  final q = filtered[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: QuestionCard(
                      question: q,
                      onDelete: () => _confirmDelete(context, q.id),
                      onEdit: () => _openForm(context, question: q),
                    ),
                  );
                },
                childCount: childCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final String? currentSubject, currentDifficulty, currentTag;
  final List<String> customSubjects, customDiffs, allTags;
  final void Function(String?, String?, String?) onFilter;

  const _FilterDialog({
    required this.currentSubject,
    required this.currentDifficulty,
    required this.currentTag,
    required this.customSubjects,
    required this.customDiffs,
    required this.allTags,
    required this.onFilter,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  String? _subject, _difficulty, _tag;

  @override
  void initState() {
    super.initState();
    _subject = widget.currentSubject;
    _difficulty = widget.currentDifficulty;
    _tag = widget.currentTag;
  }

  @override
  Widget build(BuildContext context) {
    final allSubj = [...subjectMap.keys, ...widget.customSubjects];
    final allDiff = [...difficultyMap.keys, ...widget.customDiffs];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      snap: true,
      builder: (_, scrollController) => BottomSheetContainer(
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SheetTitle('Filter Questions'.t),
              const FormLabel('SUBJECT'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChipBtn(
                        label: 'All',
                        color: kAccent,
                        selected: _subject == null,
                        compact: true,
                        onTap: () => setState(() => _subject = null),
                      ),
                    ),
                    ...allSubj.map((s) {
                      final info = getSubjectInfo(s);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChipBtn(
                          label: info.name,
                          color: info.color,
                          selected: _subject == s,
                          compact: true,
                          onTap: () => setState(() => _subject = s),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const FormLabel('DIFFICULTY LEVEL'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [null, ...allDiff].map((d) {
                  final label = d == null ? 'All' : getDifficultyInfo(d).$1;
                  final color = d == null ? kAccent : getDifficultyInfo(d).$2;
                  return ChipBtn(
                    label: label,
                    color: color,
                    selected: _difficulty == d,
                    onTap: () => setState(() => _difficulty = d),
                  );
                }).toList(),
              ),
              if (widget.allTags.isNotEmpty) ...[
                const SizedBox(height: 20),
                const FormLabel('Tags'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [null, ...widget.allTags].map((t) {
                    final label = t == null ? 'All' : '#$t';
                    return ChipBtn(
                      label: label,
                      color: kTeal,
                      selected: _tag == t,
                      onTap: () => setState(() => _tag = t),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GlassBtn(
                      label: 'Clear',
                      icon: Icons.clear_all_rounded,
                      color: kSubtext,
                      onTap: () => setState(() {
                        _subject = null;
                        _difficulty = null;
                        _tag = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassBtn(
                      label: 'Apply',
                      icon: Icons.check_rounded,
                      onTap: () {
                        widget.onFilter(_subject, _difficulty, _tag);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int total, streak;
  final Map<String, int> stats;
  final bool streakActive;

  const _StatsCard({
    required this.total,
    required this.stats,
    required this.streak,
    required this.streakActive,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = (stats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Glass(
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: kText,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Question'.t,
                  style: const TextStyle(
                    color: kSubtext,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.7)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 34,
                  color: streakActive
                      ? const Color(0xFFFF9F0A)
                      : Colors.grey.withValues(alpha: 0.4),
                ),
                Text(
                  '$streak ${'Days'.t}',
                  style: TextStyle(
                    color: streakActive ? const Color(0xFFFF9F0A) : kSubtext,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.7)),
          Expanded(
            child: top3.isEmpty
                ? Center(
                    child: Text(
                      'No data'.t,
                      style: const TextStyle(color: kSubtext, fontSize: 13),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: top3.map((e) {
                      final d = getSubjectInfo(e.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(d.icon, size: 14, color: d.color),
                            const SizedBox(width: 5),
                            Text(
                              d.short,
                              style: const TextStyle(
                                color: kText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${e.value}',
                              style: TextStyle(
                                color: d.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Glass(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.style, color: kAccent, size: 42),
          ),
          const SizedBox(height: 18),
          Text(
            'No Questions'.t,
            style: const TextStyle(
              color: kText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add questions you couldn\'t solve here.'.t,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kSubtext, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          GlassBtn(label: 'Add First Question', icon: Icons.add_circle_outline, onTap: onTap),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
