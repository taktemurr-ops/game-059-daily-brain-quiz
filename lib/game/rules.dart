import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'quiz_engine.dart';

class BrainRules extends GameRules<QuizLevel> {
  @override
  String get gameId => 'game-059-daily-brain-quiz';

  @override
  List<String> get optionalMechanics => const ['speed', 'sudden_death'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('correct_answers', 'Doğru cevap', 'Correct answers', scale: 200),
        GameStat('best_streak', 'En uzun seri', 'Best streak', scale: 5),
        GameStat('perfect_quizzes', 'Kusursuz test', 'Perfect tests', scale: 3),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'correct_answers', [10, 25, 50]),
        MissionTemplate('m2', 'best_streak', [1, 3, 5], coinReward: 80),
      ];

  @override
  QuizLevel generate(LevelSpec spec) => generateQuiz(QuizKind.brain, spec);

  @override
  Validation validate(QuizLevel l, LevelSpec spec) {
    final e = checkQuiz(l);
    return e == null ? Validation.ok(l.qs.length) : Validation.fail(e);
  }
}

GameRules createRules() => BrainRules();
