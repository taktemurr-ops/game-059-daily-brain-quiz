import '../core/level_plan.dart';
import '../core/rng.dart';
import 'word_data.dart';

/// Shared multiple-choice engine for Trivia, Symbol, Country and Brain quizzes.
enum QuizKind { trivia, symbol, country, brain }

class Question {
  final String pEn;
  final String pTr;

  /// 0 none, 1 material icon name(s) (comma separated), 2 flag (iso2), 3 big text
  final int visual;
  final String vis;
  final List<String> oEn;
  final List<String> oTr;
  final int answer;
  final String key;
  const Question(this.pEn, this.pTr, this.visual, this.vis, this.oEn, this.oTr, this.answer, this.key);

  String prompt(bool tr) => tr ? pTr : pEn;
  List<String> options(bool tr) => tr ? oTr : oEn;
}

class QuizLevel {
  final QuizKind kind;
  final List<Question> qs;
  final int secondsPerQ;
  final int lives;
  const QuizLevel(this.kind, this.qs, this.secondsPerQ, this.lives);
}

/// Unicode regional-indicator flag for an ISO 3166 alpha-2 code.
String flagOf(String iso) => String.fromCharCodes(iso.codeUnits.map((c) => 0x1F1E6 + c - 65));

class _Opt {
  final String en;
  final String tr;
  const _Opt(this.en, this.tr);
}

Question _mc(SeededRandom r, String pEn, String pTr, int visual, String vis, _Opt right, List<_Opt> wrong, String key) {
  final opts = [right, ...wrong.take(3)];
  r.shuffle(opts);
  return Question(pEn, pTr, visual, vis, [for (final o in opts) o.en], [for (final o in opts) o.tr], opts.indexOf(right), key);
}

List<_Opt> _distinct(SeededRandom r, _Opt right, List<_Opt> pool, int n) {
  final out = <_Opt>[];
  final seenEn = {right.en}, seenTr = {right.tr};
  final p = [...pool];
  r.shuffle(p);
  for (final o in p) {
    if (out.length >= n) break;
    if (seenEn.contains(o.en) || seenTr.contains(o.tr)) continue;
    seenEn.add(o.en);
    seenTr.add(o.tr);
    out.add(o);
  }
  return out;
}

Question countryQ(SeededRandom r, int difficulty, {bool flagsOnly = false}) {
  final c = kCountries[r.nextInt(kCountries.length)];
  final near = difficulty >= 5 ? kCountries.where((x) => x[5] == c[5]).toList() : kCountries;
  final pool = near.length >= 4 ? near : kCountries;
  final type = flagsOnly ? 0 : r.nextInt(difficulty <= 2 ? 2 : 4);
  switch (type) {
    case 0:
      final right = _Opt(c[1], c[2]);
      return _mc(r, 'Which country does this flag belong to?', 'Bu bayrak hangi ülkeye ait?', 2, c[0], right,
          _distinct(r, right, [for (final x in pool) _Opt(x[1], x[2])], 3), 'flag${c[0]}');
    case 1:
      final right = _Opt(c[3], c[4]);
      return _mc(r, 'What is the capital of ${c[1]}?', '${c[2]} ülkesinin başkenti neresidir?', 2, c[0], right,
          _distinct(r, right, [for (final x in pool) _Opt(x[3], x[4])], 3), 'cap${c[0]}');
    case 2:
      final right = _Opt(c[1], c[2]);
      return _mc(r, '${c[3]} is the capital of which country?', '${c[4]} hangi ülkenin başkentidir?', 0, '', right,
          _distinct(r, right, [for (final x in pool) _Opt(x[1], x[2])], 3), 'cty${c[0]}');
    default:
      final cont = kContinents[c[5]]!;
      final right = _Opt(cont[0], cont[1]);
      return _mc(r, 'On which continent is ${c[1]}?', '${c[2]} hangi kıtadadır?', 2, c[0], right,
          _distinct(r, right, [for (final v in kContinents.values) _Opt(v[0], v[1])], 3), 'con${c[0]}');
  }
}

Question elementQ(SeededRandom r) {
  final e = kElements[r.nextInt(kElements.length)];
  if (r.chance(0.5)) {
    final right = _Opt(e.$2, e.$3);
    return _mc(r, 'Which element has the symbol ${e.$1}?', '${e.$1} sembolü hangi elemente aittir?', 3, e.$1, right,
        _distinct(r, right, [for (final x in kElements) _Opt(x.$2, x.$3)], 3), 'el${e.$1}');
  }
  final right = _Opt(e.$1, e.$1);
  return _mc(r, 'What is the chemical symbol of ${e.$2}?', '${e.$3} elementinin sembolü nedir?', 0, '', right,
      _distinct(r, right, [for (final x in kElements) _Opt(x.$1, x.$1)], 3), 'es${e.$1}');
}

Question factQ(SeededRandom r) {
  final f = kFacts[r.nextInt(kFacts.length)];
  final wrong = [for (var i = 0; i < 3; i++) _Opt(f.$3[i], f.$6[i])];
  return _mc(r, f.$1, f.$4, 0, '', _Opt(f.$2, f.$5), wrong, 'f${f.$1.hashCode}');
}

List<_Opt> _numWrong(SeededRandom r, int v, int spread) {
  final s = <int>{v};
  final out = <_Opt>[];
  var guard = 0;
  while (out.length < 3 && guard++ < 100) {
    final d = r.range(1, spread) * (r.chance(0.5) ? 1 : -1);
    final w = v + d;
    if (s.add(w)) out.add(_Opt('$w', '$w'));
  }
  return out;
}

Question mathQ(SeededRandom r, int difficulty) {
  final hi = 10 + difficulty * 8;
  final op = r.nextInt(difficulty <= 2 ? 2 : 4);
  int a = r.range(2, hi), b = r.range(2, hi), v;
  String s;
  switch (op) {
    case 0:
      v = a + b;
      s = '$a + $b';
    case 1:
      if (b > a) (a, b) = (b, a);
      v = a - b;
      s = '$a − $b';
    case 2:
      a = r.range(2, 4 + difficulty * 2);
      b = r.range(2, 12);
      v = a * b;
      s = '$a × $b';
    default:
      b = r.range(2, 12);
      v = r.range(2, 4 + difficulty * 2);
      a = v * b;
      s = '$a ÷ $b';
  }
  return _mc(r, '$s = ?', '$s = ?', 3, s, _Opt('$v', '$v'), _numWrong(r, v, 2 + difficulty), 'm$s');
}

Question sequenceQ(SeededRandom r, int difficulty) {
  final start = r.range(1, 9 + difficulty);
  final kind = r.nextInt(difficulty <= 3 ? 1 : 3);
  final seq = <int>[];
  switch (kind) {
    case 0:
      final step = r.range(2, 3 + difficulty);
      for (var i = 0; i < 5; i++) {
        seq.add(start + step * i);
      }
    case 1:
      final m = r.range(2, 3);
      for (var i = 0; i < 5; i++) {
        seq.add(start * _pow(m, i));
      }
    default:
      var a = start, d = r.range(1, 3);
      for (var i = 0; i < 5; i++) {
        seq.add(a);
        a += d;
        d += r.range(1, 2);
      }
  }
  final shown = '${seq.take(4).join(', ')}, ?';
  return _mc(r, 'What comes next?', 'Sırada hangi sayı var?', 3, shown, _Opt('${seq[4]}', '${seq[4]}'),
      _numWrong(r, seq[4], 3 + difficulty), 'q$shown');
}

int _pow(int b, int e) => e == 0 ? 1 : b * _pow(b, e - 1);

Question compareQ(SeededRandom r, int difficulty) {
  final a = r.range(10, 40 + difficulty * 20), b = r.range(2, 9), c = r.range(10, 40 + difficulty * 20), d = r.range(2, 9);
  final x = a * b, y = c + d * 10;
  if (x == y) return mathQ(r, difficulty);
  final right = x > y ? _Opt('$a × $b', '$a × $b') : _Opt('$c + ${d * 10}', '$c + ${d * 10}');
  final wrong = x > y ? _Opt('$c + ${d * 10}', '$c + ${d * 10}') : _Opt('$a × $b', '$a × $b');
  final opts = [right, wrong];
  r.shuffle(opts);
  return Question('Which is bigger?', 'Hangisi daha büyük?', 0, '', [for (final o in opts) o.en], [for (final o in opts) o.tr],
      opts.indexOf(right), 'c$a$b$c$d');
}

Question oddOneOutQ(SeededRandom r) {
  final cats = {for (final i in kIconWords) i[3]}.toList()..sort();
  for (var t = 0; t < 20; t++) {
    final ca = cats[r.nextInt(cats.length)];
    final cb = cats[r.nextInt(cats.length)];
    if (ca == cb) continue;
    final a = kIconWords.where((i) => i[3] == ca).toList();
    final b = kIconWords.where((i) => i[3] == cb).toList();
    if (a.length < 3 || b.isEmpty) continue;
    r.shuffle(a);
    final odd = b[r.nextInt(b.length)];
    final right = _Opt(odd[1], odd[2]);
    return _mc(r, 'Which one does not belong?', 'Hangisi gruba uymuyor?', 0, '', right,
        [for (final x in a.take(3)) _Opt(x[1], x[2])], 'o${odd[0]}${a.take(3).map((x) => x[0]).join()}');
  }
  return mathQ(r, 3);
}

Question symbolQ(SeededRandom r, int difficulty) {
  final it = kIconWords[r.nextInt(kIconWords.length)];
  final same = kIconWords.where((x) => x[3] == it[3] && x[0] != it[0]).toList();
  final pool = difficulty >= 5 && same.length >= 3 ? same : kIconWords;
  final right = _Opt(it[1], it[2]);
  return _mc(r, 'What does this symbol show?', 'Bu sembol neyi gösteriyor?', 1, it[0], right,
      _distinct(r, right, [for (final x in pool) _Opt(x[1], x[2])], 3), 's${it[0]}');
}

Question comboQ(SeededRandom r) {
  final c = kCombos[r.nextInt(kCombos.length)];
  final right = _Opt(c.$2, c.$3);
  return _mc(r, 'Which word links these symbols?', 'Bu sembolleri hangi kelime birleştirir?', 1, c.$1.join(','), right,
      _distinct(r, right, [for (final x in kCombos) _Opt(x.$2, x.$3)], 3), 'k${c.$2}');
}

Question questionFor(QuizKind kind, SeededRandom r, int difficulty) {
  switch (kind) {
    case QuizKind.trivia:
      final k = r.weighted([5, 3, 2, 1]);
      return switch (k) { 0 => factQ(r), 1 => countryQ(r, difficulty), 2 => elementQ(r), _ => mathQ(r, difficulty) };
    case QuizKind.symbol:
      return difficulty >= 4 && r.chance(0.3) ? comboQ(r) : symbolQ(r, difficulty);
    case QuizKind.country:
      return countryQ(r, difficulty, flagsOnly: difficulty <= 1 && r.chance(0.5));
    case QuizKind.brain:
      final k = r.weighted([3, 3, 2, 2, 1]);
      return switch (k) {
        0 => mathQ(r, difficulty),
        1 => sequenceQ(r, difficulty),
        2 => oddOneOutQ(r),
        3 => compareQ(r, difficulty),
        _ => factQ(r),
      };
  }
}

QuizLevel generateQuiz(QuizKind kind, LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final n = 8 + spec.difficulty ~/ 2;
  final qs = <Question>[];
  final keys = <String>{};
  var guard = 0;
  while (qs.length < n && guard++ < n * 30) {
    final q = questionFor(kind, r, spec.difficulty);
    if (keys.add(q.key)) qs.add(q);
  }
  var secs = 26 - spec.difficulty;
  if (spec.has('speed')) secs = secs * 2 ~/ 3;
  final lives = spec.has('sudden_death') ? 1 : (spec.difficulty <= 3 ? 3 : 2);
  return QuizLevel(kind, qs, secs, lives);
}

String? checkQuiz(QuizLevel l) {
  if (l.qs.length < 8) return 'few questions';
  if (l.qs.map((q) => q.key).toSet().length != l.qs.length) return 'duplicate question';
  for (final q in l.qs) {
    for (final o in [q.oEn, q.oTr]) {
      if (o.length < 2 || o.toSet().length != o.length) return 'options ${q.key}';
      if (q.answer < 0 || q.answer >= o.length) return 'answer ${q.key}';
    }
  }
  return null;
}

class QuizGame {
  final QuizLevel l;
  int index = 0;
  int correct = 0;
  int mistakes = 0;
  int streak = 0;
  int bestStreak = 0;
  int lives;
  int score = 0;
  final Set<int> hidden = {};
  QuizGame(this.l) : lives = l.lives;

  Question get q => l.qs[index];
  bool get finished => index >= l.qs.length;
  bool get won => finished && lives > 0;
  bool get lost => lives <= 0;

  /// Returns true when [choice] is right. [secondsLeft] adds a speed bonus.
  bool answer(int choice, {int secondsLeft = 0}) {
    if (finished || lost) return false;
    final ok = choice == q.answer;
    if (ok) {
      correct++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      score += 100 + secondsLeft * 5 + (streak >= 3 ? 50 : 0);
    } else {
      mistakes++;
      streak = 0;
      lives--;
    }
    index++;
    hidden.clear();
    return ok;
  }

  /// Time ran out for the current question.
  void timeout() => answer(-1);

  /// 50/50 booster: hides two wrong answers.
  void fifty(SeededRandom r) {
    final wrong = [for (var i = 0; i < q.oEn.length; i++) if (i != q.answer && !hidden.contains(i)) i];
    r.shuffle(wrong);
    hidden.addAll(wrong.take(wrong.length - 1 < 2 ? wrong.length - 1 : 2));
  }

  /// Hint: hides one wrong answer.
  bool hint(SeededRandom r) {
    final wrong = [for (var i = 0; i < q.oEn.length; i++) if (i != q.answer && !hidden.contains(i)) i];
    if (wrong.length <= 1) return false;
    hidden.add(wrong[r.nextInt(wrong.length)]);
    return true;
  }

  void addLife() => lives++;

  String serialize() => [index, correct, mistakes, streak, bestStreak, lives, score].join('|');

  factory QuizGame.restore(QuizLevel l, String s) {
    final g = QuizGame(l);
    final p = s.split('|').map((x) => int.tryParse(x) ?? 0).toList();
    if (p.length < 7) return g;
    g.index = p[0].clamp(0, l.qs.length);
    g.correct = p[1];
    g.mistakes = p[2];
    g.streak = p[3];
    g.bestStreak = p[4];
    g.lives = p[5];
    g.score = p[6];
    return g;
  }
}
