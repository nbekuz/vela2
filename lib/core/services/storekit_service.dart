import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'dart:developer' as developer;

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
      
      if (!_isAvailable) {
        developer.log('⚠️ In-App Purchase is not available');
        print('⚠️ In-App Purchase is not available');
        return;
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
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ Products not found: ${response.notFoundIDs}');
        developer.log('⚠️ Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        print('❌ Error querying products: ${response.error}');
        developer.log('❌ Error querying products: ${response.error}');
        // Throw exception with error details for better error handling
        throw Exception('StoreKit error: ${response.error!.code} - ${response.error!.message}');
      }

      print('✅ Found ${response.productDetails.length} products');
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

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
}
