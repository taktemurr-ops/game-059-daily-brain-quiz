import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';

/// Shared widgets for the word & quiz games.
bool isTr(PlayContext ctx) => ctx.lang == 'tr';

String tx(PlayContext ctx, String en, String tr) => isTr(ctx) ? tr : en;

/// Soft animated-looking backdrop drawn with a painter (cheap, no assets).
class WordBackdrop extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  const WordBackdrop({super.key, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _Dots(colors.isEmpty ? [Colors.indigo, Colors.purple] : colors),
        child: child,
      );
}

class _Dots extends CustomPainter {
  final List<Color> colors;
  _Dots(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < 14; i++) {
      p.color = colors[i % colors.length].withValues(alpha: 0.07);
      final x = (i * 97 % 100) / 100 * size.width;
      final y = (i * 61 % 100) / 100 * size.height;
      canvas.drawCircle(Offset(x, y), 24.0 + (i * 13 % 40), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Dots old) => false;
}

class LetterTile extends StatelessWidget {
  final String letter;
  final double size;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool faded;
  const LetterTile(this.letter,
      {super.key, this.size = 44, this.color, this.textColor, this.onTap, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: letter,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: faded ? 0.25 : 1,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color ?? cs.primaryContainer,
              borderRadius: BorderRadius.circular(size * 0.22),
              boxShadow: const [BoxShadow(blurRadius: 3, offset: Offset(0, 2), color: Colors.black26)],
            ),
            child: Text(letter,
                style: TextStyle(
                    fontSize: size * 0.5, fontWeight: FontWeight.w800, color: textColor ?? cs.onPrimaryContainer)),
          ),
        ),
      ),
    );
  }
}

/// On-screen keyboard with the language's alphabet.
class WordKeyboard extends StatelessWidget {
  final String alphabet;
  final void Function(String) onKey;
  final Set<String> hits;
  final Set<String> misses;
  final VoidCallback? onBackspace;
  const WordKeyboard(
      {super.key, required this.alphabet, required this.onKey, this.hits = const {}, this.misses = const {}, this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letters = alphabet.split('');
    return LayoutBuilder(builder: (context, c) {
      const perRow = 10;
      final size = ((c.maxWidth - 16) / perRow - 4).clamp(24.0, 48.0);
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Wrap(alignment: WrapAlignment.center, children: [
          for (final l in letters)
            LetterTile(
              l,
              size: size,
              color: hits.contains(l)
                  ? Colors.green.shade400
                  : misses.contains(l)
                      ? Colors.grey.shade400
                      : cs.secondaryContainer,
              textColor: hits.contains(l) || misses.contains(l) ? Colors.white : cs.onSecondaryContainer,
              onTap: hits.contains(l) || misses.contains(l) ? null : () => onKey(l),
            ),
          if (onBackspace != null)
            Padding(
              padding: const EdgeInsets.all(2),
              child: IconButton.filledTonal(onPressed: onBackspace, icon: const Icon(Icons.backspace_outlined)),
            ),
        ]),
      );
    });
  }
}

/// Short toast-like feedback line.
class FeedbackLine extends StatelessWidget {
  final String text;
  final bool good;
  const FeedbackLine(this.text, {super.key, this.good = true});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(text,
            key: ValueKey(text),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: good ? Colors.green.shade700 : Colors.red.shade700)),
      );
}
