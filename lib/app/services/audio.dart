import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum Sfx { tap, place, clear, combo, win, lose, coin, error, unlock }

/// Short generated sound effects (assets/sfx/*.wav, created by
/// tool/generate_assets.py) + a soft ambient loop. Every call is guarded:
/// a missing asset or audio failure never interrupts the game.
class AudioService {
  final Map<Sfx, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool sound = true;
  bool music = true;
  bool haptics = true;
  bool _failed = false;

  Future<void> init() async {
    try {
      for (final s in Sfx.values) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sfx/${s.name}.wav'));
        _players[s] = p;
      }
    } catch (_) {
      _failed = true;
    }
  }

  Future<void> play(Sfx s) async {
    if (haptics) {
      switch (s) {
        case Sfx.clear:
        case Sfx.combo:
        case Sfx.win:
          HapticFeedback.mediumImpact();
          break;
        case Sfx.error:
        case Sfx.lose:
          HapticFeedback.heavyImpact();
          break;
        default:
          HapticFeedback.selectionClick();
      }
    }
    if (!sound || _failed) return;
    try {
      final p = _players[s];
      if (p == null) return;
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  Future<void> startMusic() async {
    if (!music || _failed) return;
    try {
      _music ??= AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.25);
      await _music!.play(AssetSource('sfx/music.wav'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  Future<void> pauseAll() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> resumeAll() async {
    if (music) {
      try {
        await _music?.resume();
      } catch (_) {}
    }
  }
}
