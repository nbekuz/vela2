import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../shared/widgets/stars_animation.dart';
import '../../core/stores/auth_store.dart';
import '../../core/services/api_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _dailyMeditationEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authStore = Provider.of<AuthStore>(context, listen: false);
    final user = authStore.user;

    if (user != null) {
      setState(() {
        _dailyMeditationEnabled = user.userDeviceActive ?? false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (Platform.isIOS) {
        NotificationSettings settings = await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true);

        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // Show dialog to guide user to settings
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Enable Notifications'),
                  content: const Text(
                    'To receive meditation reminders, please enable notifications:\n\n'
                    '1. Go to Settings\n'
                    '2. Tap "Notifications"\n'
                    '3. Turn on "Allow Notifications"\n\n'
                    'Then return to the app and try again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          }
        }
      } else {
        await FirebaseMessaging.instance.requestPermission();
      }
    } catch (e) {
      print('DEBUG: Error in _requestNotificationPermission: $e');
      // Silent error handling
    }
  }

  Future<void> _sendDeviceTokenToAPI(String deviceToken) async {
    print('DEBUG: _sendDeviceTokenToAPI called with token: $deviceToken');
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
      );
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final authStore = Provider.of<AuthStore>(context, listen: false);
      final user = authStore.user;
      print('DEBUG: User exists: ${user != null}');
      if (user != null) {
        print('DEBUG: Current user.userDeviceActive: ${user.userDeviceActive}');
      }

      if (user != null) {
        print('DEBUG: Processing notification settings...');
        print('DEBUG: _dailyMeditationEnabled: $_dailyMeditationEnabled');
        print('DEBUG: user.userDeviceActive: ${user.userDeviceActive}');

        // Always process based on current toggle state
        if (_dailyMeditationEnabled) {
          print('DEBUG: Enabling notifications...');

          // Request notification permission first
          await _requestNotificationPermission();

          try {
            // For iOS, first get APNS token, then FCM token
            if (Platform.isIOS) {
              print('DEBUG: Getting APNS token for iOS...');

              // Request permission first
              NotificationSettings settings = await FirebaseMessaging.instance
                  .requestPermission(alert: true, badge: true, sound: true);
              print(
                'DEBUG: Notification permission status: ${settings.authorizationStatus}',
              );

              // Wait longer for APNS token to be set
              print('DEBUG: Waiting for APNS token to be set...');
              await Future.delayed(const Duration(seconds: 10));

              // Try different approach - get FCM token directly
              print('DEBUG: Trying to get FCM token directly...');
              String? deviceToken;
              int attempts = 0;
              const maxAttempts = 10;

              while (deviceToken == null && attempts < maxAttempts) {
                attempts++;
                print('DEBUG: FCM attempt $attempts...');

                try {
                  await Future.delayed(Duration(seconds: 3));
                  deviceToken = await FirebaseMessaging.instance.getToken();
                  print('DEBUG: FCM Token attempt $attempts: $deviceToken');
                } catch (e) {
                  print('DEBUG: FCM attempt $attempts failed: $e');
                }
              }

              // Send FCM token to API if successful
              if (deviceToken != null) {
                print('DEBUG: Using FCM token for API call: $deviceToken');
                await _sendDeviceTokenToAPI(deviceToken);
              } else {
                print('DEBUG: FCM token is null, cannot send to API');
              }

              // If FCM token failed, try APNS token
              print('DEBUG: FCM token failed, trying APNS token...');
              String? apnsToken;
              int apnsAttempts = 0;
              const maxApnsAttempts = 10;

              while (apnsToken == null && apnsAttempts < maxApnsAttempts) {
                apnsAttempts++;
                print('DEBUG: APNS attempt $apnsAttempts...');

                try {
                  await Future.delayed(Duration(seconds: 3));
                  apnsToken = await FirebaseMessaging.instance.getAPNSToken();
                  print('DEBUG: APNS Token attempt $apnsAttempts: $apnsToken');
                } catch (e) {
                  print('DEBUG: APNS attempt $apnsAttempts failed: $e');
                }
              }

              // Send APNS token to API if FCM failed
              if (apnsToken != null) {
                print('DEBUG: Using APNS token for API call: $apnsToken');
                await _sendDeviceTokenToAPI(apnsToken);
              } else {
                print('DEBUG: APNS token is null, cannot send to API');
              }
            }

            // FCM token already handled above for iOS
            if (!Platform.isIOS) {
              // For Android, try to get FCM token
              String? deviceToken;
              int attempts = 0;
              const maxAttempts = 5;

              while (deviceToken == null && attempts < maxAttempts) {
                attempts++;
                print('DEBUG: Android FCM attempt $attempts...');

                try {
                  if (attempts > 1) {
                    await Future.delayed(Duration(seconds: 2));
                  }

                  deviceToken = await FirebaseMessaging.instance.getToken();
                  if (deviceToken != null) {
                    print(
                      'DEBUG: Android FCM token obtained on attempt $attempts!',
                    );
                    print('DEBUG: Android FCM Token: $deviceToken');
                    break;
                  }
                } catch (e) {
                  print('DEBUG: Android FCM attempt $attempts failed: $e');
                }
              }

              if (deviceToken != null) {
                await _sendDeviceTokenToAPI(deviceToken);
              } else {
                throw Exception(
                  'Could not get FCM token after $maxAttempts attempts',
                );
              }
            }
          } catch (firebaseError) {
            // If Firebase fails, show error
            print('Firebase error: $firebaseError');
            throw Exception('Failed to get FCM token: $firebaseError');
          }

          final updatedUser = user.copyWith(userDeviceActive: true);
          authStore.setUser(updatedUser);
        } else {
          try {
            // Get device token from Firebase
            String? deviceToken = await FirebaseMessaging.instance.getToken();
            print('DEBUG: Device token for disabling: $deviceToken');

            if (deviceToken != null && deviceToken.isNotEmpty) {
            
              await ApiService.request(
                url: 'auth/update-device-token-status/$deviceToken/',
                method: 'PUT',
                data: {'is_active': false},
              );
            } else {}
          } catch (firebaseError) {}

          // Update local user data
          final updatedUser = user.copyWith(userDeviceActive: false);
          authStore.setUser(updatedUser);
        }
      }

      // Show success message
      if (mounted) {
        Fluttertoast.showToast(
          msg: _dailyMeditationEnabled
              ? 'Notifications enabled successfully!'
              : 'Notifications disabled successfully!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: const Color(0xFFF2EFEA),
          textColor: const Color(0xFF3B6EAA),
        );

        // Navigate back to previous page
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('DEBUG: Main error in _saveSettings: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to update settings: ${e.toString()}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: const Color(0xFFF2EFEA),
          textColor: const Color(0xFF3B6EAA),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back button behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: Stack(
            children: [
              const StarsAnimation(
                starCount: 20,
                topColor: const Color(0xFF3C6EAB),
                bottomColor: const Color(0xFFA4C6EB),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    SizedBox(height: 30.h),
                    Text(
                      'Reminders',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 242, 239, 234),
                        fontSize: 36.sp,
                        fontFamily: 'Canela',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 30.h),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: _buildContent(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          Transform.translate(
            offset: const Offset(3, 0),
            child: Image.asset('assets/img/logo.png', width: 60, height: 39),
          ),
          Container(
            width: 36,
            height: 36,
            child: const Icon(
              Icons.settings,
              color: Colors.transparent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Meditation',
              style: TextStyle(
                color: const Color.fromARGB(255, 242, 239, 234),
                fontSize: 16.sp,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: _isSaving
                  ? null
                  : () {
                      setState(() {
                        _dailyMeditationEnabled = !_dailyMeditationEnabled;
                      });
                    },
              child: Container(
                width: 45,
                height: 24,
                decoration: BoxDecoration(
                  color: _dailyMeditationEnabled
                      ? const Color.fromRGBO(21, 43, 86, 0.1)
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1000),
                  border: Border.all(
                    color: const Color.fromRGBO(21, 43, 86, 0.1),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      left: _dailyMeditationEnabled ? 20 : 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 60.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B6EAA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(vertical: 18.h),
              elevation: 0,
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
