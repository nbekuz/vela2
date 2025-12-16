import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vela/pages/auth/onboarding_page_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import '../../core/services/api_service.dart';
import '../../shared/widgets/video_background_wrapper.dart';
import '../../styles/components/button_styles.dart';
import '../../styles/components/text_styles.dart';
import '../../styles/components/spacing_styles.dart';

class OnboardingPage1 extends StatefulWidget {
  const OnboardingPage1({super.key});

  @override
  State<OnboardingPage1> createState() => _OnboardingPage1State();
}

class _OnboardingPage1State extends State<OnboardingPage1> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isIOS) {
        // iOS - use Firebase Messaging for proper permission request
        await _requestIOSNotificationPermission();
      } else {
        // Android - use permission_handler
        await _requestAndroidNotificationPermission();
      }
    } catch (e) {
      // Silent error handling
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestIOSNotificationPermission() async {
    try {
      // Request permission using Firebase Messaging for iOS 15+
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? apnsToken;
        int apnsAttempts = 0;
        const maxApnsAttempts = 10;

        while (apnsToken == null && apnsAttempts < maxApnsAttempts) {
          apnsAttempts++;

          try {
            await Future.delayed(Duration(seconds: 2));
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          } catch (e) {}
        }

        // Now try to get FCM token only if APNS token is available
        if (apnsToken != null) {
          String? deviceToken;
          int attempts = 0;
          const maxAttempts = 5;

          while (deviceToken == null && attempts < maxAttempts) {
            attempts++;

            try {
              if (attempts > 1) {
                await Future.delayed(Duration(seconds: 2));
              }

              deviceToken = await FirebaseMessaging.instance.getToken();
              if (deviceToken != null) {
                break;
              }
            } catch (e) {
              print('iOS: FCM attempt $attempts failed: $e');
            }
          }

          if (deviceToken != null) {
            await _sendDeviceTokenToAPI(deviceToken);
          } else {
            print('iOS: Could not get FCM token after $maxAttempts attempts');
            // Don't send anything if no token
          }
        } else {
          print('iOS: APNS token not available, skipping FCM token');
        }
      } else {
        print('iOS: Permission denied ❌');
        // Show manual settings dialog for iOS
        _showIOSManualSettingsDialog();
      }
    } catch (e) {
      print('iOS: Error in notification permission: $e');
      // Don't send anything if error
    }
  }

  void _showIOSManualSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'To receive meditation reminders, please enable notifications:\n\n'
            '1. Go to Settings > Vela\n'
            '2. Tap "Notifications"\n'
            '3. Turn on "Allow Notifications"\n\n'
            'Would you like to open Settings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestAndroidNotificationPermission() async {
    try {
      PermissionStatus currentStatus = await Permission.notification.status;

      if (currentStatus == PermissionStatus.permanentlyDenied) {
        await openAppSettings();
        currentStatus = await Permission.notification.status;
      } else {
        currentStatus = await Permission.notification.request();
      }

      if (currentStatus.isGranted || currentStatus.isLimited) {
        // Get real FCM token for Android
        try {
          String? deviceToken = await FirebaseMessaging.instance.getToken();
          if (deviceToken != null) {
            await _sendDeviceTokenToAPI(deviceToken);
          } else {
            print('Android: FCM token is null');
            // Don't send anything if no token
          }
        } catch (e) {
          print('Android: Error getting FCM token: $e');
          // Don't send anything if error
        }
      } else {
        print('Android: Permission denied');
      }
    } catch (e) {
      print('Android: Error in notification permission: $e');
      // Silent error handling
    }
  }

  Future<void> _sendDeviceTokenToAPI(String deviceToken) async {
    try {
      String platform = Platform.isIOS ? 'ios' : 'android';

      final data = {
        'device_token': deviceToken,
        'device_type': platform,
        'platform': platform,
      };

      await ApiService.request(
        url: 'auth/create-device-token/',
        method: 'POST',
        data: data,
        open: true,
      );
    } catch (e) {
      print('Error sending device token to API: $e');
      // Silent error handling
    }
  }

  void _handleNext() async {
    // Navigate to next page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingPage2()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VideoBackgroundWrapper(
      topOffset: 0,
      showControls: true,
      isMuted: false,
      showBackButton: false,
      child: Column(
        children: [
          // Main content
          Expanded(child: Container()),

          // Bottom content container
          Container(
            padding: SpacingStyles.paddingHorizontal,
            child: Column(
              children: [
                Text(
                  'Navigate\nfrom Within',
                  textAlign: TextAlign.center,
                  style: TextStyles.headingLarge.copyWith(
                    fontSize: 64.sp,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'Canela',
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  'Vela is the only meditation app built \n specifically for you',
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyLarge,
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ButtonStyles.primary,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Next ', style: ButtonStyles.primaryText),
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
