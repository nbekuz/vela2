import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import '../shared/widgets/stars_animation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:share_plus/share_plus.dart';
import 'components/sleep_meditation_header.dart';
import 'components/sleep_meditation_audio_player.dart';
import 'components/sleep_meditation_control_bar.dart';
import 'components/sleep_meditation_action_buttons.dart';
import 'package:provider/provider.dart';
import '../core/stores/meditation_store.dart';
import '../core/stores/like_store.dart';
import '../core/services/meditation_streaming_service.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/meditation_action_service.dart';
import '../core/services/navigation_service.dart';


class SleepStreamMeditationPage extends StatefulWidget {
  final String? meditationId;
  final bool isDirectRitual;

  const SleepStreamMeditationPage({
    super.key, 
    this.meditationId,
    this.isDirectRitual = false,
  });

  @override
  State<SleepStreamMeditationPage> createState() =>
      _SleepStreamMeditationPageState();
}

class _SleepStreamMeditationPageState extends State<SleepStreamMeditationPage> {
  just_audio.AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  bool _isPlaying = false;
  bool _isAudioReady = false;
  PlayerController? _waveformController;
  bool _waveformReady = false;
  Duration _duration = const Duration(minutes: 3, seconds: 29);
  Duration _position = Duration.zero;
  bool _isLiked = false;
  bool _isMuted = false;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;
  String? fileUrl;
  
  // Streaming state
  final MeditationStreamingService _streamingService = MeditationStreamingService();
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isStreaming = false;
  final List<Uint8List> _pcmChunks = [];
  Timer? _progressTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    _setupStreamingService();
    _setupAudioService();
    _startStreamingMeditation();
  }

  void _setupStreamingService() {
    _streamingService.onChunkReceived = (chunks) {
      if (mounted) {
        setState(() {
          _pcmChunks.clear();
          _pcmChunks.addAll(chunks);
        });
      }
    };

    _streamingService.onStreamComplete = (wavBytes) async {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _isAudioReady = true;
        });

        // Update just_audio player with final file
        if (_audioPlayer == null) {
          _audioPlayer = just_audio.AudioPlayer();
        }
        final tempFile = _streamingService.tempAudioFile;
        if (tempFile != null) {
          await _audioPlayer!.setFilePath(tempFile.path);
          await _setupAudioPlayerListeners();
          await _prepareWaveform();
        }
      }
    };

    _streamingService.onError = (error) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
        });
      }
    };

    _streamingService.onStreamingStateChanged = (streaming) {
      if (mounted) {
        setState(() {
          _isStreaming = streaming;
        });
      }
    };

    _streamingService.onProgressUpdate = (totalBytes) {
      // Start playback once we have enough initial data
      if (!_isPlaying && totalBytes >= _streamingService.bytesForInitialPlayback) {
        final tempFile = _streamingService.tempAudioFile;
        if (tempFile != null) {
          _startPlaybackDuringStreaming(tempFile);
        }
      }
    };
  }

  void _setupAudioService() {
    // Position stream listener
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = position;
        });
      }
    });

    // Duration stream listener
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Playing state - just_audio player dan olamiz
    if (_audioPlayer != null) {
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    }
  }

  Future<void> _setupAudioPlayerListeners() async {
    if (_audioPlayer == null) return;

    _audioPlayer!.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioPlayer!.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer!.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _startPlaybackDuringStreaming(File tempFile) async {
    if (_isPlaying) return;
    
    print('🔵 Starting playback during streaming...');
    try {
      await _audioService.playFromFile(tempFile.path);
      
      if (_audioPlayer == null) {
        _audioPlayer = just_audio.AudioPlayer();
      }
      await _audioPlayer!.setFilePath(tempFile.path);
      
      setState(() {
        _isPlaying = true;
        _isAudioReady = true;
      });
      
      print('✅ Audio playback started during streaming');
    } catch (e) {
      print('❌ STREAMING PLAYBACK ERROR: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  // Start streaming meditation instead of loading from fileUrl
  Future<void> _startStreamingMeditation() async {
    print('🔵 ========== Starting streaming meditation ==========');
    
    setState(() {
      _isStreaming = false;
      _pcmChunks.clear();
      _isAudioReady = false;
    });

    _progressTimer?.cancel();
    _startTime = DateTime.now();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_startTime != null && mounted) {
        final elapsed = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
        setState(() {
          _duration = Duration(seconds: elapsed.toInt());
          _position = Duration(seconds: elapsed.toInt());
        });
      }
    });

    // Start streaming using service
    await _streamingService.startStreaming(context);
  }

  Future<void> _configureAudioSession() async {
    try {
      if (Platform.isIOS) {
        // iOS audio session configuration
      } else if (Platform.isAndroid) {
        // Android audio session configuration
      }
    } catch (e) {
      // Error configuring audio session
    }
  }


  Future<void> _prepareWaveform() async {
    try {
      if (_waveformController != null) {
        final tempFile = _streamingService.tempAudioFile;
        final path = tempFile?.path ?? fileUrl ?? '';
        await _waveformController!.preparePlayer(
          path: path,
          shouldExtractWaveform: true,
          noOfSamples: 80,
        );

        if (mounted) {
          setState(() {
            _waveformReady = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error preparing waveform: $e');
      // Continue without waveform if it fails
    }
  }

  @override
  void dispose() {
    // Clean up streaming resources
    _progressTimer?.cancel();
    _streamingService.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioService.dispose();
    
    // Safely dispose audio player
    if (_audioPlayer != null) {
      try {
        _audioPlayer!.stop();
      } catch (e) {
        // Ignore stop errors
      }
      
      try {
        _audioPlayer!.dispose();
      } catch (e) {
        // Ignore dispose errors
      }
      _audioPlayer = null;
    }

    // Safely dispose waveform controller
    if (_waveformController != null) {
      try {
        _waveformController!.dispose();
      } catch (e) {
        // Ignore dispose errors
      }
      _waveformController = null;
    }

    super.dispose();
  }

  void _togglePlayPause() async {
    try {
      // If still streaming, wait for audio to be ready
      if (_isStreaming && !_isAudioReady) {
        print('⏳ Still streaming, audio not ready yet');
        return;
      }

      final tempFile = _streamingService.tempAudioFile;
      if (_audioPlayer == null && tempFile != null) {
        _audioPlayer = just_audio.AudioPlayer();
        await _audioPlayer!.setFilePath(tempFile.path);
        
        _audioPlayer!.playerStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _isPlaying = state.playing;
            });
          }
        });

        _audioPlayer!.durationStream.listen((duration) {
          if (mounted && duration != null) {
            setState(() {
              _duration = duration;
            });
          }
        });

        _audioPlayer!.positionStream.listen((position) {
          if (mounted) {
            setState(() {
              _position = position;
            });
          }
        });
        
        setState(() {
          _isAudioReady = true;
        });
      }

      if (_audioPlayer == null) {
        print('⚠️ Audio player not ready');
        return;
      }

      if (_isPlaying) {
        await _audioPlayer!.pause();
        await _audioService.pause();
        if (_waveformReady && _waveformController != null) {
          try {
            _waveformController!.pausePlayer();
          } catch (e) {
            debugPrint('Error pausing waveform: $e');
          }
        }
        setState(() {
          _isPlaying = false;
        });
      } else {
        final tempFile = _streamingService.tempAudioFile;
        if (!_isAudioReady && tempFile != null) {
          await _audioPlayer!.setFilePath(tempFile.path);
          setState(() {
            _isAudioReady = true;
          });
        }

        await _audioPlayer!.play();
        await _audioService.play();
        if (_waveformReady && _waveformController != null) {
          try {
            _waveformController!.startPlayer();
          } catch (e) {
            debugPrint('Error starting waveform: $e');
          }
        }
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      final volume = _isMuted ? 0.0 : (Platform.isAndroid ? 1.5 : 1.0);
      _audioPlayer?.setVolume(volume);
      _audioService.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleLike() async {
    final meditationStore = context.read<MeditationStore>();
    final likeStore = context.read<LikeStore>();

    // Get meditation ID from ritual data
    final meditationId = meditationStore.meditationProfile?.ritual?['id']
        ?.toString();

    if (meditationId != null) {
      await likeStore.toggleLike(meditationId);
      setState(() {
        _isLiked = likeStore.isLiked(meditationId);
      });
    } else {
      // Fallback to local state if no meditation ID
      setState(() {
        _isLiked = !_isLiked;
      });
    }
  }

  void _shareMeditation() async {
    await Share.share('Vela - Navigate fron Within. https://myvela.ai/');
  }

  void _resetMeditation() async {
    await MeditationActionService.resetMeditation(context);
  }

  void _saveToVault() async {
    await MeditationActionService.saveToVault(context);
  }

  void _showPersonalizedMeditationInfo() {
    MeditationActionService.showPersonalizedMeditationInfo(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          NavigationService.navigateToDashboard(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white.withAlpha(204), // 0.8 * 255 ≈ 204
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
                            onBackPressed: () => Navigator.of(context).pop(),
                            onInfoPressed: _showPersonalizedMeditationInfo,
                          ),
                          Consumer<MeditationStore>(
                            builder: (context, meditationStore, child) {
                              return SleepMeditationAudioPlayer(
                                isPlaying: _isPlaying,
                                onPlayPausePressed: _togglePlayPause,
                                profileData: meditationStore.meditationProfile,
                              );
                            },
                          ),
                          const SizedBox(height:0),
                          SleepMeditationControlBar(
                            isMuted: _isMuted,
                            isLiked: _isLiked,
                            onMuteToggle: _toggleMute,
                            onLikeToggle: _toggleLike,
                            onShare: _shareMeditation,
                          ),
                          const SizedBox(height: 24),
                          Column(
                            children: [
                              Slider(
                                value: _position.inSeconds.toDouble().clamp(
                                  0,
                                  _duration.inSeconds.toDouble(),
                                ),
                                min: 0,
                                max: _duration.inSeconds.toDouble(),
                                                                 onChanged: (value) async {
                                   // If this is the first change during drag, pause audio
                                   if (!_isDragging && _isPlaying) {
                                     await _audioPlayer?.pause();
                                     await _audioService.pause();
                                     setState(() {
                                       _isDragging = true;
                                       _wasPlayingBeforeDrag = true;
                                     });
                                   }
                                   
                                   final newPosition = Duration(
                                     seconds: value.toInt(),
                                   );
                                   await _audioPlayer?.seek(newPosition);
                                   await _audioService.seek(newPosition);
                                   setState(() {
                                     _position = newPosition;
                                   });
                                 },
                                                                 onChangeStart: (value) {
                                   setState(() {
                                     _isDragging = true;
                                     _wasPlayingBeforeDrag = _isPlaying;
                                   });
                                   // Pause audio while seeking
                                   if (_isPlaying) {
                                     _audioPlayer?.pause();
                                     _audioService.pause();
                                   }
                                 },
                                                                 onChangeEnd: (value) async {
                                   setState(() {
                                     _isDragging = false;
                                   });
                                   // Resume audio after seeking if it was playing before drag
                                   if (_wasPlayingBeforeDrag) {
                                     await _audioPlayer?.play();
                                     await _audioService.play();
                                     // The audio player state listener will update _isPlaying automatically
                                   }
                                 },
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom buttons outside scroll
                  SleepMeditationActionButtons(
                    onResetPressed: _resetMeditation,
                    onSavePressed: _saveToVault,
                    isDirectRitual: widget.isDirectRitual,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
