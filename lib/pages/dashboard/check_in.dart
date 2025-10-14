import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../shared/widgets/stars_animation.dart';
import '../../shared/widgets/full_width_track_shape.dart';
import '../../shared/widgets/info_dashboard_modal.dart';
import '../../core/stores/check_in_store.dart';
import '../../core/stores/auth_store.dart';
// import '../generator/generator_page.dart';
import '../generator/direct_ritual_page.dart';
import 'main.dart';

class DashboardCheckInPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const DashboardCheckInPage({this.onBackPressed, super.key});

  @override
  State<DashboardCheckInPage> createState() => _DashboardCheckInPageState();
}

class _DashboardCheckInPageState extends State<DashboardCheckInPage> {
  double _sliderValue = 0.5;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load user details when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authStore = Provider.of<AuthStore>(context, listen: false);

      authStore.getUserDetails();
    });
  }

  bool _hasCheckedInToday() {
    final authStore = Provider.of<AuthStore>(context, listen: false);
    final user = authStore.user;

    // If user has any check-ins, consider them as already checked in
    if (user == null || user.checkIns.isEmpty) {
      return false;
    }

    // Return true if checkIns array has any length greater than 0
    return user.checkIns.isNotEmpty;
  }

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
        Navigator.of(context).pushReplacementNamed('/dashboard');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Close keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            const StarsAnimation(),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0.sp, // left
                    0.sp, // top
                    0.sp, // right
                    0.sp, // bottom
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.sp, 8.sp, 16.sp, 0.sp),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Back arrow in a circle, size 24x24
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    if (widget.onBackPressed != null) {
                                      widget.onBackPressed!();
                                    } else {
                                      // Check if there's a previous page to go back to
                                      final dashboardState = context
                                          .findAncestorStateOfType<
                                            DashboardMainPageState
                                          >();
                                      if (dashboardState != null) {
                                        // If previous index is the same as current (no previous page), go to home
                                        if (dashboardState.previousIndex ==
                                            dashboardState.selectedIndex) {
                                          dashboardState.navigateToHome();
                                        } else {
                                          // Go back to previous page
                                          dashboardState.navigateBack();
                                        }
                                      } else {
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/dashboard');
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(
                                3,
                                0,
                              ), // ← сдвиг вправо на 10 пикселей
                              child: Image.asset(
                                'assets/img/logo.png',
                                width: 60,
                                height: 39,
                              ),
                            ),
                            // Info icon on the right, size 24x24
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (BuildContext context) {
                                    return const InfoDashboardModal();
                                  },
                                );
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Title
                      Text(
                        'Daily Check-In ',
                        style: TextStyle(
                          fontFamily: 'Canela',
                          fontSize: 36.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect with your inner journey today',
                        style: TextStyle(
                          color: Color(0xFFDCE6F0),
                          fontFamily: 'Satoshi',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 26),
                      // Card
                      Container(
                        margin: EdgeInsets.only(
                          top: _hasCheckedInToday()
                              ? (MediaQuery.of(context).size.height - 500) / 2
                              : 20,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Consumer<AuthStore>(
                            builder: (context, authStore, child) {
                              // Show loading state while user data is being fetched
                              if (authStore.isLoading ||
                                  authStore.user == null) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }

                              final hasCheckedInToday = _hasCheckedInToday();

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    if (hasCheckedInToday) ...[
                                      const Text(
                                        'You have already checked in today',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      // Generate New Meditation Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pushReplacement(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const DirectRitualPage(),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            side: BorderSide.none,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Text(
                                                'Generate New Meditation',
                                                style: TextStyle(
                                                  color: Color(0xFF3B6EAA),
                                                  fontSize: 16,
                                                  fontFamily: 'Satoshi',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.auto_awesome,
                                                color: Color(0xFF3B6EAA),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else ...[
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
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Dynamic mood image
                                      Image.asset(
                                        _getMoodImage(_sliderValue),
                                        width: 48,
                                        height: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _getMoodText(_sliderValue),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Satoshi',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Slider
                                      SizedBox(
                                        width: double.infinity,
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 8,
                                            activeTrackColor: Color(0xFFC9DFF4),
                                            inactiveTrackColor: Color(
                                              0xFFC9DFF4,
                                            ),
                                            thumbColor: Color(0xFF3B6EAA),
                                            overlayColor: Colors.white24,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 7.5,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 20,
                                                ),
                                            trackShape:
                                                const FullWidthTrackShape(),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                          fontSize: 14.sp,
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 100,
                                        child: TextFormField(
                                          controller: _descriptionController,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.sp,
                                            fontFamily: 'Satoshi',
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText:
                                                'I\'m overwhelmed about my test — I need help calming down.',
                                            hintStyle: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12.sp,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: Color.fromRGBO(
                                                  21,
                                                  43,
                                                  86,
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: Color.fromRGBO(
                                                  21,
                                                  43,
                                                  86,
                                                  0.3,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(16),
                                            fillColor: Color.fromRGBO(
                                              21,
                                              43,
                                              86,
                                              0.1,
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
                                                      _handleCheckIn(
                                                        context,
                                                        checkInStore,
                                                      );
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF3B6EAA,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(32),
                                                ),
                                              ),
                                              child: checkInStore.isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Complete Check-In ',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontFamily: 'Satoshi',
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                      // const SizedBox(height: 12),
                                      // // Generate New Meditation Button
                                      // SizedBox(
                                      //   width: double.infinity,
                                      //   height: 56,
                                      //   child: OutlinedButton(
                                      //     onPressed: () {
                                      //       Navigator.of(
                                      //         context,
                                      //       ).pushReplacement(
                                      //         MaterialPageRoute(
                                      //           builder: (context) =>
                                      //               const DirectRitualPage(),
                                      //         ),
                                      //       );
                                      //     },
                                      //     style: OutlinedButton.styleFrom(
                                      //       backgroundColor: Colors.white,
                                      //       side: BorderSide.none,
                                      //       shape: RoundedRectangleBorder(
                                      //         borderRadius:
                                      //             BorderRadius.circular(32),
                                      //       ),
                                      //     ),
                                      //     child: Row(
                                      //       mainAxisAlignment:
                                      //           MainAxisAlignment.center,
                                      //       children: const [
                                      //         Text(
                                      //           'Generate New Meditation',
                                      //           style: TextStyle(
                                      //             color: Color(0xFF3B6EAA),
                                      //             fontSize: 16,
                                      //             fontFamily: 'Satoshi',
                                      //             fontWeight: FontWeight.bold,
                                      //           ),
                                      //         ),
                                      //         SizedBox(width: 8),
                                      //         Icon(
                                      //           Icons.auto_awesome,
                                      //           color: Color(0xFF3B6EAA),
                                      //         ),
                                      //       ],
                                      //     ),
                                      //   ),
                                      // ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
