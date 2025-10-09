import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../shared/widgets/stars_animation.dart';
import '../core/stores/auth_store.dart';
import '../core/services/api_service.dart';
import 'dashboard/components/edit_info_header.dart';
import 'dashboard/components/edit_info_form.dart';
import 'dashboard/components/edit_info_buttons.dart';

class EditInfoPage extends StatefulWidget {
  const EditInfoPage({super.key});

  @override
  State<EditInfoPage> createState() => _EditInfoPageState();
}

class _EditInfoPageState extends State<EditInfoPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedAge = '25-34';
  String _selectedGender = 'Female';

  // Original values for comparison
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalAge = '25-34';
  String _originalGender = 'Female';

  final List<String> _ageOptions = ['18-24', '25-34', '35-44', '45-54', '55+'];
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

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
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;

      // Update selected values from user data
      if (user.ageRange != null) {
        // Convert API age range to UI format
        if (user.ageRange == '55-64') {
          _selectedAge = '55+';
        } else {
          _selectedAge = user.ageRange!;
        }
      }
      if (user.gender != null) {
        _selectedGender = _capitalizeFirst(user.gender!);
      }

      // Save original values
      _originalFirstName = user.firstName;
      _originalLastName = user.lastName;
      _originalAge = _selectedAge;
      _originalGender = _selectedGender;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleAgeChanged(String? value) {
    if (mounted) {
      setState(() {
        _selectedAge = value!;
      });
    }
  }

  void _handleGenderChanged(String? value) {
    if (mounted) {
      setState(() {
        _selectedGender = value!;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      bool hasNameChanges =
          _firstNameController.text != _originalFirstName ||
          _lastNameController.text != _originalLastName;

      bool hasProfileChanges =
          _selectedAge != _originalAge || _selectedGender != _originalGender;

      // Update user details if age or gender changed
      if (hasProfileChanges) {
        await _updateUserDetails();
      }

      // Update user profile if name changed
      if (hasNameChanges) {
        await _updateUserProfile();
      }

      // Refresh user profile data
      final authStore = Provider.of<AuthStore>(context, listen: false);
      await authStore.getUserDetails();

      // Force UI update with new values from API response
      if (mounted) {
        setState(() {
          // Update age range - force update
          _selectedAge = authStore.user?.ageRange ?? _selectedAge;
          // Update gender - force update
          _selectedGender = authStore.user?.gender != null
              ? _capitalizeFirst(authStore.user!.gender!)
              : _selectedGender;
        });
      }

      // Show success toast
      Fluttertoast.showToast(
        msg: 'Profile updated successfully!',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: const Color(0xFFF2EFEA),
        textColor: const Color(0xFF3B6EAA),
      );

      // Navigate back to profile
      Navigator.of(context).pop();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update profile. Please try again.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: const Color(0xFFF2EFEA),
        textColor: const Color(0xFF3B6EAA),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updateUserDetails() async {
    final authStore = Provider.of<AuthStore>(context, listen: false);
    final user = authStore.user;

    // Get existing user detail values
    String existingDream = user?.dream ?? '';
    String existingGoals = user?.goals ?? '';
    String existingHappiness = user?.happiness ?? '';

    final requestData = {
      'gender': _selectedGender.toLowerCase(),
      'age_range': _formatAgeRange(_selectedAge),
      'dream': existingDream,
      'goals': existingGoals,
      'happiness': existingHappiness,
    };

    await ApiService.request(
      url: 'auth/user-detail-update/',
      method: 'PUT',
      data: requestData,
      open: false,
    );
  }

  Future<void> _updateUserProfile() async {
    final requestData = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
    };

    await ApiService.request(
      url: 'auth/user-detail/',
      method: 'PUT',
      data: requestData,
      open: false,
    );
  }

  String _formatAgeRange(String ageRange) {
    // Handle "55+" case
    if (ageRange == '55+') {
      return '55-64';
    }

    try {
      // Extract first number from age range like "18-24" -> 18
      int age = int.parse(ageRange.split('-').first);

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

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back button behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Navigate back to profile page
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
          body: GestureDetector(
            onTap: () {
              // Hide keyboard when tapping outside
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                const StarsAnimation(
                  starCount: 20,
                  topColor: Color(0xFF3C6EAB),
                  bottomColor: Color(0xFFA4C6EB),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const EditInfoHeader(),
                      SizedBox(height: 30.h),
                      Text(
                        'Edit Info',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 242, 239, 234),
                          fontSize: 36.sp,
                          fontFamily: 'Canela',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      SizedBox(height: 30),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Column(
                                  children: [
                                    EditInfoForm(
                                      firstNameController: _firstNameController,
                                      lastNameController: _lastNameController,
                                      emailController: _emailController,
                                      selectedAge: _selectedAge,
                                      selectedGender: _selectedGender,
                                      ageOptions: _ageOptions,
                                      genderOptions: _genderOptions,
                                      onAgeChanged: _handleAgeChanged,
                                      onGenderChanged: _handleGenderChanged,
                                    ),
                                    SizedBox(height: 30),
                                    EditInfoButtons(
                                      isSaving: _isSaving,
                                      onSave: _handleSave,
                                      onChangePassword: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/change-password',
                                        );
                                      },
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                      ),
                    ],
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
