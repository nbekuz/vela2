import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../shared/widgets/stars_animation.dart';
import '../shared/widgets/full_width_track_shape.dart';
import '../core/stores/check_in_store.dart';
import 'dashboard/main.dart';
import 'generator/direct_ritual_page.dart';

class DailyCheckInPage extends StatelessWidget {
  const DailyCheckInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarsAnimation(starCount: 50),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _CheckInAppBar(),
                SizedBox(height: 16),
                Expanded(child: _CheckInForm()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInAppBar extends StatelessWidget {
  const _CheckInAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // растягивает на всю ширину
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Transform.translate(
                offset: const Offset(-10, 0), // -10 по оси X — сдвиг влево
                child: Image.asset(
                  'assets/img/logo.png',
                  height: 32,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.info_outline, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Daily Check-In',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Canela',
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect with your inner journey today' ,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInForm extends StatefulWidget {
  const _CheckInForm();

  @override
  State<_CheckInForm> createState() => _CheckInFormState();
}

class _CheckInFormState extends State<_CheckInForm> {
  double _sliderValue = 0.5; // Default neutral position
  final TextEditingController _descriptionController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Klaviatura yopish uchun focus ni olib tashlash
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'How are you feeling today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedDate(),
                      style: const TextStyle(
                        color: Color(0xFFF2EFEA),
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Dynamic mood image
                    Image.asset(
                      _getMoodImage(_sliderValue),
                      width: 66,
                      height: 66,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getMoodText(_sliderValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 36),
                    const Text(
                      'How can Vela support you in this exact moment?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 100,
                      child: TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'I\'m overwhelmed about my test — I need help calming down.',
                          hintStyle: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                    const SizedBox(height: 32),
                    _CheckInButtons(
                      descriptionController: _descriptionController,
                      sliderValue: _sliderValue,
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
}

class _CheckInButtons extends StatefulWidget {
  final TextEditingController descriptionController;
  final double sliderValue;

  const _CheckInButtons({
    required this.descriptionController,
    required this.sliderValue,
  });

  @override
  State<_CheckInButtons> createState() => _CheckInButtonsState();
}

class _CheckInButtonsState extends State<_CheckInButtons> {
  void _handleCheckIn(BuildContext context, CheckInStore checkInStore) {
    final checkInChoice = _getCheckInChoice(widget.sliderValue);
    final description = widget.descriptionController.text.trim();

    // if (description.isEmpty) {
    //   Fluttertoast.showToast(
    //     msg: 'Please enter a description',
    //     toastLength: Toast.LENGTH_LONG,
    //     gravity: ToastGravity.TOP,
    //     backgroundColor: const Color(0xFFF2EFEA),
    //     textColor: const Color(0xFF3B6EAA),
    //   );
    //   return;
    // }

    checkInStore.submitCheckIn(
      checkInChoice: checkInChoice,
      description: description,
      onSuccess: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardMainPage()),
        );
      },
    );
  }

  String _getCheckInChoice(double value) {
    if (value <= 0.20) {
      return 'struggling';
    } else if (value <= 0.80) {
      return 'neutral';
    } else {
      return 'excellent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckInStore>(
      builder: (context, checkInStore, child) {
        return Column(
          children: [
            SizedBox(
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
                        'Complete Check-In ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const DirectRitualPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    Icon(Icons.auto_awesome, color: Color(0xFF3B6EAA)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
