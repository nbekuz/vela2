# Superwall Promo Codes Setup Guide
## Influencerlar uchun bepul oylar taklif qilish

ChatGPT tavsiyasiga ko'ra, eng yaxshi va eng samarali usul - **100% Off Promo Codes via Superwall**.

---

## ✅ Eng Yaxshi Usul: Superwall Dashboard orqali Promo Offer yaratish

### Qadam 1: App Store Connect'da Subscription Product yaratish

1. **App Store Connect** → **Apps** → **Vela** → **Subscriptions**
2. Subscription product yaratilganligini tekshiring:
   - Product ID: `com.nbekdev.vela` (monthly)
   - Product ID: `com.nbekdev.vela.annual` (annual) - agar mavjud bo'lsa

### Qadam 2: Superwall Dashboard'da Promo Offer yaratish

1. **Superwall Dashboard** → https://superwall.com/dashboard ga kiring
2. **Products** bo'limiga o'ting
3. Subscription product'ni tanlang (monthly yoki annual)
4. **Promo Offers** yoki **Offers** bo'limiga o'ting
5. **"Create Promo Offer"** yoki **"Add Offer"** tugmasini bosing
6. Quyidagi sozlamalarni kiriting:
   - **Discount:** 100% (yoki 0% - bepul)
   - **Duration:** 1-3 oy (siz tanlaysiz)
   - **Auto-convert to paid:** Ha yoki Yo'q (siz tanlaysiz)
     - **Ha** - promo tugagach, to'lovli subscription'ga o'tadi
     - **Yo'q** - promo tugagach, subscription bekor qilinadi
   - **Offer Type:** Promotional Offer
   - **Reference Name:** Influencer promo (masalan: "influencer_free_3months")

### Qadam 3: Promo Linklar yoki Kodlar Generatsiya qilish

Superwall dashboard'da promo offer yaratilgandan keyin:

1. **Campaigns** bo'limiga o'ting
2. Yangi campaign yarating yoki mavjud campaign'ni tanlang
3. Campaign'ga promo offer'ni qo'shing
4. **Promo Links** yoki **Referral Links** bo'limiga o'ting
5. Har bir influencer uchun unique promo link generatsiya qiling:
   - Masalan: `https://superwall.com/promo/INFLUENCER123`
   - Yoki: `vela://promo/INFLUENCER123`

### Qadam 4: Influencerlarga Promo Link yuborish

Har bir influencer uchun unique promo link yuboring:
- Email orqali
- SMS orqali
- Yoki boshqa kanal orqali

### Qadam 5: Influencerlar Promo Link'ni bosadi

1. Influencer promo link'ni bosadi
2. App ochiladi (agar app o'rnatilmagan bo'lsa, App Store'ga yo'naltiriladi)
3. Superwall avtomatik ravishda promo offer'ni qo'llaydi
4. Influencer bepul access olishadi
5. Apple hali ham transaction'ni boshqaradi (Apple policies'ga mos)

---

## 📱 Flutter App'da Promo Kod Entry (Ixtiyoriy)

Agar promo kod entry UI qo'shmoqchi bo'lsangiz:

### Qadam 1: Superwall Service'ga Promo Kod Funksiyasini Qo'shish

```dart
// lib/core/services/superwall_service.dart

/// Redeem promo code and show discounted paywall
/// 
/// [promoCode] - Promo code entered by user
/// [userId] - User ID to identify user
/// 
/// This will validate the promo code and show a discounted paywall
Future<void> redeemPromoCode(String promoCode, {String? userId}) async {
  try {
    if (!_isInitialized) {
      throw Exception('SuperwallKit not initialized');
    }

    // Identify user if provided
    if (userId != null && userId.isNotEmpty) {
      await Superwall.shared.identify(userId);
    }

    // Register placement for promo code campaign
    // The placement name should match the promo code campaign in Superwall dashboard
    // Example: "promo_code_$promoCode" or a general "promo_code" placement
    final placementName = 'promo_code'; // Or use promoCode-specific placement
    
    await showPaywall(placementName, userId: userId);
    
    developer.log('✅ Promo code redeemed: $promoCode');
  } catch (e) {
    developer.log('❌ Error redeeming promo code: $e');
    rethrow;
  }
}
```

### Qadam 2: Plan Page'ga Promo Kod Entry UI Qo'shish

```dart
// lib/pages/plan_page.dart

// Plan page'ga "Have a promo code?" link qo'shing
TextButton(
  onPressed: () {
    _showPromoCodeDialog(context);
  },
  child: Text(
    'Have a promo code?',
    style: TextStyle(
      color: Colors.white.withOpacity(0.7),
      fontSize: 14,
    ),
  ),
),

// Promo kod dialog funksiyasi
void _showPromoCodeDialog(BuildContext context) async {
  final promoCodeController = TextEditingController();
  
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enter Promo Code'),
      content: TextField(
        controller: promoCodeController,
        decoration: InputDecoration(
          hintText: 'Enter your promo code',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, promoCodeController.text),
          child: Text('Redeem'),
        ),
      ],
    ),
  );
  
  if (result != null && result.isNotEmpty) {
    final authStore = context.read<AuthStore>();
    final userId = authStore.user?.id;
    
    try {
      final superwallService = SuperwallService();
      await superwallService.redeemPromoCode(result, userId: userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promo code applied successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid promo code. Please try again.')),
      );
    }
  }
}
```

---

## 🎯 Tavsiya: Promo Linklar Usuli (Eng Oson)

**Eng oson va eng samarali usul** - promo linklar orqali:

1. ✅ Superwall dashboard'da promo offer yaratish (< 1 soat)
2. ✅ Har bir influencer uchun unique promo link generatsiya qilish
3. ✅ Influencerlarga link yuborish
4. ✅ Influencerlar link'ni bosib, bepul access olishadi

**Afzalliklari:**
- ✅ Apple policies'ga to'liq mos
- ✅ Apple review riski yo'q
- ✅ Refund muammolari yo'q
- ✅ Custom build kerak emas
- ✅ Trackable (kim, qachon, churn)
- ✅ 10 yoki 1000 creator uchun mos

**Kamchiliklari:**
- ⚠️ Superwall setup vaqti kerak (< 1 soat)

---

## 📚 Qo'shimcha Ma'lumot

- Superwall Documentation: https://superwall.com/docs
- Promo Codes Guide: https://superwall.com/docs/using-referral-or-promo-codes-with-superwall
- App Store Connect Promo Codes: https://developer.apple.com/app-store/promocodes/

---

## 🔍 Troubleshooting

### Promo kod ishlamayapti

1. Superwall dashboard'da promo offer active ekanligini tekshiring
2. Campaign active ekanligini tekshiring
3. Placement'ga paywall assigned ekanligini tekshiring
4. User identified ekanligini tekshiring
5. Sandbox environment'da test qiling

### Promo link ishlamayapti

1. Promo link to'g'ri formatda ekanligini tekshiring
2. App Store Connect'da promo offer yaratilganligini tekshiring
3. Superwall dashboard'da promo offer active ekanligini tekshiring
