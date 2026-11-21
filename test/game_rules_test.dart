import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'package:game_059_daily_brain_quiz/game/quiz_engine.dart';
import 'package:game_059_daily_brain_quiz/game/rules.dart';

void main() {
  final rules = BrainRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('quizzes have unique questions with one right answer', () {
    for (final n in [1, 10, 99, 1234, 20000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      expect(l.kind, QuizKind.brain);
      expect(checkQuiz(l), isNull, reason: 'level $n');
      for (final q in l.qs) {
        expect(q.prompt(true), isNotEmpty);
        expect(q.prompt(false), isNotEmpty);
        expect(q.options(true).length, q.options(false).length);
      }
    }
  });

  test('a perfect player wins with full lives, wrong answers cost lives', () {
    final l = rules.build(planner.spec(25)).puzzle;
    final g = QuizGame(l);
    while (!g.finished) {
      expect(g.answer(g.q.answer, secondsLeft: 5), isTrue);
    }
    expect(g.won, isTrue);
    expect(g.lives, l.lives);
    expect(g.bestStreak, l.qs.length);
    final h = QuizGame(l);
    expect(h.answer((h.q.answer + 1) % h.q.oEn.length), isFalse);
    expect(h.lives, l.lives - 1);
  });

  test('50/50 hides two wrong answers, hint one; resume', () {
    final l = rules.build(planner.spec(3)).puzzle;
    final g = QuizGame(l);
    while (g.q.oEn.length < 4) {
      g.answer(g.q.answer);
    }
    g.fifty(SeededRandom(1));
    expect(g.hidden.length, 2);
    expect(g.hidden.contains(g.q.answer), isFalse);
    g.answer(g.q.answer);
    expect(QuizGame.restore(l, g.serialize()).serialize(), g.serialize());
  });

  test('flags are regional indicator pairs', () {
    expect(flagOf('TR').runes.length, 2);
  });

  test('levels 1..80 valid', () {
    for (var n = 1; n <= 80; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
