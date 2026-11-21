import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'icon_map.dart';
import 'quiz_engine.dart';
import 'rules.dart';
import 'word_ui.dart';

class QuizView extends StatefulWidget {
  final PlayContext ctx;
  const QuizView({super.key, required this.ctx});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> with RoundClock {
  late QuizLevel level;
  late QuizGame game;
  late SeededRandom _r;
  int _hints = 0;
  int _rounds = 0;
  int _answered = 0;
  int _correctTotal = 0;
  int _qStart = 0;
  int? _picked;
  bool _ended = false;
  bool _busy = false;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _zen => ctx.spec.mode == GameModeId.zen;
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<QuizLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? QuizGame.restore(level, snap) : QuizGame(level);
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _rounds = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    _r = SeededRandom(mixSeed([ctx.spec.seed, 31]));
    startClock(
        initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
        limit: ctx.spec.mode == GameModeId.timeAttack ? 90 : 0);
    _qStart = seconds;
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_correctTotal + game.correct > 0);

  void _persist() =>
      ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _rounds});

  int get _left => _zen ? 99 : level.secondsPerQ - (seconds - _qStart);

  Future<void> _answer(int i) async {
    if (_busy || _ended || game.finished) return;
    _busy = true;
    final left = _left.clamp(0, 99);
    final ok = i >= 0 && i == game.q.answer;
    setState(() => _picked = i);
    ctx.sfx(ok ? Sfx.coin : Sfx.error);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      if (_zen && !ok) {
        // Zen: no lives lost, just move on.
        game.index++;
        game.mistakes++;
        game.streak = 0;
      } else {
        game.answer(i, secondsLeft: left);
      }
      _answered++;
      _picked = null;
      _qStart = seconds;
      game.hidden.clear();
    });
    _busy = false;
    _persist();
    if (game.lost) {
      _offerContinue();
    } else if (game.finished) {
      _roundDone();
    }
  }

  Future<void> _offerContinue() async {
    clockPaused = true;
    final again = await ctx.requestContinue();
    clockPaused = false;
    if (!mounted) return;
    if (again && !game.finished) {
      setState(() {
        game.addLife();
        _qStart = seconds;
      });
    } else if (again) {
      game.addLife();
      _roundDone();
    } else {
      _end(false);
    }
  }

  void _roundDone() {
    if (_chain) {
      _rounds++;
      _correctTotal += game.correct;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _rounds]));
      setState(() {
        level = createRules().build(next).puzzle as QuizLevel;
        game = QuizGame(level);
        _qStart = seconds;
      });
      _persist();
      return;
    }
    _end(game.won || _zen);
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    var stars = game.mistakes == 0 ? 3 : (game.mistakes <= 2 ? 2 : 1);
    if (_chain) stars = _rounds >= 3 ? 3 : (_rounds >= 1 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: game.score + _rounds * 1000,
      stars: won ? stars : 0,
      seconds: seconds,
      moves: _answered,
      hintsUsed: _hints,
      gameStats: {
        'correct_answers': _correctTotal + game.correct,
        'best_streak': game.bestStreak,
        'perfect_quizzes': won && game.mistakes == 0 ? 1 : 0,
      },
    ));
  }

  Future<void> _hint() async {
    if (_busy || game.finished || !await ctx.requestHint()) return;
    _hints++;
    setState(() => game.hint(_r));
  }

  Future<void> _fifty() async {
    if (_busy || game.finished || !await ctx.requestBooster()) return;
    setState(() => game.fifty(_r));
  }

  Widget _visual(Question q, ColorScheme cs) {
    switch (q.visual) {
      case 1:
        final icons = q.vis.split(',');
        return Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
          for (final i in icons)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(iconFor(i), size: icons.length == 1 ? 110 : 64, color: cs.primary, semanticLabel: 'symbol'),
              ),
            ),
        ]);
      case 2:
        return Text(flagOf(q.vis), style: const TextStyle(fontSize: 96));
      case 3:
        return Text(q.vis, textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: cs.primary));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_zen && !_busy && !_ended && !game.finished && !game.lost && _left <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _answer(-1));
    }
    if (game.finished) {
      return WordBackdrop(colors: ctx.background, child: const Center(child: CircularProgressIndicator()));
    }
    final q = game.q;
    final opts = q.options(_tr);
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, ctx.spec.mode == GameModeId.timeAttack ? timeText : (_zen ? '∞' : '${_left.clamp(0, 99)}')),
          (Icons.quiz, '${game.index + 1}/${level.qs.length}'),
          (Icons.favorite, _zen ? '∞' : '${game.lives}'),
          (Icons.local_fire_department, '${game.streak}'),
          if (_chain) (Icons.emoji_events, '$_rounds'),
        ]),
        if (!_zen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(value: (_left / level.secondsPerQ).clamp(0, 1), minHeight: 6),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _visual(q, cs),
              const SizedBox(height: 16),
              Text(q.prompt(_tr), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            for (var i = 0; i < opts.length; i++)
              if (!game.hidden.contains(i))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: _picked == null
                            ? null
                            : (i == q.answer ? Colors.green.shade400 : (i == _picked ? Colors.red.shade400 : null)),
                      ),
                      onPressed: () => _answer(i),
                      child: Text(opts[i], style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
          ]),
        ),
        BoosterBar(buttons: [
          BoosterButton(Icons.filter_2, '50/50', _fifty),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}
