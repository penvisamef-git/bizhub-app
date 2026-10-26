# BizHub (owner + super admin app)

Flutter app for Android and iOS. Same look, same words (EN / ខ្មែរ) and same API as the BizHub website.

- **Business owner** → Dashboard · Wallet · Licenses · More (add business, buy coins, account)
- **Super admin** (BizHub team account with super admin) → Dashboard · Customers · Businesses · Coins · More (coin orders…)
- Big editors (website builder, restaurant setup, name card designer…) open the web screen inside the app, already logged in.

App ID: `com.bizhub.admin`

## Run it

```bash
cp env.example.json env.json        # fill in your values (never commit env.json)
flutter pub get
flutter run --dart-define-from-file=env.json
```

`WEB_LOGIN_KEY` must equal the website's `VITE_LOGIN_STORAGE_KEY`, or the web screens inside the app (business tools) open on the login page.

Test with the local API without Google/Firebase (fake Google account and links — the API must run with NODE_ENV=test and FIREBASE_TEST_TOKENS=1):

```bash
flutter run --dart-define=API_HOST=http://192.168.1.10:8086 --dart-define=SITE_URL=http://192.168.1.10:3000 --dart-define=FAKE_AUTH=true
```

(On a real phone use your computer's Wi-Fi IP, not localhost.)

Build for the stores:

```bash
flutter build appbundle --dart-define-from-file=env.json   # Android → Google Play
flutter build ipa --dart-define-from-file=env.json         # iOS → App Store (on a Mac)
```

## Log in and sign up (same as the website)

- **Log in:** Continue with Google, or email + password.
- **Sign up:** Continue with Google → name, phone (optional), password → account + free coins.
  Or "Send confirm link" to any email → the link opens the website, where the person finishes; then they log in here.
- **Forgot password:** a link to the email → new password on the website.

Firebase only proves the email (same project as the website). Setup once:

1. `FIREBASE_API_KEY` = the web's `VITE_FIREBASE_API_KEY`.
2. `GOOGLE_WEB_CLIENT_ID`: Firebase console → Authentication → Sign-in method → Google → *Web SDK configuration* → Web client ID.
3. Firebase console → Project settings → **Add app → Android**, package `com.bizhub.admin`, and add the SHA-1 of your key
   (`cd android && ./gradlew signingReport`, the `debug` SHA1 for testing, and later the release / Play Store key).
   Google sign-in on Android works only after this.
4. The links open `SITE_URL`: its domain must be in Firebase → Authentication → Settings → **Authorized domains**
   (for testing on Wi-Fi add your computer's IP, e.g. `192.168.1.9`).

## Texts

`assets/i18n/en.json` and `km.json` are made from the website's own text files, so both say the same thing.
After changing texts on the website, run:

```bash
node tool/extract_texts.js ../bizhub/src assets/i18n
```

Words only the app has are in `lib/core/app_text.dart`.

## Code map

- `lib/core` — settings, API client, login, theme colours (same tokens as the web), texts, formatting
- `lib/features/onboarding` — language + 4 "Get started" screens (the website banner)
- `lib/features/auth` — log in, sign up (Google or email link), forgot password
- `lib/features/owner` — dashboard, wallet, licenses, add business, buy coins
- `lib/features/admin` — super admin dashboard, customers, businesses, coins, coin orders
- `lib/features/common` — app frame (header + bottom bar), account, web screens inside the app
