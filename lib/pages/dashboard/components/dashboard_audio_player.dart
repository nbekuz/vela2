import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // Added for ImageFilter
import '../../../shared/widgets/stars_animation.dart';
import '../../../shared/widgets/personalized_meditation_modal.dart';
import '../../../shared/widgets/full_width_track_shape.dart';
import '../../../core/stores/meditation_store.dart';
import '../../../core/stores/like_store.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/themes/app_styles.dart';
import '../../components/sleep_meditation_header.dart';
import '../../components/sleep_meditation_audio_player.dart';
import '../../components/meditation_action_bar.dart';
import '../../generator/direct_ritual_page.dart';

class DashboardAudioPlayer extends StatefulWidget {
  final String meditationId;
  final String? title;
  final String? description;
  final String? imageUrl;

  const DashboardAudioPlayer({
    super.key,
    required this.meditationId,
    this.title,
    this.description,
    this.imageUrl,
  });

  @override
  State<DashboardAudioPlayer> createState() => _DashboardAudioPlayerState();
}

class _DashboardAudioPlayerState extends State<DashboardAudioPlayer> {
  just_audio.AudioPlayer? _audioPlayer;
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

  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    // Delay the audio loading to ensure widget is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndPlayMeditation();
    });
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

  Future<void> _loadAndPlayMeditation() async {
    try {
      final meditationStore = Provider.of<MeditationStore>(
        context,
        listen: false,
      );
      final profileData = meditationStore.meditationProfile;

      // First try to get fileUrl from store
      fileUrl = meditationStore.fileUrl;

      // If not in store, try secure storage
      if (fileUrl == null || fileUrl!.isEmpty) {
        const storage = FlutterSecureStorage();
        final storedFile = await storage.read(key: 'file');
        if (storedFile != null && storedFile.isNotEmpty) {
          fileUrl = storedFile;
        }
      }

      // If still null, wait a bit and retry store
      if (fileUrl == null || fileUrl!.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        fileUrl = meditationStore.fileUrl;
      }

      // Dispose previous audio player safely
      if (_audioPlayer != null) {
        try {
          await _audioPlayer!.stop();
        } catch (e) {
          // Ignore stop errors
        }

        try {
          await _audioPlayer!.dispose();
        } catch (e) {
          // Ignore dispose errors
        }
        _audioPlayer = null;
      }

      // Dispose previous waveform controller safely
      if (_waveformController != null) {
        try {
          _waveformController!.dispose();
        } catch (e) {
          // Ignore dispose errors
        }
        _waveformController = null;
      }

      // Create new instances
      _audioPlayer = just_audio.AudioPlayer();
      _waveformController = PlayerController();

      // Android uchun maxsus konfiguratsiya
      if (Platform.isAndroid) {
        try {
          // Android'da audio session'ni to'g'ri sozlash va ovozni kuchaytirish
          await _audioPlayer!.setVolume(1.0);
          // Android uchun qo'shimcha ovoz kuchaytirish
          await _audioPlayer!.setVolume(1.5);
        } catch (e) {
          // Error configuring Android audio session
        }
      }

      if (fileUrl != null && fileUrl!.isNotEmpty && _audioPlayer != null) {
        try {
          await _audioPlayer!.setUrl(fileUrl!);
        } catch (e) {
          return;
        }

        _audioPlayer!.playerStateStream.listen((state) {
          if (mounted) {
            setState(() {
              _isPlaying = state.playing;
              _isAudioReady =
                  state.processingState == just_audio.ProcessingState.ready;
            });
          }
        });

        _audioPlayer!.durationStream.listen((duration) {
          if (mounted) {
            setState(() {
              _duration = duration ?? const Duration(minutes: 3, seconds: 29);
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

        await _prepareWaveform();
      } else {
        setState(() {
          _isAudioReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _isAudioReady = true;
      });
    }
  }

  Future<void> _prepareWaveform() async {
    try {
      if (_waveformController != null) {
        await _waveformController!.preparePlayer(
          path: fileUrl ?? '',
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
      // Error preparing waveform
    }
  }

  @override
  void dispose() {
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
      if (_audioPlayer == null) {
        await _loadAndPlayMeditation();
        return;
      }

      if (_isPlaying) {
        await _audioPlayer!.pause();
        if (_waveformReady && _waveformController != null) {
          try {
            _waveformController!.pausePlayer();
          } catch (e) {
            // Error pausing waveform
          }
        }
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (!_isAudioReady) {
          await _audioPlayer!.setUrl(fileUrl!);
          setState(() {
            _isAudioReady = true;
            _duration = const Duration(minutes: 3, seconds: 29);
          });
        }

        await _audioPlayer!.play();
        if (_waveformReady && _waveformController != null) {
          try {
            _waveformController!.startPlayer();
          } catch (e) {
            // Error starting waveform
          }
        }
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      // Error toggling play/pause
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (Platform.isAndroid) {
        _audioPlayer?.setVolume(_isMuted ? 0.0 : 1.5);
      } else {
        _audioPlayer?.setVolume(_isMuted ? 0.0 : 1.0);
      }
    });
  }

  void _handleSeek(Duration position) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.seek(position);
      setState(() {
        _position = position;
      });
    }
  }

  void _toggleLike() async {
    final meditationStore = context.read<MeditationStore>();
    final likeStore = context.read<LikeStore>();

    final meditationId = meditationStore.meditationProfile?.ritual?['id']
        ?.toString();

    if (meditationId != null) {
      await likeStore.toggleLike(meditationId);
      setState(() {
        _isLiked = likeStore.isLiked(meditationId);
      });
    } else {
      setState(() {
        _isLiked = !_isLiked;
      });
    }
  }

  void _shareMeditation() async {
    await Share.share('Vela - Navigate fron Within. https://myvela.ai/');
  }

  void _deleteMeditation() async {
    final meditationId = widget.meditationId;

    // Show custom confirmation modal
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final double modalWidth = MediaQuery.of(context).size.width * 0.92;

        return Center(
          child: ClipRRect(
            borderRadius: AppStyles.radiusMedium,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: modalWidth,
                padding: AppStyles.paddingModal,
                decoration: AppStyles.frostedGlass,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Delete Meditation',
                      style: AppStyles.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppStyles.spacingMedium,
                    // Message
                    Text(
                      'Are you sure you want to delete this meditation? This action can\'t be undone.',
                      style: AppStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppStyles.spacingLarge,
                    // Buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.white, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 59, 110, 170),
                                fontSize: 16,
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // OK button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: AppStyles.modalButton,
                            child: Text('OK', style: AppStyles.buttonTextSmall),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (shouldDelete == true) {
      try {
        final response = await ApiService.request(
          url: 'auth/delete-meditation/$meditationId/',
          method: 'DELETE',
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 204) {
          Fluttertoast.showToast(
            msg: 'Meditation deleted successfully',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: const Color(0xFFF2EFEA),
            textColor: const Color(0xFF3B6EAA),
          );

          // Refresh meditation library after successful deletion
          final meditationStore = context.read<MeditationStore>();
          await meditationStore.fetchMeditationLibrary();

          if (!mounted) return;

          // Navigate to home page instead of going back
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to delete meditation',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } catch (e) {
        if (!mounted) return;

        Fluttertoast.showToast(
          msg: 'Error deleting meditation',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _editMeditation() async {
    final meditationId = widget.meditationId;

    // Show custom confirmation modal
    final shouldEdit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final double modalWidth = MediaQuery.of(context).size.width * 0.92;

        return Center(
          child: ClipRRect(
            borderRadius: AppStyles.radiusMedium,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: modalWidth,
                padding: AppStyles.paddingModal,
                decoration: AppStyles.frostedGlass,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Edit Meditation',
                      style: AppStyles.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppStyles.spacingMedium,
                    // Message
                    Text(
                      'Are you sure you want to edit this meditation? This action can’t be undone.',
                      style: AppStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    AppStyles.spacingLarge,
                    // Buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.white, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: const Color.fromARGB(255, 59, 110, 170),
                                fontSize: 16,
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // OK button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: AppStyles.modalButton,
                            child: Text('OK', style: AppStyles.buttonTextSmall),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (shouldEdit == true) {
      try {
        // First delete the current meditation
        final response = await ApiService.request(
          url: 'auth/delete-meditation/$meditationId/',
          method: 'DELETE',
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 204) {
          Fluttertoast.showToast(
            msg: 'Meditation deleted successfully',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: const Color(0xFFF2EFEA),
            textColor: const Color(0xFF3B6EAA),
          );

          // Refresh meditation library after successful deletion
          final meditationStore = context.read<MeditationStore>();
          await meditationStore.fetchMeditationLibrary();

          if (!mounted) return;

          // Navigate to DirectRitualPage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DirectRitualPage()),
          );
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to delete meditation',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } catch (e) {
        if (!mounted) return;

        Fluttertoast.showToast(
          msg: 'Error deleting meditation',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _resetMeditation() {
    context.read<MeditationStore>().completeReset();
    // Clear navigation stack to prevent back navigation to auth pages
    Navigator.pushNamedAndRemoveUntil(context, '/generator', (route) {
      // Keep only generator and dashboard routes, remove auth pages
      return route.settings.name == '/generator' ||
          route.settings.name == '/dashboard' ||
          route.settings.name == '/my-meditations' ||
          route.settings.name == '/archive' ||
          route.settings.name == '/vault';
    });
  }

  void _saveToVault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirst = prefs.getBool('first') ?? false;

      if (isFirst) {
        // First time - go to vault and remove first flag
        await prefs.remove('first');
        // Clear navigation stack to prevent back navigation to auth pages
        Navigator.pushNamedAndRemoveUntil(context, '/vault', (route) {
          // Keep only vault and dashboard routes, remove auth pages
          return route.settings.name == '/vault' ||
              route.settings.name == '/dashboard' ||
              route.settings.name == '/my-meditations' ||
              route.settings.name == '/archive' ||
              route.settings.name == '/generator';
        });
      } else {
        // Not first time - go to dashboard
        // Clear navigation stack to prevent back navigation to auth pages
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) {
          // Keep only dashboard and its sub-routes, remove auth pages
          return route.settings.name == '/dashboard' ||
              route.settings.name == '/my-meditations' ||
              route.settings.name == '/archive' ||
              route.settings.name == '/vault' ||
              route.settings.name == '/generator';
        });
      }
    } catch (e) {
      // Error handling - default to dashboard with cleared stack
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) {
        // Keep only dashboard and its sub-routes, remove auth pages
        return route.settings.name == '/dashboard' ||
            route.settings.name == '/my-meditations' ||
            route.settings.name == '/archive' ||
            route.settings.name == '/vault' ||
            route.settings.name == '/generator';
      });
    }
  }

  void _handleBack() {
    // Navigate to home page with cleared navigation stack
    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) {
      // Keep only dashboard and its sub-routes, remove auth pages
      return route.settings.name == '/dashboard' ||
          route.settings.name == '/my-meditations' ||
          route.settings.name == '/archive' ||
          route.settings.name == '/vault' ||
          route.settings.name == '/generator';
    });
  }

  void _showPersonalizedMeditationInfo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const PersonalizedMeditationModal();
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withAlpha(204),
      child: Stack(
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
                            onBackPressed: _handleBack,
                            onInfoPressed: _showPersonalizedMeditationInfo,
                          ),

                          Consumer<MeditationStore>(
                            builder: (context, meditationStore, child) {
                              return SleepMeditationAudioPlayer(
                                isPlaying: _isPlaying,
                                onPlayPausePressed: _togglePlayPause,
                                profileData: meditationStore.meditationProfile,
                                title: widget.title,
                                description: widget.description,
                                imageUrl: widget.imageUrl,
                              );
                            },
                          ),
                          const SizedBox(height: 0),
                          Consumer<MeditationStore>(
                            builder: (context, meditationStore, child) {
                              // Check if this meditation is user's own meditation
                              final myMeditations =
                                  meditationStore.myMeditations;
                              final isUserMeditation =
                                  myMeditations?.any(
                                    (meditation) =>
                                        meditation['id']?.toString() ==
                                        widget.meditationId,
                                  ) ??
                                  false;

                              return MeditationActionBar(
                                isMuted: _isMuted,
                                isLiked: _isLiked,
                                onMuteToggle: _toggleMute,
                                onLikeToggle: _toggleLike,
                                onDelete: isUserMeditation
                                    ? _deleteMeditation
                                    : null,
                                onEdit: isUserMeditation
                                    ? _editMeditation
                                    : null,
                                onShare: _shareMeditation,
                                showLikeText:
                                    !isUserMeditation, // Show text only for library meditations
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                // Time display
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_position),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Satoshi',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(_duration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Satoshi',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Improved Slider
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      activeTrackColor: const Color(0xFFC9DFF4),
                                      inactiveTrackColor: Colors.white
                                          .withOpacity(0.3),
                                      thumbColor: _isDragging
                                          ? const Color(0xFFC9DFF4)
                                          : Colors.white,
                                      overlayColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                        disabledThumbRadius: 8,
                                        elevation: 4,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 20,
                                          ),
                                      trackShape: const AudioSliderTrackShape(),
                                    ),
                                    child: Slider(
                                      value: _position.inSeconds
                                          .toDouble()
                                          .clamp(
                                            0,
                                            _duration.inSeconds.toDouble(),
                                          ),
                                      min: 0,
                                      max: _duration.inSeconds.toDouble(),
                                      onChanged: (value) async {
                                        // If this is the first change during drag, pause audio
                                        if (!_isDragging && _isPlaying) {
                                          print(
                                            'DEBUG: First drag detected, pausing audio',
                                          );
                                          await _audioPlayer?.pause();
                                          setState(() {
                                            _isDragging = true;
                                            _wasPlayingBeforeDrag = true;
                                          });
                                        }

                                        final newPosition = Duration(
                                          seconds: value.toInt(),
                                        );
                                        await _audioPlayer?.seek(newPosition);
                                        setState(() {
                                          _position = newPosition;
                                        });
                                      },
                                      onChangeStart: (value) {
                                        print(
                                          'DEBUG: Slider onChangeStart - isPlaying: $_isPlaying',
                                        );
                                        setState(() {
                                          _isDragging = true;
                                          _wasPlayingBeforeDrag = _isPlaying;
                                        });
                                        // Pause audio while seeking
                                        if (_isPlaying) {
                                          print(
                                            'DEBUG: Pausing audio during seek',
                                          );
                                          _audioPlayer?.pause();
                                        }
                                      },
                                      onChangeEnd: (value) async {
                                        print(
                                          'DEBUG: Slider onChangeEnd - wasPlayingBeforeDrag: $_wasPlayingBeforeDrag',
                                        );
                                        setState(() {
                                          _isDragging = false;
                                        });
                                        // Resume audio after seeking if it was playing before drag
                                        if (_wasPlayingBeforeDrag) {
                                          print(
                                            'DEBUG: Resuming audio after seek',
                                          );
                                          await _audioPlayer?.play();
                                          // The audio player state listener will update _isPlaying automatically
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Progress indicator
                                if (_isDragging)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Seeking to ${_formatDuration(_position)}',
                                      style: const TextStyle(
                                        color: Color(0xFFC9DFF4),
                                        fontFamily: 'Satoshi',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
