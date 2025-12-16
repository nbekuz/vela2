import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';

enum PlayerMode { pcmStream, filePlayback }

class PcmStreamPlayer {
  FlutterSoundPlayer? _player;
  PlayerMode _mode = PlayerMode.pcmStream;

  bool _started = false;
  bool _initialized = false;
  bool _isPaused = false;
  bool _disposed = false; // Track if player is fully disposed

  /// PCM params
  final int sampleRate;
  final int channels;
  final int bytesPerSample;

  /// 1 frame = channels * bytesPerSample
  late final int _frameSize;

  /// leftover bytes for frame alignment
  Uint8List? _leftover;

  /// Buffer for accumulating small chunks (iOS prefers ≥4KB chunks)
  final BytesBuilder _chunkBuffer = BytesBuilder();
  
  /// Minimum chunk size for iOS (8KB = ~46ms @ 44.1kHz stereo)
  /// iOS audio engine prefers chunks ≥4KB to reduce needSomeFood calls
  /// Kattaroq chunk size to'xtab-to'xtab ijro etilishini oldini olish uchun
  static const int _minChunkSize = 8192;

  /// File playback uchun callbacks
  Function(Duration)? onPositionChanged;
  Function(Duration)? onDurationChanged;
  Function(bool)? onPlayingStateChanged;

  PcmStreamPlayer({
    required this.sampleRate,
    this.channels = 2,
    this.bytesPerSample = 2,
  }) {
    _frameSize = channels * bytesPerSample;
  }

  // ---------------- INIT ----------------

  Future<void> start() async {
    // Reset disposed flag if starting again
    _disposed = false;
    if (_initialized && _mode == PlayerMode.pcmStream) return;

    // Disable debug logs to reduce console spam
    _player = FlutterSoundPlayer(logLevel: Level.nothing);
    await _player!.openPlayer();

    final bufferSize = Platform.isIOS
        ? 262144 // ~3s - kattaroq buffer to'xtab-to'xtab ijro etilishini oldini olish uchun
        : 131072; // ~1.5s

    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: channels > 1,
      numChannels: channels,
      sampleRate: sampleRate,
      bufferSize: bufferSize,
    );

    _initialized = true;
    _started = true;
    _mode = PlayerMode.pcmStream;
    _isPaused = false;
  }

  // ---------------- ADD PCM ----------------

  void addChunk(Uint8List chunk) {
    if (!_started || _player == null) return;

    // Add chunk to buffer
    _chunkBuffer.add(chunk);

    // iOS prefers chunks ≥4KB, so buffer until we have enough
    if (_chunkBuffer.length < _minChunkSize) {
      return; // Wait for more data
    }

    // Get buffered data
    final bufferedData = _chunkBuffer.takeBytes();
    _chunkBuffer.clear();

    Uint8List data;

    // 1️⃣ oldingi qoldiqni qo'shamiz
    if (_leftover != null && _leftover!.isNotEmpty) {
      data = Uint8List(_leftover!.length + bufferedData.length)
        ..setAll(0, _leftover!)
        ..setAll(_leftover!.length, bufferedData);
      _leftover = null;
    } else {
      data = bufferedData;
    }

    // 2️⃣ frame-alignment
    final usableLen = data.length - (data.length % _frameSize);

    if (usableLen <= 0) {
      _leftover = data;
      return;
    }

    final aligned = data.sublist(0, usableLen);
    _leftover = data.sublist(usableLen);

    // 3️⃣ feed audio (now guaranteed to be ≥4KB and frame-aligned)
    _player!.uint8ListSink!.add(aligned);
  }

  /// Flush any remaining buffered data (call when stream ends)
  void flush() {
    if (!_started || _player == null || _chunkBuffer.length == 0) return;

    final remaining = _chunkBuffer.takeBytes();
    _chunkBuffer.clear();

    if (remaining.isEmpty) return;

    Uint8List data;

    // Combine with leftover
    if (_leftover != null && _leftover!.isNotEmpty) {
      data = Uint8List(_leftover!.length + remaining.length)
        ..setAll(0, _leftover!)
        ..setAll(_leftover!.length, remaining);
      _leftover = null;
    } else {
      data = remaining;
    }

    // Frame-align
    final usableLen = data.length - (data.length % _frameSize);
    if (usableLen > 0) {
      final aligned = data.sublist(0, usableLen);
      _player!.uint8ListSink!.add(aligned);
      _leftover = data.sublist(usableLen);
    } else {
      _leftover = data;
    }
  }

  // ---------------- FILE PLAYBACK ----------------

  /// Switch from PCM stream to file playback mode
  Future<void> switchToFilePlayback(String filePath, {Duration? initialPosition}) async {
    print('🔄 [PcmStreamPlayer] File playback ga o\'tish: $filePath');
    
    // Stop PCM streaming
    if (_mode == PlayerMode.pcmStream && _started) {
      flush();
      await _player?.stopPlayer();
    }

    // Reuse existing player or create new one
    if (_player == null) {
      _player = FlutterSoundPlayer(logLevel: Level.nothing);
      await _player!.openPlayer();
    }

    try {
      // CRITICAL: Set subscription duration for onProgress stream to work!
      await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
      print('✅ [PcmStreamPlayer] Subscription duration o\'rnatildi');
      
      // Start file playback - codec auto-detected from file extension
      await _player!.startPlayer(
        fromURI: filePath,
        codec: Codec.pcm16WAV, // WAV files uchun
        whenFinished: () {
          print('🔄 [PcmStreamPlayer] File playback tugadi');
          _started = false;
          onPlayingStateChanged?.call(false);
        },
      );

      _mode = PlayerMode.filePlayback;
      _started = true;
      _isPaused = false;
      _initialized = true;

      // Seek to initial position if provided
      if (initialPosition != null && initialPosition.inMilliseconds > 0) {
        print('🔄 [PcmStreamPlayer] Initial position: ${initialPosition.inSeconds}s');
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          await _player!.seekToPlayer(initialPosition);
          print('✅ [PcmStreamPlayer] Position restored: ${initialPosition.inSeconds}s');
          
          // Update manual tracking start position
          _filePlaybackStartPosition = initialPosition;
          _filePlaybackStartTime = DateTime.now();
        } catch (e) {
          print('❌ [PcmStreamPlayer] Error seeking: $e');
        }
      } else {
        // Reset start position if no initial position
        _filePlaybackStartPosition = Duration.zero;
        _filePlaybackStartTime = DateTime.now();
      }

      // Start position tracking for file playback
      _startFilePositionTracking();

      print('✅ [PcmStreamPlayer] File playback boshlandi');
    } catch (e) {
      print('❌ [PcmStreamPlayer] Error starting file playback: $e');
      rethrow;
    }
  }

  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  Timer? _positionPollingTimer;
  DateTime? _filePlaybackStartTime;
  Duration? _filePlaybackStartPosition;
  Duration? _lastReportedPosition; // Track last position to prevent backward jumps
  bool _onProgressActive = false; // Track if onProgress is reporting accurate positions

  /// Start position tracking for file playback
  void _startFilePositionTracking() {
    _progressSubscription?.cancel();
    _positionPollingTimer?.cancel();
    
    if (_player == null) {
      print('⚠️ [PcmStreamPlayer] Player yo\'q, position tracking boshlanmaydi');
      return;
    }
    
    print('🔄 [PcmStreamPlayer] Position tracking boshlanmoqda...');
    
    // Reset tracking state
    _lastReportedPosition = null;
    _onProgressActive = false;
    
    // IMPORTANT: Don't reset _filePlaybackStartPosition here - it's already set in switchToFilePlayback
    // Only set start time if not already set
    if (_filePlaybackStartTime == null) {
      _filePlaybackStartTime = DateTime.now();
    }
    if (_filePlaybackStartPosition == null) {
      _filePlaybackStartPosition = Duration.zero;
    }
    
    // Start manual tracking immediately as fallback/hybrid approach
    // This ensures position updates even if onProgress is delayed
    _startManualPositionTracking();
    
    // Try to use onProgress stream (should work now with setSubscriptionDuration)
    if (_player!.onProgress != null) {
      print('✅ [PcmStreamPlayer] onProgress stream mavjud, ishlatilmoqda...');
      Duration? lastOnProgressPosition;
      int stalePositionCount = 0;
      
      _progressSubscription = _player!.onProgress!.listen((disposition) {
        if (_mode == PlayerMode.filePlayback && _started) {
          final position = disposition.position;
          final duration = disposition.duration;
          
          // Detect if position is stale (not updating)
          if (lastOnProgressPosition != null && position == lastOnProgressPosition) {
            stalePositionCount++;
          } else {
            stalePositionCount = 0;
            lastOnProgressPosition = position;
            
            // Update manual tracking start position when onProgress starts reporting correctly
            if (_filePlaybackStartPosition != null && 
                (position - _filePlaybackStartPosition!).inSeconds.abs() > 1) {
              // onProgress is now reporting accurate positions, sync manual tracking
              _filePlaybackStartPosition = position;
              _filePlaybackStartTime = DateTime.now();
              _onProgressActive = true; // Mark onProgress as active
              print('✅ [PcmStreamPlayer] onProgress position synced: ${position.inSeconds}s');
            }
          }
          
          // Update position when it changes significantly (every second)
          if (position.inSeconds % 1 == 0) {
            print('🔄 [PcmStreamPlayer Progress] Position: ${position.inSeconds}s, Duration: ${duration.inSeconds}s');
          }
          
          // CRITICAL FIX: Only update position if it's newer than last reported position
          // This prevents backward jumps when onProgress reports stale positions
          if (_lastReportedPosition == null || position >= _lastReportedPosition!) {
            _lastReportedPosition = position;
            onPositionChanged?.call(position);
          } else {
            // Skip stale position updates
            print('⚠️ [PcmStreamPlayer] Skipping stale position: ${position.inSeconds}s (last: ${_lastReportedPosition!.inSeconds}s)');
          }
          
          if (duration.inMilliseconds > 0) {
            onDurationChanged?.call(duration);
          }
        }
      }, onError: (e) {
        print('❌ [PcmStreamPlayer] onProgress stream error: $e');
        _onProgressActive = false;
        // Manual tracking will continue as fallback
      });
    } else {
      print('⚠️ [PcmStreamPlayer] onProgress stream yo\'q, faqat manual tracking ishlatilmoqda...');
    }
  }
  
  /// Manual position tracking using timer (fallback/hybrid approach)
  /// This ensures position updates immediately, even if onProgress is delayed
  void _startManualPositionTracking() {
    _positionPollingTimer?.cancel();
    
    _positionPollingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_player == null || _mode != PlayerMode.filePlayback || !_started || _isPaused) {
        return;
      }

      // Manual position tracking based on elapsed time
      if (_filePlaybackStartTime != null && _filePlaybackStartPosition != null) {
        final elapsed = DateTime.now().difference(_filePlaybackStartTime!);
        final currentPosition = _filePlaybackStartPosition! + elapsed;
        
        // CRITICAL FIX: Only update from manual tracking if:
        // 1. onProgress is not active yet, OR
        // 2. Manual position is newer than last reported position
        // This prevents manual tracking from overriding accurate onProgress positions
        if (!_onProgressActive || 
            _lastReportedPosition == null || 
            currentPosition > _lastReportedPosition!) {
          _lastReportedPosition = currentPosition;
          onPositionChanged?.call(currentPosition);
          
          // Debug log every second
          if (currentPosition.inSeconds % 1 == 0 && 
              currentPosition.inMilliseconds % 1000 < 100) {
            print('🔄 [PcmStreamPlayer Manual] Position: ${currentPosition.inSeconds}s');
          }
        }
      }
    });
  }

  /// Pause playback (works for both modes)
  Future<void> pause() async {
    if (_player == null) return;

    if (_mode == PlayerMode.filePlayback) {
      await _player!.pausePlayer();
      _isPaused = true;
      onPlayingStateChanged?.call(false);
      print('✅ [PcmStreamPlayer] File playback paused');
    } else {
      // PCM streaming pause - just mark as paused
      _isPaused = true;
      onPlayingStateChanged?.call(false);
      print('✅ [PcmStreamPlayer] PCM streaming paused (state only)');
    }
  }

  /// Resume playback (works for both modes)
  Future<void> resume() async {
    if (_player == null) return;

    if (_mode == PlayerMode.filePlayback) {
      await _player!.resumePlayer();
      _isPaused = false;
      onPlayingStateChanged?.call(true);
      print('✅ [PcmStreamPlayer] File playback resumed');
    } else {
      // PCM streaming resume - just mark as playing
      _isPaused = false;
      onPlayingStateChanged?.call(true);
      print('✅ [PcmStreamPlayer] PCM streaming resumed (state only)');
    }
  }

  /// Seek to position (file playback only)
  Future<void> seek(Duration position) async {
    if (_player == null || _mode != PlayerMode.filePlayback) {
      print('⚠️ [PcmStreamPlayer] Seek faqat file playback da ishlaydi');
      return;
    }

    try {
      // Seek qilishdan oldin playing holatini saqlash
      final wasPlaying = _started && !_isPaused;
      
      print('🔄 [PcmStreamPlayer] Seek qilmoqda: ${position.inSeconds}s (wasPlaying: $wasPlaying)');
      
      // Seek qilish
      await _player!.seekToPlayer(position);
      print('✅ [PcmStreamPlayer] Seek muvaffaqiyatli: ${position.inSeconds}s');
      
      // Update manual tracking start position and reset tracking state
      _filePlaybackStartPosition = position;
      _filePlaybackStartTime = DateTime.now();
      _lastReportedPosition = position; // Reset to prevent backward jumps
      _onProgressActive = false; // Reset onProgress active state after seek
      
      // Immediately update position callback
      onPositionChanged?.call(position);
      
      // Agar playing bo'lsa, seek qilingandan keyin resume qilish kerak
      // Chunki ba'zi player'larda seek qilinganda pause bo'lib qoladi
      if (wasPlaying && _isPaused) {
        print('🔄 [PcmStreamPlayer] Seek qilingandan keyin resume qilmoqda...');
        await _player!.resumePlayer();
        _isPaused = false;
        onPlayingStateChanged?.call(true);
        print('✅ [PcmStreamPlayer] Resume qilindi seek qilingandan keyin');
      }
    } catch (e) {
      print('❌ [PcmStreamPlayer] Error seeking: $e');
      rethrow;
    }
  }

  /// Get current position (file playback only)
  /// Note: Position is tracked via onProgress stream, this is for one-time queries
  Future<Duration?> getCurrentPosition() async {
    if (_player == null || _mode != PlayerMode.filePlayback) {
      return null;
    }
    // Position is tracked via onProgress stream
    // Return null as we don't have a direct getter
    return null;
  }

  /// Get duration (file playback only)
  /// Note: Duration is tracked via onProgress stream, this is for one-time queries
  Future<Duration?> getDuration() async {
    if (_player == null || _mode != PlayerMode.filePlayback) {
      return null;
    }
    // Duration is tracked via onProgress stream
    // Return null as we don't have a direct getter
    return null;
  }

  // ---------------- STOP ----------------

  Future<void> stop() async {
    // Idempotent: if already disposed, do nothing
    if (_disposed) {
      return;
    }

    print('🛑 [PcmStreamPlayer] Stopping player...');
    
    // Mark as stopped immediately to prevent new chunks
    _started = false;
    _initialized = false;
    _isPaused = false;
    
    // Cancel all subscriptions and timers
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _positionPollingTimer?.cancel();
    _positionPollingTimer = null;
    
    // Flush any remaining buffered data before stopping (PCM mode only)
    if (_mode == PlayerMode.pcmStream && _player != null) {
      try {
        flush();
        print('✅ [PcmStreamPlayer] Flushed remaining data');
      } catch (e) {
        print('⚠️ [PcmStreamPlayer] Error flushing: $e');
      }
    }
    
    _leftover = null;
    _chunkBuffer.clear();

    // 🔴 CRITICAL: Fully dispose flutter_sound player
    if (_player != null) {
      try {
        // Stop player first
        await _player!.stopPlayer();
        print('✅ [PcmStreamPlayer] Player stopped');
        
        // Close player to release audio engine
        await _player!.closePlayer(); // This releases audio engine (iOS AVAudioEngine, Android AudioTrack)
        print('✅ [PcmStreamPlayer] Player closed, audio engine released');
        
        _player = null;
      } catch (e) {
        print('⚠️ [PcmStreamPlayer] Error during stop: $e');
        // Ignore errors during cleanup, but ensure player is null
        _player = null;
      }
    }

    _disposed = true;
    onPlayingStateChanged?.call(false);
    print('✅ [PcmStreamPlayer] Stop complete');
  }

  bool get isPlaying => _started && !_isPaused;
  bool get isPaused => _isPaused;
  PlayerMode get mode => _mode;

  FlutterSoundPlayer? get player => _player;

  Future<void> setVolume(double volume) async {
    if (_player != null) {
      await _player!.setVolume(volume);
    }
  }
}
