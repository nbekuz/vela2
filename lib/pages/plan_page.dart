import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'components/dream_life_intro_widget.dart';
import 'components/plan_selection_content.dart';
import 'components/plan_subtitle_widget.dart';
import '../shared/widgets/auth.dart';
import '../shared/widgets/exit_confirmation_dialog.dart';
import '../shared/widgets/custom_toast.dart';
import '../core/services/storekit_service.dart';
import '../core/services/revenuecat_service.dart';

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

  // StoreKit product IDs (from App Store Connect)
  static const String _monthlyProductId = 'com.nbekdev.vela.monthly';
  static const String _annualProductId = 'com.nbekdev.vela.annual';

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

  void _handleRevenueCatPurchaseUpdate(CustomerInfo customerInfo) async {
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

        // Navigate directly to generator page (subscription info will be shown there)
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/generator');
        }
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

  Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
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
          final errorMessage =
              purchaseDetails.error?.message ?? 'Purchase failed';
          if (purchaseDetails.error?.code == 'user_cancelled') {
            // Don't show error toast for user cancellation
            print('ℹ️ User cancelled the purchase');
          } else {
            ToastService.showErrorToast(context, message: errorMessage);
          }
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        print('✅ Purchase successful: ${purchaseDetails.productID}');
        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isRestoring = false;
          });
          // Navigate directly to generator page (subscription info will be shown there)
          Navigator.pushReplacementNamed(context, '/generator');
        }
      }
      if (purchaseDetails.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _startFreeTrialWithStoreKit() async {
    if (_isPurchasing) {
      return;
    }

    try {
      setState(() {
        _isPurchasing = true;
      });

      final revenueCatService = RevenueCatService();

      if (revenueCatService.isAvailable) {
        print('🔵 Starting free trial with RevenueCat');
        print(
          '🔵 Selected plan: ${_selectedPlan == PlanType.annual ? "Annual" : "Monthly"}',
        );

        // Get offerings from RevenueCat with timeout handling
        Offerings? offerings;
        try {
          offerings = await Purchases.getOfferings().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Network timeout: Unable to connect to RevenueCat. Please check your internet connection.',
              );
            },
          );
        } catch (e) {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('timeout') ||
              errorString.contains('network_error') ||
              errorString.contains('configuration_error') ||
              errorString.contains('no products registered') ||
              errorString.contains('offerings empty')) {
            print(
              '⚠️ RevenueCat configuration/network issue, falling back to StoreKit',
            );
            print('⚠️ Error details: $e');
            // Fall through to StoreKit fallback
            offerings = null;
          } else {
            rethrow;
          }
        }

        if (offerings == null || offerings.current == null) {
          print(
            '⚠️ No current offering found in RevenueCat, falling back to StoreKit',
          );
          // Fall through to StoreKit fallback below
        } else {
          // Find the package based on selected plan
          Package selectedPackage;
          if (_selectedPlan == PlanType.annual) {
            // Try to find annual package
            try {
              selectedPackage = offerings.current!.availablePackages.firstWhere(
                (package) =>
                    package.identifier.contains('annual') ||
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
                (package) =>
                    package.identifier.contains('month') ||
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

          print(
            '✅ Found package: ${selectedPackage.identifier} - ${selectedPackage.storeProduct.price}',
          );

          // Purchase the package with timeout handling
          try {
            await revenueCatService
                .purchasePackage(selectedPackage)
                .timeout(
                  const Duration(seconds: 30),
                  onTimeout: () {
                    throw Exception('Purchase timeout: Please try again.');
                  },
                );

            print('✅ Purchase initiated successfully with RevenueCat');
            // Purchase completion will be handled by _handleRevenueCatPurchaseUpdate
            return;
          } catch (e) {
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('timeout') ||
                errorString.contains('network_error') ||
                errorString.contains('configuration_error') ||
                errorString.contains('no products registered') ||
                errorString.contains('offerings empty')) {
              print('⚠️ RevenueCat purchase error, falling back to StoreKit');
              print('⚠️ Error details: $e');
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
      print(
        '🔵 Selected plan: ${_selectedPlan == PlanType.annual ? "Annual" : "Monthly"}',
      );
      print('🔵 Product ID: $productId');

      // Get products from StoreKit
      print('🔵 Querying StoreKit for product: $productId');
      final products = await storeKitService.getProducts({productId});

      if (products.isEmpty) {
        print('❌ StoreKit product not found: $productId');
        print('⚠️ This might be because:');
        print(
          '   1. StoreKit Configuration File is not attached to the scheme in Xcode',
        );
        print(
          '   2. App needs to be restarted after adding StoreKit Configuration File',
        );
        print('   3. Simulator needs to be restarted');
        print('   4. Product ID mismatch between StoreKit Config and code');
        print('');
        print('📝 To fix:');
        print('   1. Open Xcode → Product → Scheme → Edit Scheme');
        print(
          '   2. Run → Options → StoreKit Configuration → Select "Products.storekit"',
        );
        print('   3. Clean build folder (Shift+Cmd+K)');
        print('   4. Restart Simulator and app');
        throw Exception(
          'Product not found: $productId. Please check StoreKit Configuration File setup in Xcode.',
        );
      }

      final productDetails = products.first;
      print(
        '✅ Found product: ${productDetails.title} - ${productDetails.price}',
      );

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
        } else if (errorString.contains('timeout') ||
            errorString.contains('network_error')) {
          errorMessage =
              'Network timeout. Please check your internet connection and try again.';
        } else if (errorString.contains('no current offering') ||
            errorString.contains('no packages')) {
          errorMessage = 'Subscription not available. Please try again later.';
        }

        ToastService.showErrorToast(context, message: errorMessage);
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
            // Navigate directly to generator page (subscription info will be shown there)
            Navigator.pushReplacementNamed(context, '/generator');
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
      message:
          'Are you sure you want to exit? You can always come back to select your plan later.',
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
        subtitle = PlanSubtitleWidget(
          selectedPlan: _selectedPlan,
          onPlanChanged: (plan) {
            setState(() {
              _selectedPlan = plan;
            });
          },
        );
        child = PlanSelectionContent(
          selectedPlan: _selectedPlan,
          isPurchasing: _isPurchasing,
          isRestoring: _isRestoring,
          onPlanChanged: (plan) => setState(() => _selectedPlan = plan),
          onStartFreeTrial: () async {
            await _startFreeTrialWithStoreKit();
          },
          onRestorePurchases: _restorePurchases,
        );
        onBack = _showExitDialog;
        break;
      case PlanStep.dreamLifeIntro:
        title = '';
        subtitle = null;
        child = DreamLifeIntroWidget(
          onContinue: () {
            Navigator.pushReplacementNamed(context, '/generator');
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
