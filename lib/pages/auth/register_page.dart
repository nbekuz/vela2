import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../styles/base_styles.dart';
import '../../styles/pages/login_page_styles.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/stars_animation.dart';
import '../../shared/widgets/how_work_modal.dart';
import '../../shared/widgets/terms_agreement.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../core/stores/auth_store.dart';
import '../../shared/widgets/notification_handler.dart';
import '../../shared/widgets/google_signin_button.dart';
import '../../shared/widgets/apple_signin_button.dart';
import 'dart:io';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isAgree = true;
  bool _isCheckingRoute = false; // Loading state for route checking
  String? _termsError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Apple Sign-In handler
  Future<void> _handleAppleSignIn() async {
    final authStore = context.read<AuthStore>();

    await authStore.loginWithApple(
      onSuccess: () async {
        print('🍎 Existing user - redirecting to appropriate route');

        if (mounted) {
          setState(() {
            _isCheckingRoute = true; // Show loading while checking route
          });

          ToastService.showSuccessToast(context, message: 'Welcome back!');

          // Request notification permission and send device token
          await NotificationHandler.requestNotificationPermission();

          // Get the appropriate redirect route based on profile completion
          final authStore = context.read<AuthStore>();
          final redirectRoute = await authStore.getRedirectRoute();
          
          if (mounted) {
            setState(() {
              _isCheckingRoute = false; // Hide loading
            });
            Navigator.pushReplacementNamed(context, redirectRoute);
          }
        }
      },
      onNewUser: () async {
        print('🍎 Profile incomplete - redirecting to appropriate step');

        if (mounted) {
          setState(() {
            _isCheckingRoute = true; // Show loading while checking route
          });

          ToastService.showSuccessToast(
            context,
            message: 'Welcome! Let\'s complete your profile',
          );

          // Save "first" variable to localStorage as true for new users
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('first', true);
          } catch (e) {
            // Error saving first variable
          }

          // Request notification permission and send device token
          await NotificationHandler.requestNotificationPermission();

          // Get the appropriate redirect route based on profile completion
          final authStore = context.read<AuthStore>();
          final redirectRoute = await authStore.getRedirectRoute();
          
          if (mounted) {
            setState(() {
              _isCheckingRoute = false; // Hide loading
            });
            Navigator.pushReplacementNamed(context, redirectRoute);
          }
        }
      },
    );

    print('🍎 Apple Sign-In completed, error: ${authStore.error}');

    // Handle error if success callback wasn't called
    if (authStore.error != null && mounted) {
      ToastService.showWarningToast(context, message: authStore.error!);
    }
  }

  // Google Sign-In handler
  Future<void> _handleGoogleSignIn() async {
    print('🔍 Google Sign-In button pressed!');

    final authStore = context.read<AuthStore>();
    print('🔍 AuthStore loaded: ${authStore.isLoading}');

    await authStore.loginWithGoogle(
      onSuccess: () async {
        print('🔍 Existing user - redirecting to appropriate route');

        if (mounted) {
          setState(() {
            _isCheckingRoute = true; // Show loading while checking route
          });

          ToastService.showSuccessToast(context, message: 'Welcome back!');

          // Request notification permission and send device token
          await NotificationHandler.requestNotificationPermission();

          // Get the appropriate redirect route based on profile completion
          final authStore = context.read<AuthStore>();
          final redirectRoute = await authStore.getRedirectRoute();
          
          if (mounted) {
            setState(() {
              _isCheckingRoute = false; // Hide loading
            });
            Navigator.pushReplacementNamed(context, redirectRoute);
          }
        }
      },
      onNewUser: () async {
        print('🔍 Profile incomplete - redirecting to appropriate step');

        if (mounted) {
          setState(() {
            _isCheckingRoute = true; // Show loading while checking route
          });

          ToastService.showSuccessToast(
            context,
            message: 'Welcome! Let\'s complete your profile',
          );

          // Save "first" variable to localStorage as true for new users
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('first', true);
          } catch (e) {
            // Error saving first variable
          }

          // Request notification permission and send device token
          await NotificationHandler.requestNotificationPermission();

          // Get the appropriate redirect route based on profile completion
          final authStore = context.read<AuthStore>();
          final redirectRoute = await authStore.getRedirectRoute();
          
          if (mounted) {
            setState(() {
              _isCheckingRoute = false; // Hide loading
            });
            Navigator.pushReplacementNamed(context, redirectRoute);
          }
        }
      },
    );

    print('🔍 Google Sign-In completed, error: ${authStore.error}');

    // Handle error if success callback wasn't called
    if (authStore.error != null && mounted) {
      ToastService.showWarningToast(context, message: authStore.error!);
    }
  }

  Future<void> _handleEmailRegister() async {
    if (!_isAgree) {
      setState(() {
        _termsError = 'You must accept the Terms of Use.';
      });
      ToastService.showWarningToast(
        context,
        message: 'You must accept the Terms of Use.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authStore = context.read<AuthStore>();
    await authStore.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      onSuccess: () async {
        if (mounted) {
          setState(() {
            _isCheckingRoute = true; // Show loading while checking route
          });
        }

        // Save "first" variable to localStorage as true for new users
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('first', true);
        } catch (e) {
          // Error saving first variable
        }

        // Request notification permission and send device token
        await NotificationHandler.requestNotificationPermission();

        if (mounted) {
          // Get the appropriate redirect route based on profile completion
          final authStore = context.read<AuthStore>();
          final redirectRoute = await authStore.getRedirectRoute();
          
          if (mounted) {
            setState(() {
              _isCheckingRoute = false; // Hide loading
            });
            Navigator.pushReplacementNamed(context, redirectRoute);
          }
        }
      },
    );

    // Handle errors from authStore
    if (authStore.error != null && mounted) {
      ToastService.showErrorToast(context, message: authStore.error!);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
    VoidCallback? onSuffixTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        textInputAction: label == 'First name'
            ? TextInputAction.next
            : label == 'Last name'
            ? TextInputAction.next
            : label == 'Email address'
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted: label == 'First name'
            ? (_) => FocusScope.of(context).nextFocus()
            : label == 'Last name'
            ? (_) => FocusScope.of(context).nextFocus()
            : label == 'Email address'
            ? (_) => FocusScope.of(context).nextFocus()
            : (_) => FocusScope.of(context).unfocus(),
        keyboardType: label == 'Email address'
            ? TextInputType.emailAddress
            : label == 'Password'
            ? TextInputType.visiblePassword
            : TextInputType.text,
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: Colors.white,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: LoginPageStyles.subtitleStyle.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: LoginPageStyles.subtitleStyle.copyWith(
            color: Color(0xFFDCE6F0),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          filled: true,
          fillColor: LoginPageStyles.translucentBackground,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          isDense: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: LoginPageStyles.borderColor,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: LoginPageStyles.borderColor,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: LoginPageStyles.borderColor,
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          suffixIcon: suffixIcon != null
              ? GestureDetector(onTap: onSuffixTap, child: suffixIcon)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStore>(
      builder: (context, authStore, child) {
        return PopScope(
          canPop: false, // Back button ni o'chirish
          child: Builder(
            builder: (context) {
              // Handle authStore errors
              if (authStore.error != null && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ToastService.showErrorToast(
                    context,
                    message: authStore.error!,
                  );
                  authStore.clearError();
                });
              }
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: KeyboardVisibilityBuilder(
                    controller: KeyboardVisibilityController(),
                    builder: (context, isKeyboardVisible) {
                      return GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: StarsAnimation()),
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  bottom: 0,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        padding: EdgeInsets.only(
                                          bottom: isKeyboardVisible ? 20 : 0,
                                        ),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  const SizedBox(height: 24),
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.arrow_back,
                                                          color:
                                                              BaseStyles.white,
                                                          size: 30,
                                                        ),
                                                        onPressed: () {
                                                          // Check if there's a previous route
                                                          if (Navigator.of(
                                                            context,
                                                          ).canPop()) {
                                                            Navigator.of(
                                                              context,
                                                            ).pushReplacementNamed(
                                                              '/login',
                                                            );
                                                            // Navigator.of(context).pop();
                                                          } else {
                                                            // If no previous route, navigate to onboarding
                                                            Navigator.of(
                                                              context,
                                                            ).pushReplacementNamed(
                                                              '/login',
                                                            );
                                                          }
                                                        },
                                                      ),
                                                      Expanded(
                                                        child: Center(
                                                          child: SvgPicture.asset(
                                                            'assets/icons/logo.svg',
                                                            width: 60,
                                                            height: 40,
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.info_outline,
                                                          color:
                                                              BaseStyles.white,
                                                          size: 30,
                                                        ),
                                                        onPressed: () {
                                                          openPopupFromTop(
                                                            context,
                                                            const HowWorkModal(),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.height *
                                                        0.125,
                                                  ),
                                                  Center(
                                                    child: Text(
                                                      'Create an account',
                                                      style: TextStyle(
                                                        fontFamily: 'Canela',
                                                        fontSize: 36.sp,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Center(
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        Navigator.pushNamed(
                                                          context,
                                                          '/login',
                                                        );
                                                      },
                                                      child: RichText(
                                                        text: TextSpan(
                                                          text:
                                                              "Already have an account? ",
                                                          style: TextStyle(
                                                            fontSize: 16.sp,
                                                            color: Color(
                                                              0xFFF2EFEA,
                                                            ),
                                                            fontFamily:
                                                                'Satoshi',
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                              text: 'Sign in',
                                                              style: TextStyle(
                                                                fontSize: 16.sp,
                                                                color: Colors
                                                                    .white,
                                                                fontFamily:
                                                                    'Satoshi',
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 36),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: _buildTextField(
                                                          label: 'First name',
                                                          controller:
                                                              _firstNameController,
                                                          validator: (value) =>
                                                              Validators.validateRequired(
                                                                value,
                                                                'First name',
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 12,
                                                      ), // небольшой отступ между полями
                                                      Expanded(
                                                        child: _buildTextField(
                                                          label: 'Last name',
                                                          controller:
                                                              _lastNameController,
                                                          validator: (value) =>
                                                              Validators.validateRequired(
                                                                value,
                                                                'Last name',
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  _buildTextField(
                                                    label: 'Email address',
                                                    controller:
                                                        _emailController,
                                                    validator: Validators
                                                        .validateEmail,
                                                  ),
                                                  _buildTextField(
                                                    label: 'Password',
                                                    controller:
                                                        _passwordController,
                                                    obscure: _obscurePassword,
                                                    validator: Validators
                                                        .validatePassword,
                                                    suffixIcon: Icon(
                                                      _obscurePassword
                                                          ? Icons.visibility
                                                          : Icons
                                                                .visibility_off,
                                                      color: Color(0xFFF2EFEA),
                                                    ),
                                                    onSuffixTap: () {
                                                      setState(() {
                                                        _obscurePassword =
                                                            !_obscurePassword;
                                                      });
                                                    },
                                                  ),

                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    height: 60,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF3C6EAB,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                30,
                                                              ),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      onPressed:
                                                          (authStore.isLoading || _isCheckingRoute)
                                                          ? null
                                                          : _handleEmailRegister,
                                                      child: (authStore.isLoading || _isCheckingRoute)
                                                          ? const SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                      Color
                                                                    >(
                                                                      BaseStyles
                                                                          .cream,
                                                                    ),
                                                              ),
                                                            )
                                                          : const Text(
                                                              'Continue with Email',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color:
                                                                    BaseStyles
                                                                        .cream,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontFamily:
                                                                    'Satoshi',
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  // Divider with "or continue with" text
                                                  Center(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                          ),
                                                      child: Text(
                                                        '- or continue with -',
                                                        style: TextStyle(
                                                          color: const Color(
                                                            0xFFF2EFEA,
                                                          ),
                                                          fontSize: 16,
                                                          fontFamily: 'Satoshi',
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  // Social Sign-In Buttons in a row
                                                  Row(
                                                    children: [
                                                      // Google Sign-In Button
                                                      Expanded(
                                                        child: GoogleSignInButton(
                                                          onPressed:
                                                              _handleGoogleSignIn,
                                                          isLoading: authStore.isLoading || _isCheckingRoute,
                                                        ),
                                                      ),
                                                      if (Platform.isIOS) ...[
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        // Apple Sign-In Button (iOS only)
                                                        Expanded(
                                                          child: AppleSignInButton(
                                                            onPressed:
                                                                _handleAppleSignIn,
                                                            isLoading: authStore.isLoading || _isCheckingRoute,
                                                            text:
                                                                '', // Icon only
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 0),
                                                  const SizedBox(height: 0),
                                                ],
                                              ),
                                              SizedBox(
                                                height: isKeyboardVisible
                                                    ? 20
                                                    : MediaQuery.of(
                                                            context,
                                                          ).size.height *
                                                          0.2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isKeyboardVisible)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 40,
                                child: Center(child: const TermsAgreement()),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void openPopupFromTop(BuildContext context, Widget child) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withAlpha((0.3 * 255).toInt()),
        pageBuilder: (_, __, ___) => child,
        transitionsBuilder: (_, animation, __, child) {
          final offsetAnimation =
              Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
}
