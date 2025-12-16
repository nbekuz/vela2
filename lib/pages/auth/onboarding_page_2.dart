import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vela/pages/auth/onboarding_page_3.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../shared/widgets/video_background_wrapper.dart';
import '../../styles/components/button_styles.dart';
import '../../styles/components/text_styles.dart';
import '../../styles/components/spacing_styles.dart';
import '../../core/utils/video_loader.dart';

class OnboardingPage2 extends StatefulWidget {
  const OnboardingPage2({super.key});

  @override
  State<OnboardingPage2> createState() => _OnboardingPage2State();
}

class _OnboardingPage2State extends State<OnboardingPage2> {
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _checkVideoStatus();
  }

  Future<void> _checkVideoStatus() async {
    // Check if videos are already preloaded
    if (VideoLoader.isInitialized) {
      setState(() {
        _isVideoReady = true;
      });
    } else {
      // Wait for videos to be loaded
      await VideoLoader.initializeVideos();
      if (mounted) {
        setState(() {
          _isVideoReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VideoBackgroundWrapper(
      topOffset: 0,
      showControls: true,
      isMuted: false,
      showBackButton: true,
      onBack: () => Navigator.pop(context),
      child: Column(
        children: [
          // Bottom content container
          Expanded(child: Container()),

          Container(
            padding: SpacingStyles.paddingHorizontal,
            child: Column(
              children: [
                Text(
                  'What is Vela?',
                  textAlign: TextAlign.center,
                  style: TextStyles.headingLarge.copyWith(fontSize: 46.sp),
                ),

                const SizedBox(height: 30),

                Text(
                  'Vela turns your vision board into your daily meditation.\n\n'
                  'Using your own words and goals, Vela creates personalized audio meditations to help rewire your neural pathways and align with the life you want to live.',
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyLarge,
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isVideoReady
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingPage3(),
                            ),
                          );
                        }
                      : null,
                  style: ButtonStyles.primary,
                  child: _isVideoReady
                      ? Text('Next ', style: ButtonStyles.primaryText)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Loading...', style: ButtonStyles.primaryText),
                          ],
                        ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFFF2EFEA),
                          fontFamily: 'Satoshi',
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
