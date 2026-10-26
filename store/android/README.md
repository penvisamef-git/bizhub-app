# BizHub on Google Play: step by step

- **Developer account:** **Blackcorp Enterprise** (personal account), signed in with **bizhubcambodia@gmail.com**.
- **App:** **BizHub**, package `com.bizhubcambodia.app`.
- **Website:** https://bizhubcambodia.com.

Links the Play Console asks for:

| Field | URL |
|---|---|
| Privacy policy | https://bizhubcambodia.com/privacy |
| Delete account (Data safety → "Data deletion") | https://bizhubcambodia.com/delete-account |
| Terms (optional) | https://bizhubcambodia.com/terms |

---

## 1. Create the Play developer account (once)

1. Go to https://play.google.com/console and sign in with **bizhubcambodia@gmail.com**.
2. Choose **Personal**. Enter your legal name, address and phone exactly as on your ID, and pay **US$25** with a card in the same name.
3. Finish the identity check: upload your ID when asked, and confirm your Android phone in the **Play Console** app.
4. Set the **developer name** to **Blackcorp Enterprise**. Use **bizhubcambodia@gmail.com** as the contact email and **https://bizhubcambodia.com** as the website.
5. Go to **All apps → Create app**:
   - name **BizHub**;
   - default language English (United States);
   - **App**, **Free**;
   - accept the declarations.

> A **personal** account must run a **closed test with at least 12 testers for 14 days in a row** before it can publish to everyone. Collect 12+ Gmail addresses (staff, friends, family) now.

## 2. Create the upload key (once, on your Mac)

The key proves that updates come from you. **Keep the `.jks` file and its password safe**, for example in a password manager plus a backup copy. If you lose it, Google has to reset it, which takes days.

```bash
mkdir -p ~/keys
keytool -genkeypair -v -keystore ~/keys/bizhub-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -dname "CN=Blackcorp Enterprise, O=Blackcorp Enterprise, L=Phnom Penh, C=KH"
```

It asks for a password; choose a strong one. Then create `bizhub-app/android/key.properties`. Git never includes this file.

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/blackcorp/keys/bizhub-upload.jks
```

## 3. Build the app for the store

From `bizhub-app`:

```bash
tool/build_release.sh          # first build
tool/build_release.sh --bump   # every later build (each upload needs a higher build number)
```

It uses `env.prod.json` (the production API) and your upload key. It refuses to build if either is missing. The file to upload is printed at the end:

`build/app/outputs/bundle/release/app-release.aab`

## 4. Upload to Closed testing (starts the 14 days)

1. Go to Play Console → **BizHub → Test and release → Testing → Closed testing → Create track** (or use "Alpha").
2. Under **Testers**, add an email list with your 12+ testers. Copy the **opt-in link** and send it to them. Each tester must open it, accept, and install BizHub from the Play Store.
3. **Create new release:**
   - upload `app-release.aab`;
   - when asked, keep **Google Play App Signing** on (recommended);
   - release name e.g. `1.0.0 (1)`;
   - release notes "First test version".
4. Send it for review. After it's approved, the 14 days count from when your 12 testers are opted in.

Ask testers to open BizHub a few times during the 14 days. Google checks that the test was real.

## 5. After the first upload: the two key fingerprints

Google re-signs the app with its own **app signing key**. You need the fingerprints of **both** keys: your upload key and Google's app signing key.

- **Upload key** (on your Mac):

  ```bash
  keytool -list -v -keystore ~/keys/bizhub-upload.jks -alias upload
  ```

  Copy the **SHA1** and **SHA256** lines.
- **App signing key:** Play Console → BizHub → **Test and release → Setup → App signing** (App integrity). Copy its **SHA-1** and **SHA-256**.

### 5a. App links: opening bizhubcambodia.com/app/... links in the app

Edit `bizhub/public/.well-known/assetlinks.json`. Replace the two placeholders with the **SHA-256** values (upload key and app signing key):

```json
"sha256_cert_fingerprints": ["AA:BB:…upload key…", "CC:DD:…Play app signing key…"]
```

Then deploy the web (`npm run deploy:prod` in `bizhub`). Check it at https://bizhubcambodia.com/.well-known/assetlinks.json.

### 5b. "Continue with Google" in the store app

Without this, Google sign-in works in debug builds but fails in the Play Store version.

1. Go to https://console.cloud.google.com, choose project **bizhub-cambodia**, then **APIs & Services → Credentials → Create credentials → OAuth client ID → Android**.
2. Package name: `com.bizhubcambodia.app`. SHA-1: the **app signing key** SHA-1.
3. Create a **second** Android client the same way, with the **upload key** SHA-1. That one is for builds you install yourself.
4. Leave `GOOGLE_WEB_CLIENT_ID` in `env.prod.json` as it is. The app uses the web client ID as the "server client". The Android clients only need to exist.

Then build again (`tool/build_release.sh --bump`) and upload. Google sign-in works for installs from Play.

## 6. Store listing and forms

Fill these in Play Console → **Grow → Store presence → Main store listing**, and the **Policy → App content** pages. The texts and pictures are in this folder (`listing.md`, `play-forms.md`, `screenshots/`).

| Form | Answer / where |
|---|---|
| App access | "All or some functionality is restricted", with a **test login for reviewers**: create a normal owner account on production with a few sample businesses and give its email and password. |
| Ads | No ads |
| Content rating | Fill the questionnaire (business / productivity app; no violence, no gambling). |
| Target audience | 18+ (business owners) |
| Data safety | See `play-forms.md`. Data deletion URL: https://bizhubcambodia.com/delete-account |
| Privacy policy | https://bizhubcambodia.com/privacy |
| Category | Business |
| Contact | bizhubcambodia@gmail.com, https://bizhubcambodia.com |

## 7. Go live

After **14 days** with **12+ opted-in testers**:

1. Go to Play Console → **Dashboard → Apply for production** and answer the questions about your test.
2. When Google approves, go to **Production → Create new release**, upload the latest `.aab`, and send it for review. That usually takes 1–7 days.

## Every update after that

```bash
tool/build_release.sh --bump
```

Upload the new `.aab` to the track you want (testing or production), with short release notes.

## Selling coins in the app (Google Play Billing)

In the Android app, coins can **only** be bought through Google Play Billing (Google's payments policy for Cambodia).
The app has no KHQR, bank or website payment options, links or wording. KHQR / bank top-ups stay on
bizhubcambodia.com. Coins from both go into the same wallet and can be spent in the app.

**Prices are the same as on the web.** The app's coin packs come from the web coin shop packages
(Super admin → Coin shop): the same coins, the same bonus %, the same USD price. The Google product id is `coins_<coins>`.

### 1. Payments profile (merchant account)
Play Console → **Setup → Payments profile**: create it with your legal name and address and a bank account that
can receive **USD** transfers. Google pays monthly (around the 15th) for the previous month.

### 2. Join the 15% service fee program
Play Console → **Setup → Monetization setup** (or **Account details → 15% service fee**): enrol. Without it Google
takes 30%. You receive about **85%** of each app sale; web/KHQR sales stay 100% yours.

### 3. Create the coin packs
Play Console → BizHub → **Monetize → Products → In-app products → Create product**, one per active web package:

| Product ID | Name | Price (USD) |
|---|---|---|
| `coins_100` | 100 coins | 10.00 |
| `coins_250` | 250 coins (+25 free) | 25.00 |
| `coins_500` | 500 coins (+75 free) | 50.00 |
| `coins_1000` | 1,000 coins (+200 free) | 100.00 |
| `coins_2500` | 2,500 coins (+750 free) | 250.00 |

(Check Super admin → Coin shop for the packages you really use; only packages that exist in Play Console show in the app.)
Set each **USD price = the web price**. Google converts it to riel (KHR) and other currencies for each customer, so the
riel amount may differ a little from the web. **If you change a web package price, change the Play Console price too**
(Google's price is what the customer pays in the app; the coins added always follow the web package).
Activate each product.

### 4. Service account (so the API can check purchases)
1. Google Cloud console (project linked to Play Console) → **IAM & Admin → Service accounts → Create**: name `bizhub-play`.
   No roles needed in Cloud. Then **Keys → Add key → JSON** and download it.
2. Enable the **Google Play Android Developer API** for that Cloud project.
3. Play Console → **Users and permissions → Invite new users** → the service account's email →
   app permissions for BizHub: **View financial data** and **Manage orders and subscriptions**. Save.
4. Put the key on the **production** API (Vercel → bizhub-api-eight-production → Settings → Environment Variables):
   - `GOOGLE_PLAY_SERVICE_ACCOUNT` = the whole JSON file content (one value)
   - `GOOGLE_PLAY_PACKAGE` = `com.bizhubcambodia.app`
   Or add both to `bizhub-api/.env.prod` and run `npm run env:prod`, then `npm run deploy:prod`.
   Permissions can take up to 24 hours to work after inviting the service account.

Without these variables the app says "Buying coins in the app isn't open yet" and nothing can be bought.

### 5. Refunds
The daily cron (`/api/cron/daily-report`) reads Google's voided purchases (refunds, chargebacks) and takes the coins
back once. If the customer already spent them, it takes what's left and records the rest as `debt_coins` on the
purchase (collection `googlepurchases`) for the team to follow up.

### 6. Test before going live
- Play Console → **Setup → License testing**: add your Gmail addresses. Testers pay with test cards (no real money).
- Upload a build to Internal testing, install it from the Play Store link, open **Buy coins**, buy a pack.
- Check: the coins arrive, the wallet shows "Google Play" as the payment, and the purchase can be bought again.
- Refund a test order in Play Console → **Order management** and check the coins are taken back after the next cron run.

A build outside Google Play (e.g. an APK you give to staff) can keep the bank / KHQR coin shop with
`--dart-define=WEB_BILLING=true`.
