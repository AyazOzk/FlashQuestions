import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../core/localization.dart';
import '../core/ui_components.dart';
import '../services/storage.dart';

class SettingsPage extends StatefulWidget {
  final List<Question> questions;
  final Future<void> Function(List<Question>) onImport;
  final VoidCallback onDeleteAll;

  const SettingsPage({
    super.key,
    required this.questions,
    required this.onImport,
    required this.onDeleteAll,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;

  void _alert(String msg) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CupertinoAlertDialog(
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

  Future<void> _export() async {
    if (widget.questions.isEmpty) return;
    setState(() => _loading = true);
    try {
      final path = await QuestionStore.exportZip(widget.questions);
      await Share.shareXFiles([XFile(path)], subject: 'Flash Questions Backup');
    } catch (_) {
      _alert('An error occurred during export.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result?.files.single.path == null) return;

      final questions = await QuestionStore.importZip(result!.files.single.path!);
      if (questions == null) {
        _alert('Invalid file. Please select a valid ZIP.');
        return;
      }

      await widget.onImport(questions);
      _alert('Questions imported successfully.');
    } catch (_) {
      _alert('An error occurred during import.');
    }
  }

  void _confirmDeleteAll() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Delete All Questions'.t),
        content: Text('This action cannot be undone.'.t),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onDeleteAll();
              _alert('All questions deleted.');
            },
            child: Text('Delete'.t),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.t),
          ),
        ],
      ),
    );
  }

  void _selectLanguage() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Select Language'.t),
        actions: AppLang.values.map((l) {
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_lang', l.name);
              appLang.value = l;
            },
            child: Text(l.name.toUpperCase()),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel'.t),
        ),
      ),
    );
  }

  void _editPromptDialog(bool isAnalysis) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isAnalysis ? 'prompt_analysis' : 'prompt_similar';
    final defaultPrompt = isAnalysis ? kDefaultAnalysisPrompt : kDefaultSimilarPrompt;
    final ctrl = TextEditingController(text: prefs.getString(key) ?? defaultPrompt);

    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(isAnalysis ? 'Analysis Prompt'.t : 'Similar Question Prompt'.t),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: ctrl,
            maxLines: 5,
            style: const TextStyle(fontSize: 13, color: kText),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              prefs.remove(key);
              Navigator.pop(c);
              _alert('Reverted to default prompt.');
            },
            child: Text('Reset to Default'.t),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel'.t),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              prefs.setString(key, ctrl.text.trim());
              Navigator.pop(c);
              _alert('Prompt saved.');
            },
            child: Text('Save'.t),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 0.5),
            ),
            largeTitle: Text(
              'Settings'.t,
              style: const TextStyle(
                color: kText,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionHeader('APPEARANCE'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.style_outlined, color: Colors.blueGrey, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Switch to Material Theme'.t,
                                style: const TextStyle(
                                  color: kText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If the app lags on your device, you can use this setting.'.t,
                                style: const TextStyle(
                                  color: kSubtext,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: isMaterial.value,
                          activeTrackColor: kAccent,
                          onChanged: (v) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('use_material', v);
                            isMaterial.value = v;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeader('LANGUAGE'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: _SettingsRow(
                    icon: Icons.language_outlined,
                    iconColor: kAccent,
                    title: 'App Language',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appLang.value.name.toUpperCase(),
                        style: const TextStyle(
                          color: kAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: _selectLanguage,
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeader('ARTIFICIAL INTELLIGENCE'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.psychology_outlined,
                        iconColor: const Color(0xFFBF5AF2),
                        title: 'Analysis Prompt',
                        trailing: const Icon(Icons.chevron_right_rounded, color: kSubtext, size: 20),
                        onTap: () => _editPromptDialog(true),
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.auto_awesome_mosaic_outlined,
                        iconColor: const Color(0xFFBF5AF2),
                        title: 'Similar Question Prompt',
                        trailing: const Icon(Icons.chevron_right_rounded, color: kSubtext, size: 20),
                        onTap: () => _editPromptDialog(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeader('DATA MANAGEMENT'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.bar_chart_rounded,
                        iconColor: kTeal,
                        title: 'Saved Questions Count',
                        trailing: Text(
                          '${widget.questions.length}',
                          style: const TextStyle(
                            color: kTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.upload_file_outlined,
                        iconColor: const Color(0xFF34C759),
                        title: 'Export',
                        trailing: _loading
                            ? const CupertinoActivityIndicator()
                            : const Icon(Icons.chevron_right_rounded, color: kSubtext, size: 20),
                        onTap: widget.questions.isEmpty ? null : _export,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.download_outlined,
                        iconColor: const Color(0xFFFF9F0A),
                        title: 'Import',
                        trailing: const Icon(Icons.chevron_right_rounded, color: kSubtext, size: 20),
                        onTap: _import,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeader('DANGER ZONE'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: _SettingsRow(
                    icon: Icons.delete_forever_outlined,
                    iconColor: CupertinoColors.destructiveRed,
                    title: 'Delete All Questions',
                    titleColor: CupertinoColors.destructiveRed,
                    trailing: const Icon(Icons.chevron_right_rounded, color: kSubtext, size: 20),
                    onTap: widget.questions.isEmpty ? null : _confirmDeleteAll,
                  ),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    '    Flash Questions v1.0.0\nCreated by Ayaz with love❤️    ',
                    style: TextStyle(color: kSubtext, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        text.t,
        style: const TextStyle(
          color: kSubtext,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color titleColor;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
    this.titleColor = kText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: onTap == null ? 0.05 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: onTap == null ? iconColor.withValues(alpha: 0.4) : iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title.t,
                style: TextStyle(
                  color: onTap == null ? titleColor.withValues(alpha: 0.4) : titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: Colors.white.withValues(alpha: 0.6),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
