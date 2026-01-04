import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../shared/widgets/wave_visualization.dart';
import '../shared/widgets/stars_animation.dart';
import '../core/services/meditation_streaming_service.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/pcm_stream_player.dart' show PcmStreamPlayer;
import '../core/services/api_service.dart';
import '../core/services/meditation_action_service.dart';
import 'components/sleep_meditation_header.dart';
import 'package:provider/provider.dart';
import '../core/stores/meditation_store.dart';
import '../core/stores/like_store.dart';
import '../core/stores/auth_store.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meditation_streaming/helpers.dart';

/// Audio playback mode - state machine
enum AudioMode {
  generating,     // API ishlayapti
  pcmStreaming,   // realtime PCM playback
  transitioning,  // PCM → FILE
  filePaused,     // just_audio paused
  filePlaying,    // just_audio playing
}

class MeditationStreamingPage extends StatefulWidget {
  const MeditationStreamingPage({super.key});

  @override
  State<MeditationStreamingPage> createState() =>
      _MeditationStreamingPageState();
}

class _MeditationStreamingPageState extends State<MeditationStreamingPage> {
  final MeditationStreamingService _streamingService =
      MeditationStreamingService();
  final AudioPlayerService _audioService = AudioPlayerService();
  PcmStreamPlayer? _pcmStreamPlayer;

  // State machine
  AudioMode _mode = AudioMode.generating;

  // UI state
  bool _isLoading = false;
  String? _error;
  double _progressSeconds = 0;
  final List<Uint8List> _pcmChunks = [];
  Uint8List? _wavBytes;
  Timer? _progressTimer;
  Timer? _positionUpdateTimer; // PCM position tracking uchun
  DateTime? _startTime;
  DateTime? _playbackStartTime; // PCM playback boshlangan vaqt
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isMuted = false;
  bool _isLiked = false;
  bool _showGeneratingScreen = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String? _meditationId;

  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupJustAudioListeners();
    _loadRitualSettings();
    _initializeVideoController();
    // Auto-start streaming when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreaming();
    });
    _showGeneratingScreen = true;
  }

  Future<void> _initializeVideoController() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/moon.mp4');
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  Future<void> _loadRitualSettings() async {
    final meditationStore = Provider.of<MeditationStore>(
      context,
      listen: false,
    );
    if (meditationStore.storedRitualType == null) {
      await meditationStore.loadRitualSettings();
    }
  }

  /// Setup just_audio position/duration listeners (faqat file mode uchun)
  void _setupJustAudioListeners() {
    // Position stream - faqat file mode da ishlaydi
    // 🔴 CRITICAL: Transition paytida 0 ni ignore qilamiz (file load glitch)
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (!mounted) return;
      
      // Transition paytida 0 ni ignore qilamiz (savedPosition ni bosib yubormaslik uchun)
      if (_mode == AudioMode.transitioning && position == Duration.zero) {
        return;
      }
      
      if (_mode == AudioMode.filePlaying || _mode == AudioMode.filePaused) {
        setState(() {
          _position = position;
          
          // Audio tugaganda (position duration ga yetganda) mode ni filePaused ga o'zgartirish
          if (_mode == AudioMode.filePlaying && 
              _duration.inMilliseconds > 0 && 
              position >= _duration) {
            print('✅ [Position Stream] Audio completed (position >= duration), switching to paused mode');
            _mode = AudioMode.filePaused;
            _position = _duration; // Position ni duration ga tenglashtirish
          }
        });
      }
    });

    // Duration stream
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        print('🔄 [Duration Stream] Duration updated: ${duration.inSeconds}s');
        setState(() {
          _duration = duration;
        });
      }
    });

    // Player state stream - audio tugaganda mode ni filePaused ga o'zgartirish
    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) {
      if (!mounted) return;
      
      // Audio tugaganda (completed state) yoki position duration ga yetganda
      if (playerState.processingState == ProcessingState.completed) {
        if (_mode == AudioMode.filePlaying) {
          print('✅ [Player State] Audio completed, switching to paused mode');
          setState(() {
            _mode = AudioMode.filePaused;
            // Position ni duration ga tenglashtirish
            if (_duration.inMilliseconds > 0) {
              _position = _duration;
            }
          });
        }
      }
    });

    // Position stream'da ham tekshirish - position duration ga yetganda
    // Bu position stream listener'da qo'shilgan, lekin yana bir marta tekshirish kerak
  }

  @override
  void dispose() {
    print('🧹 [Dispose] Cleaning up all resources...');
    
    // 🔴 CRITICAL: Mode ni transitioning ga o'rnatish - barcha callbacklarni bloklaydi
    // Bu "setState after dispose" warningni 100% yo'q qiladi
    _mode = AudioMode.transitioning;
    
    // Cancel all timers
    _progressTimer?.cancel();
    _positionUpdateTimer?.cancel();
    
    // Cancel stream subscriptions
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    // 🔴 CRITICAL: Sync dispose (await yo'q)
    // Stop PCM player - sync (fire and forget)
    if (_pcmStreamPlayer != null) {
      try {
        // Fire and forget - don't await
        _pcmStreamPlayer!.stop().catchError((e) {
          print('⚠️ [Dispose] Error stopping PCM: $e');
        });
      } catch (e) {
        print('⚠️ [Dispose] Error calling PCM stop: $e');
      }
      _pcmStreamPlayer = null;
    }
    
    // Stop and dispose just_audio player sync
    try {
      _audioService.disposeSync();
    } catch (e) {
      print('⚠️ [Dispose] Error disposing audio: $e');
    }
    
    // Dispose streaming service
    _streamingService.dispose();
    
    // Dispose video controller
    _videoController?.dispose();
    
    print('✅ [Dispose] Cleanup complete');
    super.dispose();
  }

  String _formatTime(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  Future<void> _startStreaming() async {
    print('🔵 ========== _startStreaming called ==========');
    setState(() {
      _error = null;
      _isLoading = true;
      _wavBytes = null;
      _pcmChunks.clear();
      _progressSeconds = 0;
      _showGeneratingScreen = true;
      _mode = AudioMode.generating;
    });

    // Birinchi meditatsiya generatsiya qilinganda ritualType, voice, duration ni localStorage'da saqlash
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirst = prefs.getBool('first') ?? false;
      
      if (isFirst) {
        final meditationStore = Provider.of<MeditationStore>(context, listen: false);
        final ritualType = meditationStore.storedRitualType ?? meditationStore.storedRitualId ?? '1';
        final voice = meditationStore.storedVoice ?? 'female';
        final duration = meditationStore.storedDuration ?? '2';
        
        // Initial ma'lumotlarni saqlash
        await prefs.setString('initial_ritual_type', ritualType);
        await prefs.setString('initial_voice', voice);
        await prefs.setString('initial_duration', duration);
        
        print('✅ [First Meditation] Saved initial settings: ritualType=$ritualType, voice=$voice, duration=$duration');
      }
    } catch (e) {
      print('⚠️ [First Meditation] Error saving initial settings: $e');
    }

    // Agar registratsiya vaqtida bo'lsa, account update ni parallel ravishda yuborish
    _updateNewUserAccountInParallel();

    _progressTimer?.cancel();
    await _streamingService.startStreaming(
      context,
      onChunk: (chunks) {
        if (mounted) {
          setState(() {
            _pcmChunks.clear();
            _pcmChunks.addAll(chunks);
          });
          // Update duration based on chunks
          _updatePcmDuration();
        }
      },
      onNewChunk: (newChunk) {
        // Start PCM streaming if not started yet
        if (_mode == AudioMode.generating) {
          _startPcmStreaming();
        }
        // Add chunk to PCM player
        if (_mode == AudioMode.pcmStreaming && mounted) {
          _onNewPcmChunk(newChunk);
        }
      },
      onComplete: (wavBytes) async {
          if (mounted) {
          setState(() {
            _wavBytes = wavBytes;
            _isLoading = false;
            _showGeneratingScreen = false;
          });

          // API ga meditation yaratish uchun yuborish
          // Bu faqat meditation yaratish uchun, account update allaqachon parallel yuborilgan
          try {
            final result = await createMeditationWithFile(
              context: context,
              wavBytes: wavBytes,
            );

            String? meditationId;
            if (result != null) {
              print('✅ Meditation created successfully: $result');
              // Meditation ID ni olish va saqlash
              meditationId = result['meditation_id']?.toString() ?? 
                            result['id']?.toString();
              if (meditationId != null && mounted) {
                final likeStore = context.read<LikeStore>();
                setState(() {
                  _meditationId = meditationId;
                  _isLiked = likeStore.isLiked(meditationId!);
                });
                print('✅ Meditation ID saved: $_meditationId');
                print('✅ Like status: $_isLiked');
              }
            } else {
              print('⚠️ Failed to create meditation');
              // Meditation yaratish API dan xato keldi, lekin dashboardga o'tkazmaymiz
              // Faqat generatsiya API xatolarida dashboardga o'tkaziladi
            }
            
            // 🔴 CRITICAL: PCM streaming to'liq tugaguncha kutish
            // File backendga yuborilgandan keyin, getMeditationByID qilib link olish
            // Transition ni setState dan TASHQARIDA chaqirish (async)
            // PCM streaming to'liq tugaguncha kutish, keyin just_audio ga o'tish
            if (meditationId != null && _mode == AudioMode.pcmStreaming && mounted) {
              print('🔄 [onComplete] Waiting for PCM streaming to finish...');
              
              // PCM streaming tugaguncha kutish - position duration ga yetguncha kutamiz
              // Yoki PCM player to'xtaguncha kutamiz
              Future<void> waitForPcmToFinish() async {
                if (_pcmStreamPlayer == null) {
                  print('⚠️ [onComplete] PCM player is null, skipping wait');
                  return;
                }
                
                print('🔄 [onComplete] Waiting for PCM to finish...');
                
                // PCM streaming tugaguncha kutish - position duration ga yetguncha
                // Yoki timeout (maksimum 5 daqiqa)
                final timeout = DateTime.now().add(const Duration(minutes: 5));
                while (_mode == AudioMode.pcmStreaming && 
                       _pcmStreamPlayer != null && 
                       mounted &&
                       DateTime.now().isBefore(timeout)) {
                  
                  // Position va duration ni tekshirish
                  final currentPosition = _pcmPosition;
                  final currentDuration = _duration;
                  
                  // Agar duration mavjud bo'lsa va position duration ga yetgan bo'lsa
                  if (currentDuration.inMilliseconds > 0 && 
                      currentPosition >= currentDuration) {
                    print('✅ [onComplete] PCM position reached duration: ${currentPosition.inSeconds}s >= ${currentDuration.inSeconds}s');
                    break;
                  }
                  
                  // Yoki PCM player to'xtagan bo'lsa
                  if (_pcmStreamPlayer != null && !_pcmStreamPlayer!.isPlaying) {
                    print('✅ [onComplete] PCM player stopped playing');
                    break;
                  }
                  
                  await Future.delayed(const Duration(milliseconds: 100));
                }
                
                print('✅ [onComplete] PCM streaming finished, starting transition...');
              }
              
              // setState dan tashqarida async chaqirish
              waitForPcmToFinish().then((_) {
                if (meditationId != null && _mode == AudioMode.pcmStreaming && mounted) {
                  print('🔄 [onComplete] Starting transition to just_audio (meditationId: $meditationId)...');
                  _transitionToFileFromApi(meditationId!);
                }
              });
            }
          } catch (e, stackTrace) {
            print('❌ Error creating meditation: $e');
            print('Stack trace: $stackTrace');
            // Meditation yaratish API da xatolik bo'lsa, lekin dashboardga o'tkazmaymiz
            // Faqat generatsiya API xatolarida dashboardga o'tkaziladi
          }
        }
      },
      onErrorCallback: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _mode = AudioMode.generating;
            _error = error;
          });
          // Faqat generatsiya API (http://31.97.98.47:8000/) xatolarida dashboardga o'tkazish
          // onErrorCallback faqat startStreaming funksiyasida chaqiriladi, bu generatsiya API ga so'rov yuboradi
          print('❌ Generatsiya API xatosi: $error');
          _handleApiError();
        }
      },
      onStateChanged: (streaming) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (streaming && _mode == AudioMode.generating) {
            _startTime = DateTime.now();
            _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (
              _,
            ) {
              if (_startTime != null && mounted) {
                final elapsed =
                    DateTime.now().difference(_startTime!).inMilliseconds /
                    1000.0;
                setState(() {
                  _progressSeconds = elapsed;
                });
              }
            });
          } else {
            _progressTimer?.cancel();
            _progressTimer = null;
          }
        }
      },
      onProgress: (totalBytes) {
        final requiredBytes = _streamingService.bytesForInitialPlayback;

        // 2 sekundlik audio yetgach, generating screen ni yashirish
        if (totalBytes >= requiredBytes && _showGeneratingScreen) {
          if (mounted) {
            setState(() {
              _showGeneratingScreen = false;
            });
          }
        }

        // Legacy code - no longer needed with new architecture
      },
    );
  }

  /// Start PCM streaming
  /// 🔴 CRITICAL: Guard qo'shildi - bir necha marta chaqirilishini oldini oladi
  Future<void> _startPcmStreaming() async {
    if (_mode != AudioMode.generating || _pcmStreamPlayer != null) return;
    
    _pcmStreamPlayer = PcmStreamPlayer(
      sampleRate: SAMPLE_RATE,
      channels: CHANNELS,
      bytesPerSample: BYTES_PER_SAMPLE,
    );
    
    await _pcmStreamPlayer!.start();
    
    _mode = AudioMode.pcmStreaming;
    _playbackStartTime = DateTime.now();
    
    // Start PCM position tracking timer
    _startPcmPositionTracking();
    
    print('✅ [PCM] Streaming started');
  }

  /// Handle new PCM chunk
  void _onNewPcmChunk(Uint8List chunk) {
    if (_mode != AudioMode.pcmStreaming) return;
    _pcmStreamPlayer?.addChunk(chunk);
  }

  /// Get PCM position (BITTA MANBA - DateTime orqali)
  Duration get _pcmPosition {
    if (_playbackStartTime == null) return Duration.zero;
    return DateTime.now().difference(_playbackStartTime!);
  }

  /// Start PCM position tracking timer
  /// 🔴 CRITICAL: Timer faqat position uchun, duration ga tegma
  void _startPcmPositionTracking() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _mode != AudioMode.pcmStreaming) return;
      
      final newPosition = _pcmPosition;
      
      // Duration dan oshib ketmasligi uchun
      if (_duration.inMilliseconds > 0 && newPosition > _duration) {
        setState(() {
          _position = _duration;
        });
      } else {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  /// Update duration based on PCM chunks
  /// 🔴 CRITICAL: Duration faqat chunk kelganda yangilanadi (race condition yo'q)
  void _updatePcmDuration() {
    final totalBytes = _pcmChunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytesPerSecond = SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;
    final calculatedDuration = Duration(
      milliseconds: ((totalBytes / bytesPerSecond) * 1000).round(),
    );
    
    if (mounted && calculatedDuration > _duration) {
      setState(() {
        _duration = calculatedDuration;
      });
    }
  }

  /// PCM → FILE transition - generatsiya qilingan local file'ni to'g'ridan-to'g'ri play qilish
  /// 🔴 CRITICAL: Stream to'liq tugagach, audio boshidan boshlanib pause qilib qo'yiladi
  Future<void> _transitionToFileFromApi(String meditationId) async {
    print('🔄 [Transition] PCM → FILE transition starting...');
    print('🔄 [Transition] Stream to\'liq tugadi, audio boshidan boshlanib pause qilib qo\'yiladi');
    
    // 🔴 CRITICAL: Stream to'liq tugagach, audio boshidan boshlanib pause qilib qo'yiladi
    // savedPosition har doim Duration.zero bo'ladi
    final savedPosition = Duration.zero; // Har doim boshidan boshlanadi
    
    _mode = AudioMode.transitioning;
    
    // 1. STOP PCM (TO'LIQ)
    if (_pcmStreamPlayer != null) {
      _positionUpdateTimer?.cancel();
      _positionUpdateTimer = null;
      
      await _pcmStreamPlayer!.stop();
      _pcmStreamPlayer = null;
      print('✅ [Transition] PCM stopped');
    }
    
    // 2. STOP just_audio (safety) - faqat agar allaqachon playing bo'lsa
    // Agar PCM playing bo'lsa va seamless transition kerak bo'lsa, stop() ni o'tkazib yuborish
    // Chunki playFromFile() ichida allaqachon stop() chaqiriladi
    try {
      if (_audioService.isPlaying) {
        await _audioService.stop();
        print('✅ [Transition] Stopped existing just_audio playback');
      }
    } catch (e) {
      print('⚠️ [Transition] Error stopping just_audio: $e');
    }
    
    // 3. GENERATSIYA QILINGAN LOCAL FILE'NI TO'G'RIDAN-TO'G'RI ISHLATISH
    String? audioUrl;
    
    // Avval generatsiya qilingan local file'ni tekshirish
    if (_streamingService.tempAudioFile != null) {
      final localFile = _streamingService.tempAudioFile!;
      final fileExists = await localFile.exists();
      
      if (fileExists) {
        audioUrl = localFile.path;
        print('✅ [Transition] Using generated local file: $audioUrl');
        print('✅ [Transition] File size: ${await localFile.length()} bytes');
      } else {
        print('⚠️ [Transition] Local file does not exist, trying API...');
      }
    } else {
      print('⚠️ [Transition] No local file available, trying API...');
    }
    
    // Agar local file mavjud bo'lmasa, API'dan link olish (fallback)
    if (audioUrl == null) {
      try {
        print('🔄 [Transition] Getting meditation by ID from API: $meditationId');
        final response = await ApiService.request(
          url: 'auth/meditation/$meditationId/',
          method: 'GET',
          open: false, // Token required
        );
        
        // Response format: { "file": "http://...", "file_wav": "http://..." }
        // Yoki { "details": { ... }, "file": "http://..." }
        final responseData = response.data;
        final fileUrl = responseData is Map 
            ? (responseData['file'] ?? 
               responseData['file_wav'] ??
               responseData['details']?['file'])
            : null;
        
        if (fileUrl != null && fileUrl is String) {
          audioUrl = fileUrl;
          print('✅ [Transition] Got audio URL from API: $audioUrl');
        } else {
          print('⚠️ [Transition] No file URL in API response: $responseData');
        }
      } catch (e) {
        print('❌ [Transition] Error getting meditation from API: $e');
      }
    }
    
    if (audioUrl == null) {
      print('❌ [Transition] No audio URL available, cannot transition');
      if (mounted) {
        setState(() {
          _mode = AudioMode.pcmStreaming; // Revert to PCM mode
        });
      }
      return;
    }
    
    // 4. LOAD FILE from URL or local path
    // playFromFile URL va file path ikkalasini ham qo'llab-quvvatlaydi
    try {
      await _audioService.playFromFile(
        audioUrl,
        initialPosition: savedPosition,
      );
      print('✅ [Transition] Loaded audio: $audioUrl');
    } catch (e) {
      print('❌ [Transition] Error loading audio: $e');
      if (mounted) {
        setState(() {
          _mode = AudioMode.pcmStreaming; // Revert to PCM mode
        });
      }
      return;
    }
    
    // 🔴 CRITICAL: Duration file'dan kelishini kutamiz (waveform timing uchun)
    try {
      final duration = await _audioService.durationStream
          .where((d) => d != null && d!.inMilliseconds > 0)
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⚠️ [Transition] Duration timeout, continuing anyway');
              return null;
            },
          );
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
        print('✅ [Transition] Duration set: ${duration.inSeconds}s');
      }
    } catch (e) {
      print('⚠️ [Transition] Error waiting for duration: $e');
    }
    
    // 5. 🔴 CRITICAL: Stream to'liq tugagach, audio boshidan boshlanib pause qilib qo'yiladi
    // Har doim paused holatda qoldiramiz (wasPlaying har doim false)
    await _audioService.pause();
    if (mounted) {
      setState(() {
        _position = Duration.zero; // Boshidan boshlanadi
        _mode = AudioMode.filePaused;
      });
    }
    print('✅ [Transition] Audio loaded from beginning (position: 0s) and paused');
    
    print('✅ [Transition] Complete - mode: $_mode, position: ${_position.inSeconds}s');
  }

  /// Toggle play/pause (SODDA VA TO'G'RI)
  Future<void> _togglePlayPause() async {
    print('🔄 [Play/Pause] Toggle called - mode: $_mode, duration: ${_duration.inSeconds}s');
    
    // Block during transition or PCM streaming
    if (_mode == AudioMode.transitioning || _mode == AudioMode.pcmStreaming) {
      print('⚠️ [Play/Pause] Disabled in mode: $_mode');
      return;
    }

    if (_mode == AudioMode.filePlaying) {
      // Pause - UI ni darhol yangilash
      if (mounted) {
        setState(() {
          _mode = AudioMode.filePaused;
        });
      }
      await _audioService.pause();
      print('✅ [Play/Pause] Paused');
    } else if (_mode == AudioMode.filePaused) {
      // 🔴 CRITICAL: UI ni DARHOL yangilash (icon pausega o'zgarsin), keyin play() ni chaqirish
      // Bu icon darhol yangilanishini ta'minlaydi
      if (mounted) {
        setState(() {
          _mode = AudioMode.filePlaying;
        });
      }
      // Play ni background'da chaqirish - UI allaqachon yangilangan
      _audioService.play().then((_) {
        print('✅ [Play/Pause] Playing');
      }).catchError((e) {
        print('❌ [Play/Pause] Error playing: $e');
        if (mounted) {
          setState(() {
            _mode = AudioMode.filePaused;
          });
        }
      });
    } else {
      print('⚠️ [Play/Pause] Invalid mode for toggle: $_mode');
    }
  }

  /// Stop audio playback
  Future<void> _stopPlayback() async {
    print('🛑 [Stop] Stopping playback...');
    
    // Cancel position tracking timer
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    
    // Stop PCM if exists
    if (_pcmStreamPlayer != null) {
      await _pcmStreamPlayer!.stop();
      _pcmStreamPlayer = null;
    }
    
    // Stop just_audio
    await _audioService.stop();
    
    // Reset state
    if (mounted) {
      setState(() {
        _mode = AudioMode.generating;
        _position = Duration.zero;
      });
    }
    
    print('✅ [Stop] Playback stopped');
  }

  /// Seek to position (FAqat FILE MODE)
  Future<void> _handleSeek(double tapX, double width) async {
    print('🔄 [Seek] Called - mode: $_mode, duration: ${_duration.inSeconds}s, tapX: $tapX, width: $width');
    
    if (_duration.inMilliseconds <= 0) {
      print('⚠️ [Seek] Duration is zero, cannot seek');
      return;
    }

    // Block during transition or PCM streaming
    if (_mode != AudioMode.filePlaying && _mode != AudioMode.filePaused) {
      print('⚠️ [Seek] Cannot seek in mode: $_mode');
      return;
    }

    final progress = (tapX / width).clamp(0.0, 1.0);
    final seekPosition = Duration(
      milliseconds: (_duration.inMilliseconds * progress).round(),
    );
    
    print('⏩ [Seek] Seeking to ${seekPosition.inSeconds}s (progress: ${(progress * 100).toStringAsFixed(1)}%)...');
    
    try {
      await _audioService.seek(seekPosition);
      
      // Update position immediately in UI
      if (mounted) {
        setState(() {
          _position = seekPosition;
        });
      }
      
      print('✅ [Seek] Success: ${seekPosition.inSeconds}s');
    } catch (e) {
      print('❌ [Seek] Error: $e');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      
      // 🔴 CRITICAL: Volume faqat file mode da (PCM'da Android crash risk)
      if (_mode == AudioMode.filePlaying || _mode == AudioMode.filePaused) {
        _audioService.setVolume(_isMuted ? 0.0 : 1.0);
      }
    });
  }

  void _handleApiError() {
    if (!mounted) return;

    // Toast xabarini ko'rsatish
    Fluttertoast.showToast(
      msg: 'Something went wrong!',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );

    // Dashboardga o'tkazish
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  /// Registratsiya vaqtida bo'lsa, account update ni parallel ravishda yuborish
  Future<void> _updateNewUserAccountInParallel() async {
    print('🔄 [_updateNewUserAccountInParallel] Funksiya chaqirildi');
    if (!mounted) {
      print('⚠️ [_updateNewUserAccountInParallel] Widget mounted emas');
      return;
    }

    try {
      // Dastlab getUserDetails qilish
      final authStore = Provider.of<AuthStore>(context, listen: false);
      print('🔄 [_updateNewUserAccountInParallel] getUserDetails chaqirilmoqda...');
      await authStore.getUserDetails();
      
      // User ma'lumotlarini olish va print qilish
      final user = authStore.user;
      print('🔄 [_updateNewUserAccountInParallel] ========== USER MA\'LUMOTLARI ==========');
      print('  - ID: ${user?.id}');
      print('  - First Name: ${user?.firstName}');
      print('  - Last Name: ${user?.lastName}');
      print('  - Email: ${user?.email}');
      print('  - Gender: ${user?.gender}');
      print('  - Age Range: ${user?.ageRange}');
      print('  - Goals: ${user?.goals}');
      print('  - Dream: ${user?.dream}');
      print('  - Happiness: ${user?.happiness}');
      print('  - Created At: ${user?.createdAt}');
      print('🔄 [_updateNewUserAccountInParallel] ========================================');
      
      // Goals, happiness, dream bo'sh bo'lsa PUT so'rovlarini yuborish
      final hasGoals = user?.goals != null && user!.goals!.isNotEmpty;
      final hasHappiness = user?.happiness != null && user!.happiness!.isNotEmpty;
      final hasDream = user?.dream != null && user!.dream!.isNotEmpty;
      
      print('🔄 [_updateNewUserAccountInParallel] Ma\'lumotlar mavjudligi:');
      print('  - Goals mavjud: $hasGoals');
      print('  - Happiness mavjud: $hasHappiness');
      print('  - Dream mavjud: $hasDream');
      
      if (hasGoals && hasHappiness && hasDream) {
        // Barcha ma'lumotlar mavjud, update qilish shart emas
        print('✅ [_updateNewUserAccountInParallel] Barcha ma\'lumotlar mavjud, update qilish shart emas');
        return;
      }

      if (!mounted) {
        print('⚠️ [_updateNewUserAccountInParallel] Widget mounted emas (ikkinchi tekshiruv)');
        return;
      }

      print('🔄 [_updateNewUserAccountInParallel] Ba\'zi ma\'lumotlar yo\'q, PUT so\'rovlarini yuborish...');

      // Ma'lumotlarni olish
      final requestBody = await buildRequestBody(context);
      print('🔄 [_updateNewUserAccountInParallel] Request body: $requestBody');

      // Parallel ravishda yuborish - await qilmaymiz
      print('🔄 [_updateNewUserAccountInParallel] Calling _updateNewUserAccountParallel...');
      _updateNewUserAccountParallel(context, requestBody, user);
    } catch (e) {
      print('❌ [_updateNewUserAccountInParallel] Error starting parallel account update: $e');
      // Xatolik bo'lsa ham davom etish kerak
    }
  }

  /// Parallel ravishda account update qilish
  Future<void> _updateNewUserAccountParallel(
    BuildContext context,
    Map<String, dynamic> requestBody,
    dynamic user,
  ) async {
    print('🔄 [_updateNewUserAccountParallel] Funksiya chaqirildi');
    try {
      final authStore = Provider.of<AuthStore>(context, listen: false);

      // Name ni update qilish (agar mavjud bo'lsa)
      final name = requestBody['name']?.toString() ?? '';
      print('🔄 [_updateNewUserAccountParallel] Name: "$name"');
      if (name.isNotEmpty) {
        final nameParts = name.trim().split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          // Parallel yuborish - await qilmaymiz
          print('🔄 Sending PUT request to /user-detail/ for name update...');
          authStore
              .updateProfile(
                firstName: firstName.isNotEmpty
                    ? firstName
                    : (user?.firstName ?? ''),
                lastName: lastName.isNotEmpty
                    ? lastName
                    : (user?.lastName ?? ''),
                onSuccess: () {
                  print('✅ User name updated successfully (parallel)');
                },
              )
              .catchError((e) {
                print('⚠️ Error updating user name (parallel): $e');
              });
        }
      }

      // Goals va dream ni update qilish
      final goals = requestBody['goals']?.toString() ?? '';
      final dreamlife = requestBody['dreamlife']?.toString() ?? '';
      // 🔴 CRITICAL: happiness ni requestBody'dan olish (dream_activities - bu happiness ma'lumoti)
      final happiness = requestBody['dream_activities']?.toString() ?? '';

      if (goals.isNotEmpty || dreamlife.isNotEmpty || happiness.isNotEmpty) {
        // Mavjud user ma'lumotlarini olish
        final existingGender = user?.gender ?? 'male';
        final existingAgeRange = user?.ageRange ?? '25-34';
        // happiness ni requestBody'dan olish, agar bo'sh bo'lsa user.happiness dan olish
        final existingHappiness = happiness.isNotEmpty ? happiness : (user?.happiness ?? '');

        // Parallel yuborish - await qilmaymiz
        // 🔴 CRITICAL: Generatsiya vaqtida faqat POST ishlatiladi (forcePost: true)
        print('🔄 Sending POST request to /user-detail-update/ for goals/dream/happiness update (generation time)...');
        authStore
            .updateUserDetail(
              gender: existingGender,
              ageRange: existingAgeRange,
              dream: dreamlife.isNotEmpty ? dreamlife : (user?.dream ?? ''),
              goals: goals.isNotEmpty ? goals : (user?.goals ?? ''),
              happiness: existingHappiness,
              showToast: false, // Registratsiya paytidagi meditatsiya generatsiya qilishda toast ko'rsatmaslik
              forcePost: true, // Generatsiya vaqtida faqat POST ishlatish
              onSuccess: () {
                print('✅ User details updated successfully (parallel)');
              },
            )
            .catchError((e) {
              print('⚠️ Error updating user details (parallel): $e');
            });
      }

      // Update qilgandan keyin 'first' flag ni false qilib qo'yish
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first', false);
      print('✅ Parallel account update completed for new user');
    } catch (e) {
      print('❌ Error in parallel account update: $e');
      // Xatolik bo'lsa ham davom etish kerak
    }
  }

  void _toggleLike() async {
    // Meditation ID olinguncha like qilish mumkin emas
    if (_meditationId == null) {
      return;
    }

    final likeStore = context.read<LikeStore>();

    await likeStore.toggleLike(_meditationId!);
    if (mounted) {
      setState(() {
        _isLiked = likeStore.isLiked(_meditationId!);
      });
    }
  }

  void _shareMeditation() async {
    await Share.share('Vela - Navigate from Within. https://myvela.ai/');
  }

  void _showPersonalizedMeditationInfo() {
    MeditationActionService.showPersonalizedMeditationInfo(context);
  }

  @override
  Widget build(BuildContext context) {
    final meditationStore = Provider.of<MeditationStore>(
      context,
      listen: false,
    );
    final storedRitualType =
        meditationStore.storedRitualType ??
        meditationStore.storedRitualId ??
        '1';
    final profileData = meditationStore.meditationProfile;

    // Check if audio is fully loaded
    // 🔴 CRITICAL: isAudioReady faqat mode va duration ga qarab aniqlanadi
    // _wavBytes PCM streaming uchun, file mode da kerak emas
    final isAudioReady = (_mode == AudioMode.filePlaying || 
                          _mode == AudioMode.filePaused) && 
                         _duration.inMilliseconds > 0;

    // Get duration from audio file (rounded to minutes)
    // Agar audio hali yuklanmagan bo'lsa, default qiymat
    int durationMinutes = 2; // Default
    if (_duration.inMilliseconds > 0 && isAudioReady) {
      // Audio vaqtini minutlarda yaxlitlab olish
      final totalSeconds = _duration.inSeconds;
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      // Agar sekundlar 30 dan katta bo'lsa, 1 minut qo'shamiz (yaxlitlab yuqoriga)
      durationMinutes = seconds >= 30 ? minutes + 1 : minutes;
      // Minimum 1 minut
      if (durationMinutes < 1) durationMinutes = 1;
    }

    // Get meditation name from profileData to determine title
    final meditationName = profileData?.name ?? 
                          profileData?.ritual?['name']?.toString() ??
                          profileData?.details?['name']?.toString();
    
    // Determine title based on meditation name first, then storedRitualType
    final title = meditationName != null
        ? (meditationName.toLowerCase().contains('sleep')
            ? 'Sleep Manifestation'
            : meditationName.toLowerCase().contains('morning')
            ? 'Morning Spark'
            : meditationName.toLowerCase().contains('calming')
            ? 'Calming Reset'
            : storedRitualType == '1'
            ? 'Sleep Manifestation'
            : storedRitualType == '2'
            ? 'Morning Spark'
            : storedRitualType == '3'
            ? 'Calming Reset'
            : 'Dream Visualizer')
        : (storedRitualType == '1'
            ? 'Sleep Manifestation'
            : storedRitualType == '2'
            ? 'Morning Spark'
            : storedRitualType == '3'
            ? 'Calming Reset'
            : 'Dream Visualizer');

    // Get image path based on ritual type
    final imagePath = storedRitualType == '1'
        ? 'assets/img/card.png'
        : storedRitualType == '2'
        ? 'assets/img/card2.png'
        : storedRitualType == '3'
        ? 'assets/img/card3.png'
        : 'assets/img/card4.png';

    // Get description based on ritual type
    final description = storedRitualType == '1'
        ? 'A deeply personalized journey crafted from your unique vision and dreams'
        : storedRitualType == '2'
        ? 'An intimately tailored experience shaped by your individual aspirations and fantasies'
        : storedRitualType == '3'
        ? 'An expressive outlet that fosters creativity and self-discovery through various artistic mediums'
        : 'A deeply personalized journey crafted around your unique desires and dreams';

    // Generating screen ko'rsatish - 2 sekundlik audio yetguncha
    if (_showGeneratingScreen) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) {
                return route.settings.name == '/dashboard' ||
                    route.settings.name == '/my-meditations' ||
                    route.settings.name == '/archive' ||
                    route.settings.name == '/vault' ||
                    route.settings.name == '/generator';
              });
            }
          },
          child: Stack(
            children: [
              // Gradient background
              const StarsAnimation(),
              // Background video
              if (_isVideoInitialized && _videoController != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              else if (!_isVideoInitialized)
                // Video yuklanmagan bo'lsa, background image ko'rsatish
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/img/dep.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              // Gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x663B6EAA), // 40% opacity
                      Color(0xE6A4C7EA),
                    ],
                  ),
                ),
              ),
              // Text content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const Text(
                      'Generating meditation',
                      style: TextStyle(
                        color: Color(0xFFF2EFEA),
                        fontSize: 36,
                        fontFamily: 'Canela',
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We\'re shaping your vision\ninto a meditative journey...',
                      style: TextStyle(
                        color: Color(0xFFF2EFEA),
                        fontSize: 16,
                        fontFamily: 'Satoshi',
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const StarsAnimation(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SleepMeditationHeader(
                            onBackPressed: () {
                              // Barcha holatlarda dashboard pagega o'tish
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/dashboard',
                                (route) {
                                  return route.settings.name == '/dashboard' ||
                                      route.settings.name == '/my-meditations' ||
                                      route.settings.name == '/archive' ||
                                      route.settings.name == '/vault' ||
                                      route.settings.name == '/generator';
                                },
                              );
                            },
                            onInfoPressed: isAudioReady
                                ? _showPersonalizedMeditationInfo
                                : () {},
                          ),
                          SizedBox(height: 20),
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Canela',
                              fontSize: 36.sp,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC9DFF4),
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This meditation weaves together your personal aspirations, gratitude, and authentic self with dreamy guidance to help manifest your dream life.',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          // Play/Pause button in center of card
                          Center(
                            child: GestureDetector(
                              onTap: isAudioReady ? _togglePlayPause : null,
                              child: Opacity(
                                opacity: isAudioReady ? 1.0 : 0.5,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                      image: AssetImage(imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Center(
                                    child: ClipOval(
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color.fromRGBO(
                                            59,
                                            110,
                                            170,
                                            0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _mode == AudioMode.filePlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Control bar (mute, like, share)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white.withOpacity(
                                    isAudioReady ? 1.0 : 0.5,
                                  ),
                                ),
                                onPressed: isAudioReady ? _toggleMute : null,
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.05,
                              ),
                              Expanded(
                                child: Opacity(
                                  opacity: _meditationId != null ? 1.0 : 0.5,
                                  child: GestureDetector(
                                    onTap: (_meditationId != null && isAudioReady) 
                                        ? _toggleLike 
                                        : null,
                                    child: Container(
                                      height: 60,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(60),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Resonating?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Satoshi',
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.05,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: Colors.white.withOpacity(
                                    isAudioReady ? 1.0 : 0.5,
                                  ),
                                ),
                                onPressed: isAudioReady
                                    ? _shareMeditation
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Wave visualization with scrubbing
                          if (_pcmChunks.isNotEmpty) ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  height: 120,
                                  child: GestureDetector(
                                    onTapDown: (_duration.inMilliseconds > 0 && 
                                                (_mode == AudioMode.filePlaying || _mode == AudioMode.filePaused))
                                        ? (details) async {
                                            await _handleSeek(details.localPosition.dx, constraints.maxWidth);
                                          }
                                        : null,
                                    onPanUpdate: (_duration.inMilliseconds > 0 && 
                                                  (_mode == AudioMode.filePlaying || _mode == AudioMode.filePaused))
                                        ? (details) async {
                                            await _handleSeek(details.localPosition.dx, constraints.maxWidth);
                                          }
                                        : null,
                                    child: WaveVisualization(
                                      pcmChunks: _pcmChunks,
                                      height: 120,
                                      duration: _duration,
                                      position: _position,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Time indicators below waveform - faqat audio to'liq yuklangach
                            if (isAudioReady) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Current time (left)
                                    Text(
                                      _formatTime(_position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    // Total duration (right)
                                    Text(
                                      _formatTime(_duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          // Save to Dream Vault button - faqat audio to'liq yuklangach
                          if (isAudioReady) ...[
                            const SizedBox(height: 40),
                            SizedBox(
                              height: 60,
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Save to vault first
                                  await MeditationActionService.saveToVault(
                                    context,
                                  );
                                  // Navigate to vault page
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/vault',
                                    (route) {
                                      return route.settings.name == '/vault' ||
                                          route.settings.name == '/dashboard' ||
                                          route.settings.name ==
                                              '/my-meditations' ||
                                          route.settings.name == '/archive' ||
                                          route.settings.name == '/generator';
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B6EAA),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(48),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Center(
                                  child: Text(
                                    'Save to Dream Vault',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Satoshi',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
