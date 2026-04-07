import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../core/localization.dart';
import '../core/ui_components.dart';
import '../services/storage.dart';

class QuestionForm extends StatefulWidget {
  final Question? question;
  final List<String> availableCustomSubjects;
  final List<String> availableCustomDifficulties;
  final List<String> availableTags;
  final void Function(Question) onSave;
  final void Function(Question) onUpdate;

  const QuestionForm({
    super.key,
    this.question,
    required this.availableCustomSubjects,
    required this.availableCustomDifficulties,
    required this.availableTags,
    required this.onSave,
    required this.onUpdate,
  });

  @override
  State<QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<QuestionForm> {
  late String _subject;
  late String _difficulty;
  late String _answer;
  late TextEditingController _noteCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _tagCtrl;
  late TextEditingController _answerCtrl;
  List<String> _tags = [];
  String? _photoPath;
  String? _solutionPhotoPath;
  bool _isOpenEnded = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _subject = widget.question?.subject ?? 'math';
    _difficulty = widget.question?.difficulty ?? 'medium';
    _answer = widget.question?.answer ?? 'A';
    _photoPath = widget.question?.photoPath;
    _solutionPhotoPath = widget.question?.solutionPhotoPath;
    _isOpenEnded = widget.question?.isOpenEnded ?? false;
    _tags = widget.question?.tags.toList() ?? [];
    _noteCtrl = TextEditingController(text: widget.question?.note ?? '');
    _titleCtrl = TextEditingController(text: widget.question?.title ?? '');
    _tagCtrl = TextEditingController();
    _answerCtrl = TextEditingController(text: _isOpenEnded ? _answer : '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src, bool isSolution) async {
    final file =
        await _picker.pickImage(source: src, imageQuality: 60, maxWidth: 800);
    if (file != null) {
      setState(() {
        if (isSolution) {
          _solutionPhotoPath = file.path;
        } else {
          _photoPath = file.path;
        }
      });
    }
  }

  void _showPhotoSheet(bool isSolution) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('Add Photo'.t),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, isSolution);
            },
            child: Text('Take with Camera'.t),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, isSolution);
            },
            child: Text('Select from Gallery'.t),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.t),
        ),
      ),
    );
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
    _tagCtrl.clear();
  }

  void _addCustomItem(bool isSubject) {
    final ctrl = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(isSubject ? 'Custom Subject'.t : 'Custom Difficulty'.t),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder:
                isSubject ? 'New Subject Name'.t : 'New Difficulty Name'.t,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel'.t),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (isSubject) {
                    _subject = val;
                  } else {
                    _difficulty = val;
                  }
                });
              }
              Navigator.pop(c);
            },
            child: Text('Add'.t),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    String? savedPhoto;
    if (_photoPath != null && File(_photoPath!).existsSync()) {
      savedPhoto = await QuestionStore.copyPhoto(_photoPath!);
    }

    String? savedSolution;
    if (_solutionPhotoPath != null && File(_solutionPhotoPath!).existsSync()) {
      savedSolution = await QuestionStore.copyPhoto(_solutionPhotoPath!);
    }

    final finalAnswer = _isOpenEnded ? _answerCtrl.text.trim() : _answer;

    if (widget.question != null) {
      widget.question!
        ..subject = _subject
        ..difficulty = _difficulty
        ..title = _titleCtrl.text.trim()
        ..tags = _tags
        ..answer = finalAnswer
        ..note = _noteCtrl.text
        ..isOpenEnded = _isOpenEnded
        ..photoPath = savedPhoto
        ..solutionPhotoPath = savedSolution;
      widget.onUpdate(widget.question!);
    } else {
      widget.onSave(Question(
        subject: _subject,
        difficulty: _difficulty,
        title: _titleCtrl.text.trim(),
        tags: _tags,
        answer: finalAnswer,
        note: _noteCtrl.text,
        isOpenEnded: _isOpenEnded,
        photoPath: savedPhoto,
        solutionPhotoPath: savedSolution,
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allSubj = [...subjectMap.keys, ...widget.availableCustomSubjects];
    if (_subject.isNotEmpty && !allSubj.contains(_subject)) {
      allSubj.add(_subject);
    }

    final allDiff = [
      ...difficultyMap.keys,
      ...widget.availableCustomDifficulties
    ];
    if (_difficulty.isNotEmpty && !allDiff.contains(_difficulty)) {
      allDiff.add(_difficulty);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      builder: (_, scrollController) => Container(
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
                SheetTitle(widget.question == null
                    ? 'Add New Question'.t
                    : 'Edit Question'.t),
                const FormLabel('Title (Optional)'),
                CupertinoTextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: kText, fontSize: 15),
                  placeholder: 'Question title...'.t,
                  placeholderStyle: const TextStyle(color: kSubtext),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 20),
                const FormLabel('QUESTION PHOTO'),
                GestureDetector(
                  onTap: () => _showPhotoSheet(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _photoPath != null ? 190 : 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: _photoPath != null && File(_photoPath!).existsSync()
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  image: DecorationImage(
                                    image: FileImage(File(_photoPath!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _photoPath = null),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt_rounded,
                                  color: kAccent, size: 32),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to add photo'.t,
                                style: const TextStyle(
                                  color: kSubtext,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const FormLabel('SUBJECT'),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...allSubj.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChipBtn(
                              label: getSubjectInfo(s).name,
                              color: getSubjectInfo(s).color,
                              selected: _subject == s,
                              compact: true,
                              onTap: () => setState(() => _subject = s),
                            ),
                          )),
                      ChipBtn(
                        label: '+',
                        color: kSubtext,
                        selected: false,
                        compact: true,
                        onTap: () => _addCustomItem(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const FormLabel('DIFFICULTY'),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...allDiff.map((d) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChipBtn(
                              label: getDifficultyInfo(d).$1,
                              color: getDifficultyInfo(d).$2,
                              selected: _difficulty == d,
                              compact: true,
                              onTap: () => setState(() => _difficulty = d),
                            ),
                          )),
                      ChipBtn(
                        label: '+',
                        color: kSubtext,
                        selected: false,
                        compact: true,
                        onTap: () => _addCustomItem(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Glass(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Open-Ended Question'.t,
                          style: const TextStyle(
                            color: kText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: _isOpenEnded,
                        activeTrackColor: kAccent,
                        onChanged: (v) => setState(() => _isOpenEnded = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const FormLabel('CORRECT ANSWER'),
                _isOpenEnded
                    ? CupertinoTextField(
                        controller: _answerCtrl,
                        style: const TextStyle(
                          color: kText,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        placeholder: 'Answer text...'.t,
                        placeholderStyle: const TextStyle(color: kSubtext),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(16),
                      )
                    : Row(
                        children: ['A', 'B', 'C', 'D', 'E'].map((c) {
                          final isSelected = _answer == c;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _answer = c),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isSelected ? kAccent : Colors.white,
                                      width: isSelected ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      c,
                                      style: TextStyle(
                                        color: isSelected ? kAccent : kText,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 20),
                const FormLabel('Tags'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CupertinoTextField(
                        controller: _tagCtrl,
                        placeholder: 'Add Tag'.t,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: GlassBtn(
                          label: 'Add',
                          icon: Icons.add,
                          compact: true,
                          onTap: _addTag),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map((t) => Chip(
                                label: Text('#$t',
                                    style: const TextStyle(fontSize: 12)),
                                onDeleted: () =>
                                    setState(() => _tags.remove(t)),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.6),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 20),
                const FormLabel('NOTE (OPTIONAL)'),
                CupertinoTextField(
                  controller: _noteCtrl,
                  style: const TextStyle(color: kText, fontSize: 15),
                  placeholder: 'Description, hint, topic...'.t,
                  placeholderStyle: const TextStyle(color: kSubtext),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(16),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const FormLabel('SOLUTION PHOTO'),
                GestureDetector(
                  onTap: () => _showPhotoSheet(true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _solutionPhotoPath != null ? 190 : 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: _solutionPhotoPath != null &&
                            File(_solutionPhotoPath!).existsSync()
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  image: DecorationImage(
                                    image: FileImage(File(_solutionPhotoPath!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _solutionPhotoPath = null),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_search_rounded,
                                  color: kTeal, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Add Solution Photo'.t,
                                style: const TextStyle(
                                  color: kSubtext,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                GlassBtn(
                    label: 'Save',
                    icon: Icons.check_circle_outline,
                    onTap: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onDelete, onEdit;

  const QuestionCard({
    super.key,
    required this.question,
    required this.onDelete,
    required this.onEdit,
  });

  String _reviewLabel() {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final reviewDate = DateTime(
      question.nextReview.year,
      question.nextReview.month,
      question.nextReview.day,
    );
    final diff = reviewDate.difference(today).inDays;

    // Questions added today with no attempts yet are shown as due today.
    bool isNewToday = false;
    final idInt = int.tryParse(question.id);
    if (idInt != null) {
      final created = DateTime.fromMicrosecondsSinceEpoch(idInt);
      isNewToday = created.year == today.year &&
          created.month == today.month &&
          created.day == today.day &&
          question.correct == 0 &&
          question.wrong == 0;
    }

    if (isNewToday || diff == 0) return 'Today'.t;
    if (diff < 0) return 'Overdue'.t;
    if (diff == 1) return 'Tomorrow'.t;
    return '${question.nextReview.day}.${question.nextReview.month}.${question.nextReview.year}';
  }

  Future<File> _buildAIImage(bool isAnalysis) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 1000;
    double y = 120;

    ui.Image? qImage;
    if (question.photoPath != null && File(question.photoPath!).existsSync()) {
      final data = await File(question.photoPath!).readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      qImage = (await codec.getNextFrame()).image;
    }

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 5000),
      Paint()..color = Colors.white,
    );

    final header = TextPainter(
      text: TextSpan(
        text: 'Flash Questions AI Support'.t,
        style: const TextStyle(
            color: kAccent, fontSize: 40, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    header.paint(canvas, Offset((width - header.width) / 2, 40));

    if (qImage != null) {
      final imgH = (width - 80) * qImage.height / qImage.width;
      canvas.drawImageRect(
        qImage,
        Rect.fromLTWH(0, 0, qImage.width.toDouble(), qImage.height.toDouble()),
        Rect.fromLTWH(40, y, width - 80, imgH),
        Paint(),
      );
      y += imgH + 40;
    }

    if (question.note.isNotEmpty) {
      final notePainter = TextPainter(
        text: TextSpan(
          text: '${'Note:'.t} ${question.note}',
          style: const TextStyle(color: Colors.black87, fontSize: 28),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      notePainter.paint(canvas, Offset(40, y));
      y += notePainter.height + 40;
    }

    final prefs = await SharedPreferences.getInstance();
    final prompt = isAnalysis
        ? (prefs.getString('prompt_analysis') ?? kDefaultAnalysisPrompt)
        : (prefs.getString('prompt_similar') ?? kDefaultSimilarPrompt);

    final promptPainter = TextPainter(
      text: TextSpan(
        text: '${'Prompt for AI:'.t}\n$prompt',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 120);

    final boxH = promptPainter.height + 60;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(40, y, width - 80, boxH), const Radius.circular(24)),
      Paint()..color = const Color(0xFFF2F2F7),
    );
    promptPainter.paint(canvas, Offset(60, y + 30));
    y += boxH + 60;

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), y.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    final tmpDir = await getTemporaryDirectory();
    final file = File(
        '${tmpDir.path}/ai_prompt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _processAI(BuildContext context, bool isAnalysis) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => CupertinoAlertDialog(
        title: Text('Preparing Image'.t),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 16),
              Text(
                'Please wait.\nThis process may vary depending on your device\'s performance.'
                    .t,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final file = await _buildAIImage(isAnalysis);
      if (context.mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)],
            subject: 'AI Question Template');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text('Error'.t),
            content:
                Text('${'An error occurred while generating the image:'.t} $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(c),
                child: Text('OK'.t),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAIMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('AI Support'.t),
        message: Text('What would you like to do with this question?'.t),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _processAI(context, true);
            },
            child: Text('Analyze Question'.t),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _processAI(context, false);
            },
            child: Text('Generate Similar Question'.t),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel'.t),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subj = getSubjectInfo(question.subject);
    final diff = getDifficultyInfo(question.difficulty);
    final label = _reviewLabel();
    final urgent = label == 'Overdue'.t || label == 'Today'.t;

    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white),
                ),
                child: Icon(subj.icon, color: subj.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subj.name,
                      style: TextStyle(
                        color: subj.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          diff.$1,
                          style: TextStyle(
                              color: diff.$2,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        if (question.correct > 0 || question.wrong > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: kTeal, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${question.correct}',
                            style: const TextStyle(
                              color: kTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.cancel_rounded,
                            color: CupertinoColors.destructiveRed,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${question.wrong}',
                            style: const TextStyle(
                              color: CupertinoColors.destructiveRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconBtn(
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFBF5AF2),
                onTap: () => _showAIMenu(context),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    question.isOpenEnded ? '🖋' : question.answer,
                    style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                        fontSize: 18),
                  ),
                ),
              ),
              IconBtn(
                  icon: Icons.edit_outlined, color: kSubtext, onTap: onEdit),
              IconBtn(
                icon: Icons.delete_outline_rounded,
                color: CupertinoColors.destructiveRed,
                onTap: onDelete,
              ),
            ],
          ),
          if (question.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                question.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgent
                      ? kAccent.withValues(alpha: 0.1)
                      : kSubtext.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_repeat_rounded,
                      size: 12,
                      color: urgent ? kAccent : kSubtext,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${'Review: '.t}$label',
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: urgent ? kAccent : kSubtext,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (question.solutionPhotoPath != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image, size: 12, color: kTeal),
                      const SizedBox(width: 4),
                      Text(
                        'Solution Photo'.t,
                        style: const TextStyle(
                          color: kTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ...question.tags.map((t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$t',
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )),
            ],
          ),
          if (question.photoPath != null &&
              File(question.photoPath!).existsSync()) ...[
            const SizedBox(height: 10),
            PhotoWidget(
                path: question.photoPath!, heroTag: question.id, height: 170),
          ],
          if (question.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              question.note,
              style: const TextStyle(color: kText, fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
