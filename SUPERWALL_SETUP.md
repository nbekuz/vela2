# Superwall Dashboard'da Narxlarni Sozlash

## 1. Products (Mahsulotlar) Qo'shish

### Qadamlar:
1. **Superwall Dashboard** → **Products** bo'limiga o'ting
2. **"Add Product"** yoki **"+"** tugmasini bosing
3. Quyidagi ma'lumotlarni kiriting:

   **Monthly Plan:**
   - **Product ID:** `com.nbekdev.vela` (yoki App Store Connect'dagi subscription Product ID)
   - **Type:** Subscription
   - **Duration:** 1 month
   - **Price:** $9.99/month

   **Annual Plan:**
   - **Product ID:** `com.nbekdev.vela.annual` (yoki App Store Connect'dagi annual subscription Product ID)
   - **Type:** Subscription  
   - **Duration:** 1 year
   - **Price:** $49.99/year

## 2. Paywall Dizaynini Yaratish

### Qadamlar:
1. **Superwall Dashboard** → **Paywalls** bo'limiga o'ting
2. **"Create Paywall"** tugmasini bosing
3. Paywall dizaynini sozlang:
   - Dizaynni tanlang (template yoki custom)
   - Product'larni qo'shing (monthly va annual)
   - Narxlarni ko'rsating
   - Dizaynni saqlang

## 3. Campaign Yaratish

### Qadamlar:
1. **Superwall Dashboard** → **Campaigns** bo'limiga o'ting
2. **"Create Campaign"** tugmasini bosing
3. Campaign nomini kiriting:
   - **Monthly Plan Campaign:** `monthly_plan`
   - **Annual Plan Campaign:** `annual_plan`
4. Paywall'ni tanlang (yuqorida yaratilgan paywall)
5. Trigger event'ni sozlang (yoki manual trigger)
6. Campaign'ni saqlang

## 4. App Store Connect'da Product ID'larni Qo'shish

### Qadamlar:
1. **App Store Connect** → **Apps** → **Vela** → **Subscriptions**
2. Subscription yaratilganligini tekshiring:
   - Product ID: `com.nbekdev.vela`
   - Duration: 1 month
   - Price: $9.99/month

3. Agar annual plan kerak bo'lsa:
   - Yana bir subscription yarating:
   - Product ID: `com.nbekdev.vela.annual` (yoki boshqa ID)
   - Duration: 1 year
   - Price: $49.99/year

## 5. Superwall'da Product ID'larni Bog'lash

### Qadamlar:
1. **Superwall Dashboard** → **Products** bo'limiga o'ting
2. Har bir product'ni tanlang
3. **App Store Connect Product ID** ni kiriting:
   - Monthly: `com.nbekdev.vela`
   - Annual: `com.nbekdev.vela.annual` (yoki App Store Connect'dagi ID)

## 6. Test Qilish

### Qadamlar:
1. **TestFlight**'da ilovani o'rnating
2. **Sandbox Test Account** yarating:
   - App Store Connect → Users and Access → Sandbox Testers
3. Ilovada plan page'ga o'ting
4. "Start my free trial" tugmasini bosing
5. Superwall paywall ko'rinishi kerak
6. Sandbox account bilan test qiling

## Muhim Eslatmalar:

- **Product ID** App Store Connect va Superwall'da bir xil bo'lishi kerak
- **Campaign nomi** kodda ishlatilgan nom bilan mos kelishi kerak (`monthly_plan`, `annual_plan`)
- **Narxlar** App Store Connect'da sozlangan narxlar bilan mos kelishi kerak
- TestFlight'da test qilish uchun Sandbox account kerak

## Kodda Ishlatilgan Campaign Nomlari:

- `monthly_plan` - Monthly subscription uchun
- `annual_plan` - Annual subscription uchun

Bu nomlar `lib/pages/plan_page.dart` faylida ishlatilgan.


