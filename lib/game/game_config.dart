import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'quiz_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-059-daily-brain-quiz',
  title: const ['Günlük Zekâ Testi', 'Daily Brain Quiz', 'Tägliches Gehirnquiz', 'Quiz Mental Diario', 'Quiz Cérébral du Jour'],
  tagline: const ['Her gün yeni sorularla zihnini çalıştır!', 'Train your brain with new questions every day!', 'Trainiere täglich dein Gehirn!', '¡Entrena tu mente cada día!', 'Entraînez votre cerveau chaque jour !'],
  seedColor: const Color(0xFFFF4D6D),
  icon: Icons.psychology,
  rules: BrainRules(),
  buildPlay: (ctx) => QuizView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.calculate, ['İşlem ve dizi sorularında hızlı düşün.', 'Think fast on math and sequence questions.', 'Schnell rechnen!', '¡Piensa rápido!', 'Réfléchissez vite !']),
    TutorialStep(Icons.category, ['Gruba uymayanı bul.', 'Find the odd one out.', 'Finde den Außenseiter.', 'Encuentra el intruso.', 'Trouvez l\'intrus.']),
    TutorialStep(Icons.today, ['Günlük test her gün yenilenir.', 'The daily test changes every day.', 'Der Tagestest wechselt täglich.', 'El test diario cambia cada día.', 'Le test du jour change chaque jour.']),
  ],
);
