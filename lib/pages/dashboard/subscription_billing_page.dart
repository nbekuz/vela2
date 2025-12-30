// To'lov tizimi va to'lovni tekshirish API'si bilan bog'liq sahifa - comment qilindi
/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../shared/widgets/stars_animation.dart';

class SubscriptionBillingPage extends StatelessWidget {
  const SubscriptionBillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const StarsAnimation(
              starCount: 20,
              topColor: const Color(0xFF3C6EAB),
              bottomColor: const Color(0xFFA4C6EB),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 30),
                  Text(
                    'Subscription & Billing',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 242, 239, 234),
                      fontSize: 36.sp,
                      fontFamily: 'Canela',
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30.sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Plan',
                            style: TextStyle(
                              color: const Color.fromARGB(255, 242, 239, 234),
                              fontSize: 24.sp,
                              fontFamily: 'Canela',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.sp),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Free Plan',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      242,
                                      239,
                                      234,
                                    ),
                                    fontSize: 20.sp,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Access to basic meditation features',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      242,
                                      239,
                                      234,
                                    ),
                                    fontSize: 14.sp,
                                    fontFamily: 'Satoshi',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          //  const SizedBox(height: 32),
                          //  Text(
                          //    'Upgrade Options',
                          //    style: TextStyle(
                          //      color: const Color.fromARGB(255, 242, 239, 234),
                          //      fontSize: 24.sp,
                          //      fontFamily: 'Canela',
                          //      fontWeight: FontWeight.w300,
                          //    ),
                          //  ),
                          //  const SizedBox(height: 16),
                          //  Container(
                          //    width: double.infinity,
                          //    padding: EdgeInsets.all(20.sp),
                          //    decoration: BoxDecoration(
                          //      color: Colors.white.withValues(alpha: 0.1),
                          //      borderRadius: BorderRadius.circular(16),
                          //      border: Border.all(
                          //        color: Colors.white.withValues(alpha: 0.2),
                          //        width: 1,
                          //      ),
                          //    ),
                          //    child: Column(
                          //      crossAxisAlignment: CrossAxisAlignment.start,
                          //      children: [
                          //        Text(
                          //          'Premium Plan',
                          //          style: TextStyle(
                          //            color: const Color.fromARGB(
                          //              255,
                          //              242,
                          //              239,
                          //              234,
                          //            ),
                          //            fontSize: 20.sp,
                          //            fontFamily: 'Satoshi',
                          //            fontWeight: FontWeight.w600,
                          //          ),
                          //        ),
                          //        const SizedBox(height: 8),
                          //        Text(
                          //          'Unlimited access to all features',
                          //          style: TextStyle(
                          //            color: const Color.fromARGB(
                          //              255,
                          //              242,
                          //              239,
                          //              234,
                          //            ),
                          //            fontSize: 14.sp,
                          //            fontFamily: 'Satoshi',
                          //            fontWeight: FontWeight.w400,
                          //          ),
                          //        ),
                          //        const SizedBox(height: 12),
                          //        Text(
                          //          '\$9.99/month',
                          //          style: TextStyle(
                          //            color: const Color(0xFF3B6EAA),
                          //            fontSize: 18.sp,
                          //            fontFamily: 'Satoshi',
                          //            fontWeight: FontWeight.w700,
                          //          ),
                          //        ),
                          //      ],
                          //    ),
                          //  ),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.sp, 8.sp, 16.sp, 0.sp),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(3, 0),
            child: Image.asset('assets/img/logo.png', width: 60, height: 39),
          ),
          Container(
            width: 36,
            height: 36,
            child: const Icon(
              Icons.settings,
              color: Colors.transparent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
*/
