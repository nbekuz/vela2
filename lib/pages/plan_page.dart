import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../styles/pages/plan_page_styles.dart';
import 'components/plan_switch.dart';
import 'components/plan_info_card.dart';
import '../shared/widgets/auth.dart';
import '../shared/widgets/exit_confirmation_dialog.dart';
import '../shared/widgets/custom_toast.dart';
import '../core/services/storekit_service.dart';
import '../core/services/revenuecat_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum PlanStep { choosePlan, subscriptionSuccess, dreamLifeIntro }

enum PlanType { annual, monthly }

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  PlanStep _currentStep = PlanStep.choosePlan;
  PlanType _selectedPlan = PlanType.annual;
  
  // StoreKit product IDs (from App Store Connect)
  static const String _monthlyProductId = 'com.nbekdev.vela.month';
  static const String _annualProductId = 'com.nbekdev.vela.year';
  
  // Purchase stream subscription (for StoreKit fallback)
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _setupPurchaseListener();
    _setupRevenueCatListener();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _setupRevenueCatListener() {
    final revenueCatService = RevenueCatService();
    if (revenueCatService.isAvailable) {
      // RevenueCat uses listener pattern, not stream
      Purchases.addCustomerInfoUpdateListener((CustomerInfo customerInfo) {
        _handleRevenueCatPurchaseUpdate(customerInfo);
      });
    }
  }

  void _handleRevenueCatPurchaseUpdate(CustomerInfo customerInfo) {
    print('✅ RevenueCat purchase update received');
    
    // Check if user has active entitlement
    final hasActiveEntitlement = customerInfo.entitlements.active.isNotEmpty;
    
    if (hasActiveEntitlement) {
      print('✅ Purchase successful - user has active entitlement');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isRestoring = false;
        });
        
        // Navigate to success screen
        setState(() {
          _currentStep = PlanStep.subscriptionSuccess;
        });
      }
    } else {
      print('⚠️ No active entitlement found');
    }
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
        // Status message removed - loader is shown in button itself
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Purchase error: ${purchaseDetails.error}');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isRestoring = false;
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
        // Navigate to success screen immediately (CRITICAL for Apple review)
        // This shows DARHOL that purchase was successful and subscription is active
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isRestoring = false;
            _currentStep = PlanStep.subscriptionSuccess;
          });
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

      final revenueCatService = RevenueCatService();
      
      // Try RevenueCat first
      if (revenueCatService.isAvailable) {
        print('🔵 Starting free trial with RevenueCat');
        print('🔵 Selected plan: ${_selectedPlan == PlanType.annual ? "Annual" : "Monthly"}');
        
        // Get offerings from RevenueCat with timeout handling
        Offerings? offerings;
        try {
          offerings = await Purchases.getOfferings().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Network timeout: Unable to connect to RevenueCat. Please check your internet connection.');
            },
          );
        } catch (e) {
          if (e.toString().contains('timeout') || e.toString().contains('NETWORK_ERROR')) {
            print('⚠️ RevenueCat network timeout, falling back to StoreKit');
            // Fall through to StoreKit fallback
            offerings = null;
          } else {
            rethrow;
          }
        }
        
        if (offerings == null || offerings.current == null) {
          print('⚠️ No current offering found in RevenueCat, falling back to StoreKit');
          // Fall through to StoreKit fallback below
        } else {

        // Find the package based on selected plan
        Package selectedPackage;
        if (_selectedPlan == PlanType.annual) {
          // Try to find annual package
          try {
            selectedPackage = offerings.current!.availablePackages.firstWhere(
              (package) => package.identifier.contains('annual') || 
                          package.identifier.contains('year') ||
                          package.storeProduct.identifier == _annualProductId,
            );
          } catch (e) {
            // Fallback to first package if not found
            if (offerings.current!.availablePackages.isEmpty) {
              throw Exception('No packages available in RevenueCat offering');
            }
            selectedPackage = offerings.current!.availablePackages.first;
          }
        } else {
          // Try to find monthly package
          try {
            selectedPackage = offerings.current!.availablePackages.firstWhere(
              (package) => package.identifier.contains('month') ||
                          package.storeProduct.identifier == _monthlyProductId,
            );
          } catch (e) {
            // Fallback to first package if not found
            if (offerings.current!.availablePackages.isEmpty) {
              throw Exception('No packages available in RevenueCat offering');
            }
            selectedPackage = offerings.current!.availablePackages.first;
          }
        }

          print('✅ Found package: ${selectedPackage.identifier} - ${selectedPackage.storeProduct.price}');

          // Purchase the package with timeout handling
          try {
            await revenueCatService.purchasePackage(selectedPackage).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Purchase timeout: Please try again.');
              },
            );
            
            print('✅ Purchase initiated successfully with RevenueCat');
            // Purchase completion will be handled by _handleRevenueCatPurchaseUpdate
            return;
          } catch (e) {
            if (e.toString().contains('timeout') || e.toString().contains('NETWORK_ERROR')) {
              print('⚠️ RevenueCat purchase timeout, falling back to StoreKit');
              // Fall through to StoreKit fallback
            } else {
              rethrow;
            }
          }
        }
      }

      // Fallback to StoreKit if RevenueCat is not available
      print('⚠️ RevenueCat not available, falling back to StoreKit');
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
        
        String errorMessage = 'Failed to start free trial. Please try again.';
        
        // Handle specific error types
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('user_cancelled')) {
          print('ℹ️ User cancelled the purchase');
          return; // Don't show error for cancellation
        } else if (errorString.contains('timeout') || errorString.contains('network_error')) {
          errorMessage = 'Network timeout. Please check your internet connection and try again.';
        } else if (errorString.contains('no current offering') || errorString.contains('no packages')) {
          errorMessage = 'Subscription not available. Please try again later.';
        }
        
        ToastService.showErrorToast(
          context,
          message: errorMessage,
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring || _isPurchasing) {
      print('⚠️ Restore already in progress');
      return;
    }

    try {
      setState(() {
        _isRestoring = true;
      });

      final revenueCatService = RevenueCatService();
      
      // Try RevenueCat first
      if (revenueCatService.isAvailable) {
        print('🔵 Restoring purchases with RevenueCat');
        final customerInfo = await revenueCatService.restorePurchases();
        
        // Check if restore was successful
        if (customerInfo.entitlements.active.isNotEmpty || 
            customerInfo.activeSubscriptions.isNotEmpty) {
          print('✅ Purchases restored successfully');
          if (mounted) {
            setState(() {
              _isRestoring = false;
            });
            // Navigate to success screen
            setState(() {
              _currentStep = PlanStep.subscriptionSuccess;
            });
          }
        } else {
          print('⚠️ No active purchases found to restore');
          if (mounted) {
            setState(() {
              _isRestoring = false;
            });
            ToastService.showErrorToast(
              context,
              message: 'No previous purchases found to restore.',
            );
          }
        }
        return;
      }

      // Fallback to StoreKit if RevenueCat is not available
      print('⚠️ RevenueCat not available, falling back to StoreKit');
      final storeKitService = StoreKitService();
      await storeKitService.restorePurchases();
      
      // Note: Restore results will come through _handlePurchaseUpdate
      // If no purchases found, we'll show a message after a timeout
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isRestoring) {
          setState(() {
            _isRestoring = false;
          });
          ToastService.showErrorToast(
            context,
            message: 'No previous purchases found to restore.',
          );
        }
      });
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
        ToastService.showErrorToast(
          context,
          message: 'Failed to restore purchases. Please try again.',
        );
      }
    }
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
                        ? '\$49.99/year'
                        : '\$9.99/month',
                    style: PlanPageStyles.price,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedPlan == PlanType.annual
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
                onPressed: (_isPurchasing || _isRestoring) ? null : () async {
                  // Use StoreKit to purchase subscription
                  await _startFreeTrialWithStoreKit();
                },
                child: _isPurchasing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF2EFEA)),
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
              onPressed: (_isPurchasing || _isRestoring) ? null : _restorePurchases,
              child: _isRestoring
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        onBack = _showExitDialog;
        break;
      case PlanStep.subscriptionSuccess:
        title = '';
        subtitle = null;
        child = LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.of(context).size.height;
            final headerHeight = 200.0;
            final bottomPadding = 40.0;
            final contentHeight = screenHeight - headerHeight - bottomPadding;
            final topPadding = contentHeight / 2 - 220;

            return Center(
              child: Container(
                padding: EdgeInsets.fromLTRB(10, topPadding, 10, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C6EAB).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF3C6EAB),
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Subscription Active',
                      style: PlanPageStyles.pageTitle.copyWith(
                        fontSize: 32.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your free trial has started!\nYou can now generate your customized meditation experience.',
                      style: PlanPageStyles.cardBody.copyWith(
                        fontSize: 16.sp,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
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
                          // Navigate to generator page with pushReplacementNamed (clear stack)
                          // This is CRITICAL for Apple review - clear navigation shows purchase worked
                          Navigator.pushReplacementNamed(context, '/generator');
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
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
        onBack = null; // No back button on success screen
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
