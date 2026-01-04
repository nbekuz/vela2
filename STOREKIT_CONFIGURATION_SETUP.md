# StoreKit Configuration File Setup

Bu file iOS Simulator'da in-app purchase'larni test qilish uchun kerak.

## ✅ File yaratildi

`ios/Runner/Products.storekit` file yaratildi va quyidagi product'lar bilan sozlangan:

- **Monthly Subscription**: `com.nbekdev.vela.month` - $9.99/month
- **Annual Subscription**: `com.nbekdev.vela.year` - $49.99/year

Har ikkala subscription'da 3 kunlik free trial mavjud.

## 📝 Xcode'da qo'shish

### 1. Xcode'da project'ni oching

```bash
open ios/Runner.xcworkspace
```

### 2. StoreKit Configuration File'ni project'ga qo'shing

1. Xcode'da **File → Add Files to "Runner"...**
2. `ios/Runner/Products.storekit` file'ni tanlang
3. **"Copy items if needed"** checkbox'ni belgilang
4. **"Add to targets: Runner"** checkbox'ni belgilang
5. **Add** tugmasini bosing

### 3. Scheme'ga StoreKit Configuration File'ni attach qiling

1. Xcode'da **Product → Scheme → Edit Scheme...**
2. **Run** (chap panelda) ni tanlang
3. **Options** tab'ni oching
4. **StoreKit Configuration** dropdown'dan **Products.storekit** ni tanlang
5. **Close** tugmasini bosing

### 4. Test qiling

1. Simulator'da app'ni run qiling
2. Plan page'ga o'ting
3. "Start my free trial" tugmasini bosing
4. StoreKit Configuration File'dan product'lar ko'rinishi kerak
5. Purchase qilish mumkin bo'lishi kerak

## 🔍 Tekshirish

Agar product'lar hali ham topilmasa:

1. **Product → Clean Build Folder** (Shift + Cmd + K)
2. Xcode'ni qayta ishga tushiring
3. Scheme'da StoreKit Configuration File tanlanganligini tekshiring
4. Simulator'ni restart qiling

## 📌 Eslatmalar

- StoreKit Configuration File faqat **Simulator'da** ishlaydi
- **Real device** yoki **TestFlight**'da App Store Connect'dan product'lar olinadi
- StoreKit Configuration File'dagi product ID'lar App Store Connect'dagi ID'lar bilan mos kelishi kerak

## 🛠️ Product ma'lumotlari

### Monthly Subscription
- **Product ID**: `com.nbekdev.vela.month`
- **Price**: $9.99/month
- **Free Trial**: 3 days
- **Subscription Period**: 1 month

### Annual Subscription
- **Product ID**: `com.nbekdev.vela.year`
- **Price**: $49.99/year
- **Free Trial**: 3 days
- **Subscription Period**: 1 year

## ⚠️ Muammo hal qilish

Agar product'lar hali ham topilmasa:

1. **Xcode → Product → Clean Build Folder**
2. **ios/Flutter/Generated.xcconfig** file'ni o'chirib, `flutter pub get` qiling
3. **ios/Pods** folder'ni o'chirib, `cd ios && pod install` qiling
4. Xcode'ni to'liq yopib, qayta oching
5. Scheme'da StoreKit Configuration File tanlanganligini tekshiring

