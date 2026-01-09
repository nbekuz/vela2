import 'package:flutter/material.dart';
import '../../styles/pages/plan_page_styles.dart';
import 'plan_info_card.dart';
import '../plan_page.dart'; // Import PlanType from plan_page.dart

class PlanSelectionContent extends StatelessWidget {
  final PlanType selectedPlan;
  final bool isPurchasing;
  final bool isRestoring;
  final Function(PlanType) onPlanChanged;
  final VoidCallback onStartFreeTrial;
  final VoidCallback onRestorePurchases;

  const PlanSelectionContent({
    super.key,
    required this.selectedPlan,
    required this.isPurchasing,
    required this.isRestoring,
    required this.onPlanChanged,
    required this.onStartFreeTrial,
    required this.onRestorePurchases,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        PlanInfoCard(),
        const SizedBox(height: 20),
        // Timeline, matnlar, stepper va h.k.
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                selectedPlan == PlanType.annual
                    ? '\$49.99/year'
                    : '\$9.99/month',
                style: PlanPageStyles.price,
              ),
              const SizedBox(width: 10),
              Text(
                selectedPlan == PlanType.annual
                    ? '(\$4.17/month)'
                    : '(\$120/year)',
                style: PlanPageStyles.priceSub,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3C6EAB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            onPressed: (isPurchasing || isRestoring) ? null : onStartFreeTrial,
            child: isPurchasing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF2EFEA),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing purchase...',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Satoshi',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF2EFEA),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Start my free trial  ',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF2EFEA),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Restore Purchases button - REQUIRED by Apple
        TextButton(
          onPressed: (isPurchasing || isRestoring) ? null : onRestorePurchases,
          child: isRestoring
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Restoring purchases...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Restore Purchases',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

