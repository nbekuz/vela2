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

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  late KeyboardVisibilityController _keyboardVisibilityController;

  @override
  void initState() {
    super.initState();
    _keyboardVisibilityController = KeyboardVisibilityController();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if passwords match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ToastService.showErrorToast(
        context,
        message: 'Passwords do not match',
      );
      return;
    }

    final authStore = context.read<AuthStore>();
    await authStore.changePassword(
      newPassword: _newPasswordController.text,
      onSuccess: () {
        if (mounted) {
          ToastService.showSuccessToast(
            context,
            message: 'Password changed successfully!',
          );
          
          // Navigate back to edit info page
          Navigator.pop(context);
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
        textInputAction: label == 'New Password'
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted: label == 'New Password'
            ? (_) => FocusScope.of(context).nextFocus()
            : (_) => FocusScope.of(context).unfocus(),
        keyboardType: TextInputType.visiblePassword,
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
                                                      Navigator.pop(context);
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
                                                  'Change Password',
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
                                                  'Enter your new password',
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
                                                label: 'New Password',
                                                controller: _newPasswordController,
                                                obscure: _obscureNewPassword,
                                                validator: Validators.validatePassword,
                                                suffixIcon: Icon(
                                                  _obscureNewPassword
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: Color(0xFFF2EFEA),
                                                ),
                                                onSuffixTap: () {
                                                  setState(() {
                                                    _obscureNewPassword =
                                                        !_obscureNewPassword;
                                                  });
                                                },
                                              ),
                                              _buildTextField(
                                                label: 'Confirm password',
                                                controller: _confirmPasswordController,
                                                obscure: _obscureConfirmPassword,
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return 'Please confirm your password';
                                                  }
                                                  if (value != _newPasswordController.text) {
                                                    return 'Passwords do not match';
                                                  }
                                                  return null;
                                                },
                                                suffixIcon: Icon(
                                                  _obscureConfirmPassword
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: Color(0xFFF2EFEA),
                                                ),
                                                onSuffixTap: () {
                                                  setState(() {
                                                    _obscureConfirmPassword =
                                                        !_obscureConfirmPassword;
                                                  });
                                                },
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
                                                      : _handleChangePassword,
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
                                                          'Change Password',
                                                          style: LoginPageStyles
                                                              .orContinueStyle,
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

