import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../styles/pages/plan_page_styles.dart';

class DreamLifeIntroWidget extends StatelessWidget {
  final VoidCallback onContinue;

  const DreamLifeIntroWidget({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final headerHeight = 200.0; // Header balandligi (logo + padding)
        final bottomPadding = 40.0; // Pastki padding (Terms uchun)
        final contentHeight = screenHeight - headerHeight - bottomPadding;
        final topPadding =
            contentHeight / 2 - 220; // Content balandligi taxminan 300px

        return Center(
          child: Container(
            padding: EdgeInsets.fromLTRB(10, topPadding, 10, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set sail to your dream life',
                  style: PlanPageStyles.pageTitle.copyWith(
                    fontSize: 34.sp,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  child: Text(
                    'We will set up your profile based on your answers to generate your customized manifesting meditation experience, grounded in neuroscience, and tailored to you.',
                    style: PlanPageStyles.cardBody.copyWith(
                      fontSize: 15.sp,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C6EAB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onContinue,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue to Dream Life Intake',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF2EFEA),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

