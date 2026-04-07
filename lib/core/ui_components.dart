import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization.dart';

// Color palette
const kBg = Color(0xFFF2F2F7);
const kAccent = Color(0xFF0A84FF);
const kTeal = Color(0xFF30D158);
const kText = Color(0xFF1C1C1E);
const kSubtext = Color(0xFF8E8E93);

// Global toggle: when true, uses flat Material-style rendering instead of
// the frosted-glass Cupertino look. Useful for lower-end devices.
final isMaterial = ValueNotifier<bool>(false);

Future<void> initTheme() async {
  final prefs = await SharedPreferences.getInstance();
  isMaterial.value = prefs.getBool('use_material') ?? false;
}

// Frosted-glass card container. Falls back to a plain white card in Material mode.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const Glass({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: isMaterial.value
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            )
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
      child: child,
    );
  }
}

class GlassBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final Color? color;

  const GlassBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
        decoration: isMaterial.value
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 12 : 16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
                ],
              )
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(compact ? 16 : 22),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? kAccent, size: compact ? 18 : 22),
            const SizedBox(width: 8),
            Text(
              label.t,
              style: TextStyle(
                color: color ?? kText,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 14 : 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CircleBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: isMaterial.value
            ? BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              )
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
        child: Icon(icon, color: kAccent, size: 20),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const IconBtn({super.key, required this.icon, required this.onTap, this.color = kText});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(8),
        decoration: isMaterial.value
            ? BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              )
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class ChipBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected, vertical, compact;
  final VoidCallback onTap;

  const ChipBtn({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.vertical = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          vertical: vertical ? 14 : (compact ? 8 : 10),
          horizontal: vertical ? 0 : (compact ? 12 : 14),
        ),
        decoration: isMaterial.value
            ? BoxDecoration(
                color: selected ? color.withValues(alpha: 0.15) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              )
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? color : Colors.white, width: selected ? 2.0 : 1.5),
              ),
        child: Center(
          child: Text(
            label.t,
            style: TextStyle(
              color: selected ? color : kText,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

class BottomSheetContainer extends StatelessWidget {
  final Widget child;

  const BottomSheetContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  final String text;

  const SheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: kSubtext.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          text,
          style: const TextStyle(
            color: kText,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class FormLabel extends StatelessWidget {
  final String text;

  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text.t,
        style: const TextStyle(
          color: kSubtext,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class PhotoWidget extends StatelessWidget {
  final String path, heroTag;
  final double height;

  const PhotoWidget({super.key, required this.path, required this.heroTag, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FullscreenPhoto(path: path, heroTag: heroTag),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        ),
      ),
      child: Hero(
        tag: heroTag,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 1.5),
            image: DecorationImage(
              image: ResizeImage(FileImage(File(path)), width: 600),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class FullscreenPhoto extends StatelessWidget {
  final String path, heroTag;

  const FullscreenPhoto({super.key, required this.path, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BgDecor extends StatelessWidget {
  const BgDecor({super.key});

  Widget _orb(double? top, double? bottom, double? right, double? left, double size, Color color) {
    return Positioned(
      top: top,
      bottom: bottom,
      right: right,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In Material mode we skip the gradient orbs entirely to avoid jank on weaker devices.
    if (isMaterial.value) {
      return Container(color: kBg);
    }

    return Stack(
      children: [
        Container(color: kBg),
        _orb(-50, null, -50, null, 300, const Color(0x66FF9F0A)),
        _orb(250, null, null, -100, 350, const Color(0x550A84FF)),
        _orb(null, -50, null, 50, 400, const Color(0x44BF5AF2)),
      ],
    );
  }
}
