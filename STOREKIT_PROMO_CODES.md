# StoreKit Promo Codes Setup Guide (Apple Native)
## Influencerlar uchun bepul oylar taklif qilish - Superwall'siz

Bu qo'llanma Apple'ning native StoreKit API'si orqali promo kodlar qo'llashni ko'rsatadi.

---

## ✅ App Store Connect'da Promo Offer Yaratish

### Qadam 1: Subscription Product'ni Tekshirish

1. **App Store Connect** → **Apps** → **Vela** → **Subscriptions**
2. Subscription product'lar mavjudligini tekshiring:
   - **Product ID:** `com.nbekdev.vela` (monthly)
   - **Product ID:** `com.nbekdev.vela.pro.year` (annual)

### Qadam 2: Promotional Offer Yaratish

1. **Subscriptions** bo'limida subscription'ni tanlang (masalan, "Vela month")
2. **Promotional Offers** yoki **Offers** bo'limiga o'ting
3. **"Create Promotional Offer"** yoki **"+"** tugmasini bosing
4. Quyidagi sozlamalarni kiriting:
   - **Reference Name:** `influencer_free_3months` (yoki boshqa nom)
   - **Duration:** 1-3 oy (siz tanlaysiz)
   - **Type:** Pay as You Go yoki Pay Up Front
   - **Price:** $0.00 (100% discount)
   - **Payment Mode:** Free Trial
   - **Subscription Periods:** 1-3 oy

### Qadam 3: Promo Kodlar Generatsiya qilish

1. **Promotional Offers** bo'limida yaratilgan offer'ni tanlang
2. **"Generate Promo Codes"** yoki **"Promo Codes"** tugmasini bosing
3. Har bir influencer uchun unique promo kod generatsiya qiling:
   - Masalan: `INFLUENCER123`
   - Yoki: `CREATOR456`
   - Yoki: `PRESS789`

### Qadam 4: Promo Kodlarni Yuborish

Har bir influencer uchun unique promo kod yuboring:
- Email orqali
- SMS orqali
- Yoki boshqa kanal orqali

---

## 📱 Flutter App'da Promo Kod Entry

### Qadam 1: StoreKit Service'ni Initialize qilish

```dart
// lib/main.dart
import 'package:provider/provider.dart';
import 'core/services/storekit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize StoreKit Service
  final storeKitService = StoreKitService();
  await storeKitService.initialize();
  
  runApp(MyApp(...));
}
```

### Qadam 2: Plan Page'ga Promo Kod Entry UI Qo'shish

```dart
// lib/pages/plan_page.dart

import 'package:flutter/material.dart';
import '../core/services/storekit_service.dart';

// Plan page'ga "Have a promo code?" link qo'shing
TextButton(
  onPressed: () async {
    final storeKitService = StoreKitService();
    await storeKitService.presentCodeRedemptionSheet();
  },
  child: Text(
    'Have a promo code?',
    style: TextStyle(
      color: Colors.white.withOpacity(0.7),
      fontSize: 14,
    ),
  ),
),
```

### Qadam 3: Promo Kod Redemption Sheet'ni Ko'rsatish

StoreKit service'da `presentCodeRedemptionSheet()` funksiyasi mavjud. Bu funksiya iOS native promo kod redemption sheet'ni ko'rsatadi.

```dart
final storeKitService = StoreKitService();
await storeKitService.presentCodeRedemptionSheet();
```

---

## 🎯 Ishlash Prinsipi

1. **Influencer promo kodni oladi** (masalan: `INFLUENCER123`)
2. **App'da "Have a promo code?" tugmasini bosadi**
3. **iOS native redemption sheet ochiladi**
4. **Influencer promo kodni kiritaди**
5. **Apple promo kodni validate qiladi**
6. **Promotional offer qo'llanadi** (100% discount, 1-3 oy)
7. **Influencer bepul access olishadi**
8. **Promo tugagach, subscription bekor qilinadi yoki to'lovli subscription'ga o'tadi** (sizning sozlamangizga qarab)

---

## ✅ Afzalliklari

- ✅ **100% Apple native** - Apple policies'ga to'liq mos
- ✅ **Apple review riski yo'q** - Native API ishlatiladi
- ✅ **Refund muammolari yo'q** - Apple boshqaradi
- ✅ **Custom build kerak emas** - Standard StoreKit API
- ✅ **Trackable** - App Store Connect'da ko'rish mumkin
- ✅ **Scales cleanly** - 10 yoki 1000 creator uchun mos

---

## 📚 Qo'shimcha Ma'lumot

- Apple Documentation: https://developer.apple.com/documentation/storekit/in-app_purchase
- Promo Codes Guide: https://developer.apple.com/app-store/promocodes/
- Promotional Offers: https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers/implementing_promotional_offers_in_your_app

---

## 🔍 Troubleshooting

### Promo kod ishlamayapti

1. App Store Connect'da promo offer active ekanligini tekshiring
2. Promo kod to'g'ri formatda ekanligini tekshiring
3. Sandbox environment'da test qiling
4. Test account bilan promo kodni test qiling

### Code redemption sheet ochilmayapti

1. iOS device yoki simulator'da test qiling (Web'da ishlamaydi)
2. StoreKit service initialized ekanligini tekshiring
3. In-App Purchase available ekanligini tekshiring

---

## 💡 Maslahat

- Har bir influencer uchun unique promo kod yarating
- Promo kodlarni xavfsiz saqlang va faqat kerakli odamlarga yuboring
- Promo kodlarni muddatini belgilang (masalan, 3 oydan keyin bekor qilish)
- App Store Connect'da promo kodlar statistikasini kuzatib boring
