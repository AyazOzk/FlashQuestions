import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/models.dart';
import '../core/localization.dart';

class QuestionStore {
  static const _key = 'questions_v1';

  static Future<Directory> get _photoDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/photos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<List<Question>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Question.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Failed to load questions: $e');
      return [];
    }
  }

  static Future<void> save(List<Question> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // Copies a photo into the app's dedicated photos directory so it survives
  // temp-file cleanup done by the OS or image picker.
  static Future<String> copyPhoto(String path) async {
    final dir = await _photoDir;
    if (path.contains(dir.path)) return path; // Already in the right place.
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final filename = path.split('/').last;
    final dest = '${dir.path}/uploaded_${timestamp}_$filename';
    await File(path).copy(dest);
    return dest;
  }

  static Future<String> exportZip(List<Question> list) async {
    final prefs = await SharedPreferences.getInstance();
    final archive = Archive();

    final payload = {
      'version': 1,
      'date': DateTime.now().toIso8601String(),
      'streak_days': prefs.getInt('streak_days') ?? 0,
      'last_solved_date': prefs.getString('last_solved_date'),
      'app_lang': prefs.getString('app_lang'),
      'prompt_analysis': prefs.getString('prompt_analysis'),
      'prompt_similar': prefs.getString('prompt_similar'),
      'questions': list.map((e) => e.toJson()).toList(),
    };

    final jsonBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('FlashQuestions_backup.json', jsonBytes.length, jsonBytes));

    for (final q in list) {
      for (final photoPath in [q.photoPath, q.solutionPhotoPath]) {
        if (photoPath != null && File(photoPath).existsSync()) {
          final bytes = await File(photoPath).readAsBytes();
          archive.addFile(ArchiveFile(photoPath.split('/').last, bytes.length, bytes));
        }
      }
    }

    final base = await getApplicationDocumentsDirectory();
    final zipFile = File('${base.path}/FlashQuestions_backup.zip');
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));
    return zipFile.path;
  }

  static Future<List<Question>?> importZip(String zipPath) async {
    try {
      final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
      final dir = await _photoDir;
      String? jsonContent;

      for (final entry in archive) {
        if (!entry.isFile) continue;
        final data = entry.content as List<int>;
        if (entry.name == 'FlashQuestions_backup.json') {
          jsonContent = utf8.decode(data);
        } else {
          await File('${dir.path}/${entry.name}').writeAsBytes(data);
        }
      }

      if (jsonContent == null) return null;

      final map = jsonDecode(jsonContent) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      if (map.containsKey('streak_days')) {
        await prefs.setInt('streak_days', map['streak_days']);
      }
      if (map['last_solved_date'] != null) {
        await prefs.setString('last_solved_date', map['last_solved_date']);
      }
      if (map['app_lang'] != null) {
        await prefs.setString('app_lang', map['app_lang']);
        appLang.value = AppLang.values.firstWhere(
          (e) => e.name == map['app_lang'],
          orElse: () => AppLang.en,
        );
      }
      if (map['prompt_analysis'] != null) {
        await prefs.setString('prompt_analysis', map['prompt_analysis']);
      }
      if (map['prompt_similar'] != null) {
        await prefs.setString('prompt_similar', map['prompt_similar']);
      }

      return (map['questions'] as List? ?? []).map((item) {
        final q = Question.fromJson(item as Map<String, dynamic>);

        // Remap photo paths to the local photos directory.
        if (q.photoPath != null) {
          final local = '${dir.path}/${q.photoPath!.split('/').last}';
          q.photoPath = File(local).existsSync() ? local : null;
        }
        if (q.solutionPhotoPath != null) {
          final local = '${dir.path}/${q.solutionPhotoPath!.split('/').last}';
          q.solutionPhotoPath = File(local).existsSync() ? local : null;
        }

        return q;
      }).toList();
    } catch (e) {
      debugPrint('Failed to import zip: $e');
      return null;
    }
  }
}
