# Wylde Self iOS — TestFlight Submission Guide

End-to-end checklist to get the app into TestFlight beta. Assumes you're already enrolled in Apple Developer Program.

**Total time: ~3 hours of your work + 24-48 hr Apple review.**

---

## Prerequisite — confirm you have these

- [ ] Apple Developer Program membership (active)
- [ ] Mac with Xcode 15.0+ installed
- [ ] App icon: 1024×1024 PNG, RGB, no transparency, no rounded corners
  - (We've placed `Wyldeselflogo2.png` as a placeholder. Swap with designer-final before App Store launch — TestFlight is fine with the placeholder.)
- [ ] Privacy policy URL — get one for $0 at https://privacypolicies.com if you don't have one yet

---

## Step 1 — App Store Connect: create the app entry (15 min)

1. Go to https://appstoreconnect.apple.com → My Apps → **+** → New App
2. Fill in:
   - **Platform:** iOS
   - **Name:** Wylde Self
   - **Primary language:** English (U.S.)
   - **Bundle ID:** `com.wylde.self` (or your chosen ID — must match Xcode → Target → General → Bundle Identifier)
   - **SKU:** `wylde-self-001` (any unique string)
   - **User access:** Full Access
3. Click Create

---

## Step 2 — Configure Bundle ID + Signing in Xcode (15 min)

Open `WyldeSelf.xcodeproj` in Xcode.

1. Click the project in the navigator → **WyldeSelf target** → Signing & Capabilities
2. Set:
   - **Team:** your developer team
   - **Bundle Identifier:** `com.wylde.self` (must match App Store Connect)
   - **Automatically manage signing:** ✓ checked
3. Xcode will fetch a provisioning profile automatically. Wait for the green checkmark.

If you see "No signing certificate":
- Open Xcode → Settings → Accounts → your Apple ID → Manage Certificates → + → Apple Development
- Repeat the Signing & Capabilities step

---

## Step 3 — Increment version (2 min)

Open `WyldeSelf/Info.plist` (or General tab in Xcode):
- **Version (CFBundleShortVersionString):** `1.0.0`
- **Build (CFBundleVersion):** increment by 1 each time you upload (start at `1`)

For TestFlight, build number must be unique per upload. Apple won't let you overwrite.

---

## Step 4 — Test on simulator first (10 min)

1. In Xcode → Choose a simulator (iPhone 15 Pro recommended)
2. Cmd + R to build & run
3. Verify:
   - [ ] Launch screen shows the Wylde logo
   - [ ] Today screen renders
   - [ ] Hamburger drawer opens from left, lists vertically
   - [ ] All 4 bottom tabs work (Today / Future / Coach / Progress)
   - [ ] WebView tabs load wyldeself.com content
   - [ ] No crashes

If anything's broken — fix before archiving.

---

## Step 5 — Archive + Upload (15 min)

1. In Xcode top bar, change the device target from a simulator to **Any iOS Device (arm64)**
2. Product menu → **Archive**
3. Wait for archive to complete (5-10 min)
4. The Organizer window opens automatically
5. Click your build → **Distribute App**
6. Choose:
   - **App Store Connect**
   - **Upload**
   - Distribution certificate: auto
   - Include bitcode: deprecated, leave default
   - Strip Swift symbols: ✓
   - Upload symbols: ✓
7. **Upload**

Apple processes the build for ~10-30 minutes. You'll get an email when it's ready.

---

## Step 6 — Configure TestFlight (10 min)

Once Apple finishes processing:

1. App Store Connect → your app → **TestFlight** tab
2. Wait for the build to appear (left sidebar shows it under your iOS version number)
3. Click the build → **Test Information**:
   - **What to test:** *"Beta — main flows: onboarding, today screen, coach, library, paywall."*
   - **Beta App Description:** *"Wylde Self — your future self, daily."*
   - **Email:** your support email
   - **Marketing URL:** `https://wyldeself.com`
   - **Privacy policy URL:** required, paste yours
4. Save

5. Add **Export Compliance** info:
   - Does your app use encryption? → Standard HTTPS only? → exempt
   - Mark as compliant

6. Once compliant + processed, the build is ready for **Internal Testing**

---

## Step 7 — Add Internal Testers (5 min)

Internal testers are people on your App Store Connect team. No Apple review needed — they get the build immediately.

1. App Store Connect → Users and Access → **+** → add your contacts as Internal Testers (only their Apple ID email needed)
2. TestFlight tab → Internal Testing → + Group → name it "Founders" or similar
3. Add the testers
4. Add the build
5. They get an email + can install via the TestFlight app

**For external testers** (more than 100 people), you need to submit for Beta App Review (24-48 hr Apple review). For your initial founders contact list, internal testing is faster.

---

## Step 8 — Send the founder offer to your contacts

Once TestFlight is live, send a single message to your contacts (see `STRIPE_SETUP.md` for outreach template). They get:

1. **TestFlight invite link** — install the iOS beta (free during beta)
2. **Stripe checkout link** — `https://wyldeself.com/founder.html?tier=lifetime` to lock in $149 lifetime founder pricing

Both work in parallel.

---

## Common issues

**Archive grayed out**
→ Device target is set to a simulator. Change to "Any iOS Device".

**"Provisioning profile doesn't include device"**
→ Only an issue when running on a physical device, not for archive uploads. For TestFlight, you don't need this.

**"Code signing identity does not match"**
→ Xcode → Settings → Accounts → re-download manual profiles. Or toggle "Automatically manage signing" off + back on.

**Build uploads but doesn't appear in TestFlight**
→ Check the email Apple sent — they often reject builds for missing `NSCameraUsageDescription` etc. Our Info.plist already has all required usage strings, but verify if Apple flags anything.

**"Missing compliance" warning in TestFlight**
→ Step 6.5 — answer the encryption question (standard HTTPS = exempt).

**Testers don't see the build**
→ They need the TestFlight app installed on iPhone first. They get an email with an install link → opens TestFlight → installs Wylde Self.

---

## Once TestFlight is happy — App Store submission later

When you're ready for the public App Store:
1. Same archive + upload flow
2. App Store Connect → App Store tab → Prepare for Submission
3. Add: app description, keywords, screenshots (3 sizes minimum: 6.7", 6.5", 5.5"), category, age rating
4. **Submit for Review** — Apple takes 24h-7days
5. After approval, choose to release immediately or hold for manual release

Don't worry about App Store today — TestFlight is the goal. App Store is the next milestone after the beta proves out.

---

## RevenueCat — for in-app purchases later

The native iOS PaywallView is currently in stub mode (simulated purchases). To make it actually charge real money via Apple IAP:

1. Follow the steps in `PAYWALL_SETUP.md`
2. Your TestFlight beta works WITHOUT this — you can test the app flow without real purchases
3. Add RevenueCat once you're ready to flip on iOS-side payments

**For your initial founders push**, web Stripe is the primary path (see `STRIPE_SETUP.md`). iOS IAP can come post-launch.

---

## You're set

After Step 7, your iOS app is live in TestFlight. Send the founder link + the TestFlight install link to your contacts. Track:

- **TestFlight** → who's installed + active sessions
- **Supabase** → `SELECT COUNT(*) FROM profiles WHERE founding_member_number IS NOT NULL` for paid founders
- **Stripe Dashboard** → revenue + checkout conversion rate
