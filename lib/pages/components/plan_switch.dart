import 'package:flutter/material.dart';
import '../../styles/pages/plan_page_styles.dart';
import '../plan_page.dart';

class PlanSwitch extends StatelessWidget {
  final PlanType selected;
  final ValueChanged<PlanType> onChanged;

  const PlanSwitch({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: PlanPageStyles.pillBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PlanPageStyles.pillBorder, width: 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Expanded(
                child: PlanSwitchButton(
                  text: 'Annual',
                  selected: selected == PlanType.annual,
                  onTap: () => onChanged(PlanType.annual),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PlanSwitchButton(
                  text: 'Monthly',
                  selected: selected == PlanType.monthly,
                  onTap: () => onChanged(PlanType.monthly),
                ),
              ),
            ],
          ),
          Positioned(
            top: -15,
            left: 24,
            child: Transform.rotate(
              angle: -5 * 3.1415926535 / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  gradient: PlanPageStyles.badgeBgGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('58% savings', style: PlanPageStyles.badge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanSwitchButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const PlanSwitchButton({super.key, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF3B6EAA) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            text,
            style: PlanPageStyles.pill.copyWith(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}
