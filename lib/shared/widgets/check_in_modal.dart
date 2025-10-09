import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/app_styles.dart';
import '../../core/stores/check_in_store.dart';
import '../../core/stores/auth_store.dart';
import '../../shared/widgets/full_width_track_shape.dart';

class CheckInModal extends StatefulWidget {
  final VoidCallback? onClose;
  const CheckInModal({super.key, this.onClose});

  @override
  State<CheckInModal> createState() => _CheckInModalState();
}

class _CheckInModalState extends State<CheckInModal> {
  double _sliderValue = 0.5;
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descriptionFocusNode = FocusNode();

  String _getMoodText(double value) {
    if (value <= 0.20) {
      return 'Bad';
    } else if (value <= 0.40) {
      return 'Not Great';
    } else if (value <= 0.60) {
      return 'Neutral';
    } else if (value <= 0.80) {
      return 'Good';
    } else {
      return 'Excellent';
    }
  }

  String _getCheckInChoice(double value) {
    if (value <= 0.40) {
      return 'struggling';
    } else if (value <= 0.80) {
      return 'neutral';
    } else {
      return 'excellent';
    }
  }

  String _getMoodImage(double value) {
    if (value <= 0.20) {
      return 'assets/img/struggling.png'; // Bad
    } else if (value <= 0.40) {
      return 'assets/img/notgreat.png'; // Not Great
    } else if (value <= 0.60) {
      return 'assets/img/planet.png'; // Neutral
    } else if (value <= 0.80) {
      return 'assets/img/good.png'; // Good
    } else {
      return 'assets/img/excellent.png'; // Excellent
    }
  }

  void _handleCheckIn(BuildContext context, CheckInStore checkInStore) {
    final checkInChoice = _getCheckInChoice(_sliderValue);
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a description',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFF2EFEA),
        textColor: const Color(0xFF3B6EAA),
      );
      return;
    }

    final authStore = Provider.of<AuthStore>(context, listen: false);

    checkInStore.submitCheckIn(
      checkInChoice: checkInChoice,
      description: description,
      authStore: authStore,
      onSuccess: () {
        Navigator.of(context).pop(); // Close modal
      },
    );
  }

  static String _formattedDate() {
    final now = DateTime.now();
    return '${_weekday(now.weekday)}, ${now.month}/${now.day}/${now.year}';
  }

  static String _weekday(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth = MediaQuery.of(context).size.width * 0.9;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double availableHeight = screenHeight - keyboardHeight;

    // Calculate max height: 80% of available height when keyboard is open, 80% of screen when closed
    final double maxHeight = keyboardHeight > 0
        ? availableHeight * 0.8 - 100
        : screenHeight * 0.8;

    return GestureDetector(
      onTap: () {
        // Close keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Center(child: _buildModalContent(modalWidth, maxHeight)),
    );
  }

  Widget _buildModalContent(double modalWidth, double maxHeight) {
    return ClipRRect(
      borderRadius: AppStyles.radiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: modalWidth,
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: AppStyles.paddingModal,
            decoration: AppStyles.frostedGlass,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with back button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppStyles.white,
                          size: 28,
                        ),
                        onPressed:
                            widget.onClose ?? () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Daily Check-In',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Canela',
                            fontSize: 36.sp,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 0,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 0),

                  // Subtitle
                  Text(
                    'Connect with your inner journey today',
                    style: TextStyle(
                      color: Color(0xFFDCE6F0),
                      fontFamily: 'Satoshi',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Check-in form
                  const Text(
                    'How are you feeling today?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formattedDate(),
                    style: const TextStyle(
                      color: Color(0xFFDCE6F0),
                      fontSize: 14,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dynamic mood image
                  Image.asset(
                    _getMoodImage(_sliderValue),
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 0),
                  Text(
                    _getMoodText(_sliderValue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 0),

                  // Slider
                  SizedBox(
                    width: double.infinity,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        activeTrackColor: Color(0xFFC9DFF4),
                        inactiveTrackColor: Color(0xFFC9DFF4),
                        thumbColor: Color(0xFF3B6EAA),
                        overlayColor: Colors.white24,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7.5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        trackShape: const FullWidthTrackShape(),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        onChanged: (v) {
                          setState(() {
                            _sliderValue = v;
                          });
                        },
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Bad',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Not Great',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Neutral',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Good',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Excellent',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'How can Vela support you in this exact moment?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text field with explicit tap handling
                  GestureDetector(
                    onTap: () {
                      _descriptionFocusNode.requestFocus();
                    },
                    child: AbsorbPointer(
                      absorbing: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: TextFormField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocusNode,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLines: 3,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText:
                                'I\'m overwhelmed about my test — I need help calming down.',
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.sp,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(21, 43, 86, 0.3),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(21, 43, 86, 0.3),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            fillColor: Color.fromRGBO(21, 43, 86, 0.1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Complete Check-In Button
                  Consumer<CheckInStore>(
                    builder: (context, checkInStore, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: checkInStore.isLoading
                              ? null
                              : () {
                                  _handleCheckIn(context, checkInStore);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B6EAA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: checkInStore.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Complete Check-In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Satoshi',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
