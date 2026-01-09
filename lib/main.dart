import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_constants.dart';
import 'shared/themes/app_theme.dart';
import 'core/stores/auth_store.dart';
import 'core/stores/meditation_store.dart';
import 'core/stores/like_store.dart';
import 'core/stores/check_in_store.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/storekit_service.dart';
import 'core/services/revenuecat_service.dart';
import 'pages/loading_screen.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/change_password_page.dart';
import 'pages/dashboard/main.dart';
import 'pages/auth/starter_page.dart';
import 'pages/auth/onboarding_page_1.dart';
import 'pages/auth/onboarding_page_2.dart';
import 'pages/auth/onboarding_page_3.dart';
import 'pages/auth/onboarding_page_4.dart';
import 'pages/plan_page.dart';
import 'pages/generator/generator_page.dart';
import 'pages/vault_page.dart';
import 'pages/dashboard/my_meditations_page.dart';
import 'pages/dashboard/archive_page.dart';
import 'pages/dashboard/reminders_page.dart';
import 'pages/edit_info_page.dart';
import 'pages/dashboard/components/dashboard_audio_player.dart';
import 'core/utils/video_loader.dart';
import 'core/services/superwall_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

// Global navigator key for API service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global variable to store meditation ID for audio player
String? globalMeditationId;

// Global variable to navigate to profile tab
bool shouldNavigateToProfile = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only (no landscape)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Force portrait mode and prevent any rotation
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize SuperwallKit for payments
  // Superwall API key from https://superwall.com/dashboard
  // According to Superwall documentation, configure should be called in main.dart
  try {
    // Determine Superwall API Key for platform
    // For now using same key for both platforms, but can be different
    const superwallApiKey = String.fromEnvironment(
      'SUPERWALL_API_KEY',
      defaultValue: 'pk_pJRetlpqb1kyNrf0WFCUQ', // Superwall API key
    );

    if (superwallApiKey.isNotEmpty) {
      // Configure Superwall - this creates a shared instance
      Superwall.configure(superwallApiKey);

      // Also initialize our service wrapper for additional functionality
      final superwallService = SuperwallService();
      await superwallService.initialize(superwallApiKey);
    }
  } catch (e, stackTrace) {
    print('⚠️ Failed to initialize SuperwallKit: $e');
    print('🔵 Stack trace: $stackTrace');
  }

  // Initialize stores
  final authStore = AuthStore();
  final meditationStore = MeditationStore();
  final likeStore = LikeStore();
  final checkInStore = CheckInStore();

  // Initialize app lifecycle service for uninstall detection
  final appLifecycleService = AppLifecycleService();
  await appLifecycleService.initialize();

  // Initialize RevenueCat for in-app purchases
  try {
    print('🔵 [main.dart] Starting RevenueCat initialization...');
    final revenueCatService = RevenueCatService();
    await revenueCatService.initialize();

    // Check if initialization was successful
    if (revenueCatService.isAvailable) {
      print(
        '✅ [main.dart] RevenueCat initialized successfully and is available',
      );
    } else {
      print('⚠️ [main.dart] RevenueCat initialized but is not available');
      print('⚠️ [main.dart] isInitialized: ${revenueCatService.isInitialized}');
    }
  } catch (e, stackTrace) {
    print('❌ [main.dart] Failed to initialize RevenueCat: $e');
    print('❌ [main.dart] Stack trace: $stackTrace');
    // Continue app initialization even if RevenueCat fails
  }

  // Initialize StoreKit Service for promo codes (Apple native)
  try {
    final storeKitService = StoreKitService();
    await storeKitService.initialize();
    print('✅ StoreKitService initialized successfully');
  } catch (e) {
    print('⚠️ Failed to initialize StoreKitService: $e');
    // Continue app initialization even if StoreKitService fails
  }

  await authStore.initialize();
  await meditationStore.initialize();

  // Preload videos before app starts
  await VideoLoader.initializeVideos();

  // Check if user is authenticated using the store method
  String initialRoute = '/loading';
  final isAuthenticated = await authStore.isAuthenticated();
  if (isAuthenticated) {
    // Still go to loading screen to check authentication and profile completion
    initialRoute = '/loading';
  }

  runApp(
    MyApp(
      authStore: authStore,
      meditationStore: meditationStore,
      likeStore: likeStore,
      checkInStore: checkInStore,
      appLifecycleService: appLifecycleService,
      initialRoute: initialRoute,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthStore authStore;
  final MeditationStore meditationStore;
  final LikeStore likeStore;
  final CheckInStore checkInStore;
  final AppLifecycleService appLifecycleService;
  final String initialRoute;

  const MyApp({
    super.key,
    required this.authStore,
    required this.meditationStore,
    required this.likeStore,
    required this.checkInStore,
    required this.appLifecycleService,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        // Force portrait orientation
        if (orientation != Orientation.portrait) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authStore),
              ChangeNotifierProvider.value(value: meditationStore),
              ChangeNotifierProvider.value(value: likeStore),
              ChangeNotifierProvider.value(value: checkInStore),
            ],
            child: ScreenUtilInit(
              designSize: Size(
                390,
                844,
              ), // ← здесь укажи размер твоего дизайна (из Figma и т.п.)
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  title: AppConstants.appName,
                  theme: AppTheme.lightTheme.copyWith(
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android:
                            NoAnimationPageTransitionsBuilder(),
                        TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                      },
                    ),
                  ),
                  darkTheme: AppTheme.darkTheme.copyWith(
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android:
                            NoAnimationPageTransitionsBuilder(),
                        TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                      },
                    ),
                  ),
                  debugShowCheckedModeBanner: false,
                  initialRoute: initialRoute,
                  routes: {
                    '/loading': (context) => const LoadingScreen(),
                    '/starter': (context) => const StarterPage(),
                    '/onboarding-1': (context) => const OnboardingPage1(),
                    '/onboarding-2': (context) => const OnboardingPage2(),
                    '/onboarding-3': (context) => const OnboardingPage3(),
                    '/onboarding-4': (context) => const OnboardingPage4(),
                    '/login': (context) => const LoginPage(),
                    '/register': (context) => const RegisterPage(),
                    '/forgot-password': (context) => const ForgotPasswordPage(),
                    '/change-password': (context) => const ChangePasswordPage(),
                    '/plan': (context) => const PlanPage(),
                    '/generator': (context) => const GeneratorPage(),
                    '/vault': (context) => const VaultPage(),
                    '/dashboard': (context) => const DashboardMainPage(),
                    '/my-meditations': (context) => MyMeditationsPage(
                      onAudioPlay: (meditationId) {
                        globalMeditationId = meditationId;
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      },
                    ),
                    '/archive': (context) => const ArchivePage(),
                    '/reminders': (context) => const RemindersPage(),
                    '/edit-info': (context) => const EditInfoPage(),
                    '/audio-player': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as Map<String, dynamic>?;
                      return DashboardAudioPlayer(
                        meditationId: args?['meditationId'] ?? '',
                        title: args?['title'],
                        description: args?['description'],
                        imageUrl: args?['imageUrl'],
                      );
                    },
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
