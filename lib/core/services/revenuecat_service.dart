import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';

/// RevenueCat Service for handling in-app purchases
/// RevenueCat orqali in-app purchases bilan ishlash
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  bool _isAvailable = false;
  
  // Product IDs
  static const String monthlyProductId = 'com.nbekdev.vela.monthly';
  static const String annualProductId = 'com.nbekdev.vela.annual';
  
  // API Key - Real device production key
  static const String apiKey = 'appl_rzjbuzDneiamfPMllyZsHEMEmrg';

  /// Initialize RevenueCat
  Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('⚠️ RevenueCatService already initialized');
      print('⚠️ RevenueCatService already initialized');
      return;
    }

    try {
      print('🔵 Initializing RevenueCat...');
      print('🔵 Platform: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Unknown"}');
      print('🔵 API Key: ${apiKey.substring(0, 10)}...');
      
      // Platform-specific API key (same for both platforms in this case)
      String platformApiKey = apiKey;
      
      if (Platform.isIOS) {
        platformApiKey = apiKey;
        print('🔵 Using iOS API key');
      } else if (Platform.isAndroid) {
        platformApiKey = apiKey;
        print('🔵 Using Android API key');
      } else {
        print('⚠️ Platform not supported for RevenueCat');
        developer.log('⚠️ Platform not supported for RevenueCat');
        return;
      }

      // Configure RevenueCat
      print('🔵 Configuring RevenueCat...');
      await Purchases.configure(PurchasesConfiguration(platformApiKey));
      
      // Set log level for debugging
      await Purchases.setLogLevel(LogLevel.debug);
      
      _isInitialized = true;
      _isAvailable = true;
      
      print('✅ RevenueCat initialized successfully');
      print('✅ RevenueCat isAvailable: $_isAvailable');
      developer.log('✅ RevenueCat initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing RevenueCat: $e');
      print('❌ Stack trace: $stackTrace');
      developer.log('❌ Error initializing RevenueCat: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      _isInitialized = false;
      _isAvailable = false;
    }
  }

  /// Check if RevenueCat is available
  bool get isAvailable => _isAvailable && _isInitialized;
  
  /// Get initialization status (for debugging)
  bool get isInitialized => _isInitialized;

  /// Get available products
  Future<List<StoreProduct>> getProducts() async {
    if (!isAvailable) {
      developer.log('⚠️ RevenueCat is not available');
      return [];
    }

    try {
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current == null) {
        developer.log('⚠️ No current offering found');
        return [];
      }

      final packages = offerings.current!.availablePackages;
      final products = packages.map((package) => package.storeProduct).toList();
      
      developer.log('✅ Found ${products.length} products');
      return products;
    } catch (e) {
      developer.log('❌ Error getting products: $e');
      return [];
    }
  }

  /// Purchase a product
  Future<CustomerInfo> purchaseProduct(StoreProduct product) async {
    if (!isAvailable) {
      throw Exception('RevenueCat is not available');
    }

    try {
      final customerInfo = await Purchases.purchaseStoreProduct(product);
      developer.log('✅ Purchase successful: ${product.identifier}');
      return customerInfo;
    } catch (e) {
      developer.log('❌ Purchase error: $e');
      rethrow;
    }
  }

  /// Purchase a package
  Future<CustomerInfo> purchasePackage(Package package) async {
    if (!isAvailable) {
      throw Exception('RevenueCat is not available');
    }

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      developer.log('✅ Purchase successful: ${package.identifier}');
      return customerInfo;
    } catch (e) {
      developer.log('❌ Purchase error: $e');
      rethrow;
    }
  }

  /// Restore purchases
  Future<CustomerInfo> restorePurchases() async {
    if (!isAvailable) {
      throw Exception('RevenueCat is not available');
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      developer.log('✅ Purchases restored');
      return customerInfo;
    } catch (e) {
      developer.log('❌ Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActivePurchase() async {
    if (!isAvailable) {
      developer.log('⚠️ RevenueCat is not available');
      return false;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Check for "Vela Pro" entitlement (preferred method)
      final hasPro = customerInfo.entitlements.active.containsKey('velaPro');
      
      if (hasPro) {
        developer.log('✅ User has active "Vela Pro" entitlement');
        return true;
      }
      
      // Check if user has any active entitlement
      final hasActiveEntitlement = customerInfo.entitlements.active.isNotEmpty;
      
      if (hasActiveEntitlement) {
        developer.log('✅ User has active entitlement');
        return true;
      }

      // Also check for specific product IDs
      final activeSubscriptions = customerInfo.activeSubscriptions;
      final hasActiveSubscription = activeSubscriptions.contains(monthlyProductId) ||
          activeSubscriptions.contains(annualProductId);
      
      developer.log('🔄 Active subscriptions: $activeSubscriptions');
      developer.log('🔄 Has active subscription: $hasActiveSubscription');
      
      return hasActiveSubscription;
    } catch (e) {
      developer.log('❌ Error checking active purchase: $e');
      return false;
    }
  }
  
  /// Check if user has specific entitlement
  Future<bool> hasEntitlement(String entitlementId) async {
    if (!isAvailable) {
      developer.log('⚠️ RevenueCat is not available');
      return false;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasEntitlement = customerInfo.entitlements.active.containsKey(entitlementId);
      developer.log('🔄 Entitlement "$entitlementId" check: $hasEntitlement');
      return hasEntitlement;
    } catch (e) {
      developer.log('❌ Error checking entitlement: $e');
      return false;
    }
  }

  /// Get customer info
  Future<CustomerInfo> getCustomerInfo() async {
    if (!isAvailable) {
      throw Exception('RevenueCat is not available');
    }

    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      developer.log('❌ Error getting customer info: $e');
      rethrow;
    }
  }

  /// Listen to purchase updates
  /// Note: RevenueCat uses listener pattern, not stream
  /// Use Purchases.addCustomerInfoUpdateListener() instead
  void addPurchaseUpdateListener(Function(CustomerInfo) listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Present code redemption sheet (iOS only)
  Future<void> presentCodeRedemptionSheet() async {
    if (!isAvailable) {
      throw Exception('RevenueCat is not available');
    }

    if (!Platform.isIOS) {
      throw Exception('Code redemption sheet is only available on iOS');
    }

    try {
      await Purchases.presentCodeRedemptionSheet();
      developer.log('✅ Code redemption sheet presented');
    } catch (e) {
      developer.log('❌ Error presenting code redemption sheet: $e');
      rethrow;
    }
  }
}

