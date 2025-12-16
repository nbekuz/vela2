import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';
import '../shared/widgets/wave_visualization.dart';
import '../shared/widgets/stars_animation.dart';
import '../core/services/meditation_streaming_service.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/pcm_stream_player.dart' show PcmStreamPlayer;
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
        });
      }
    });

    // Duration stream
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
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

            if (result != null) {
              print('✅ Meditation created successfully: $result');
              // Meditation ID ni olish va saqlash
              final meditationId = result['meditation_id']?.toString() ?? 
                                  result['id']?.toString();
              if (meditationId != null && mounted) {
                final likeStore = context.read<LikeStore>();
                setState(() {
                  _meditationId = meditationId;
                  _isLiked = likeStore.isLiked(meditationId);
                });
                print('✅ Meditation ID saved: $_meditationId');
                print('✅ Like status: $_isLiked');
              }
            } else {
              print('⚠️ Failed to create meditation');
              // Meditation yaratish API dan xato keldi, lekin dashboardga o'tkazmaymiz
              // Faqat generatsiya API xatolarida dashboardga o'tkaziladi
            }
          } catch (e, stackTrace) {
            print('❌ Error creating meditation: $e');
            print('Stack trace: $stackTrace');
            // Meditation yaratish API da xatolik bo'lsa, lekin dashboardga o'tkazmaymiz
            // Faqat generatsiya API xatolarida dashboardga o'tkaziladi
          }

          // PCM → FILE transition
          if (_streamingService.tempAudioFile != null && _mode == AudioMode.pcmStreaming) {
            await _transitionToFile(_streamingService.tempAudioFile!);
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

  /// PCM → FILE transition (TOZA VA SODDA)
  Future<void> _transitionToFile(File audioFile) async {
    print('🔄 [Transition] PCM → FILE starting...');
    
    // 🔴 CRITICAL: Save position and playing state BEFORE changing mode
    final wasPcm = _mode == AudioMode.pcmStreaming;
    final wasPlaying = wasPcm && _playbackStartTime != null; // PCM playing bo'lsa
    final savedPosition = wasPcm ? _pcmPosition : _position;
    print('🔄 [Transition] Saved position: ${savedPosition.inSeconds}s (wasPcm: $wasPcm, wasPlaying: $wasPlaying)');
    
    _mode = AudioMode.transitioning;
    
    // 1. STOP PCM (TO'LIQ)
    if (_pcmStreamPlayer != null) {
      _positionUpdateTimer?.cancel();
      _positionUpdateTimer = null;
      
      await _pcmStreamPlayer!.stop();
      _pcmStreamPlayer = null;
      print('✅ [Transition] PCM stopped');
    }
    
    // 2. STOP just_audio (safety)
    await _audioService.stop();
    
    // 3. LOAD FILE
    await _audioService.playFromFile(
      audioFile.path,
      initialPosition: savedPosition,
    );
    
    // 🔴 CRITICAL: Duration file'dan kelishini kutamiz (waveform timing uchun)
    try {
      await _audioService.durationStream
          .where((d) => d != null)
          .first
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print('⚠️ [Transition] Duration timeout, continuing anyway');
              return null;
            },
          );
    } catch (e) {
      print('⚠️ [Transition] Error waiting for duration: $e');
    }
    
    // 4. Agar PCM playing bo'lsa, file ham playing bo'lishi kerak
    if (wasPlaying) {
      // Resume playing
      await _audioService.play();
      if (mounted) {
        setState(() {
          _position = savedPosition;
          _mode = AudioMode.filePlaying;
        });
      }
      print('✅ [Transition] Resumed playing');
    } else {
      // Paused holatda qoldiramiz
      await _audioService.pause();
      if (mounted) {
        setState(() {
          _position = savedPosition;
          _mode = AudioMode.filePaused;
        });
      }
      print('✅ [Transition] Kept paused');
    }
    
    print('✅ [Transition] Complete - mode: $_mode, position: ${_position.inSeconds}s');
  }

  /// Toggle play/pause (SODDA VA TO'G'RI)
  Future<void> _togglePlayPause() async {
    // Block during transition or PCM streaming
    if (_mode == AudioMode.transitioning || _mode == AudioMode.pcmStreaming) {
      print('⚠️ [Play/Pause] Disabled in mode: $_mode');
      return;
    }

    if (_mode == AudioMode.filePlaying) {
      await _audioService.pause();
      if (mounted) {
        setState(() {
          _mode = AudioMode.filePaused;
        });
      }
      print('✅ [Play/Pause] Paused');
    } else if (_mode == AudioMode.filePaused) {
      await _audioService.play();
      if (mounted) {
        setState(() {
          _mode = AudioMode.filePlaying;
        });
      }
      print('✅ [Play/Pause] Playing');
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
    if (_duration.inMilliseconds <= 0) {
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
    
    print('⏩ [Seek] Seeking to ${seekPosition.inSeconds}s...');
    
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
      final requestBody = buildRequestBody(context);
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

      if (goals.isNotEmpty || dreamlife.isNotEmpty) {
        // Mavjud user ma'lumotlarini olish
        final existingGender = user?.gender ?? 'male';
        final existingAgeRange = user?.ageRange ?? '25-34';
        final existingHappiness = user?.happiness ?? '';

        // Parallel yuborish - await qilmaymiz
        print('🔄 Sending PUT request to /user-detail-update/ for goals/dream update...');
        authStore
            .updateUserDetail(
              gender: existingGender,
              ageRange: existingAgeRange,
              dream: dreamlife.isNotEmpty ? dreamlife : (user?.dream ?? ''),
              goals: goals.isNotEmpty ? goals : (user?.goals ?? ''),
              happiness: existingHappiness,
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
    final isAudioReady = (_mode == AudioMode.filePlaying || 
                          _mode == AudioMode.filePaused) && 
                         _wavBytes != null;

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

    // Get title based on ritual type
    final title = storedRitualType == '1'
        ? 'Sleep Manifestation'
        : storedRitualType == '2'
        ? 'Morning Spark'
        : storedRitualType == '3'
        ? 'Calming Reset'
        : 'Dream Visualizer';

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
                            'This $durationMinutes min meditation weaves together your personal aspirations, gratitude, and authentic self with dreamy guidance to help manifest your dream life.',
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
