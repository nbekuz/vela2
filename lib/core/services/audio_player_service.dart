import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// Service for managing audio playback using just_audio
/// SODDA VA BARQAROR - stream-based yondashuv
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Position stream (faqat file mode uchun)
  Stream<Duration> get positionStream => _player.positionStream;

  /// Duration stream
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Player state stream (for detecting completion)
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Play audio from file or URL (SODDA)
  Future<void> playFromFile(String filePathOrUrl, {Duration? initialPosition}) async {
    await _player.stop();
    
    // URL yoki file path ni aniqlash
    if (filePathOrUrl.startsWith('http://') || filePathOrUrl.startsWith('https://')) {
      // URL - setUrl ishlatish
      await _player.setUrl(filePathOrUrl);
      } else {
      // Local file path - setFilePath ishlatish
      await _player.setFilePath(filePathOrUrl);
    }
    
      if (initialPosition != null && initialPosition.inMilliseconds > 0) {
      await _player.seek(initialPosition);
    }
  }

  /// Play
  Future<void> play() => _player.play();

  /// Pause
  Future<void> pause() => _player.pause();

  /// Stop
  Future<void> stop() => _player.stop();

  /// Seek
  Future<void> seek(Duration position) => _player.seek(position);

  /// Set volume
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  /// Check if playing
  bool get isPlaying => _player.playing;

  /// Dispose (async - for normal cleanup)
  Future<void> dispose() async {
    await _player.stop();
    await _player.dispose();
  }

  /// Dispose sync (for widget dispose - no await)
  void disposeSync() {
    try {
      _player.dispose();
      } catch (e) {
      print('⚠️ [AudioPlayerService] Error in sync dispose: $e');
    }
  }
}
