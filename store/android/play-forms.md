# BizHub: draft answers for the Play Console forms

**Draft for Mr Black to review.** These answers are based on the app code as it is now: the plugins in `pubspec.yaml`, the Android permissions, the BizHub API and the crash reporter. If you add analytics, ads, location or a new SDK later, update **Data safety** before the next release.

- **Developer:** Blackcorp Enterprise
- **Email:** bizhubcambodia@gmail.com
- **Website:** https://bizhubcambodia.com
- **Privacy policy:** https://bizhubcambodia.com/privacy
- **Account deletion:** https://bizhubcambodia.com/delete-account (also in the app: Account → Delete account)

---

## 1. App content → Privacy policy

URL: `https://bizhubcambodia.com/privacy`

## 2. App content → Ads

**Does your app contain ads?** No.

## 3. App content → App access

**All or some functionality is restricted** → Yes, users must sign in.

Give the reviewers a demo login. It is made on production by `bizhub-api/scripts/demo-reviewer.js` (run `node scripts/demo-reviewer.js` to see what it will do, then `node scripts/demo-reviewer.js --yes`). Never use a real customer account.

| Field | Value |
|---|---|
| Name | Google Play review |
| Username | `playreview@bizhubcambodia.com` |
| Password | printed once by the script; type it only into Play Console. Running the script again sets a new one. |
| Instructions | Sign in with the email and password. The account has a sample name card (Sokha Design Studio), restaurant (Mekong Kitchen), mini mart (Lucky Mini Mart), guest house (Lotus Guest House), event (Khmer New Year Party) and Digital Note (Team Notes), plus 1,000 coins, so every screen and add-on can be opened. No SMS or email code is needed. |

## 4. App content → Target audience and content

- **Target age groups:** 18 and over. BizHub is a business tool.
- **Could the app appeal to children?** No.

## 5. App content → Content rating (IARC questionnaire)

- **Email:** bizhubcambodia@gmail.com
- **Category:** All other app types (Utility, Productivity, Communication, or Other). Not a game.

| Question | Answer | Why |
|---|---|---|
| Violence, blood, gore | No | |
| Fear or horror | No | |
| Sexual content or nudity | No | |
| Profanity or crude humour | No | |
| Drugs, alcohol, tobacco | No | A restaurant can list drinks on its menu, but the app does not promote or sell alcohol itself. Answer No unless the questionnaire asks specifically about references in user content. |
| Gambling (real or simulated) | No | Loyalty stamps and coins are not gambling. There are no random rewards. |
| **Users can interact or exchange content** | **Yes** | Digital Note public pages accept replies, sign-ups and files from guests. Name cards, menus, websites and event pages are public. |
| Shares the user's current location | No | The app has no location permission. A name card can link to a map address the owner types. |
| Allows digital purchases | **Yes** | BizHub Coin packs, sold with Google Play billing (see section 8). |
| Unrestricted internet access (web browser) | No | Web pages open in the system browser or inside the app only for BizHub pages. |

Expected rating: **Everyone / PEGI 3 / IARC 3+**, with the notes "Users Interact" and "In-App Purchases".

## 6. App content → Data safety

### Overview

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS only) |
| Do you provide a way for users to request that their data is deleted? | **Yes**: in the app and at https://bizhubcambodia.com/delete-account |

**Sharing.** BizHub does not sell data or share it with third parties for their own use. The services below process data **on BizHub's behalf** (service providers), which Google does **not** count as "sharing":

- Vercel (API hosting)
- MongoDB Atlas (database)
- Cloudinary (photos and files)
- Firebase Authentication / Google Sign-In (sign-in)
- Telegram (alerts sent to the owner's own Telegram, and crash alerts to the BizHub team)

So answer **Shared: No** for every type.

### Data types

Tick only these. For each one: **Collected: Yes · Shared: No · Processed only on the device: No**.

| Category → type | Required or optional | Purposes (tick) | Where it comes from in the app |
|---|---|---|---|
| **Personal info → Name** | Required | App functionality, Account management | Sign-up, profile, name cards |
| **Personal info → Email address** | Required | App functionality, Account management, Developer communications | Sign-up and sign-in, Google Sign-In, receipts |
| **Personal info → Phone number** | Optional | App functionality | Profile, name card, business contact |
| **Personal info → Address** | Optional | App functionality | Business address the owner types on a name card, website or event |
| **Personal info → User IDs** | Required | App functionality, Account management | The BizHub account ID and the Google account ID when signing in with Google |
| **Financial info → Purchase history** | Required (when coins are used) | App functionality | Coin pack purchases (through Google Play), top-up card redemptions and coin spending in the wallet. Card details are handled by Google Play; the app does **not** collect card or bank numbers. |
| **Photos and videos → Photos** | Optional | App functionality | Logos, product and room photos, note images (image_picker, camera) |
| **Photos and videos → Videos** | Optional | App functionality | Video files attached to notes |
| **Audio → Voice or sound recordings** | Optional | App functionality | Voice notes in Digital Note (RECORD_AUDIO, only while the user records) |
| **Files and docs → Files and docs** | Optional | App functionality | PDFs for flip books, files attached to notes (file_picker) |
| **Messages → Other in-app messages** | Optional | App functionality | Replies and sign-ups on Digital Note pages, guest comments |
| **App activity → Other user-generated content** | Optional | App functionality | Menus, products, bookings, debts, attendance records, note text |
| **App info and performance → Crash logs** | Required | Analytics (app stability) | `Crash.install()` sends the error message, stack trace, screen, app version, OS and the signed-in user's ID and email to the BizHub API |
| **App info and performance → Diagnostics** | Required | Analytics (app stability) | App version, platform and OS version sent with crash reports |
| **Device or other IDs** | Not collected | | The app doesn't read the advertising ID or the device ID. Tick it only if a future SDK does. |

**Do not tick:**

- Location (no location permission);
- Contacts;
- Calendar;
- Health;
- Web browsing;
- Installed apps;
- Credit or debit card numbers (no card form in the app);
- Race, religion and the other sensitive types.

**Camera.** Scanning QR codes and barcodes (mobile_scanner) reads the camera image **on the device only**; nothing is uploaded. That is not "collection". Photos taken with the camera *and uploaded* are already covered by "Photos".

**Account creation methods:** Username, password and other authentication (SMS code or email link) + OAuth (Google). **Delete some data without deleting the account:** answered No (optional question).

### Security practices

- **Data is encrypted in transit:** Yes.
- **Users can request that data be deleted:** Yes.
- **Committed to the Play Families Policy:** No (not a children's app).
- **Independent security review:** No.

## 7. Account deletion (Play policy)

- **In-app path:** Account (avatar) → **Delete account**.
- **Web link for the form:** https://bizhubcambodia.com/delete-account. It must work without the app installed.
- **What is deleted:** the account, profile, businesses and their content, and uploaded files.
- **What is deleted, and when:** everything above, 30 days after the request (signing in again during those 30 days cancels it). Links and QR codes of the businesses stop working.
- **What is kept, and for how long:** coin purchase and payment records (including Google Play purchases) for 5 years, without name or contact details, for accounting and tax; login and error logs for up to 90 days. The same text is on /privacy and /delete-account.

## 8. Payments policy: BizHub Coins (decided: Google Play billing)

Mr Black chose **option 1**: in the Android app, coins are sold **only with Google Play billing**.

- **Same packs and prices as the web:** 100 / 250 (+10%) / 500 (+15%) / 1,000 (+20%) / 2,500 (+30%) coins at $10 / $25 / $50 / $100 / $250. The Play products are `coins_100`, `coins_250`, `coins_500`, `coins_1000` and `coins_2500`.
- **Nothing else for coins on Android:** the app shows no KHQR, bank transfer or link to buying on the website. Redeeming a top-up card code stays, because Google allows gift-card redemption.
- **Fee:** Google takes **15%** after you join the 15% service-fee programme (Play Console → Monetization setup). Without it, the fee is 30%.
- **Payouts:** monthly, in USD, to the bank account in your payments profile.
- **Event tickets paid by KHQR are fine.** The business's own customers are paying for a real event, which is a physical service and exempt.
- **Store listing:** no wording that sends people to buy coins outside the app. `listing.md` is updated.
- **Setup steps:** products, service account and testing are in `README.md` → "Selling coins in the app (Google Play Billing)".

## 9. Other declarations

| Form | Answer |
|---|---|
| News app | No |
| COVID-19 contact tracing or status | No |
| Government app | No |
| Financial features (Play "Financial features" declaration) | **Rewards, points and other incentives** (loyalty stamp cards and restaurant points). Saved: Google asks for no documents. The debt book is personal record keeping only: no loans and no money transfers. |
| Health apps | No health features |
| Photo and media permissions | Uses the system photo picker (image_picker); no broad `READ_MEDIA_IMAGES` permission needed. Check the merged manifest before upload. |
| Foreground service / exact alarms | None |
| Advertising ID | **No**, the app doesn't use the advertising ID. If the merged manifest contains `com.google.android.gms.permission.AD_ID`, add `tools:node="remove"` for it. |

## 10. What is filled in Play Console (22 Oct 2026)

- Done and saved: privacy policy, ads (no), government (no), financial features, health (none), advertising ID (no), store settings (Business, email, website), default store listing English + Khmer (texts, icon, feature graphics, 8 screenshots each, AI label: not AI-generated).
- Drafts waiting for Mr Black: Sign in details (type the password, tick the full-access box), Content rating (tick the IARC terms), Target audience (opens after Sign in details), Data safety (final Save after Target audience).
- Screenshot 07 now says coins are bought in the app (no KHQR for coins).
