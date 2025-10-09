import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/stars_animation.dart';
import '../../styles/base_styles.dart';
import '../../styles/pages/login_page_styles.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../core/stores/auth_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late KeyboardVisibilityController _keyboardVisibilityController;

  @override
  void initState() {
    super.initState();
    _keyboardVisibilityController = KeyboardVisibilityController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authStore = context.read<AuthStore>();
    await authStore.forgotPassword(
      email: _emailController.text.trim(),
      onSuccess: () {
        if (mounted) {
          ToastService.showSuccessToast(
            context,
            message: 'New password sent! Please check your email',
          );
          
          // Navigate back to login page
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
    );

    // Handle error if success callback wasn't called
    if (authStore.error != null && mounted) {
      ToastService.showErrorToast(context, message: authStore.error!);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        keyboardType: TextInputType.emailAddress,
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
              color: Color.fromARGB(26, 218, 3, 3),
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
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: KeyboardVisibilityBuilder(
                controller: _keyboardVisibilityController,
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
                              bottom: isKeyboardVisible ? 0 : 0,
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
                                                      color: BaseStyles.white,
                                                      size: 30,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pushReplacementNamed(
                                                        context,
                                                        '/login',
                                                      );
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
                                                  const SizedBox(width: 50), // Balance the back button
                                                ],
                                              ),
                                              SizedBox(
                                                height:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.15,
                                              ),
                                              Center(
                                                child: Text(
                                                  'Forgot password',
                                                  style: LoginPageStyles
                                                      .titleStyle
                                                      .copyWith(
                                                        fontSize: 36.sp,
                                                        color: Colors.white,
                                                      ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Center(
                                                child: Text(
                                                  'Enter your email address and we\'ll send you a new password',
                                                  style: TextStyle(
                                                    fontSize: 16.sp,
                                                    color: Color(0xFFF2EFEA),
                                                    fontFamily: 'Satoshi',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 36),
                                              _buildTextField(
                                                label: 'Email address',
                                                controller: _emailController,
                                                validator:
                                                    Validators.validateEmail,
                                              ),
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                height: 60,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF3C6EAB),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            30,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: authStore.isLoading
                                                      ? null
                                                      : _handleForgotPassword,
                                                  child: authStore.isLoading
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                      : const Text(
                                                          'Send new password',
                                                          style: LoginPageStyles
                                                              .orContinueStyle,
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Center(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Navigator.pushReplacementNamed(
                                                      context,
                                                      '/login',
                                                    );
                                                  },
                                                  child: RichText(
                                                    text: TextSpan(
                                                      text: 'Go back to ',
                                                      style: TextStyle(
                                                        fontSize: 16.sp,
                                                        color: Color(0xFFF2EFEA),
                                                        fontFamily: 'Satoshi',
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: 'login',
                                                          style: TextStyle(
                                                            fontSize: 16.sp,
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
                                              const SizedBox(height: 8),
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
                            child: Center(
                              child: Text(
                                'by using vela',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Color(0xFFF2EFEA),
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
