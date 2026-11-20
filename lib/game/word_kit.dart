import '../core/rng.dart';
import 'word_data.dart';

/// A word from the categorized bank (used for themes, clues and hints).
class Entry {
  final String word;
  final String cat;
  final String clue;
  const Entry(this.word, this.cat, this.clue);
}

/// Content in both languages: every level is generated for EN and TR from
/// the same seed, the screen shows the one matching the player's language.
class Dual<T> {
  final T en;
  final T tr;
  const Dual(this.en, this.tr);
  T of(bool tr) => tr ? this.tr : en;
}

/// Offline dictionary + letter statistics for one language.
class WordLang {
  final bool tr;
  final String alphabet;
  final List<String> words;
  final Set<String> dict;
  final List<Entry> bank;
  final List<String> letters;
  final List<int> weights;
  final Set<String> prefixes;
  final Map<int, List<String>> byLength;

  WordLang._(this.tr, this.alphabet, this.words, this.bank, this.letters, this.weights)
      : dict = words.toSet(),
        prefixes = {for (final w in words) for (var i = 1; i <= w.length; i++) w.substring(0, i)},
        byLength = _group(words);

  static Map<int, List<String>> _group(List<String> words) {
    final m = <int, List<String>>{};
    for (final w in words) {
      (m[w.length] ??= []).add(w);
    }
    return m;
  }

  static WordLang? _en, _tr;

  static WordLang of(bool tr) => tr ? (_tr ??= _build(true)) : (_en ??= _build(false));

  static WordLang _build(bool tr) {
    final alphabet = tr ? 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ' : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final words = (tr ? kTrWords : kEnWords).split(' ');
    final bank = [for (final b in (tr ? kTrBank : kEnBank)) Entry(b[0], b[1], b[2])];
    final counts = <String, int>{};
    for (final w in words) {
      for (final c in w.split('')) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final letters = [for (final c in alphabet.split('')) c];
    final weights = [for (final c in letters) (counts[c] ?? 0) + 1];
    return WordLang._(tr, alphabet, words, bank, letters, weights);
  }

  String catName(String cat) => (kCategories[cat] ?? const ['?', '?'])[tr ? 1 : 0];

  List<String> get categories => kCategories.keys.toList();

  String randomLetter(SeededRandom r) => letters[r.weighted(weights)];

  bool isVowel(String c) => (tr ? 'AEIİOÖUÜ' : 'AEIOU').contains(c);

  /// Uppercases typed text with the language's rules (i -> İ in Turkish).
  String up(String s) => tr ? s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase() : s.toUpperCase();

  List<Entry> bankFor(String cat) => bank.where((e) => e.cat == cat).toList();
}

Map<String, int> letterCounts(String w) {
  final m = <String, int>{};
  for (final c in w.split('')) {
    m[c] = (m[c] ?? 0) + 1;
  }
  return m;
}

bool canForm(String w, Map<String, int> pool) {
  final need = letterCounts(w);
  for (final e in need.entries) {
    if ((pool[e.key] ?? 0) < e.value) return false;
  }
  return true;
}

/// Simple escaping for the `|`/`;` separated resume snapshots.
String joinList(Iterable<String> l) => l.join(',');
List<String> splitList(String s) => s.isEmpty ? <String>[] : s.split(',');
