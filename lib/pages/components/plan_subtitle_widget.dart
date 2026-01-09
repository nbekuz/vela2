import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../styles/pages/plan_page_styles.dart';
import 'plan_switch.dart';
import '../plan_page.dart'; // Import PlanType from plan_page.dart

class PlanSubtitleWidget extends StatelessWidget {
  final PlanType selectedPlan;
  final ValueChanged<PlanType> onPlanChanged;

  const PlanSubtitleWidget({
    super.key,
    required this.selectedPlan,
    required this.onPlanChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          children: [
            Text(
              selectedPlan == PlanType.annual
                  ? 'First 3 days free, then \$49.99/year (\$4.17/month)'
                  : 'First 3 days free, then \$9.99/month (\$120/year)',
              style: PlanPageStyles.priceSub,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Free trial available. Subscription required to continue.',
              style: PlanPageStyles.priceSub.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'After trial you will be charged automatically. Cancel anytime in Settings.',
              style: PlanPageStyles.priceSub.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: PlanSwitch(
              selected: selectedPlan,
              onChanged: onPlanChanged,
            ),
          ),
        ),
      ],
    );
  }
}

