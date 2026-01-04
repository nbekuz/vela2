import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../shared/models/meditation_profile_data.dart';
import '../../core/stores/meditation_store.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SleepMeditationAudioPlayer extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPlayPausePressed;
  final MeditationProfileData? profileData;
  final String? description;
  final String? title;
  final String? imageUrl;

  const SleepMeditationAudioPlayer({
    super.key,
    required this.isPlaying,
    required this.onPlayPausePressed,
    this.profileData,
    this.description,
    this.title,
    this.imageUrl,
  });

  @override
  State<SleepMeditationAudioPlayer> createState() =>
      _SleepMeditationAudioPlayerState();
}

class _SleepMeditationAudioPlayerState
    extends State<SleepMeditationAudioPlayer> {
  @override
  void initState() {
    super.initState();
    _loadRitualSettings();
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

  @override
  Widget build(BuildContext context) {
    // Get duration from MeditationProfileData ritual, details, or duration field
    final duration =
        widget.profileData?.ritual?['duration'] ??
        widget.profileData?.details?['duration'] ??
        widget.profileData?.duration?.firstOrNull ??
        '2'; // Get duration from ritual object, details, or duration field

    // Get stored ritual type to determine card image and title
    final meditationStore = Provider.of<MeditationStore>(
      context,
      listen: false,
    );

    final storedRitualType =
        meditationStore.storedRitualType ??
        meditationStore.storedRitualId ??
        '1';

    // Get meditation name from profileData to determine title
    final meditationName = widget.profileData?.name ?? 
                          widget.profileData?.ritual?['name']?.toString() ??
                          widget.profileData?.details?['name']?.toString();
    
    // Determine title based on meditation name first, then storedRitualType
    final title = widget.title ??
        (meditationName != null
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
                : 'Dream Visualizer'));

    // Get image - use provided imageUrl if available, otherwise use ritual type
    final imagePath =
        widget.imageUrl ??
        (storedRitualType == '1'
            ? 'assets/img/card.png'
            : storedRitualType == '2'
            ? 'assets/img/card2.png'
            : storedRitualType == '3'
            ? 'assets/img/card3.png'
            : 'assets/img/card4.png');

    // Get description based on ritual type or use provided description
    final description =
        widget.description ??
        (storedRitualType == '1'
            ? 'A deeply personalized journey crafted from your unique vision and dreams'
            : storedRitualType == '2'
            ? 'An intimately tailored experience shaped by your individual aspirations and fantasies'
            : storedRitualType == '3'
            ? 'An expressive outlet that fosters creativity and self-discovery through various artistic mediums'
            : 'A deeply personalized journey crafted around your unique desires and dreams');

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.10),
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
        Center(
          child: GestureDetector(
            onTap: widget.onPlayPausePressed,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? NetworkImage(imagePath)
                      : AssetImage(imagePath) as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: ClipOval(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(59, 110, 170, 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isPlaying
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
        const SizedBox(height: 40),
      ],
    );
  }
}
