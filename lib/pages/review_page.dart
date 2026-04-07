import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../core/localization.dart';
import '../core/ui_components.dart';

class ReviewDialog extends StatefulWidget {
  final List<Question> questions;
  final List<String> allTags, customSubjects, customDiffs;
  final VoidCallback onQuestionSolved;

  const ReviewDialog({
    super.key,
    required this.questions,
    required this.allTags,
    required this.customSubjects,
    required this.customDiffs,
    required this.onQuestionSolved,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _count = 10;
  String? _difficulty;
  String? _subject;
  String? _tag;
  bool _isGeneratingPdf = false;
  bool _randomMode = false;

  void _warn(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Warning'.t),
        content: Text(msg.t),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.t),
          ),
        ],
      ),
    );
  }

  List<Question> _filtered() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return widget.questions.where((q) {
      final matchDiff = _difficulty == null || q.difficulty == _difficulty;
      final matchSubj = _subject == null || q.subject == _subject;
      final matchTag = _tag == null || q.tags.contains(_tag);

      if (_randomMode) return matchDiff && matchSubj && matchTag;

      final reviewDate = DateTime(q.nextReview.year, q.nextReview.month, q.nextReview.day);

      // Questions added today that haven't been attempted yet are treated as due.
      bool isNewToday = false;
      final idInt = int.tryParse(q.id);
      if (idInt != null) {
        final created = DateTime.fromMicrosecondsSinceEpoch(idInt);
        isNewToday = created.year == today.year &&
            created.month == today.month &&
            created.day == today.day &&
            q.correct == 0 &&
            q.wrong == 0;
      }

      return matchDiff && matchSubj && matchTag && (reviewDate.compareTo(today) <= 0 || isNewToday);
    }).toList();
  }

  void _clampCount() {
    final limit = _filtered().length;
    if (_count > limit && limit > 0) setState(() => _count = limit);
  }

  void _start() {
    final candidates = _filtered();
    if (candidates.isEmpty) {
      _warn('No suitable questions found.');
      return;
    }
    if (_count > candidates.length) {
      _warn('${'There are only'.t} ${candidates.length} ${'questions matching these criteria.'.t}');
      return;
    }

    candidates.shuffle(Random());
    Navigator.pop(context);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ReviewPage(
          questions: candidates.take(_count).toList(),
          isRandomReview: _randomMode,
          onQuestionSolved: widget.onQuestionSolved,
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final candidates = _filtered();
    if (candidates.isEmpty) {
      _warn('No suitable questions found.');
      return;
    }
    if (_count > candidates.length) {
      _warn('${'There are only'.t} ${candidates.length} ${'questions matching these criteria.'.t}');
      return;
    }

    candidates.shuffle(Random());
    final selected = candidates.take(_count).toList();
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) {
          final widgets = <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Text(
                'Flash Questions - PDF',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
          ];

          for (int i = 0; i < selected.length; i++) {
            final q = selected[i];
            final titleSuffix = q.title.isNotEmpty ? ' - ${q.title}' : '';

            widgets.addAll([
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${i + 1}. ${'Question'.t}$titleSuffix',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    getSubjectInfo(q.subject).name.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              if (q.photoPath != null && File(q.photoPath!).existsSync())
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Image(
                    pw.MemoryImage(File(q.photoPath!).readAsBytesSync()),
                    fit: pw.BoxFit.contain,
                    height: 250,
                  ),
                )
              else if (q.note.isNotEmpty)
                pw.Text(q.note, style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 16),
              pw.Container(
                height: 150,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Solution area',
                    style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 16),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
            ]);
          }

          return widgets;
        },
      ));

      pdf.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 1, child: pw.Text('Answer Key'.t)),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 20,
                runSpacing: 10,
                children: List.generate(selected.length, (i) {
                  final q = selected[i];
                  final diffLabel = getDifficultyInfo(q.difficulty).$1;
                  return pw.Container(
                    width: 90,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                    child: pw.Text(
                      '${i + 1}. ${'Question'.t}: ${q.answer}\n($diffLabel)',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );

      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/FlashQuestions_test_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], subject: 'Flash Questions Test PDF');
      }
    } catch (e) {
      _warn('An error occurred while generating the image: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxCount = _filtered().length;
    final allSubj = [...subjectMap.keys, ...widget.customSubjects];
    final allDiff = [...difficultyMap.keys, ...widget.customDiffs];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      builder: (_, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
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
                  const SheetTitle('Review'),
                  Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Random Questions'.t,
                                style: const TextStyle(
                                  color: kText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Practice without affecting review dates.'.t,
                                style: const TextStyle(color: kSubtext, fontSize: 11, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _randomMode,
                          activeTrackColor: kAccent,
                          onChanged: (v) {
                            setState(() => _randomMode = v);
                            _clampCount();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FormLabel('NUMBER OF QUESTIONS'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${'Available'.t}: $maxCount',
                          style: const TextStyle(
                            color: kAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Glass(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconBtn(
                          icon: Icons.remove,
                          onTap: () {
                            if (_count > 1) setState(() => _count--);
                          },
                        ),
                        Text(
                          '$_count',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: kText,
                          ),
                        ),
                        IconBtn(
                          icon: Icons.add,
                          onTap: () {
                            if (_count < maxCount) {
                              setState(() => _count++);
                            } else {
                              _warn('Selected count cannot exceed available questions.');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                            onTap: () {
                              setState(() => _subject = null);
                              _clampCount();
                            },
                          ),
                        ),
                        ...allSubj.map((String s) {
                          final info = getSubjectInfo(s);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChipBtn(
                              label: info.name,
                              color: info.color,
                              selected: _subject == s,
                              compact: true,
                              onTap: () {
                                setState(() => _subject = s);
                                _clampCount();
                              },
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
                    children: [
                      ChipBtn(
                        label: 'All',
                        color: kAccent,
                        selected: _difficulty == null,
                        onTap: () {
                          setState(() => _difficulty = null);
                          _clampCount();
                        },
                      ),
                      ...allDiff.map((String d) {
                        final info = getDifficultyInfo(d);
                        return ChipBtn(
                          label: info.$1,
                          color: info.$2,
                          selected: _difficulty == d,
                          onTap: () {
                            setState(() => _difficulty = d);
                            _clampCount();
                          },
                        );
                      }),
                    ],
                  ),
                  if (widget.allTags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const FormLabel('Tags'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChipBtn(
                          label: 'All',
                          color: kTeal,
                          selected: _tag == null,
                          onTap: () {
                            setState(() => _tag = null);
                            _clampCount();
                          },
                        ),
                        ...widget.allTags.map((String t) {
                          return ChipBtn(
                            label: '#$t',
                            color: kTeal,
                            selected: _tag == t,
                            onTap: () {
                              setState(() => _tag = t);
                              _clampCount();
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  _isGeneratingPdf
                      ? const Center(child: CupertinoActivityIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: GlassBtn(
                                label: 'Export PDF',
                                icon: Icons.picture_as_pdf_outlined,
                                color: CupertinoColors.destructiveRed,
                                onTap: _generatePdf,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassBtn(
                                label: 'Start',
                                icon: Icons.rocket_launch_rounded,
                                onTap: _start,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReviewPage extends StatefulWidget {
  final List<Question> questions;
  final bool isRandomReview;
  final VoidCallback onQuestionSolved;

  const ReviewPage({
    super.key,
    required this.questions,
    required this.isRandomReview,
    required this.onQuestionSolved,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late PageController _ctrl;
  int _index = 0;
  final Map<String, String> _answers = {};
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    SystemChrome.setPreferredOrientations(
      _isLandscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  void _navigate(bool forward) {
    if (forward && _index < widget.questions.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else if (forward) {
      Navigator.pop(context);
    } else if (_index > 0) {
      _ctrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _submitAnswer(String choice) {
    final q = widget.questions[_index];
    if (_answers.containsKey(q.id)) return;

    setState(() => _answers[q.id] = choice);

    if (!widget.isRandomReview) {
      final isCorrect = q.isOpenEnded
          ? choice.trim().toLowerCase() == q.answer.trim().toLowerCase()
          : choice == q.answer;
      q.markAnswer(isCorrect);
    }

    widget.onQuestionSolved();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const RepaintBoundary(child: BgDecor()),
        CupertinoPageScaffold(
          backgroundColor: Colors.transparent,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 0.5),
            ),
            middle: Text(
              '${'Question'.t} ${_index + 1} / ${widget.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleOrientation,
              child: Icon(
                _isLandscape
                    ? Icons.screen_lock_portrait_outlined
                    : Icons.screen_rotation_outlined,
                color: kAccent,
                size: 24,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _index = i),
                    itemCount: widget.questions.length,
                    itemBuilder: (_, i) => _SolutionArea(question: widget.questions[i]),
                  ),
                ),
                _AnswerBar(
                  question: widget.questions[_index],
                  answers: _answers,
                  index: _index,
                  total: widget.questions.length,
                  onAnswer: _submitAnswer,
                  onNavigate: _navigate,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerBar extends StatefulWidget {
  final Question question;
  final Map<String, String> answers;
  final int index, total;
  final void Function(String) onAnswer;
  final void Function(bool) onNavigate;

  const _AnswerBar({
    required this.question,
    required this.answers,
    required this.index,
    required this.total,
    required this.onAnswer,
    required this.onNavigate,
  });

  @override
  State<_AnswerBar> createState() => _AnswerBarState();
}

class _AnswerBarState extends State<_AnswerBar> {
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.answers[widget.question.id] ?? '');
  }

  @override
  void didUpdateWidget(covariant _AnswerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _textCtrl.text = widget.answers[widget.question.id] ?? '';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.answers[widget.question.id];
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget optionsArea;

    if (widget.question.isOpenEnded) {
      final answeredCorrectly = selected != null &&
          selected.trim().toLowerCase() == widget.question.answer.trim().toLowerCase();

      optionsArea = Row(
        children: [
          Expanded(
            flex: 2,
            child: CupertinoTextField(
              controller: _textCtrl,
              readOnly: selected != null,
              placeholder: 'Answer text...'.t,
              style: TextStyle(
                color: selected == null
                    ? kText
                    : (answeredCorrectly ? kTeal : CupertinoColors.destructiveRed),
                fontWeight: FontWeight.bold,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white),
              ),
              padding: const EdgeInsets.all(14),
            ),
          ),
          if (selected == null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: GlassBtn(
                label: 'Submit',
                icon: Icons.send,
                compact: true,
                onTap: () {
                  if (_textCtrl.text.isNotEmpty) widget.onAnswer(_textCtrl.text);
                },
              ),
            ),
          ] else ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${'CORRECT ANSWER'.t}: ${widget.question.answer}',
                style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      );
    } else {
      optionsArea = Row(
        children: ['A', 'B', 'C', 'D', 'E'].map((c) {
          Color border = Colors.white;
          Color bg = Colors.white.withValues(alpha: 0.65);
          Color text = kText;

          if (selected != null) {
            if (c == widget.question.answer) {
              border = kTeal;
              bg = kTeal.withValues(alpha: 0.2);
              text = kTeal;
            } else if (c == selected) {
              border = CupertinoColors.destructiveRed;
              bg = CupertinoColors.destructiveRed.withValues(alpha: 0.2);
              text = CupertinoColors.destructiveRed;
            }
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  if (selected == null) widget.onAnswer(c);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isLandscape ? 44 : 50,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: border,
                      width: selected != null && (c == widget.question.answer || c == selected)
                          ? 2.0
                          : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      c,
                      style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    final navRow = Row(
      children: [
        Expanded(
          child: GlassBtn(
            label: 'Back',
            icon: Icons.arrow_back_ios_rounded,
            compact: isLandscape,
            onTap: () => widget.onNavigate(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassBtn(
            label: widget.index == widget.total - 1 ? 'Finish' : 'Next',
            icon: widget.index == widget.total - 1
                ? Icons.check_rounded
                : Icons.arrow_forward_ios_rounded,
            compact: isLandscape,
            onTap: () => widget.onNavigate(true),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isLandscape ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: isLandscape
          ? Row(
              children: [
                Expanded(flex: 3, child: optionsArea),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: navRow),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [optionsArea, const SizedBox(height: 16), navRow],
            ),
    );
  }
}

class _SolutionArea extends StatefulWidget {
  final Question question;

  const _SolutionArea({required this.question});

  @override
  State<_SolutionArea> createState() => _SolutionAreaState();
}

class _SolutionAreaState extends State<_SolutionArea> with AutomaticKeepAliveClientMixin {
  final List<List<Offset>> _strokes = [];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final subj = getSubjectInfo(widget.question.subject);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final infoArea = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white),
                ),
                child: Icon(subj.icon, color: subj.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.question.title.isNotEmpty ? widget.question.title : subj.name,
                  style: TextStyle(
                    color: widget.question.title.isNotEmpty ? kText : subj.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.question.photoPath != null &&
              File(widget.question.photoPath!).existsSync()) ...[
            PhotoWidget(
              path: widget.question.photoPath!,
              heroTag: '${widget.question.id}_solution',
              height: isLandscape ? 160 : 200,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.question.note.isNotEmpty) ...[
            Text(widget.question.note, style: const TextStyle(color: kText, fontSize: 15)),
            const SizedBox(height: 12),
          ],
          if (widget.question.solutionPhotoPath != null &&
              File(widget.question.solutionPhotoPath!).existsSync()) ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image, color: kTeal, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'SOLUTION PHOTO'.t,
                        style: const TextStyle(
                          color: kTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PhotoWidget(
                    path: widget.question.solutionPhotoPath!,
                    heroTag: '${widget.question.id}_solutionPhoto',
                    height: isLandscape ? 120 : 160,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final drawArea = Glass(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
            onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
            child: RepaintBoundary(
              child: CustomPaint(painter: _StrokePainter(_strokes), size: Size.infinite),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconBtn(
              icon: Icons.delete_outline,
              onTap: () => setState(() => _strokes.clear()),
            ),
          ),
          if (_strokes.isEmpty)
            Center(
              child: Text(
                'You can write your solution here'.t,
                style: const TextStyle(color: kSubtext, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: infoArea),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: drawArea),
              ],
            )
          : Column(
              children: [
                Flexible(child: infoArea),
                Expanded(child: drawArea),
              ],
            ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}