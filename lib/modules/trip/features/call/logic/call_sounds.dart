import 'package:audioplayers/audioplayers.dart';

/// Loops the synthesized call tones bundled in assets/audio: ITU-style
/// 425 Hz ringback for the caller, a warm dual-tone ring for the in-app
/// incoming screen. One player — starting a tone stops the previous one.
class CallSounds {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playRingback() => _loop('audio/ringback.wav');

  Future<void> playRingtone() => _loop('audio/ringtone.wav');

  Future<void> _loop(String asset) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(asset));
    } catch (_) {/* sound is best-effort */}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() => _player.dispose();
}
