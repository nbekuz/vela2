// To'lov tizimi sahifasi - comment qilindi
/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../styles/pages/plan_page_styles.dart';
import 'components/plan_switch.dart';
import 'components/plan_info_card.dart';
import '../shared/widgets/auth.dart';
import '../shared/widgets/exit_confirmation_dialog.dart';
import '../shared/widgets/custom_toast.dart';
import '../core/services/storekit_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum PlanStep { choosePlan, dreamLifeIntro }

enum PlanType { annual, monthly }

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  PlanStep _currentStep = PlanStep.choosePlan;
  PlanType _selectedPlan = PlanType.annual;
  
  // StoreKit product IDs
  static const String _monthlyProductId = 'com.nbekdev.vela';
  static const String _annualProductId = 'com.nbekdev.vela.pro.year';
  
  // Purchase stream subscription
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _setupPurchaseListener();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _setupPurchaseListener() {
    final InAppPurchase inAppPurchase = InAppPurchase.instance;
    _purchaseSubscription = inAppPurchase.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdate(purchaseDetailsList);
      },
      onDone: () {
        print('✅ Purchase stream closed');
      },
      onError: (error) {
        print('❌ Purchase stream error: $error');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase error: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print('⏳ Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Purchase error: ${purchaseDetails.error}');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
          // Show custom toast from top
          final errorMessage = purchaseDetails.error?.message ?? 'Purchase failed';
          if (purchaseDetails.error?.code == 'user_cancelled') {
            // Don't show error toast for user cancellation
            print('ℹ️ User cancelled the purchase');
          } else {
            ToastService.showErrorToast(
              context,
              message: errorMessage,
            );
          }
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        print('✅ Purchase successful: ${purchaseDetails.productID}');
        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        // Navigate to next step
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
          _goToNextStep();
        }
      }
      
      // Complete the purchase if pending
      if (purchaseDetails.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _startFreeTrialWithStoreKit() async {
    if (_isPurchasing) {
      print('⚠️ Purchase already in progress');
      return;
    }

    try {
      setState(() {
        _isPurchasing = true;
      });

      final storeKitService = StoreKitService();
      
      // Determine product ID based on selected plan
      final productId = _selectedPlan == PlanType.annual
          ? _annualProductId
          : _monthlyProductId;

      print('🔵 Starting free trial with StoreKit');
      print('🔵 Selected plan: ${_selectedPlan == PlanType.annual ? "Annual" : "Monthly"}');
      print('🔵 Product ID: $productId');

      // Get products from StoreKit
      final products = await storeKitService.getProducts({productId});

      if (products.isEmpty) {
        // More user-friendly error message for simulator/StoreKit errors
        throw Exception('Product not found: $productId');
      }

      final productDetails = products.first;
      print('✅ Found product: ${productDetails.title} - ${productDetails.price}');

      // Purchase the product
      await storeKitService.purchaseProduct(productDetails);
      
      print('✅ Purchase initiated successfully');
      // Purchase completion will be handled by _handlePurchaseUpdate
    } catch (e) {
      print('❌ Error starting free trial: $e');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
        // Show custom toast with specific error messages
        String errorMessage;
        final errorString = e.toString().toLowerCase();
        
        // Handle different error scenarios
        if (errorString.contains('storekit_no_response') || 
            errorString.contains('storekit error: storekit_no_response')) {
          // Simulator or network issue - usually won't happen in TestFlight
          errorMessage = 'Unable to connect to App Store. Please check your internet connection and try again.';
        } else if (errorString.contains('product not found') || 
                   errorString.contains('notfoundids')) {
          // Product not configured in App Store Connect - should not happen in TestFlight if configured correctly
          errorMessage = 'Subscription product not available. Please contact support.';
        } else if (errorString.contains('storekit')) {
          errorMessage = 'App Store connection issue. Please try again later.';
        } else {
          errorMessage = 'Failed to start free trial. Please try again.';
        }
        
        ToastService.showErrorToast(
          context,
          message: errorMessage,
        );
      }
    }
  }

  void _goToNextStep() {
    setState(() {
      _currentStep = PlanStep.dreamLifeIntro;
    });
  }

  void _showExitDialog() {
    ExitConfirmationDialog.show(
      context,
      title: 'Exit Plan Selection?',
      message: 'Are you sure you want to exit? You can always come back to select your plan later.',
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    Widget? subtitle;
    Widget child;
    VoidCallback? onBack;

    switch (_currentStep) {
      case PlanStep.choosePlan:
        title = 'Choose your plan';
        subtitle = Column(
          children: [
            Column(
              children: [
                Text(
                  _selectedPlan == PlanType.annual
                      ? 'First 3 days free, then \$49/year (\$4.08/month)'
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
              ],
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: PlanSwitch(
                  selected: _selectedPlan,
                  onChanged: (plan) => setState(() => _selectedPlan = plan),
                ),
              ),
            ),
          ],
        );
        child = Column(
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
                    _selectedPlan == PlanType.annual
                        ? '\$49/year'
                        : '\$9.99/month',
                    style: PlanPageStyles.price,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedPlan == PlanType.annual
                        ? '(\$4.08/month)'
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
                onPressed: _isPurchasing ? null : () async {
                  // Use StoreKit to purchase subscription
                  await _startFreeTrialWithStoreKit();
                },
                child: _isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF2EFEA)),
                        ),
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
            const SizedBox(height: 20),
            // Promo code entry button
            TextButton(
              onPressed: () async {
                try {
                  final storeKitService = StoreKitService();
                  await storeKitService.presentCodeRedemptionSheet();
                } catch (e) {
                  print('❌ Error presenting promo code sheet: $e');
                  ToastService.showErrorToast(
                    context,
                    message: 'Unable to open promo code redemption. Please try again.',
                  );
                }
              },
              child: Text(
                'Have a promo code?',
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
        onBack = _showExitDialog;
        break;
      case PlanStep.dreamLifeIntro:
        title = '';
        subtitle = null;
        child = LayoutBuilder(
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
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/generator');
                        },
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
        onBack = _showExitDialog;
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: AuthScaffold(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        showTerms: _currentStep == PlanStep.choosePlan,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 50),
        child: child,
      ),
    );
  }
}
*/
