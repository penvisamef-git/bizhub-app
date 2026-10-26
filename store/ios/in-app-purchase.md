# BizHub (iPhone): coin packs with Apple in-app purchase

App Store rule 3.1.1: coins bought inside the iPhone app must use Apple's in-app purchase. The iPhone app shows the
same in-app coin shop as the Play app (`lib/features/owner/coin_play.dart`) and never points to the website's
KHQR / bank payments (`playBilling` is true on Android and iPhone).

## How it works
- App: StoreKit 2 (`in_app_purchase` + `in_app_purchase_storekit`). `appAccountToken` = a UUID the server makes
  from the account (`GET /api/user/coins/apple-packs` → `account_ref`).
- After paying, StoreKit gives a transaction **signed by Apple** (JWS). The app sends it to
  `POST /api/user/coins/apple/verify { productId, jws }`. The server checks Apple's certificate chain up to the
  pinned Apple Root CA - G3 and the signature (`bizhub-api/src/coin/apple_store.js`), checks the bundle id,
  product, account, adds the coins once (`ApplePurchase`, unique transaction id), and the app then finishes the
  transaction. No Apple key is needed on the server.
- Unfinished transactions (app closed / offline) are sent again on the next start.
- Refunds: App Store Server Notifications V2 → `POST /api/public/apple/notifications` takes the coins back once
  (what was already spent is recorded as `debt_coins`).
- Tests: `node scripts/test-apple-iap.js` (API, 39 checks), `flutter test test/coin_play_test.dart` (app).

## Server settings (optional, Vercel env)
| Name | Default | Meaning |
|---|---|---|
| `APPLE_BUNDLE_ID` | `com.bizhubcambodia.app` | only this app's purchases are accepted |
| `APPLE_IAP` | open | `off` closes buying coins on iPhone |
| `APPLE_ALLOW_SANDBOX` | allowed | App Review and TestFlight pay with sandbox accounts against the production server. Sandbox coins are saved with `usd: null` and payment reference `sandbox:<id>`. `false` refuses them (don't, while the app is in review). |

## To do in App Store Connect (after the developer account is active)
1. Agreements, Tax, and Banking → accept the **Paid Apps** agreement, add bank + tax (Mr Black types these).
2. App → Monetization → In-App Purchases → **Consumable** for each pack, the same ids as Google Play:
   `coins_100` ($10), `coins_250` ($25), `coins_500` ($50), `coins_1000` ($100), `coins_2500` ($250) (same USD as the web), with an EN + KM display name
   (e.g. "250 coins + 25 free") and a review screenshot of the coin shop.
3. App → App Information → **App Store Server Notifications**: Production and Sandbox URL
   `https://bizhub-api-eight-production.vercel.app/api/public/apple/notifications`, Version 2.
4. Users and Access → Sandbox → add a **sandbox tester** Apple ID to test purchases on a real iPhone / TestFlight.
5. Submit the in-app purchases together with the first app version.

The simulator can show the coin shop, but real purchases need a sandbox tester on a device (or a StoreKit
configuration file in Xcode; those test purchases are signed by Xcode, so the server correctly refuses them).
