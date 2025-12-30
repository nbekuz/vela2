// import 'package:flutter/material.dart';
// import '../../shared/widgets/auth.dart';
// import '../../styles/pages/plan_page_styles.dart';
// import '../plan_page.dart';
// import 'plan_switch.dart';
// import 'plan_info_card.dart';

// class ChoosePlanStep extends StatelessWidget {
//   final PlanType selectedPlan;
//   final ValueChanged<PlanType> onPlanChanged;
//   final VoidCallback onContinue;

//   const ChoosePlanStep({
//     super.key,
//     required this.selectedPlan,
//     required this.onPlanChanged,
//     required this.onContinue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isAnnual = selectedPlan == PlanType.annual;
//     return AuthScaffold(
//       title: 'Choose your plan',
//       subtitle: Column(
//         children: [
//           Text(
//             isAnnual
//                 ? 'First 3 days free, then \$49/year (\$4.08/month)'
//                 : 'First 3 days free, then \$9.99/month (\$120/year)',
//             style: PlanPageStyles.priceSub,
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: SizedBox(
//               width: double.infinity,
//               child: PlanSwitch(
//                 selected: selectedPlan,
//                 onChanged: onPlanChanged,
//               ),
//             ),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           const SizedBox(height: 24),
//           PlanInfoCard(),
//           const SizedBox(height: 32),
//           Padding(
//             padding: const EdgeInsets.only(top: 0),
//             child: Center(
//               child: Text(
//                 isAnnual ? '\$49/year' : '\$9.99/month',
//                 style: PlanPageStyles.price,
//               ),
//             ),
//           ),
//           Center(
//             child: Text(
//               isAnnual ? '(\$4.08/month)*' : '(\$120/year)',
//               style: PlanPageStyles.priceSub,
//             ),
//           ),
//           const SizedBox(height: 10),
//           SizedBox(
//             width: double.infinity,
//             height: 56,
//             child: ElevatedButton(
//               style: PlanPageStyles.mainButton,
//               onPressed: onContinue,
//               child: const Text(
//                 'Start my free trial',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontFamily: 'Satoshi',
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
