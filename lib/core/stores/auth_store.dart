import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:io';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../../shared/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/superwall_service.dart';

// Pinia store ga o'xshash AuthStore - API chaqiruvlar va ma'lumotlarni saqlash
class AuthStore extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;

  // Services
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // iOS uchun soddalashtirilgan sozlamalar
    signInOption: SignInOption.standard,
    // Android uchun serverClientId - Web application OAuth Client ID kerak
    // Bu idToken olish uchun zarur
    serverClientId: Platform.isAndroid 
        ? '354237870385-vjm9880kbjje9gc9ptrisl30ih80qivk.apps.googleusercontent.com'
        : null,
  );
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Global variable for ID token
  static String? _lastIdToken;
  static String? get lastIdToken => _lastIdToken;

  // Getters (Pinia'ga o'xshash)
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // Check authentication status directly from storage
  Future<bool> isAuthenticated() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check if user profile is complete
  bool isProfileComplete() {
    if (_user == null) return false;

    // Check if essential profile fields are filled
    final hasGender = _user!.gender != null && _user!.gender!.isNotEmpty;
    final hasAgeRange = _user!.ageRange != null && _user!.ageRange!.isNotEmpty;
    final hasDream = _user!.dream != null && _user!.dream!.isNotEmpty;
    final hasGoals = _user!.goals != null && _user!.goals!.isNotEmpty;
    final hasHappiness =
        _user!.happiness != null && _user!.happiness!.isNotEmpty;

    return hasGender && hasAgeRange && hasDream && hasGoals && hasHappiness;
  }

  // Check if user has selected a plan
  Future<bool> hasSelectedPlan() async {
    try {
      final planType = await _secureStorage.read(key: 'plan_type');
      return planType != null && planType.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get the appropriate redirect route based on profile completion and plan status
  Future<String> getRedirectRoute() async {
    // First check plan status from API
    final planStatus = await checkPlanStatus();
    if (planStatus != null) {
      final hasActivePlan = planStatus['has_active_plan'] ?? false;
      if (!hasActivePlan) {
        return '/plan'; // No active plan, redirect to plan selection
      }
    }

    // If user has active plan, get user details and check profile completion
    await getUserDetails();

    if (!isProfileComplete()) {
      // If profile is not complete, check which step to start from
      if (_user?.gender == null || _user!.gender!.isEmpty) {
        return '/generator'; // Start from gender step
      }
      return '/generator'; // Continue from where they left off
    }

    return '/dashboard'; // Profile is complete and has active plan, go to dashboard
  }

  // Actions (Pinia actions ga o'xshash)
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _user = user;

    // Register user with SuperwallKit for payment tracking
    if (user != null && user.id.isNotEmpty) {
      try {
        final superwallService = SuperwallService();
        if (superwallService.isInitialized) {
          superwallService.registerUser(user.id);
        }
      } catch (e) {
        developer.log('⚠️ Error registering user with SuperwallKit: $e');
        // Don't block user flow if SuperwallKit registration fails
      }
    }

    notifyListeners();
  }

  void setTokens({String? accessToken, String? refreshToken}) {
    if (accessToken != null) _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;

    // Update API Service memory token
    if (accessToken != null) {
      try {
        ApiService.setMemoryToken(accessToken);
      } catch (e) {
        print('🔍 Error setting memory token: $e');
      }
    }

    notifyListeners();
  }

  // Initialize store - check if user is already logged in
  Future<void> initialize() async {
    try {
      // Initialize ApiService
      ApiService.init();

      // Check if user is authenticated and get user details if needed
      final isAuth = await isAuthenticated();
      if (isAuth) {
        // Load token to memory for API calls
        _accessToken = await _secureStorage.read(key: 'access_token');

        // Update API Service memory token
        if (_accessToken != null) {
          ApiService.setMemoryToken(_accessToken);
        }

        await getUserDetails();
      }
    } catch (e) {}
  }

  // Login action with API call
  Future<void> login({
    required String email,
    required String password,
    VoidCallback? onSuccess,
    VoidCallback? onNewUser, // Yangi user uchun callback
  }) async {
    setLoading(true);
    setError(null);

    try {
      final response = await ApiService.request(
        url: 'auth/signin/',
        method: 'POST',
        data: {'identifier': email, 'password': password},
        open: true, // Bu endpoint uchun token kerak emas
      );

      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];

      if (accessToken != null) {
        try {
          await _secureStorage.write(key: 'access_token', value: accessToken);
          if (refreshToken != null) {
            await _secureStorage.write(
              key: 'refresh_token',
              value: refreshToken,
            );
          }
        } catch (e) {
          // If token already exists, delete it first then write
          if (e.toString().contains('already exists')) {
            await _secureStorage.delete(key: 'access_token');
            await _secureStorage.write(key: 'access_token', value: accessToken);
            if (refreshToken != null) {
              await _secureStorage.delete(key: 'refresh_token');
              await _secureStorage.write(
                key: 'refresh_token',
                value: refreshToken,
              );
            }
          }
        }

        setTokens(accessToken: accessToken, refreshToken: refreshToken);

        // Get user details from API
        await getUserDetails();

        // Check plan status and profile completion, then redirect accordingly
        final redirectRoute = await getRedirectRoute();
        if (redirectRoute == '/dashboard') {
          // Profile is complete and has active plan - go to dashboard
          onSuccess?.call();
        } else {
          // Either no active plan or profile incomplete - go to appropriate step
          onNewUser?.call();
        }
      }
    } catch (e) {
      String errorMessage = 'Login failed. Please check your credentials.';

      if (e.toString().contains('400')) {
        errorMessage = 'Invalid email or password.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please check your credentials.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Wrong Login or Password. Please try again';
      }

      setError(errorMessage);
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Google login action with API call
  Future<void> loginWithGoogle({
    VoidCallback? onSuccess,
    VoidCallback? onNewUser, // Yangi user uchun callback
  }) async {
    // Web platformasi uchun Google Sign-In o'chirilgan
    if (kIsWeb) {
      setError('Google Sign-In is not available on web platform');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        developer.log('🔍 Google Sign-In was cancelled by user');
        // Foydalanuvchi dialog'ni bekor qilgan - bu xato emas, shunchaki bekor qilindi
        // Error o'rnatmaymiz, chunki bu normal holat
        return;
      }

      // Get authentication data
      GoogleSignInAuthentication? auth;
      try {
        auth = await googleUser.authentication;
        developer.log('🔍 Google authentication obtained');
        developer.log('🔍 ID Token: ${auth.idToken != null ? "Present" : "NULL"}');
        developer.log('🔍 Access Token: ${auth.accessToken != null ? "Present" : "NULL"}');
      } catch (authError) {
        developer.log('❌ Auth error: $authError');
        setError('Failed to get authentication data. Please try again.');
        return;
      }

      // Check if idToken is null and try to get it from Firebase if needed
      String? idTokenToUse = auth.idToken;
      
      // Firebase Authentication bilan sign-in qilish (faqat mobile platformalar uchun)
      if (idTokenToUse != null && !kIsWeb) {
        try {
          developer.log('🔍 Firebase Authentication bilan sign-in qilish...');

          // Firebase credential yaratish
          final credential = GoogleAuthProvider.credential(
            idToken: auth.idToken,
            accessToken: auth.accessToken,
          );

          // Firebase Authentication bilan sign-in
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final firebaseUser = userCredential.user;

          if (firebaseUser != null) {
            // Firebase ID token'ni olish (Firebase'dan) - bu backend uchun kerak
            String? firebaseIdToken;
            try {
              firebaseIdToken = await firebaseUser.getIdToken();
              developer.log('🔍 Firebase ID token obtained: ${firebaseIdToken != null ? "Present" : "NULL"}');
            } catch (e) {
              developer.log('❌ Error getting Firebase ID token: $e');
            }

            // Google ID token'ni olish (Google'dan to'g'ridan-to'g'ri)
            final googleIdToken = auth.idToken ?? firebaseIdToken;
            
            if (googleIdToken == null) {
              developer.log('❌ Both Google ID token and Firebase ID token are null');
              setError('Failed to get authentication token. Please try again.');
              return;
            }

            _lastIdToken = googleIdToken;

            // Firebase login API ga so'rov yuborish
            try {
              developer.log('🔍 Sending ID token to backend (length: ${googleIdToken.length})');
              final response = await ApiService.request(
                url: 'auth/firebase/login/',
                method: 'POST',
                data: {'firebase_id_token': googleIdToken},
                open: true, // Bu endpoint uchun token kerak emas
              );

              developer.log('🔍 Backend response: ${response.data}');
              developer.log('🔍 Response status: ${response.statusCode}');
              developer.log('🔍 Response headers: ${response.headers}');
              developer.log('🔍 Response status: ${response.statusCode}');
              developer.log('🔍 Response headers: ${response.headers}');

              // Backend token'ni saqlash
              if (response.data['access_token'] != null) {
                await _secureStorage.write(
                  key: 'access_token',
                  value: response.data['access_token'],
                );
                setTokens(accessToken: response.data['access_token']);

                // User details'ni olish
                await getUserDetails();

                // Check plan status and profile completion, then redirect accordingly
                final redirectRoute = await getRedirectRoute();
                if (redirectRoute == '/dashboard') {
                  // Profile is complete and has active plan - go to dashboard
                  onSuccess?.call();
                } else {
                  // Either no active plan or profile incomplete - go to appropriate step
                  onNewUser?.call();
                }
              } else {
                developer.log(
                  '❌ No access token in response: ${response.data}',
                );
                setError(
                  'Backend authentication failed. No access token received.',
                );
              }
            } catch (e) {
              developer.log('❌ Backend API error: $e');

              // Check if it's a 401 error specifically
              if (e.toString().contains('401')) {
                setError(
                  'Server authentication failed. Please check backend configuration.',
                );
              } else if (e.toString().contains('400')) {
                setError('Invalid token format. Please try again.');
              } else if (e.toString().contains('500')) {
                setError('Server error. Please try again later.');
              } else {
                setError('Backend authentication failed: ${e.toString()}');
              }
            }
          } else {
            setError('Firebase Authentication failed. User is null.');
          }
        } catch (firebaseError) {
          developer.log('❌ Firebase Authentication error: $firebaseError');
          setError('Firebase Authentication failed: $firebaseError');
        }
      } else {
        developer.log('❌ Google ID Token is null');
        developer.log('🔍 Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
        developer.log('🔍 ID Token: ${auth.idToken}');
        developer.log('🔍 Access Token: ${auth.accessToken != null ? "Present" : "NULL"}');
        
        // Try to get serverAuthCode as fallback (Android only)
        if (Platform.isAndroid) {
          try {
            final serverAuthCode = await googleUser.serverAuthCode;
            if (serverAuthCode != null) {
              developer.log('🔍 Server Auth Code obtained, but backend expects ID token');
            }
          } catch (e) {
            developer.log('❌ Error getting serverAuthCode: $e');
          }
        }
        
        setError('Google ID Token is null. Please check Google Sign-In configuration. Make sure serverClientId is set correctly.');
      }
    } catch (e) {
      String errorMessage = 'Google Sign-In failed. Please try again.';

      if (e.toString().contains('12501')) {
        errorMessage = 'Google Sign-In was cancelled by user.';
      } else if (e.toString().contains('12500')) {
        errorMessage =
            'Google Sign-In failed. Please check your internet connection.';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Invalid Google credentials.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please try again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Wrong Login or Password. Please try again';
      } else if (e.toString().contains('configuration')) {
        errorMessage =
            'Google Sign-In configuration error. Please restart the app.';
      } else if (Platform.isIOS) {
        // iOS uchun maxsus xatoliklar
        if (e.toString().contains('12501')) {
          errorMessage = 'Google Sign-In was cancelled by user.';
        } else if (e.toString().contains('12500')) {
          errorMessage =
              'Google Sign-In failed. Please check your internet connection.';
        } else if (e.toString().contains('network')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (e.toString().contains('sign_in_failed')) {
          errorMessage = 'Google Sign-In failed. Please try again.';
        } else if (e.toString().contains('sign_in_canceled')) {
          errorMessage = 'Google Sign-In was cancelled.';
        } else {
          errorMessage = 'Google Sign-In failed. Please try again.';
        }
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }

  // Apple Sign In
  Future<void> loginWithApple({
    VoidCallback? onSuccess,
    VoidCallback? onNewUser, // Yangi user uchun callback
  }) async {
    setLoading(true);
    setError(null);

    try {
      // Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        developer.log('❌ Apple Sign-In failed: No identity token');
        setError('Apple Sign-In failed: No identity token');
        return;
      }

      // Firebase Authentication bilan sign-in qilish
      try {
        developer.log(
          '🔍 Firebase Authentication bilan Apple sign-in qilish...',
        );

        // Firebase credential yaratish
        final firebaseCredential = OAuthProvider("apple.com").credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );

        // Firebase Authentication bilan sign-in
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          firebaseCredential,
        );
        final firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          _lastIdToken = credential.identityToken;
          final appleIdToken = credential.identityToken;

          // Firebase login API ga so'rov yuborish
          try {
            developer.log(
              '🔍 Sending Firebase ID token to backend: ${appleIdToken}',
            );

            final response = await ApiService.request(
              url: 'auth/firebase/login/',
              method: 'POST',
              data: {'firebase_id_token': appleIdToken},
              open: true, // Bu endpoint uchun token kerak emas
            );

            developer.log('🔍 Backend response: ${response.data}');
            developer.log('🔍 Response status: ${response.statusCode}');
            developer.log('🔍 Response headers: ${response.headers}');

            // Backend token'ni saqlash
            if (response.data['access_token'] != null) {
              await _secureStorage.write(
                key: 'access_token',
                value: response.data['access_token'],
              );
              setTokens(accessToken: response.data['access_token']);

              // User details'ni olish
              await getUserDetails();

              // Check plan status and profile completion, then redirect accordingly
              final redirectRoute = await getRedirectRoute();
              if (redirectRoute == '/dashboard') {
                // Profile is complete and has active plan - go to dashboard
                onSuccess?.call();
              } else {
                // Either no active plan or profile incomplete - go to appropriate step
                onNewUser?.call();
              }
            } else {
              developer.log('❌ No access token in response: ${response.data}');
              setError(
                'Backend authentication failed. No access token received.',
              );
            }
          } catch (e) {
            developer.log('❌ Backend API error: $e');

            // Check if it's a 401 error specifically
            if (e.toString().contains('401')) {
              setError(
                'Server authentication failed. Please check backend configuration.',
              );
            } else if (e.toString().contains('400')) {
              setError('Invalid token format. Please try again.');
            } else if (e.toString().contains('500')) {
              setError('Server error. Please try again later.');
            } else {
              setError('Backend authentication failed: ${e.toString()}');
            }
          }
        } else {
          setError('Firebase Authentication failed. User is null.');
        }
      } catch (firebaseError) {
        developer.log('❌ Firebase Authentication error: $firebaseError');
        setError('Firebase Authentication failed: $firebaseError');
      }
    } catch (e) {
      String errorMessage = 'Apple Sign-In failed. Please try again.';

      if (e.toString().contains('SignInWithAppleAuthorizationException')) {
        if (e.toString().contains('canceled')) {
          errorMessage = 'Apple Sign-In was cancelled by user.';
        } else if (e.toString().contains('failed')) {
          errorMessage = 'Apple Sign-In failed. Please try again.';
        } else if (e.toString().contains('invalidResponse')) {
          errorMessage = 'Invalid Apple Sign-In response.';
        } else if (e.toString().contains('notHandled')) {
          errorMessage = 'Apple Sign-In not handled.';
        } else if (e.toString().contains('unknown')) {
          errorMessage = 'Unknown Apple Sign-In error.';
        }
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }

  // Register action with API call
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    VoidCallback? onSuccess,
  }) async {
    setLoading(true);
    setError(null);

    try {
      final data = {
        "email": email,
        "first_name": firstName,
        "last_name": lastName,
        "password": password,
        "password_confirm": password,
        "is_agree": true,
      };

      await ApiService.request(
        url: 'auth/signup/',
        method: 'POST',
        data: data,
        open: true, // Bu endpoint uchun token kerak emas
      );
      await login(
        email: email,
        password: password,
        onSuccess: onSuccess,
        onNewUser: onSuccess, // Register qilayotgan user har doim yangi user
      );
    } catch (e) {
      String errorMessage = 'Registration failed. Please try again.';

      if (e.toString().contains('400')) {
        errorMessage = 'This email is already registered.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please try again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Wrong Login or Password. Please try again';
      }

      setError(errorMessage);
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Get user details from API
  Future<void> getUserDetails() async {
    try {
      final response = await ApiService.request(
        url: 'auth/user-detail/',
        method: 'GET',
      );

      // Parse user data from response
      final userData = response.data;

      if (userData != null) {
        final user = UserModel.fromJson(userData);
        setUser(user);

        // Check if user has gender, if not redirect to gender selection
        if (user.gender == null || user.gender!.isEmpty) {
          developer.log(
            '🔍 User gender is missing, redirecting to gender selection',
          );
          // This will be handled by getRedirectRoute() in the calling function
        }
      }
    } catch (e) {
      developer.log('❌ Get user details error: $e');
    }
  }

  // Facebook login action with API call
  Future<void> loginWithFacebook({
    VoidCallback? onSuccess,
    VoidCallback? onNewUser,
  }) async {
    // Web platformasi uchun Facebook Sign-In o'chirilgan
    if (kIsWeb) {
      setError('Facebook Sign-In is not available on web platform');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Facebook Sign-In with Standard Login (non-limited) to get full access token
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        // Use Standard Login to get full access token (not Limited Login)
      );

      if (result.status == LoginStatus.success) {
        // Get user data from Facebook
        final userData = await FacebookAuth.instance.getUserData(
          fields: "name,email,picture.width(200)",
        );

        // Get the standard access token
        try {
          // Get current access token
          final currentToken = await FacebookAuth.instance.accessToken;

          // Try to get token as string
          if (currentToken != null) {
            // Prepare data for auth/facebook/register/ endpoint
            final registerData = {
              "first_name": userData['name']?.split(' ').first ?? '',
              "last_name": userData['name']?.split(' ').skip(1).join(' ') ?? '',
              "email": userData['email'] ?? '',
            };

            // Send request to auth/facebook/register/ endpoint
            final response = await ApiService.request(
              url: 'auth/facebook/register/',
              method: 'POST',
              data: registerData,
              open: true,
            );

            // Store access token from response
            if (response.data['access_token'] != null) {
              try {
                await _secureStorage.write(
                  key: 'access_token',
                  value: response.data['access_token'],
                );
                setTokens(accessToken: response.data['access_token']);
              } catch (e) {
                // If token already exists, delete it first then write
                if (e.toString().contains('already exists')) {
                  await _secureStorage.delete(key: 'access_token');
                  await _secureStorage.write(
                    key: 'access_token',
                    value: response.data['access_token'],
                  );
                  setTokens(accessToken: response.data['access_token']);
                } else {
                  print('❌ Error storing access token: $e');
                }
              }

              // Get user details to determine if new or existing user
              await getUserDetails();

              // Check plan status and profile completion, then redirect accordingly
              final redirectRoute = await getRedirectRoute();
              if (redirectRoute == '/dashboard') {
                // Profile is complete and has active plan - go to dashboard
                onSuccess?.call();
              } else {
                // Either no active plan or profile incomplete - go to appropriate step
                onNewUser?.call();
              }
            } else {
              print('❌ No access token in response');
            }
          }
        } catch (e) {
          print('🔍 Error getting current token: $e');
        }
      } else if (result.status == LoginStatus.cancelled) {
        setError('Facebook Sign-In was cancelled');
      } else {
        setError('Facebook Sign-In failed: ${result.message}');
      }
    } catch (e) {
      String errorMessage = 'Facebook Sign-In failed. Please try again.';

      if (e.toString().contains('cancelled')) {
        errorMessage = 'Facebook Sign-In was cancelled by user.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Facebook Sign-In failed. Please check your internet connection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Facebook permissions denied. Please try again.';
      } else if (e.toString().contains('configuration')) {
        errorMessage =
            'Facebook Sign-In configuration error. Please restart the app.';
      } else if (e.toString().contains('invalid-credential')) {
        errorMessage = 'Facebook authentication token issue. Please try again.';
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }

  // Logout action (Pinia'ga o'xshash)
  Future<void> logout() async {
    try {
      // Faqat mobile platformalar uchun social auth logout
      if (!kIsWeb) {
        await _googleSignIn.signOut();
        await FacebookAuth.instance.logOut();
      }

      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');

      // Clear neuroplasticity state
      await _secureStorage.delete(key: 'neuroplasticity_active');
      await _secureStorage.delete(key: 'neuroplasticity_content');

      _user = null;
      _accessToken = null;
      _refreshToken = null;
      _error = null;

      notifyListeners();
    } catch (e) {
      developer.log('❌ Logout error: $e');
    }
  }

  // Clear all tokens and data (for app uninstall detection)
  Future<void> clearAllData() async {
    try {
      // Clear all secure storage data
      await _secureStorage.deleteAll();

      // Clear social auth sessions
      if (!kIsWeb) {
        await _googleSignIn.signOut();
        await FacebookAuth.instance.logOut();
        await FirebaseAuth.instance.signOut();
      }

      // Clear memory tokens
      _user = null;
      _accessToken = null;
      _refreshToken = null;
      _error = null;
      _lastIdToken = null;

      // Clear API service memory token
      ApiService.setMemoryToken(null);

      notifyListeners();

      developer.log('✅ All user data cleared successfully');
    } catch (e) {
      developer.log('❌ Error clearing all data: $e');
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get Firebase ID Token (faqat mobile platformalar uchun)
  Future<String?> getFirebaseIdToken() async {
    if (kIsWeb) {
      print('🔍 Firebase ID Token not available on web platform');
      return null;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final idToken = await currentUser.getIdToken();
        return idToken;
      } else {
        print('🔍 No Firebase user logged in');
        return null;
      }
    } catch (e) {
      print('🔍 Error getting Firebase ID Token: $e');
      return null;
    }
  }

  // Assign free trial and save to store
  Future<void> assignFreeTrial() async {
    setLoading(true);
    setError(null);

    try {
      final response = await ApiService.request(
        url: 'auth/assign-free-trial/',
        method: 'POST',
      );
      // print('🔍 Assign free trial response: $response');
      // final planStatus = await checkPlanStatus();
      // print('🔍 Plan status: $planStatus');
      if (response.data != null) {
        return response.data;
      }
    } catch (e) {
      setError('Failed to assign free trial');
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Check plan status from API
  Future<Map<String, dynamic>?> checkPlanStatus() async {
    try {
      final response = await ApiService.request(
        url: 'auth/check-plan-status/',
        method: 'GET',
      );

      print('🔍 Check plan status response: $response');
      if (response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      developer.log('❌ Check plan status error: $e');
      return null;
    }
  }

  // Helper method to format age range to required format
  String _formatAgeRange(String ageRange) {
    try {
      int age = int.parse(ageRange);

      if (age >= 18 && age <= 24) {
        return '18-24';
      } else if (age >= 25 && age <= 34) {
        return '25-34';
      } else if (age >= 35 && age <= 44) {
        return '35-44';
      } else if (age >= 45 && age <= 54) {
        return '45-54';
      } else {
        return '55-64';
      }
    } catch (e) {
      // If parsing fails, return default value
      return '55-64';
    }
  }

  // Update user detail information (gender, age_range, dream, goals, happiness)
  Future<void> updateUserDetail({
    required String gender,
    required String ageRange,
    required String dream,
    required String goals,
    required String happiness,
    VoidCallback? onSuccess,
  }) async {
    print('🔄 [updateUserDetail] Starting user detail update...');
    print('🔄 [updateUserDetail] gender: $gender');
    print('🔄 [updateUserDetail] ageRange: $ageRange');
    print('🔄 [updateUserDetail] dream: $dream');
    print('🔄 [updateUserDetail] goals: $goals');
    print('🔄 [updateUserDetail] happiness: $happiness');

    setLoading(true);
    setError(null);

    try {
      // Format age range to required format
      String formattedAgeRange = _formatAgeRange(ageRange);

      final requestData = {
        'gender': gender,
        'age_range': formattedAgeRange,
        'dream': dream,
        'goals': goals,
        'happiness': happiness,
      };

      print('🔄 [updateUserDetail] Formatted age range: $formattedAgeRange');
      print('🔄 [updateUserDetail] Request data: $requestData');

      // Ensure token is in API Service memory
      if (_accessToken != null) {
        ApiService.setMemoryToken(_accessToken);
      }

      // Re-initialize API Service to ensure interceptors work
      ApiService.init();
      
      // Django requires trailing slash for PUT requests with APPEND_SLASH enabled
      String endpoint = 'auth/user-detail-update/';
      
      print('🔄 [updateUserDetail] Trying endpoint: $endpoint');
      print('🔄 [updateUserDetail] Full URL will be: ${ApiService.baseUrl}$endpoint');
      
      final response = await ApiService.request(
        url: endpoint,
        method: 'PUT',
        data: requestData,
        open: false, // Token required
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update local user data
        if (_user != null) {
          final updatedUser = _user!.copyWith(
            gender: gender,
            ageRange: ageRange,
            dream: dream,
            goals: goals,
            happiness: happiness,
          );
          setUser(updatedUser);
        }

        // Show success toast
        Fluttertoast.showToast(
          msg: 'User details updated successfully!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        onSuccess?.call();
      }
    } catch (e) {
      print('❌ [updateUserDetail] API Error: $e');

      // Response ma'lumotlarini olish (agar mavjud bo'lsa)
      if (e is DioException && e.response != null) {
        print('❌ [updateUserDetail] DioException details:');
        print('❌ [updateUserDetail] Status code: ${e.response?.statusCode}');
        print('❌ [updateUserDetail] Response data: ${e.response?.data}');
        print('❌ [updateUserDetail] Request URL: ${e.requestOptions.uri}');
        print('❌ [updateUserDetail] Request method: ${e.requestOptions.method}');
        print('❌ [updateUserDetail] Request headers: ${e.requestOptions.headers}');
        
        if (e.response?.statusCode == 404) {
          print('❌ [updateUserDetail] 404 Error - Endpoint topilmadi');
        print('❌ [updateUserDetail] Base URL: ${ApiService.baseUrl}');
          print('❌ [updateUserDetail] Tried endpoint: auth/user-detail-update');
          print('❌ [updateUserDetail] Full URL tried: ${ApiService.baseUrl}auth/user-detail-update');
          print('❌ [updateUserDetail] Browser shows 401 (endpoint exists but needs auth)');
          print('❌ [updateUserDetail] This suggests URL format issue or method not supported');
        }
      } else if (e.toString().contains('404')) {
        print('❌ [updateUserDetail] 404 Error detected in exception string');
        print('❌ [updateUserDetail] Base URL: ${ApiService.baseUrl}');
        print('❌ [updateUserDetail] Endpoint: auth/user-detail-update');
      }

      developer.log('❌ Update user detail error: $e');

      setError('Failed to update user details');

      // Show error toast - faqat parallel yuborishda emas
      // Parallel yuborishda toast ko'rsatmaymiz, chunki bu background process
      if (onSuccess == null) {
        Fluttertoast.showToast(
          msg: 'Failed to update user details',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // Update user profile information
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? avatar,
    Uint8List? avatarBytes,
    VoidCallback? onSuccess,
  }) async {
    print('🔄 [updateProfile] Starting profile update...');
    print('🔄 [updateProfile] firstName: $firstName');
    print('🔄 [updateProfile] lastName: $lastName');
    print('🔄 [updateProfile] avatar: $avatar');

    setLoading(true);
    setError(null);

    try {
      // If we have avatar bytes or it's a file path/blob URL, we need to handle it as a file upload
      if (avatarBytes != null ||
          (avatar != null &&
              (avatar.startsWith('/') || avatar.startsWith('blob:')))) {
        // This is a file upload
        final Map<String, dynamic> data = {
          'first_name': firstName,
          'last_name': lastName,
        };

        // Add avatar data - we'll handle this in the API service
        if (avatarBytes != null) {
          data['avatar_bytes'] = avatarBytes;
        } else if (avatar != null) {
          data['avatar'] = avatar;
        }

        print(
          '🔄 [updateProfile] Sending PUT request to auth/user-detail/ (with file upload)',
        );
        print('🔄 [updateProfile] Request data: $data');
        final uploadResponse = await ApiService.uploadFile(
          url: 'auth/user-detail/',
          method: 'PUT',
          data: data,
        );
        print(
          '✅ [updateProfile] Response status: ${uploadResponse.statusCode}',
        );
        print('✅ [updateProfile] Response data: ${uploadResponse.data}');

        // Update local user data with the response
        if (_user != null && uploadResponse.data != null) {
          final userData = uploadResponse.data;
          if (userData is Map<String, dynamic>) {
            final updatedUser = UserModel.fromJson(userData);
            setUser(updatedUser);
          } else {
            // Fallback to local update
            final updatedUser = _user!.copyWith(
              firstName: firstName,
              lastName: lastName,
              avatar: avatar,
            );
            setUser(updatedUser);
          }
        }
      } else {
        // Regular text update
        final data = {
          'first_name': firstName,
          'last_name': lastName,
          'avatar': avatar?.isEmpty == true ? null : avatar,
        };

        print('🔄 [updateProfile] Sending PUT request to auth/user-detail/');
        print('🔄 [updateProfile] Request data: $data');
        final requestResponse = await ApiService.request(
          url: 'auth/user-detail/',
          method: 'PUT',
          data: data,
        );
        print(
          '✅ [updateProfile] Response status: ${requestResponse.statusCode}',
        );
        print('✅ [updateProfile] Response data: ${requestResponse.data}');

        // Update local user data
        if (_user != null) {
          final updatedUser = _user!.copyWith(
            firstName: firstName,
            lastName: lastName,
            avatar: avatar?.isEmpty == true ? null : avatar,
          );
          setUser(updatedUser);
        }
      }

      onSuccess?.call();
    } catch (e) {
      String errorMessage = 'Profile update failed. Please try again.';

      if (e.toString().contains('400')) {
        errorMessage = 'Invalid data provided.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please login again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Wrong Login or Password. Please try again';
      }

      setError(errorMessage);
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Get profile data with life_visions from API
  Future<List<LifeVision>> getProfileDataWithLifeVisions() async {
    try {
      final response = await ApiService.request(
        url: 'auth/life-vision/',
        method: 'GET',
      );

      // Parse response data
      final responseData = response.data;

      // Handle direct array response from API
      if (responseData != null && responseData is List) {
        final lifeVisions = responseData
            .map((vision) => LifeVision.fromJson(vision))
            .toList();

        return lifeVisions;
      }

      return [];
    } catch (e) {
      developer.log('❌ Get profile data with life visions error: $e');
      return [];
    }
  }

  // Create a new LifeVision with POST request
  Future<LifeVision?> createLifeVision({
    required String title,
    required String description,
    required String visionType,
  }) async {
    try {
      // Validate visionType
      if (!['north_star', 'goal', 'dream'].contains(visionType)) {
        throw Exception('Invalid visionType');
      }

      print('🌐 CALLING POST API: auth/life-vision/create/');
      final response = await ApiService.request(
        url: 'auth/life-vision/create/',
        method: 'POST',
        data: {
          'live_vision': title,
          'dreams_realized': description,
          'vision_type': [visionType],
        },
      );

      final responseData = response.data;

      if (responseData != null) {
        final newVision = LifeVision.fromJson(responseData);
        return newVision;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Update a specific LifeVision's visionType
  Future<LifeVision?> updateLifeVisionType({
    required int visionId,
    required List<String> newVisionType,
  }) async {
    try {
      // Validate newVisionType
      for (String type in newVisionType) {
        if (!['north_star', 'goal', 'dream'].contains(type)) {
          throw Exception('Invalid visionType: $type');
        }
      }

      final response = await ApiService.request(
        url: 'auth/life-vision/$visionId/',
        method: 'PUT',
        data: {
          'vision_type': newVisionType,
          'live_vision': '',
          'dreams_realized': '',
        },
      );

      final responseData = response.data;

      if (responseData != null) {
        // Assuming the API returns the updated LifeVision object
        final updatedVision = LifeVision.fromJson(responseData);
        return updatedVision;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Forgot password action with API call
  Future<void> forgotPassword({
    required String email,
    VoidCallback? onSuccess,
  }) async {
    setLoading(true);
    setError(null);

    try {
      await ApiService.request(
        url: 'auth/forgot-password/',
        method: 'POST',
        data: {'email': email},
        open: true, // Bu endpoint uchun token kerak emas
      );

      onSuccess?.call();
    } catch (e) {
      String errorMessage =
          'Failed to send password reset email. Please try again.';

      if (e.toString().contains('400')) {
        errorMessage = 'User with this email address not found.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please try again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }

      setError(errorMessage);
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Change password action with API call
  Future<void> changePassword({
    required String newPassword,
    VoidCallback? onSuccess,
  }) async {
    setLoading(true);
    setError(null);

    try {
      await ApiService.request(
        url: 'auth/update-password/',
        method: 'PATCH',
        data: {'new_password': newPassword},
        open: false, // Bu endpoint uchun token kerak
      );

      onSuccess?.call();
    } catch (e) {
      String errorMessage = 'Failed to change password. Please try again.';

      if (e.toString().contains('400')) {
        errorMessage = 'Invalid password format.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Unauthorized. Please login again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }

      setError(errorMessage);
      // Toast will be shown from the UI layer
    } finally {
      setLoading(false);
    }
  }

  // Check goals - send checked goal item IDs to API
  Future<void> checkGoals({required List<int> goalsItemIds}) async {
    try {
      developer.log('🔍 Sending check-goals request with IDs: $goalsItemIds');
      final response = await ApiService.request(
        url: 'auth/check-goals/',
        method: 'POST',
        data: {'goals_item_ids': goalsItemIds},
        headers: {'Content-Type': 'application/json'},
      );
      developer.log('✅ Check goals response: ${response.data}');
    } catch (e) {
      developer.log('❌ Check goals error: $e');
      if (e is DioException && e.response != null) {
        developer.log('❌ Response status: ${e.response?.statusCode}');
        developer.log('❌ Response data: ${e.response?.data}');
      }
      rethrow;
    }
  }
}
