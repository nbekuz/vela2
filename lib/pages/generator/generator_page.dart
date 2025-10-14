import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vela/shared/widgets/stars_animation.dart';
import 'package:vela/shared/widgets/exit_confirmation_dialog.dart';
import 'steps/age_step.dart';
import 'steps/gender_step.dart';
import 'steps/goals_step.dart';
import 'steps/vision_step.dart';
import 'steps/happy_step.dart';
import 'steps/ritual_step.dart';
import 'zero_generator.dart';
import '../../shared/models/meditation_profile_data.dart';
import '../../core/stores/meditation_store.dart';

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  MeditationProfileData profileData = MeditationProfileData();
  int _currentStep = 0;
  static const int _totalSteps = 7;
  static const int _stepperCount = 5;

  @override
  void initState() {
    super.initState();
    // Ensure we start from the beginning
    _currentStep = 0;
    profileData = MeditationProfileData();
  }

  void updateProfileData(MeditationProfileData newData) {
    setState(() {
      profileData = newData;
    });
  }

  void _goToNextStep() {
    setState(() {
      if (_currentStep < _totalSteps - 1) {
        _currentStep++;
      }
    });
  }

  void _goToPreviousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _goToZeroGenerator() {
    setState(() {
      _currentStep = 0;
    });
  }

  void nextStep() => setState(() => _currentStep++);
  void prevStep() => setState(() => _currentStep--);

  void generateMeditation() async {
    final meditationStore = context.read<MeditationStore>();
    
    // Debug: Print the actual values being sent
    print('🔍 Debug - Profile data being sent:');
    print('  dream: ${profileData.dream}');
    print('  goals: ${profileData.goals}');
    print('  happiness: ${profileData.happiness}');
    print('  dream joined: ${_getJoinedValue(profileData.dream)}');
    print('  goals joined: ${_getJoinedValue(profileData.goals)}');
    print('  happiness joined: ${_getJoinedValue(profileData.happiness)}');
    
    await meditationStore.postCombinedProfile(
      gender: profileData.gender?.toLowerCase() ?? '',
      dream: _getJoinedValue(profileData.dream),
      goals: _getJoinedValue(profileData.goals),
      ageRange: profileData.ageRange ?? '',
      happiness: _getJoinedValue(profileData.happiness),
      name: profileData.name,
      description: profileData.description,
      ritualType: _getFirstValue(profileData.ritualType),
      tone: _getFirstValue(profileData.tone),
      voice: _getFirstValue(profileData.voice),
      duration: _getFirstValue(profileData.duration),
      isDirectRitual: false,
      onError: () {
         if (mounted) {
          // Clear navigation stack to prevent back navigation to auth pages
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/dashboard',
            (route) {
              // Keep only dashboard and its sub-routes, remove auth pages
              return route.settings.name == '/dashboard' || 
                     route.settings.name == '/my-meditations' ||
                     route.settings.name == '/archive' ||
                     route.settings.name == '/vault' ||
                     route.settings.name == '/generator';
            },
          );
        }
      },
    );
  }

  // Helper method to get all values joined from list or empty string
  String _getJoinedValue(List<String>? list) {
    return (list?.isNotEmpty ?? false) ? list!.join(', ') : '';
  }
  
  // Helper method to get first value from list or empty string (for single values)
  String _getFirstValue(List<String>? list) {
    return (list?.isNotEmpty ?? false) ? list!.first : '';
  }

  List<Widget> get _steps => [
    ZeroGenerator(onNext: _goToNextStep),
    _buildStep(
      AgeStep(
        profileData: profileData,
        onProfileDataChanged: updateProfileData,
        onNext: nextStep,
        onBack: prevStep,
        currentStep: 1,
        totalSteps: _totalSteps,
        stepperIndex: 0,
        stepperCount: _stepperCount,
      ),
    ),
    _buildStep(
      GenderStep(
        profileData: profileData,
        onProfileDataChanged: updateProfileData,
        onNext: _goToNextStep,
        onBack: _goToPreviousStep,
        currentStep: 2,
        totalSteps: _totalSteps,
        stepperIndex: 1,
        stepperCount: _stepperCount,
      ),
    ),
    _buildStep(
      GoalsStep(
        profileData: profileData,
        onProfileDataChanged: updateProfileData,
        onNext: _goToNextStep,
        onBack: _goToPreviousStep,
        currentStep: 3,
        totalSteps: _totalSteps,
        stepperIndex: 2,
        stepperCount: _stepperCount,
      ),
    ),
    _buildStep(
      VisionStep(
        profileData: profileData,
        onProfileDataChanged: updateProfileData,
        onNext: _goToNextStep,
        onBack: _goToPreviousStep,
        currentStep: 4,
        totalSteps: _totalSteps,
        stepperIndex: 3,
        stepperCount: _stepperCount,
      ),
    ),
    _buildStep(
      HappyStep(
        profileData: profileData,
        onProfileDataChanged: updateProfileData,
        onBack: _goToPreviousStep,
        onNext: _goToNextStep,
        currentStep: 5,
        totalSteps: _totalSteps,
        stepperIndex: 4,
        stepperCount: _stepperCount,
      ),
    ),
    RitualStep(
      profileData: profileData,
      onProfileDataChanged: updateProfileData,
      onBack: _goToPreviousStep,
      currentStep: 6,
      totalSteps: _totalSteps,
      showStepper: false,
      isDirectRitual: false,
    ),
  ];

  // Helper method to build step widgets (for future extensibility)
  Widget _buildStep(Widget step) => step;

  void _showExitDialog() {
    ExitConfirmationDialog.show(
      context,
      title: 'Exit Dream Life Intake?',
      message: 'Are you sure you want to exit? Your progress will be lost.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const StarsAnimation(),
            Center(
              child: _steps[_currentStep],
            ),
          ],
        ),
        // floatingActionButton removed
      ),
    );
  }
}
