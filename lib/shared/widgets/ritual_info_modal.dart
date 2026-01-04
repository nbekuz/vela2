import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../themes/app_styles.dart';
import '../models/meditation_profile_data.dart';
import '../../core/stores/meditation_store.dart';
import '../../core/services/storekit_service.dart';
import '../../core/services/revenuecat_service.dart';
import 'package:vela/pages/meditation_streaming_page.dart';

class RitualInfoModal extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onClose;
  const RitualInfoModal({
    super.key,
    required this.title,
    required this.body,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final double modalWidth = MediaQuery.of(context).size.width * 0.95;

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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppStyles.white,
                            size: 28,
                          ),
                          onPressed:
                              onClose ?? () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppStyles.headingMedium,
                          ),
                        ),
                        Opacity(
                          opacity: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AppStyles.spacingMedium,
                Text(
                  body,
                  style: AppStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                AppStyles.spacingLarge,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    style: AppStyles.modalButton,
                    child: Text('Continue', style: AppStyles.buttonTextSmall),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomizeRitualModal extends StatefulWidget {
  final MeditationProfileData profileData;
  final Function(MeditationProfileData) onProfileDataChanged;
  final String planType;
  final VoidCallback? onClose;
  final bool isDirectRitual;

  const CustomizeRitualModal({
    required this.profileData,
    required this.onProfileDataChanged,
    required this.planType,
    this.onClose,
    this.isDirectRitual = false,
    super.key,
  });

  @override
  State<CustomizeRitualModal> createState() => _CustomizeRitualModalState();
}

class _CustomizeRitualModalState extends State<CustomizeRitualModal> {
  late String ritualType;
  late String tone;
  late String voice;
  late int duration;
  bool _isCheckingSubscription = false; // Loading state for subscription check

  final List<Map<String, String>> ritualTypes = [
    {'label': 'Guided Meditations', 'value': 'guided'},
    {'label': 'Story', 'value': 'story'},
  ];
  final List<Map<String, String>> tones = [
    {'label': 'Dreamy', 'value': 'dreamy'},
    {'label': 'ASMR', 'value': 'asmr'},
  ];
  final List<Map<String, String>> voices = [
    {'label': 'Male', 'value': 'male'},
    {'label': 'Female', 'value': 'female'},
  ];
  final List<int> durations = [2, 5, 10];

  @override
  void initState() {
    super.initState();
    // Set default values
    ritualType = 'guided';
    tone = 'dreamy';
    voice = widget.profileData.voice?.isNotEmpty == true
        ? widget.profileData.voice!.first
        : 'male';
    duration = widget.profileData.duration?.isNotEmpty == true
        ? int.tryParse(widget.profileData.duration!.first) ?? 5
        : 5;
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth = MediaQuery.of(context).size.width * 0.95;
    return Center(
      child: ClipRRect(
        borderRadius: AppStyles.radiusMedium,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: modalWidth,
            padding: AppStyles.paddingModal,
            decoration: AppStyles.frostedGlass,
            child: Material(
              color: Colors.transparent,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppStyles.white,
                                size: 28,
                              ),
                              onPressed:
                                  widget.onClose ??
                                  () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Expanded(
                              child: Text(
                                'Customize Ritual',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Canela',
                                  fontSize: 32,
                                  color: Color.fromARGB(255, 242, 239, 234),
                                  fontWeight: FontWeight.w300,
                                  decoration: TextDecoration.none,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: 0,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AppStyles.spacingMedium,
                    // Align(
                    //   alignment: Alignment.centerLeft,
                    //   child: Text('Ritual Type', style: AppStyles.bodyMedium),
                    // ),
                    // const SizedBox(height: 8),
                    // _StyledDropdown<String>(
                    //   value: ritualType,
                    //   items: ritualTypes.map((e) => e['value']!).toList(),
                    //   itemLabels: ritualTypes.map((e) => e['label']!).toList(),
                    //   onChanged: (v) async {
                    //     setState(() => ritualType = v!);
                    //     final updatedProfileData = widget.profileData.copyWith(
                    //       ritualType: [v ?? ''],
                    //     );
                    //     widget.onProfileDataChanged(updatedProfileData);

                    //     // Meditation store ga ritual type ni update qilish
                    //     final meditationStore = Provider.of<MeditationStore>(
                    //       context,
                    //       listen: false,
                    //     );
                    //     await meditationStore.saveRitualSettings(
                    //       ritualType: v ?? '',
                    //       tone: tone,
                    //       duration: duration.toString(),
                    //       planType: widget.profileData.planType ?? 1,
                    //     );
                    //   },
                    // ),
                    // AppStyles.spacingSmall,
                    // Align(
                    //   alignment: Alignment.centerLeft,
                    //   child: Text(
                    //     'Choose your tone',
                    //     style: AppStyles.bodyMedium,
                    //   ),
                    // ),
                    // const SizedBox(height: 8),
                    // _StyledDropdown<String>(
                    //   value: tone,
                    //   items: tones.map((e) => e['value']!).toList(),
                    //   itemLabels: tones.map((e) => e['label']!).toList(),
                    //   onChanged: (v) async {
                    //     setState(() => tone = v!);
                    //     final updatedProfileData = widget.profileData.copyWith(
                    //       tone: [v ?? ''],
                    //     );
                    //     widget.onProfileDataChanged(updatedProfileData);

                    //     // Meditation store ga tone ni update qilish
                    //     final meditationStore = Provider.of<MeditationStore>(
                    //       context,
                    //       listen: false,
                    //     );
                    //     await meditationStore.saveRitualSettings(
                    //       ritualType: ritualType,
                    //       tone: v ?? '',
                    //       duration: duration.toString(),
                    //       planType: widget.profileData.planType ?? 1,
                    //     );
                    //   },
                    // ),
                    AppStyles.spacingSmall,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose your voice',
                        style: AppStyles.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      value: voice,
                      items: voices.map((e) => e['value']!).toList(),
                      itemLabels: voices.map((e) => e['label']!).toList(),
                      onChanged: (v) {
                        setState(() => voice = v!);
                        final updatedProfile = widget.profileData.copyWith(
                          voice: [v ?? ''],
                        );
                        widget.onProfileDataChanged(updatedProfile);

                        // Force update the meditation store with the new voice
                        final meditationStore = Provider.of<MeditationStore>(
                          context,
                          listen: false,
                        );
                        meditationStore.setMeditationProfile(updatedProfile);

                        // Also save the voice to storage immediately
                        meditationStore.saveRitualSettings(
                          ritualType: ritualType,
                          tone: tone,
                          duration: duration.toString(),
                          planType: widget.profileData.planType ?? 1,
                          voice: v!,
                        );

                        print('Voice selected: $v'); // Debug print
                      },
                    ),
                    AppStyles.spacingSmall,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Duration', style: AppStyles.bodyMedium),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: durations
                          .map(
                            (d) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: duration == d
                                        ? AppStyles.primaryBlue
                                        : AppStyles.transparentWhite,
                                    foregroundColor: AppStyles.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(70),
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () async {
                                    setState(() => duration = d);
                                    final updatedProfileData = widget
                                        .profileData
                                        .copyWith(duration: [d.toString()]);
                                    widget.onProfileDataChanged(
                                      updatedProfileData,
                                    );

                                    // Meditation store ga duration ni update qilish
                                    final meditationStore =
                                        Provider.of<MeditationStore>(
                                          context,
                                          listen: false,
                                        );
                                    await meditationStore.saveRitualSettings(
                                      ritualType: ritualType,
                                      tone: tone,
                                      duration: d.toString(),
                                      planType:
                                          widget.profileData.planType ?? 1,
                                    );
                                  },
                                  child: Text(
                                    '$d min',
                                    style: AppStyles.buttonTextSmall,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    AppStyles.spacingLarge,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCheckingSubscription ? null : () async {
                          // Obuna tekshirish - agar obuna yo'q bo'lsa plan page'ga o'tish
                          setState(() {
                            _isCheckingSubscription = true; // Show loading
                          });

                          try {
                            // Try RevenueCat first, then fallback to StoreKit
                            final revenueCatService = RevenueCatService();
                            bool hasActivePlan = false;
                            
                            if (revenueCatService.isAvailable) {
                              hasActivePlan = await revenueCatService.hasActivePurchase();
                            } else {
                              final storeKitService = StoreKitService();
                              if (storeKitService.isAvailable) {
                                hasActivePlan = await storeKitService.hasActivePurchase();
                              }
                            }
                            
                            if (!mounted) return;
                            
                            if (!hasActivePlan) {
                              // Obuna yo'q - plan page'ga o'tish
                              Navigator.of(context).pop(); // Modal'ni yopish
                              Navigator.pushReplacementNamed(context, '/plan');
                              return;
                            }
                            
                            // Obuna bor - meditation_streaming_page ga o'tish
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MeditationStreamingPage(),
                              ),
                            );
                          } catch (e) {
                            // Xatolik bo'lsa ham plan page'ga o'tish (xavfsizlik uchun)
                            print('⚠️ Error checking subscription: $e');
                            if (mounted) {
                              Navigator.of(context).pop(); // Modal'ni yopish
                              Navigator.pushReplacementNamed(context, '/plan');
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isCheckingSubscription = false; // Hide loading
                              });
                            }
                          }
                        },
                        style: AppStyles.modalButton,
                        child: _isCheckingSubscription
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFF2EFEA),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Generate My Meditation',
                                    style: AppStyles.buttonTextSmall,
                                  ),
                                  SizedBox(width: 12),
                                  Image.asset(
                                    'assets/img/star.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final List<String>? itemLabels;
  final ValueChanged<T?> onChanged;
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabels,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.transparentWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppStyles.white),
        dropdownColor: const Color(0xCC3B6EAA),
        style: AppStyles.buttonTextSmall,
        borderRadius: BorderRadius.circular(16),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem<T>(
            value: items[i],
            child: Text(
              itemLabels != null ? itemLabels![i] : items[i].toString(),
              style: AppStyles.buttonTextSmall,
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
