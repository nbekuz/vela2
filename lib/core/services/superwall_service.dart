import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';

class SuperwallService {
  static final SuperwallService _instance = SuperwallService._internal();
  factory SuperwallService() => _instance;
  SuperwallService._internal();

  bool _isInitialized = false;
  String? _apiKey;

  /// Initialize SuperwallKit
  /// 
  /// [apiKey] - Your Superwall API key
  /// You can get this from your Superwall dashboard
  Future<void> initialize(String apiKey) async {
    if (_isInitialized) {
      developer.log('⚠️ SuperwallKit already initialized');
      print('⚠️ SuperwallKit already initialized');
      return;
    }

    try {
      print('🔵 Initializing SuperwallKit with API key: ${apiKey.substring(0, 10)}...');
      developer.log('🔵 Initializing SuperwallKit...');
      
      // Configure Superwall with API key
      // This is the main initialization method
      Superwall.configure(apiKey);
      _apiKey = apiKey;
      _isInitialized = true;
      
      print('✅ SuperwallKit initialized successfully');
      developer.log('✅ SuperwallKit initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing SuperwallKit: $e');
      print('🔵 Stack trace: $stackTrace');
      developer.log('❌ Error initializing SuperwallKit: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Show paywall for a specific campaign
  /// 
  /// [campaignName] - The name of the placement/event to show (from Superwall dashboard)
  /// This should match the "In-App Event Name" in Superwall dashboard placement
  /// 
  /// [userId] - Optional user ID to identify user before showing paywall
  /// 
  /// This will trigger the paywall to appear based on your Superwall dashboard configuration
  Future<void> showPaywall(String campaignName, {String? userId}) async {
    try {
      if (!_isInitialized) {
        developer.log('⚠️ SuperwallKit not initialized. Cannot show paywall.');
        print('⚠️ SuperwallKit not initialized. Cannot show paywall.');
        throw Exception('SuperwallKit not initialized');
      }

      print('🔵 ========== SuperwallService: Starting paywall flow ==========');
      print('🔵 Placement name: $campaignName');
      print('🔵 User ID: ${userId ?? "not provided"}');
      developer.log('🔵 SuperwallService: Registering placement: $campaignName');

      // Identify user if provided (important for Superwall to track user)
      if (userId != null && userId.isNotEmpty) {
        try {
          print('🔵 Identifying user with Superwall: $userId');
          await Superwall.shared.identify(userId);
          print('✅ User identified successfully');
          developer.log('✅ User identified with SuperwallKit: $userId');
        } catch (e) {
          print('⚠️ Warning: Failed to identify user: $e');
          developer.log('⚠️ Warning: Failed to identify user: $e');
          // Continue anyway - user might already be identified
        }
      } else {
        print('⚠️ Warning: No user ID provided. Superwall may not show paywall correctly.');
        print('💡 Tip: Make sure user is identified before showing paywall');
      }

      // Register the placement to trigger the paywall
      // The placement name should match the "In-App Event Name" in Superwall dashboard
      // Note: registerPlacement will automatically show paywall if configured in dashboard
      
      // Create handler to track paywall presentation
      // Use Completer to wait for async callbacks
      final handler = PaywallPresentationHandler();
      final completer = Completer<void>();
      bool paywallWasPresented = false;
      bool paywallWasSkipped = false;
      String? skipReason;
      String? errorMessage;
      
      handler.onPresent((PaywallInfo paywallInfo) {
        paywallWasPresented = true;
        print('✅ ========== PAYWALL PRESENTED SUCCESSFULLY ==========');
        print('✅ Paywall ID: ${paywallInfo.identifier}');
        print('✅ Paywall name: ${paywallInfo.name}');
        developer.log('✅ Paywall presented successfully');
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      
      handler.onDismiss((PaywallInfo paywallInfo, PaywallResult result) {
        print('🔵 ========== PAYWALL DISMISSED ==========');
        print('🔵 Result: $result');
        print('🔵 Paywall ID: ${paywallInfo.identifier}');
        developer.log('🔵 Paywall dismissed with result: $result');
      });
      
      handler.onSkip((PaywallSkippedReason reason) {
        paywallWasSkipped = true;
        skipReason = reason.toString();
        print('❌ ========== PAYWALL SKIPPED ==========');
        print('❌ Skip reason: $reason');
        developer.log('🔵 Paywall skipped: $reason');
        
        // Log specific skip reason
        if (reason.toString().contains('NoAudienceMatch')) {
          print('❌ Paywall skipped: User does not match audience criteria');
          print('💡 ========== SOLUTION FOR NoAudienceMatch ==========');
          print('💡 Go to Superwall dashboard: https://superwall.com/dashboard');
          print('💡 Steps to fix:');
          print('   1. Navigate to Campaigns → Find campaign for "$campaignName"');
          print('   2. Click "Pause" button to UNPAUSE the campaign (if paused)');
          print('   3. Go to "Audiences" tab → Click "All Users"');
          print('   4. Click "Everyone + Limit" tab');
          print('   5. Remove ALL filters and limits (set to unlimited)');
          print('   6. OR click "Create catch-all audience" button');
          print('   7. Make sure "All Users" has NO filters or limits');
          print('   8. Go to Placements → "$campaignName" → Verify paywall is assigned');
          print('   9. Verify paywall has products assigned');
          print('   10. Save all changes');
          print('   11. Wait 10-15 seconds for changes to sync');
          print('   12. Try again in the app');
        } else if (reason.toString().contains('Holdout')) {
          print('🔵 Paywall skipped: User is in holdout group');
        } else if (reason.toString().contains('NoPaywall')) {
          print('❌ Paywall skipped: No paywall assigned to this placement');
          print('💡 Solution: Check Superwall dashboard → Placements → Assign a paywall');
        } else {
          print('🔵 Paywall skipped for reason: $reason');
        }
        
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      
      handler.onError((String error) {
        errorMessage = error;
        print('❌ ========== PAYWALL ERROR ==========');
        print('❌ Error: $error');
        developer.log('❌ Paywall error: $error');
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      
      print('🔵 Calling Superwall.shared.registerPlacement("$campaignName")...');
      await Superwall.shared.registerPlacement(campaignName, handler: handler);
      
      print('🔵 Waiting for Superwall callback (max 5 seconds)...');
      
      // Wait for callback with timeout
      try {
        await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Timeout: No callback received within 5 seconds');
            print('⚠️ This might indicate:');
            print('   1. Placement name "$campaignName" does not exist in Superwall dashboard');
            print('   2. Network issue - Superwall could not fetch paywall configuration');
            print('   3. Superwall SDK issue');
          },
        );
      } catch (e) {
        print('⚠️ Error waiting for callback: $e');
      }
      
      print('🔵 ========== Placement registration completed ==========');
      print('✅ Placement registered: $campaignName');
      print('🔵 Paywall presented: $paywallWasPresented');
      print('🔵 Paywall skipped: $paywallWasSkipped');
      if (skipReason != null) {
        print('🔵 Skip reason: $skipReason');
      }
      if (errorMessage != null) {
        print('🔵 Error: $errorMessage');
      }
      
      developer.log('✅ Placement registered: $campaignName');
      
      if (!paywallWasPresented && !paywallWasSkipped) {
        print('⚠️ ========== WARNING: No callback received ==========');
        print('⚠️ Paywall neither presented nor skipped. This might indicate:');
        print('   1. Placement name "$campaignName" does not exist in Superwall dashboard');
        print('   2. Network issue - Superwall could not fetch paywall configuration');
        print('   3. Superwall SDK issue');
        print('💡 Check Superwall dashboard to verify placement exists');
      }
      
      if (paywallWasSkipped) {
        print('💡 ========== TROUBLESHOOTING GUIDE ==========');
        print('💡 Check Superwall dashboard:');
        print('   1. Go to https://superwall.com/dashboard');
        print('   2. Navigate to Placements');
        print('   3. Find placement with "In-App Event Name" = "$campaignName"');
        print('   4. Make sure:');
        print('      - Placement exists and is active');
        print('      - A paywall is assigned to this placement');
        print('      - Campaign is active (not paused)');
        print('      - Audience is set to "All Users" or matches your test user');
        print('      - Environment is Sandbox (for testing)');
      }
    } catch (e, stackTrace) {
      print('❌ ========== ERROR SHOWING PAYWALL ==========');
      print('❌ Error: $e');
      print('🔵 Stack trace: $stackTrace');
      developer.log('❌ Error showing paywall: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      developer.log('💡 Make sure:');
      developer.log('   1. SuperwallKit is initialized');
      developer.log('   2. Placement name "$campaignName" matches Superwall dashboard "In-App Event Name"');
      developer.log('   3. Campaign is active in Superwall dashboard');
      developer.log('   4. Paywall is configured in the placement');
      rethrow;
    }
  }

  /// Register user with SuperwallKit
  /// Call this after user logs in to identify them in Superwall
  Future<void> registerUser(String userId) async {
    try {
      if (!_isInitialized) {
        developer.log('⚠️ SuperwallKit not initialized. Cannot register user.');
        return;
      }

      // Identify user with Superwall
      await Superwall.shared.identify(userId);
      developer.log('✅ User registered with SuperwallKit: $userId');
    } catch (e) {
      developer.log('❌ Error registering user: $e');
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Reset user session (for logout)
  Future<void> reset() async {
    try {
      if (!_isInitialized) {
        return;
      }

      // Reset Superwall user session
      await Superwall.shared.reset();
      developer.log('✅ SuperwallKit user session reset');
    } catch (e) {
      developer.log('❌ Error resetting SuperwallKit: $e');
    }
  }

  /// Redeem promo code and show discounted paywall
  /// 
  /// This method is used for influencer promo codes (100% off offers)
  /// 
  /// [promoCode] - Promo code entered by user (e.g., "INFLUENCER123")
  /// [userId] - User ID to identify user in Superwall
  /// 
  /// How it works:
  /// 1. User enters promo code in the app
  /// 2. This method registers a placement for the promo code campaign
  /// 3. Superwall shows a discounted paywall (100% off) based on dashboard configuration
  /// 4. User subscribes with the promo code applied
  /// 
  /// Setup required in Superwall Dashboard:
  /// 1. Create a promo offer with 100% discount
  /// 2. Create a campaign for promo codes
  /// 3. Create a placement (e.g., "promo_code") for the campaign
  /// 4. Assign the promo offer to the paywall in the campaign
  /// 
  /// See SUPERWALL_PROMO_CODES.md for detailed setup instructions
  Future<void> redeemPromoCode(String promoCode, {String? userId}) async {
    try {
      if (!_isInitialized) {
        developer.log('⚠️ SuperwallKit not initialized. Cannot redeem promo code.');
        print('⚠️ SuperwallKit not initialized. Cannot redeem promo code.');
        throw Exception('SuperwallKit not initialized');
      }

      print('🔵 ========== Redeeming Promo Code ==========');
      print('🔵 Promo code: $promoCode');
      print('🔵 User ID: ${userId ?? "not provided"}');
      developer.log('🔵 Redeeming promo code: $promoCode');

      // Identify user if provided
      if (userId != null && userId.isNotEmpty) {
        try {
          print('🔵 Identifying user with Superwall: $userId');
          await Superwall.shared.identify(userId);
          print('✅ User identified successfully');
          developer.log('✅ User identified with SuperwallKit: $userId');
        } catch (e) {
          print('⚠️ Warning: Failed to identify user: $e');
          developer.log('⚠️ Warning: Failed to identify user: $e');
        }
      }

      // Register placement for promo code campaign
      // The placement name should match the promo code campaign in Superwall dashboard
      // Example placement names:
      // - "promo_code" (general promo code placement)
      // - "promo_code_$promoCode" (specific promo code placement)
      // 
      // Note: You can create multiple placements for different promo codes
      // or use a single "promo_code" placement that handles all promo codes
      final placementName = 'promo_code'; // Change this to match your Superwall dashboard placement
      
      print('🔵 Registering placement: $placementName');
      print('💡 Make sure this placement exists in Superwall dashboard');
      print('💡 The placement should have a paywall with promo offer (100% discount)');
      
      // Use the existing showPaywall method to show the discounted paywall
      await showPaywall(placementName, userId: userId);
      
      print('✅ Promo code redeemed successfully: $promoCode');
      developer.log('✅ Promo code redeemed: $promoCode');
    } catch (e, stackTrace) {
      print('❌ ========== ERROR REDEEMING PROMO CODE ==========');
      print('❌ Error: $e');
      print('🔵 Stack trace: $stackTrace');
      developer.log('❌ Error redeeming promo code: $e');
      developer.log('🔵 Stack trace: $stackTrace');
      developer.log('💡 Make sure:');
      developer.log('   1. SuperwallKit is initialized');
      developer.log('   2. Placement "promo_code" exists in Superwall dashboard');
      developer.log('   3. Campaign is active in Superwall dashboard');
      developer.log('   4. Paywall has promo offer (100% discount) assigned');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;
  String? get apiKey => _apiKey;
}

