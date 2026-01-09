import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'dart:developer' as developer;
import 'dart:async';

/// StoreKit Service for handling promo codes and promotional offers
/// Apple StoreKit orqali promo kodlar va promotional offers bilan ishlash
class StoreKitService {
  static final StoreKitService _instance = StoreKitService._internal();
  factory StoreKitService() => _instance;
  StoreKitService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isAvailable = false;
  bool _isInitialized = false;

  /// Initialize StoreKit service
  Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('⚠️ StoreKitService already initialized');
      return;
    }

    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      
      print('🔵 StoreKitService initialization check:');
      print('  - isAvailable: $_isAvailable');
      print('  - Platform: ${defaultTargetPlatform}');
      
      if (!_isAvailable) {
        developer.log('⚠️ In-App Purchase is not available');
        print('⚠️ In-App Purchase is not available');
        print('⚠️ Make sure you are running on a real device or simulator with StoreKit Configuration File attached');
        return;
      }

      // Test query to check if StoreKit Configuration File is loaded
      // Try querying a test product to see if StoreKit is working
      try {
        final testResponse = await _inAppPurchase.queryProductDetails({'com.nbekdev.vela.monthly'});
        print('🔵 StoreKit test query result:');
        print('  - Found products: ${testResponse.productDetails.length}');
        print('  - Not found IDs: ${testResponse.notFoundIDs}');
        if (testResponse.productDetails.isNotEmpty) {
          print('✅ StoreKit Configuration File is loaded correctly');
        } else if (testResponse.notFoundIDs.isNotEmpty) {
          print('⚠️ StoreKit Configuration File might not be attached to scheme');
          print('⚠️ Please check Xcode → Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration');
        }
      } catch (e) {
        print('⚠️ StoreKit test query failed: $e');
      }

      // Listen to purchase updates
      _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () {
          developer.log('✅ Purchase stream closed');
        },
        onError: (error) {
          developer.log('❌ Purchase stream error: $error');
        },
      );

      _isInitialized = true;
      print('✅ StoreKitService initialized successfully');
      developer.log('✅ StoreKitService initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing StoreKitService: $e');
      developer.log('❌ Error initializing StoreKitService: $e');
      developer.log('🔵 Stack trace: $stackTrace');
    }
  }

  /// Present code redemption sheet (iOS only)
  /// 
  /// This shows the native iOS promo code redemption sheet
  /// Users can enter promo codes directly in this sheet
  /// 
  /// Promo codes must be created in App Store Connect:
  /// 1. App Store Connect → Apps → Vela → Subscriptions
  /// 2. Select subscription → Promotional Offers
  /// 3. Create promo offer (100% discount, duration: 1-3 months)
  /// 4. Generate promo codes for influencers
  Future<void> presentCodeRedemptionSheet() async {
    if (!_isAvailable) {
      print('⚠️ In-App Purchase is not available');
      developer.log('⚠️ In-App Purchase is not available');
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        
        print('🔵 Presenting code redemption sheet...');
        developer.log('🔵 Presenting code redemption sheet...');
        
        await iosPlatformAddition.presentCodeRedemptionSheet();
        
        print('✅ Code redemption sheet presented');
        developer.log('✅ Code redemption sheet presented');
      } catch (e, stackTrace) {
        print('❌ Error presenting code redemption sheet: $e');
        developer.log('❌ Error presenting code redemption sheet: $e');
        developer.log('🔵 Stack trace: $stackTrace');
        rethrow;
      }
    } else {
      print('⚠️ Code redemption sheet is only available on iOS');
      developer.log('⚠️ Code redemption sheet is only available on iOS');
    }
  }

  /// Get available products
  /// 
  /// [productIds] - List of product IDs to fetch
  /// Returns list of ProductDetails
  Future<List<ProductDetails>> getProducts(Set<String> productIds) async {
    if (!_isAvailable) {
      print('⚠️ In-App Purchase is not available');
      return [];
    }

    try {
      print('🔵 Querying StoreKit for products: $productIds');
      print('🔵 Platform: ${defaultTargetPlatform}');
      print('🔵 StoreKit available: $_isAvailable');
      
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);
      
      print('🔵 StoreKit response received:');
      print('  - Product details count: ${response.productDetails.length}');
      print('  - Not found IDs: ${response.notFoundIDs}');
      print('  - Error: ${response.error}');
      
      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ Products not found: ${response.notFoundIDs}');
        print('⚠️ Requested product IDs: $productIds');
        print('⚠️ This usually means:');
        print('   1. StoreKit Configuration File is not attached to Xcode scheme');
        print('   2. Simulator needs to be restarted');
        print('   3. App needs to be run from Xcode (not Flutter)');
        print('   4. Product IDs in StoreKit Config don\'t match code');
        developer.log('⚠️ Products not found: ${response.notFoundIDs}');
        developer.log('⚠️ Requested product IDs: $productIds');
        
        // Throw exception with detailed information
        throw Exception('Products not found: ${response.notFoundIDs.join(", ")}. Please check StoreKit Configuration File setup in Xcode.');
      }

      if (response.error != null) {
        print('❌ Error querying products: ${response.error}');
        print('❌ Error code: ${response.error!.code}');
        print('❌ Error message: ${response.error!.message}');
        print('❌ Requested product IDs: $productIds');
        developer.log('❌ Error querying products: ${response.error}');
        // Throw exception with error details for better error handling
        throw Exception('StoreKit error: ${response.error!.code} - ${response.error!.message}');
      }

      print('✅ Found ${response.productDetails.length} products');
      for (var product in response.productDetails) {
        print('  - ${product.id}: ${product.title} (${product.price})');
      }
      developer.log('✅ Found ${response.productDetails.length} products');
      
      return response.productDetails;
    } catch (e, stackTrace) {
      print('❌ Error getting products: $e');
      developer.log('❌ Error getting products: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Purchase product with promotional offer
  /// 
  /// [productDetails] - Product to purchase
  /// [promoCode] - Promo code to apply (optional)
  /// 
  /// Note: Promotional offers require server-side signature generation
  /// For promo codes, use presentCodeRedemptionSheet() instead
  Future<void> purchaseProduct(
    ProductDetails productDetails, {
    String? promoCode,
  }) async {
    if (!_isAvailable) {
      print('⚠️ In-App Purchase is not available');
      throw Exception('In-App Purchase is not available');
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        // Promotional offer can be added here if you have server-side signature
        // applicationUserName: userId, // Optional: user ID for purchase
      );

      print('🔵 Purchasing product: ${productDetails.id}');
      developer.log('🔵 Purchasing product: ${productDetails.id}');
      
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      print('✅ Purchase initiated');
      developer.log('✅ Purchase initiated');
    } catch (e, stackTrace) {
      print('❌ Error purchasing product: $e');
      developer.log('❌ Error purchasing product: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Handle purchase updates
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print('🔵 Purchase update: ${purchaseDetails.status}');
      developer.log('🔵 Purchase update: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        print('⏳ Purchase pending...');
        developer.log('⏳ Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Purchase error: ${purchaseDetails.error}');
        developer.log('❌ Purchase error: ${purchaseDetails.error}');
        _handlePurchaseError(purchaseDetails.error!);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        print('✅ Purchase successful: ${purchaseDetails.productID}');
        developer.log('✅ Purchase successful: ${purchaseDetails.productID}');
        _handlePurchaseSuccess(purchaseDetails);
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        print('✅ Completing purchase...');
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase
  void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) {
    // Here you can:
    // 1. Verify receipt with your backend
    // 2. Update user subscription status
    // 3. Grant access to premium features
    print('✅ Purchase completed: ${purchaseDetails.productID}');
    developer.log('✅ Purchase completed: ${purchaseDetails.productID}');
    
    // TODO: Verify receipt with backend and update user subscription
  }

  /// Handle purchase error
  void _handlePurchaseError(IAPError error) {
    print('❌ Purchase error: ${error.code} - ${error.message}');
    developer.log('❌ Purchase error: ${error.code} - ${error.message}');
    
    // Handle specific error codes
    switch (error.code) {
      case 'user_cancelled':
        print('ℹ️ User cancelled the purchase');
        break;
      case 'payment_invalid':
        print('❌ Payment invalid');
        break;
      case 'store_product_not_available':
        print('❌ Product not available in store');
        break;
      default:
        print('❌ Unknown error: ${error.code}');
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      print('⚠️ In-App Purchase is not available');
      return;
    }

    try {
      print('🔵 Restoring purchases...');
      developer.log('🔵 Restoring purchases...');
      
      await _inAppPurchase.restorePurchases();
      
      print('✅ Purchases restored');
      developer.log('✅ Purchases restored');
    } catch (e, stackTrace) {
      print('❌ Error restoring purchases: $e');
      developer.log('❌ Error restoring purchases: $e');
      developer.log('🔵 Stack trace: $stackTrace');
    }
  }

  /// Check if user has active purchase/subscription
  /// Returns true if user has purchased or restored any subscription product
  Future<bool> hasActivePurchase() async {
    if (!_isAvailable) {
      print('⚠️ In-App Purchase is not available');
      return false;
    }

    try {
      print('🔵 Checking for active purchases...');
      developer.log('🔵 Checking for active purchases...');

      // Product IDs to check
      final productIds = {
        'com.nbekdev.vela.monthly',
        'com.nbekdev.vela.annual',
      };

      // Get past purchases from StoreKit
      // Note: restorePurchases() triggers purchase stream, but we need to check existing purchases
      // For iOS, we can use the purchase stream listener to check for restored purchases
      // But for a synchronous check, we'll use a different approach
      
      // Create a completer to wait for purchase stream response
      final completer = Completer<bool>();
      bool hasActivePurchase = false;
      
      // Listen to purchase stream temporarily
      late StreamSubscription<List<PurchaseDetails>> subscription;
      subscription = _inAppPurchase.purchaseStream.listen(
        (List<PurchaseDetails> purchaseDetailsList) {
          for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
            if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              // Check if it's one of our subscription products
              if (productIds.contains(purchaseDetails.productID)) {
                print('✅ Found active purchase: ${purchaseDetails.productID}');
                developer.log('✅ Found active purchase: ${purchaseDetails.productID}');
                hasActivePurchase = true;
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
                subscription.cancel();
                return;
              }
            }
          }
        },
        onError: (error) {
          print('❌ Error checking purchases: $error');
          developer.log('❌ Error checking purchases: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          subscription.cancel();
        },
      );

      // Trigger restore to check for existing purchases
      await _inAppPurchase.restorePurchases();

      // Wait for response with timeout
      try {
        hasActivePurchase = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⏳ Purchase check timeout - assuming no active purchase');
            developer.log('⏳ Purchase check timeout - assuming no active purchase');
            subscription.cancel();
            return false;
          },
        );
      } catch (e) {
        print('⚠️ Error waiting for purchase check: $e');
        developer.log('⚠️ Error waiting for purchase check: $e');
        subscription.cancel();
        return false;
      }

      subscription.cancel();
      return hasActivePurchase;
    } catch (e, stackTrace) {
      print('❌ Error checking active purchase: $e');
      developer.log('❌ Error checking active purchase: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      return false;
    }
  }

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
}
