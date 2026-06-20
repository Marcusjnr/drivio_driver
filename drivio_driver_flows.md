# Drivio Driver — Screen Catalog & Flow Reference

**Purpose:** Every screen in the driver app, with enough detail to generate mockups via ChatGPT (or any image-gen model). Plus end-to-end flow sequences that link screens.

**Use this document like:**
1. **For a single screen mockup:** find the screen in §3 (Screen Catalog). Copy the brand prefix from §2 + the screen's prompt block. Paste into ChatGPT.
2. **For a full flow mockup set:** go to §4 (Flow Catalog), pick a flow, generate each screen in the sequence using the prompts in §3.
3. **For brand context only:** §2 is the copy-paste brand prefix.

---

## 1. How to Use This Document for Mockup Generation

### 1.1 Recommended workflow

1. Copy the **§2 Brand prefix** once. It anchors ChatGPT to the right visual world.
2. For each screen you want to mock, find it in §3 by screen ID (SCR-001 through SCR-061).
3. Concatenate: `<brand prefix> + <screen's prompt block>` → paste to ChatGPT.
4. ChatGPT generates the mockup. Refine by editing the prompt block.

### 1.2 What's in a screen entry

Each screen has:
- **ID** (`SCR-001` etc.)
- **Name**
- **Purpose** — one line
- **Reached from / Reaches** — flow position
- **Layout** — top-to-bottom description
- **Copy** — exact strings
- **States** — loading, empty, error, success
- **Mockup prompt** — ready to paste

### 1.3 Conventions

- **Coral** = primary brand color `#EE6F4A`. Use for live state, primary CTA, the wordmark dot, pickup pin.
- **Teal** = secondary `#236767`. Use for depth, drop-off, calm metadata.
- **Butter** = accent `#F1B940`. Sparing — peak tags, stars.
- **Charcoal-teal** = anchor `#0E2E2E`. Text in light mode, BG in dark.
- **Ivory** = base `#F4ECE0`. Light-mode background.
- **Default theme**: light. All examples here assume light mode unless noted.
- **Device frame**: iPhone 14 baseline (390 × 844 logical, 1170 × 2532 px at @3x).

---

## 2. Brand Prefix (copy-paste this before every screen prompt)

```
You're designing a screen for "Drivio" — a warm, premium, pan-African ride-hailing app for drivers in Lagos. Drivers set their own prices for every ride and keep 100% of fares (Drivio takes a tiered subscription — Daily ₦2,500, Weekly ₦15,000, Monthly ₦50,000 — not a per-trip cut).

VISUAL LANGUAGE
- Palette (Coastal Pulse):
  - Coral #EE6F4A (primary — live state, primary CTAs, pickup pin, the wordmark dot)
  - Teal #236767 (secondary — depth, dropoff pin, calm metadata)
  - Butter #F1B940 (sparing accent — peak tags, stars)
  - Charcoal-teal #0E2E2E (text, top-bar logo)
  - Ivory #F4ECE0 (background, breathing space)

- Typography:
  - Display + headlines + wordmark: Marcellus serif (Roman-inscriptional, Italian-Renaissance refinement)
  - UI body + buttons + captions: Albert Sans (humanist sans, modern)
  - Mono for codes/plates/timers: system monospace

- Wordmark: "Drivio" in Marcellus headline-case, with a small coral dot accent immediately after the "o", baseline-aligned with a slight bottom offset.

- Iconography: Lucide (line icons, 2.0px stroke, geometric, quiet).

- Photography (when present): warm editorial portraits of real African drivers + cinematic golden-hour African cityscapes. Never US/European stock. Never flat studio.

- Tone: calm, considered, premium-warm. Generous whitespace. No exclamation marks (except success states). No fake iOS status bar / home indicator — the OS owns those pixels. No emoji in headings.

- Motion language (for transitions): 260–320ms easeOutQuart, no springs, editorial stagger.

DEVICE
- iPhone 14 mockup (portrait, 390 × 844 logical / 1170 × 2532 px).
- Show in a clean phone bezel with rounded corners.
- The OS status bar at top (time 9:41, signal, wifi, battery) is visible but small — Drivio doesn't render it itself.

DEFAULT THEME: Light (ivory background, charcoal-teal text). If the screen description says "dark", invert.

NOW DESIGN THE FOLLOWING SCREEN:
```

(Append the per-screen prompt block from §3.)

---

## 3. Screen Catalog

Screens are grouped by area. Each has an ID, layout, copy, states, and a ready-to-paste prompt block.

---

### 3.1 Onboarding & Auth

#### SCR-001 — Splash

**Purpose:** First screen on every launch. Brand reveal + location permission ask + auth route decision.

**Reached from:** App launch (always)
**Reaches:** `/welcome` (signed out) or `/home` (signed in)

**Layout (top to bottom):**
- Full-bleed charcoal-teal background
- Center: large "Drivio" wordmark in Marcellus, ~120pt, ivory color, with a coral dot accent
- Below wordmark: italicized tagline in two lines, Marcellus 28pt
  - Line 1: "Movement," (ivory)
  - Line 2: "on your terms." (coral)
- Below tagline: animated coral radar pulse (3 concentric rings expanding, staggered)
- Bottom 200px: location permission card (rises after 1100ms brand-reveal hold)
  - White/ivory card with rounded top corners, shadow
  - Icon + headline ("Find your pickup")
  - Body copy ("Allow location so we can match you with nearby riders.")
  - Primary CTA: "Allow location" (coral, full-width)
  - Ghost button: "Not now"

**Copy:**
- Wordmark: `Drivio`
- Tagline: `Movement, on your terms.`
- Permission card title: `Find your pickup` (varies by permission state)
- Permission body: `Allow location so we can match you with nearby riders.`
- Primary CTA: `Allow location`
- Ghost button: `Not now`

**States:**
- **Brand reveal (first 1.1s):** only wordmark + pulse animation visible
- **Permission denied:** card body changes to "Location is blocked. Enable it in Settings."; CTA becomes "Open Settings"
- **Services disabled:** card body "Turn on Location Services to find your pickup."; CTA "Open location settings"
- **Already granted (returning user):** card skipped; splash holds 1100ms then routes

**Mockup prompt block:**
```
SCREEN: Drivio Splash
- Full-bleed dark charcoal-teal (#0E2E2E) background.
- Center vertically: massive "Drivio" wordmark, Marcellus serif, ivory (#F4ECE0), ~120pt, with a coral (#EE6F4A) dot immediately after the "o", baseline-aligned, ~10pt diameter.
- Below wordmark, in italic Marcellus 28pt: two lines
  - "Movement," in ivory
  - "on your terms." in coral
- Behind the wordmark: 3 concentric coral rings (radar pulse), thin stroke, expanding outward, slightly transparent.
- Bottom 25% of the screen: light-ivory card (rounded top corners, soft shadow) rising from the bottom.
  - Inside the card: a small coral location-pin icon (Lucide, line style)
  - Heading: "Find your pickup" in Marcellus 18pt, charcoal-teal
  - Body: "Allow location so we can match you with nearby riders." in Albert Sans 14pt, dim charcoal-teal
  - Primary button (full-width): "Allow location" in coral background, ivory text, Albert Sans bold
  - Below the button: "Not now" in Albert Sans 13pt, dim charcoal-teal, centered
- iOS status bar at top (time 9:41).
```

---

#### SCR-002 — Welcome

**Purpose:** Signed-out landing. Choose Sign Up or Sign In.

**Reached from:** Splash (no session) or sign-out
**Reaches:** `/sign-up` or `/sign-in`

**Layout:**
- Full-bleed ivory background
- Top: small "Drivio" wordmark in Marcellus, ~22pt, charcoal-teal, with coral dot
- Middle 60%: hero photography (real African driver portrait, warm editorial lighting)
- Below photo:
  - Eyebrow uppercase Albert Sans 11pt charcoal-teal-dim: "DRIVE WITH DRIVIO"
  - Headline Marcellus 36pt charcoal-teal: "Set your price. Keep what you earn."
  - Body Albert Sans 14pt charcoal-teal-dim: "Drivio doesn't take a per-trip cut. You decide what each ride is worth."
- Bottom 200px stacked CTAs:
  - Primary (coral fill, ivory text): "Get started"
  - Ghost (charcoal-teal text, no fill): "I already have an account"

**Copy:**
- Wordmark: `Drivio`
- Eyebrow: `DRIVE WITH DRIVIO`
- Headline: `Set your price. Keep what you earn.`
- Body: `Drivio doesn't take a per-trip cut. You decide what each ride is worth.`
- Primary CTA: `Get started`
- Secondary CTA: `I already have an account`

**Mockup prompt block:**
```
SCREEN: Drivio Welcome (signed out)
- Light ivory (#F4ECE0) background.
- Top bar: small "Drivio" wordmark in Marcellus serif, 22pt charcoal-teal (#0E2E2E), with a coral (#EE6F4A) dot after the "o". Left-aligned with 24pt padding.
- Hero photo area (60% of screen): warm editorial portrait of a real African driver in his 30s, lit naturally, looking slightly off-camera, premium Vogue-Africa lighting. Photo fills the width edge-to-edge.
- Below the photo, with 24pt margins:
  - Small uppercase eyebrow in Albert Sans bold 11pt, letter-spaced 1.6, dim charcoal-teal: "DRIVE WITH DRIVIO"
  - Headline in Marcellus 36pt, charcoal-teal: "Set your price. Keep what you earn."
  - Body in Albert Sans 14pt, dimmer charcoal-teal: "Drivio doesn't take a per-trip cut. You decide what each ride is worth."
- Bottom 25% of screen:
  - Primary button (full-width, coral background, ivory text, 52pt height): "Get started" in Albert Sans bold
  - Below: text-only button "I already have an account" in Albert Sans 14pt charcoal-teal, centered
- iOS status bar at top.
```

---

#### SCR-003 — Sign Up

**Purpose:** Create a new driver account.

**Reached from:** Welcome → "Get started"
**Reaches:** OTP

**Layout:**
- Ivory background
- Top: small back button (BackButtonBox, 32×32 rounded square)
- Top eyebrow: "STEP 1 OF 2"
- Title (Marcellus 28pt): "Create your account"
- Body (Albert Sans 14pt dim): "Phone, then a few quick details."
- Stacked compact form fields (each with floating label):
  - Full name
  - Email
  - Phone (PhoneNumberInput: 🇳🇬 +234 prefix + numeric input)
  - Password (with eye toggle)
  - Referral code (optional, smaller)
- Bottom (always visible):
  - Primary CTA: "Continue" (coral, disabled until form valid)
  - Below CTA: small text "By continuing you agree to our Terms" with linked words

**Copy:**
- Eyebrow: `STEP 1 OF 2`
- Title: `Create your account`
- Body: `Phone, then a few quick details.`
- Field labels: `Full name`, `Email`, `Phone`, `Password`, `Referral code (optional)`
- CTA: `Continue`
- Footer: `By continuing you agree to our Terms and Privacy Policy`

**States:**
- Empty (default)
- Filled (CTA enabled, coral, 100% opacity)
- Invalid email (red eyebrow on the email field)
- Phone already in use (after submit, banner: "That number already has an account. Sign in instead.")

**Mockup prompt block:**
```
SCREEN: Drivio Sign Up form
- Light ivory (#F4ECE0) background.
- Top: rounded 32x32 back button (left arrow Lucide icon), top-left with 24pt padding.
- Eyebrow uppercase Albert Sans bold 11pt letter-spaced 1.6, dim charcoal-teal: "STEP 1 OF 2"
- Title in Marcellus 28pt charcoal-teal: "Create your account"
- Subtitle in Albert Sans 14pt dim: "Phone, then a few quick details."
- Stacked form fields (each 56pt tall, ivory-light background, hairline border):
  - "Full name" input
  - "Email" input
  - "Phone" with Nigerian flag + "+234" prefix + numeric field
  - "Password" with eye-icon visibility toggle
  - "Referral code (optional)" smaller, lighter
- Each field has a floating label that floats above when focused, like a Material 3 text field.
- Bottom 80pt section pinned to bottom:
  - Primary "Continue" button (full-width, coral #EE6F4A, ivory text, 52pt, Albert Sans bold)
  - Small centered text below: "By continuing you agree to our Terms and Privacy Policy" in Albert Sans 11pt dim, with "Terms" and "Privacy Policy" underlined
- iOS status bar at top.
```

---

#### SCR-004 — Sign In

**Purpose:** Existing drivers sign back in.

**Reached from:** Welcome → "I already have an account"
**Reaches:** OTP

**Layout:**
- Same shell as Sign Up (back button, eyebrow, title)
- Title (Marcellus 28pt): "Welcome back, driver"
- Body (Albert Sans 14pt): "Phone and password."
- Two form fields:
  - Phone (PhoneNumberInput)
  - Password
- Below fields: "Forgot password?" link
- Primary CTA: "Sign in"
- Face ID stub button (optional, below primary)

**Copy:**
- Title: `Welcome back, driver`
- Body: `Phone and password.`
- Fields: `Phone`, `Password`
- Link: `Forgot password?`
- CTA: `Sign in`
- Biometric: `Use Face ID`

**Mockup prompt block:**
```
SCREEN: Drivio Sign In form
- Light ivory (#F4ECE0) background.
- Top: rounded 32x32 back button (Lucide left-arrow), top-left.
- Title in Marcellus 28pt charcoal-teal: "Welcome back, driver"
- Subtitle in Albert Sans 14pt dim: "Phone and password."
- Two form fields stacked, 56pt tall each:
  - "Phone" with 🇳🇬 +234 prefix
  - "Password" with eye-icon toggle
- "Forgot password?" link in Albert Sans 13pt charcoal-teal under the password field, right-aligned
- Bottom:
  - Primary "Sign in" button (full-width, coral, 52pt)
  - Below: ghost "Use Face ID" button with a Face-ID-style icon (Lucide), text-only
- iOS status bar at top.
```

---

#### SCR-005 — OTP Verification

**Purpose:** Verify the phone number with a 6-digit code.

**Reached from:** Sign Up or Sign In submit
**Reaches:** Paywall (new account) or Home (returning)

**Layout:**
- Ivory background
- Top: back button
- Eyebrow: "STEP 2 OF 2" (or "VERIFY" for sign-in)
- Title (Marcellus 28pt): "Enter the code"
- Body (Albert Sans 14pt dim): "We sent it to +234 812 335 4467."
- Below body: 6 OTP cells in a row, square-ish, each ~52×64pt, hairline borders. Active cell highlighted with coral border and a vertical-bar cursor.
- Below cells: "Resend (24s)" countdown (disabled during countdown, becomes coral link when reached 0)
- Bottom: primary CTA "Verify & continue" (disabled until 6 digits entered)

**Copy:**
- Eyebrow: `STEP 2 OF 2`
- Title: `Enter the code`
- Body (dynamic): `We sent it to +234 812 335 4467.`
- Resend (countdown): `Resend (24s)`
- Resend (active): `Resend code`
- CTA: `Verify & continue`

**States:**
- 0/6 digits → CTA disabled
- 1-5/6 digits → CTA still disabled
- 6/6 digits → CTA enabled, coral
- Verifying → CTA shows spinner, label "Verifying..."
- Wrong code → cells shake, banner "Wrong code. Try again."
- Resent → toast "Code sent again"

**Mockup prompt block:**
```
SCREEN: Drivio OTP Verification
- Light ivory (#F4ECE0) background.
- Top: rounded back button top-left.
- Uppercase eyebrow Albert Sans bold 11pt: "STEP 2 OF 2", dim
- Title Marcellus 28pt charcoal-teal: "Enter the code"
- Body Albert Sans 14pt: "We sent it to +234 812 335 4467."
- Below body: 6 square OTP cells in a horizontal row, each 52×64pt, with hairline borders. The third cell has a coral border (active) and shows a thin vertical bar | cursor inside.
- Below cells: text "Resend (24s)" in Albert Sans 13pt dim charcoal-teal
- Bottom pinned: primary button "Verify & continue" (coral fill, ivory text, 52pt) — currently DISABLED state, so opacity 40%
- iOS status bar at top.
```

---

#### SCR-006 — Paywall (Trial Intro, pre-KYC)

**Purpose:** Introduce Drivio Pro + 90-day free trial. **No tier selection here** — that happens at trial end (SCR-006b). This screen sets the expectation: "drive free for 90 days, pick a tier later, no card needed up front."

**Reached from:** OTP verify (new account) — KYC will trigger trial start after approval
**Reaches:** KYC orchestrator → `/kyc`

**Layout:**
- Charcoal-teal background (dark moment for the money decision)
- Top: small Drivio wordmark in ivory + coral dot
- Hero card centered:
  - Eyebrow ivory uppercase: "DRIVIO PRO"
  - Massive tagline (Marcellus 40pt ivory): "Free for 90 days."
  - Below: "Pick a plan when your trial ends." in Albert Sans 16pt dim ivory
- Below hero card, 4 benefit rows (each = 32pt icon disc + headline + body):
  1. coral check icon: "Zero per-trip cut. You keep ₦2,400 of a ₦2,400 trip."
  2. coral check icon: "Set your own prices. The marketplace, not the algorithm."
  3. coral check icon: "Real human support. No chatbots."
  4. coral check icon: "No card up front. We'll remind you 7 days before your trial ends."
- Bottom:
  - Primary CTA (coral, ivory text): "Start trial — KYC next"
  - Below CTA: small "Drivers pay ₦2,500/day, ₦15,000/week, or ₦50,000/month after trial. You choose." in dim ivory

**Copy:**
- Wordmark: `Drivio` (in ivory, coral dot)
- Eyebrow: `DRIVIO PRO`
- Tagline: `Free for 90 days.`
- Sub: `Pick a plan when your trial ends.`
- Benefits (4):
  - `Zero per-trip cut. You keep ₦2,400 of a ₦2,400 trip.`
  - `Set your own prices. The marketplace, not the algorithm.`
  - `Real human support. No chatbots.`
  - `No card up front. We'll remind you 7 days before your trial ends.`
- CTA: `Start trial — KYC next`
- Footer: `Drivers pay ₦2,500/day, ₦15,000/week, or ₦50,000/month after trial. You choose.`

**Mockup prompt block:**
```
SCREEN: Drivio Paywall — trial intro (pre-KYC, no tier selection yet)
- Full-bleed charcoal-teal (#0E2E2E) DARK background.
- Top: small "Drivio" wordmark in Marcellus 22pt ivory (#F4ECE0) with coral (#EE6F4A) dot, top-left.
- Hero card (rounded, slightly lighter charcoal background, generous padding):
  - Uppercase eyebrow Albert Sans bold 11pt letter-spaced 1.6, coral: "DRIVIO PRO"
  - Massive headline "Free for 90 days." Marcellus 40pt ivory
  - Below: "Pick a plan when your trial ends." in Albert Sans 16pt dim ivory
- Below card: 4 benefit rows stacked, each row:
  - Left: 32×32 coral-filled circle with an ivory check icon (Lucide)
  - Middle: short headline in Marcellus 16pt ivory + body in Albert Sans 12pt dim ivory
  - Benefits in order:
    1. "Zero per-trip cut" / "You keep ₦2,400 of a ₦2,400 trip."
    2. "Set your own prices" / "The marketplace, not the algorithm."
    3. "Real human support" / "No chatbots."
    4. "No card up front" / "We'll remind you 7 days before your trial ends."
- Bottom pinned:
  - Primary button (full-width, coral fill, ivory text, 52pt) "Start trial — KYC next" in Albert Sans bold
  - Below: very small "Drivers pay ₦2,500/day, ₦15,000/week, or ₦50,000/month after trial. You choose." Albert Sans 10pt dim ivory, centered
- iOS status bar at top.
```

---

#### SCR-006b — Pick a Plan (Tier Selection)

**Purpose:** Driver picks one of the 3 tiers. Shown at end of trial, OR when an expired driver re-subscribes, OR when the driver opens "Change plan" from /subscription/manage.

**Reached from:**
- Trial T-0 or after expiry — auto-routes from `/edge/subscription-expired` or any blocked action
- Trial T-7 / T-3 / T-1 banner tap — drivers can pick early to avoid the lockout
- `/subscription/manage` → "Change plan"

**Reaches:**
- On confirm → Paystack hosted checkout (real) or success modal (dev) → `/home`
- On Cancel → if trial active and time left → `/home`; if expired → stays / `/edge/subscription-expired`

**Layout:**
- Ivory background (light moment — making a clear, informed choice)
- Top bar: back button (only if reachable; not on hard-expired) + title "Pick your plan" Marcellus 22pt
- Top card: **Recommendation banner** (subtle coral background, hairline border)
  - Eyebrow coral uppercase: "BASED ON YOUR LAST 90 DAYS"
  - Personalized line: "You bid on 67 of 90 days. **Weekly fits your pattern.**" (or "Monthly is your cheapest" / "Daily lets you only pay on days you drive")
  - Small "Why this?" link → tooltip explaining the math
- Middle: **3 tier cards stacked vertically** (or horizontally side-by-side on tablet)
  - Each card = ivoryLight background, hairline, generous padding
  - Recommended tier has a coral border + small coral "RECOMMENDED" pill in top-right
  - Card structure:
    - Eyebrow: tier name in Marcellus 18pt "Daily" / "Weekly" / "Monthly"
    - Price hero: "₦2,500" / "₦15,000" / "₦50,000" in Albert Sans bold 36pt, charcoal-teal
    - Cadence sub: "per day · auto-renews every 24h" / "per week · auto-renews every 7 days" / "per month · auto-renews every 30 days"
    - 1-line value framing: "Pay only when you drive" / "Save ₦2,500 vs daily" / "Cheapest per-day rate"
    - Effective monthly: "≈ ₦75,000/month if used 30 days" / "≈ ₦60,000/month if used 4 weeks" / "₦50,000/month flat"
    - Bottom row right-aligned: radio-button-style selection indicator (filled coral if selected)
- Below tier cards: **Switch policy note** in Albert Sans 12pt dim charcoal-teal: "Switch anytime. Changes apply at your next renewal."
- Bottom pinned:
  - Selected tier summary chip showing total to charge today
  - Primary CTA: "Continue to payment" (coral fill, ivory text, 52pt)

**Copy:**
- Title: `Pick your plan`
- Recommendation banner (one of):
  - `Based on your last 90 days, you bid on 67 of them. **Weekly fits your pattern.**`
  - `You bid on 84 of 90 days. **Monthly is your cheapest option.**`
  - `You bid on 23 of 90 days. **Daily lets you only pay on days you drive.**`
- Tier cards:
  - Daily: `Daily` / `₦2,500` / `per day · auto-renews every 24h` / `Pay only when you drive` / `≈ ₦75,000/month if used 30 days`
  - Weekly: `Weekly` / `₦15,000` / `per week · auto-renews every 7 days` / `Save ₦2,500 vs daily` / `≈ ₦60,000/month if used 4 weeks`
  - Monthly: `Monthly` / `₦50,000` / `per month · auto-renews every 30 days` / `Cheapest per-day rate` / `₦50,000/month flat`
- Policy: `Switch anytime. Changes apply at your next renewal.`
- CTA: `Continue to payment`

**States:**
- Initial (recommended tier pre-selected)
- Tier changed (selected card updates)
- Confirming (CTA spinner)
- Paystack checkout overlay (real mode)
- Success → `/home` with toast "Drivio Pro active. Welcome back."
- Failure → AppNotifier error, sheet stays

**Edge cases:**
- No trial activity yet (KYC just completed, no bids yet) → recommendation banner shows "Most drivers on Drivio choose Weekly to start." Monthly is pre-selected as a safer default.
- Driver in pending tier switch (already queued a change) → top of page shows "Switch queued: <currentTier> → <pendingTier> at <renewalDate>. Confirm a different switch?"
- Hard-expired driver → back button hidden; only way out is to subscribe.

**Mockup prompt block:**
```
SCREEN: Drivio Pick Your Plan — 3-tier subscription selection
- Ivory (#F4ECE0) background, light mode.
- Top bar: chevron-left icon (Lucide, charcoal-teal) + page title "Pick your plan" in Marcellus 22pt centered.
- Recommendation banner card just below (full-width minus 20pt margins):
  - ivoryLight (#FBF7EE) background, hairline coral border, generous padding
  - Eyebrow uppercase coral Albert Sans bold 10pt letter-spaced 1.5: "BASED ON YOUR LAST 90 DAYS"
  - Body line in Marcellus 16pt charcoal-teal: "You bid on 67 of 90 days. " with "**Weekly fits your pattern.**" bolded
  - Small "Why this?" text link in teal underline below
- Three tier cards stacked vertically below, each with hairline border + ivoryLight background:
  Card 1 - DAILY:
  - Top row: small "Daily" label Marcellus 18pt charcoal-teal LEFT + empty radio circle RIGHT
  - Big price "₦2,500" Albert Sans bold 36pt charcoal-teal
  - Cadence "per day · auto-renews every 24h" Albert Sans 13pt textDim
  - Value line: "Pay only when you drive" Marcellus italic 13pt teal
  - Effective monthly: "≈ ₦75,000/month if used 30 days" Albert Sans 11pt textMuted
  Card 2 - WEEKLY (RECOMMENDED — coral border, small "RECOMMENDED" pill top-right in coral fill ivory text):
  - Same structure
  - Price "₦15,000", "per week · auto-renews every 7 days", "Save ₦2,500 vs daily", "≈ ₦60,000/month if used 4 weeks"
  - Radio circle FILLED coral
  Card 3 - MONTHLY:
  - Same structure
  - Price "₦50,000", "per month · auto-renews every 30 days", "Cheapest per-day rate", "₦50,000/month flat"
- Below cards, centered small text: "Switch anytime. Changes apply at your next renewal." Albert Sans 12pt dim
- Bottom pinned:
  - Small summary "Total today: ₦15,000" Albert Sans semibold charcoal-teal centered
  - Primary button (full-width, coral fill, ivory text, 52pt) "Continue to payment" Albert Sans bold
- iOS status bar at top (system).
```

---

### 3.2 KYC

#### SCR-007 — KYC Orchestrator (overview)

**Purpose:** Show the driver where they are in KYC and what's left.

**Reached from:** Paywall (first time) or home banner "Finish KYC"
**Reaches:** Each KYC step in sequence

**Layout:**
- Ivory background
- Top: progress bar (5 steps) at top — current step highlighted coral
- Eyebrow: "VERIFICATION"
- Title (Marcellus 28pt): "Let's get you verified"
- Body: "5 steps. Usually 6–10 minutes."
- Below: 5 step rows (each = step number + title + status icon)
  1. ✓ "Identity (BVN + NIN)" — completed (coral check)
  2. ○ "Selfie + liveness" — current (coral dot)
  3. ○ "Drivers' licence" — pending (gray)
  4. ○ "Vehicle documents" — pending (gray)
  5. ○ "Inspection report" — pending (gray)
- Primary CTA at bottom: "Continue with selfie"

**Copy:**
- Eyebrow: `VERIFICATION`
- Title: `Let's get you verified`
- Body: `5 steps. Usually 6–10 minutes.`
- Steps: `Identity (BVN + NIN)`, `Selfie + liveness`, `Drivers' licence`, `Vehicle documents`, `Inspection report`
- CTA: `Continue with selfie`

**Mockup prompt block:**
```
SCREEN: Drivio KYC Orchestrator (verification progress)
- Light ivory background.
- Top: progress bar with 5 segments, the first 1 filled coral, the second one coral-active (slightly pulsing), the rest dim charcoal-teal.
- Eyebrow Albert Sans bold uppercase 11pt: "VERIFICATION"
- Title in Marcellus 28pt charcoal-teal: "Let's get you verified"
- Body Albert Sans 14pt dim: "5 steps. Usually 6–10 minutes."
- 5 step rows, each ~64pt tall, separated by hairline borders:
  - Row 1: 24pt coral check circle icon, "Identity (BVN + NIN)" Marcellus 16pt, "Verified" in coral 12pt right-aligned
  - Row 2: 24pt coral filled dot icon, "Selfie + liveness" Marcellus 16pt, "Current" right-aligned in coral
  - Rows 3,4,5: empty hollow circle icons, titles in dim Marcellus
- Bottom pinned: primary "Continue with selfie" button (full-width coral, 52pt)
- iOS status bar at top.
```

---

#### SCR-008 — BVN / NIN Entry

**Purpose:** Collect BVN + NIN for identity verification.

**Reached from:** KYC orchestrator
**Reaches:** Selfie

**Layout:**
- Same shell as sign-up forms
- Eyebrow: "STEP 1 OF 5"
- Title (Marcellus 28pt): "Verify your identity"
- Body (Albert Sans 14pt): "We use BVN and NIN to confirm you're you. We never share it."
- Two compact fields:
  - BVN (11 digits)
  - NIN (11 digits)
- Security note row with coral lock icon + "Encrypted at rest, never logged"
- Primary CTA: "Verify"

**Copy:**
- Eyebrow: `STEP 1 OF 5`
- Title: `Verify your identity`
- Body: `We use BVN and NIN to confirm you're you. We never share it.`
- Fields: `BVN (11 digits)`, `NIN (11 digits)`
- Security: `Encrypted at rest, never logged`
- CTA: `Verify`

**Mockup prompt block:**
```
SCREEN: Drivio KYC — BVN/NIN Entry
- Light ivory background.
- Top: small back button + progress bar (1/5 filled coral).
- Eyebrow "STEP 1 OF 5" in Albert Sans bold uppercase, dim.
- Title "Verify your identity" in Marcellus 28pt charcoal-teal.
- Body "We use BVN and NIN to confirm you're you. We never share it." in Albert Sans 14pt dim.
- Two stacked 56pt-tall input fields:
  - "BVN (11 digits)" with numeric keyboard hint
  - "NIN (11 digits)" with numeric keyboard hint
- Below fields, a small information row: a coral Lucide lock icon (16pt) + "Encrypted at rest, never logged" Albert Sans 11pt dim
- Bottom: primary "Verify" button (coral, full-width, 52pt)
- iOS status bar at top.
```

---

#### SCR-009 — Selfie + Liveness Capture

**Purpose:** Take a live selfie to confirm the driver matches their ID.

**Reached from:** BVN/NIN success
**Reaches:** Document upload

**Layout:**
- Charcoal-teal background (camera view)
- Top: eyebrow "STEP 2 OF 5" in ivory + close button
- Camera viewfinder: oval mask in the center (3:4 aspect), live camera feed visible inside
- Around the oval: coral guide ring (animated pulse when alignment is correct)
- Above viewfinder: title "Look into the camera" Marcellus 22pt ivory
- Below viewfinder: instruction Albert Sans 14pt ivory dim: "Blink twice. Turn your head slowly left, then right."
- Bottom: large coral capture button (round, 80pt diameter)

**Copy:**
- Eyebrow: `STEP 2 OF 5`
- Title: `Look into the camera`
- Body: `Blink twice. Turn your head slowly left, then right.`
- Capture state: `Hold still...`
- Success: `Got it — verifying`

**Mockup prompt block:**
```
SCREEN: Drivio KYC — Selfie + Liveness
- Full-bleed dark charcoal-teal background with live camera viewfinder in the center.
- Top: small ivory "STEP 2 OF 5" eyebrow + a close X button on the right.
- Center: oval viewfinder mask (3:4 portrait aspect) with the live camera feed inside. Around the oval, a thin coral guide ring that's slightly pulsing (animated). The viewfinder fills roughly 70% of the vertical space.
- Above the viewfinder: title "Look into the camera" in Marcellus 22pt ivory, centered.
- Below the viewfinder: instruction "Blink twice. Turn your head slowly left, then right." in Albert Sans 14pt dim ivory.
- Bottom: a large round coral capture button (80pt diameter, coral fill, white ring border, looks like a camera shutter button).
- iOS status bar at top.
```

---

#### SCR-010 — Document Upload (canonical template)

**Purpose:** Upload a single document (drivers' licence, vehicle reg, insurance, road worthiness, LASRRA, or inspection).

**Reached from:** KYC orchestrator or KYC sequence
**Reaches:** Next step or pending review

**Layout:**
- Ivory background
- Top: back + progress bar
- Eyebrow: "STEP 3 OF 5" (or appropriate)
- Title (Marcellus 28pt): "Drivers' licence" (varies by document)
- Body: "Front of card. Make sure all 4 corners are visible."
- Document capture frame (4:3 aspect, hairline border, "Tap to capture" hint inside)
- After capture: preview thumbnail with retake/use buttons
- Below frame: meta fields (license number, expiry date — auto-extracted if possible, editable)
- Primary CTA: "Upload"

**Copy variants:**
- Drivers' licence: `Front of card. Make sure all 4 corners are visible.`
- Vehicle reg: `The vehicle paper showing your registration number.`
- Insurance: `Current insurance certificate. Must be valid.`
- Road worthiness: `Most recent road-worthiness certificate.`
- LASRRA: `LASRRA card or registration document.`
- Inspection: `Inspection report from a recognized garage.`

**Mockup prompt block:**
```
SCREEN: Drivio KYC — Document Upload (Drivers' Licence)
- Light ivory background.
- Top: small back button + progress bar (3/5 filled coral).
- Eyebrow "STEP 3 OF 5" in Albert Sans bold uppercase dim.
- Title "Drivers' licence" in Marcellus 28pt charcoal-teal.
- Body "Front of card. Make sure all 4 corners are visible." in Albert Sans 14pt dim.
- Center: a 4:3 aspect capture frame with a charcoal-teal hairline border, rounded corners. Inside the frame: a centered coral camera icon (Lucide, 28pt) and "Tap to capture" text in Albert Sans 13pt dim.
- Below the capture frame: two compact input fields stacked
  - "Licence number" with floating label
  - "Expiry date" with calendar icon
- Bottom: primary "Upload" button (coral, full-width, 52pt)
- iOS status bar at top.
```

---

#### SCR-011 — KYC Pending Review

**Purpose:** Show driver they've submitted everything and we're reviewing.

**Reached from:** Final KYC step submitted
**Reaches:** Home (banner: "Pending review") on driver tap; auto-routes to home when admin approves

**Layout:**
- Ivory background
- Center: large coral hourglass/pending icon (~96pt)
- Title (Marcellus 36pt): "You're in."
- Body (Albert Sans 14pt dim): "We're reviewing your documents. Usually within 24 hours. You'll get a push when it's done."
- Below body: status card with a coral disc + "Documents under review · Submitted 2 minutes ago"
- Bottom: ghost "Go to home" button

**Copy:**
- Title: `You're in.`
- Body: `We're reviewing your documents. Usually within 24 hours. You'll get a push when it's done.`
- Status: `Documents under review · Submitted 2 minutes ago`
- CTA: `Go to home`

**Mockup prompt block:**
```
SCREEN: Drivio KYC — Pending Review confirmation
- Light ivory background.
- Top: small Drivio wordmark in Marcellus 22pt charcoal-teal with coral dot, centered or top-left.
- Center (vertically centered): large coral filled-circle icon (96pt diameter) with an ivory hourglass icon (Lucide) inside. Slight pulse animation.
- Below icon: title "You're in." in Marcellus 36pt charcoal-teal centered.
- Below title: body "We're reviewing your documents. Usually within 24 hours. You'll get a push when it's done." in Albert Sans 14pt dim charcoal-teal, centered, 80% width.
- Below body: small surface-tone card with a coral dot icon + "Documents under review · Submitted 2 minutes ago" in Albert Sans 12pt, hairline border, centered, with 24pt margins.
- Bottom: ghost-style "Go to home" button (text-only, charcoal-teal) centered.
- iOS status bar at top.
```

---

#### SCR-012 — KYC Rejected (re-upload prompt)

**Purpose:** Tell the driver a document was rejected and what to do.

**Reached from:** Admin rejects a document (push notification → tap)
**Reaches:** Document re-upload (SCR-060)

**Layout:**
- Ivory background with a warm red accent stripe at top
- Eyebrow (red): "ACTION REQUIRED"
- Title (Marcellus 28pt): "We need this one again."
- Card showing the rejected document name + rejection reason in plain language
- Below: "What to fix" tips
- Primary CTA: "Re-upload now"

**Copy:**
- Eyebrow: `ACTION REQUIRED`
- Title: `We need this one again.`
- Sample reason: `The photo was too dark to read the licence number clearly.`
- Tips intro: `What to fix`
- CTA: `Re-upload now`

**Mockup prompt block:**
```
SCREEN: Drivio KYC — Rejection Notice
- Light ivory background.
- Top stripe: 4pt warm-red (#CC3D2F) horizontal line spanning full width.
- Eyebrow "ACTION REQUIRED" in Albert Sans bold uppercase 11pt, red.
- Title "We need this one again." in Marcellus 28pt charcoal-teal.
- Card (surface tone, hairline border, rounded, 24pt margins):
  - "DRIVERS' LICENCE" in Albert Sans bold uppercase 10pt, dim
  - Rejection reason in Marcellus 16pt charcoal-teal: "The photo was too dark to read the licence number clearly."
- Below card, "What to fix:" heading in Albert Sans bold 13pt charcoal-teal, then a 3-bullet list with coral checkmark icons:
  - "Find brighter light — natural daylight works best"
  - "Lay the card flat on a contrasting surface"
  - "All 4 corners visible"
- Bottom: primary "Re-upload now" button (coral fill, full-width, 52pt)
- iOS status bar at top.
```

---

### 3.3 Vehicle Management

#### SCR-013 — Add Vehicle

**Purpose:** Register a new vehicle.

**Reached from:** Profile → Vehicle row (no vehicle yet) or KYC sequence
**Reaches:** Vehicle docs flow (or KYC)

**Layout:**
- Ivory background, back button top-left
- Eyebrow: "VEHICLE"
- Title (Marcellus 28pt): "Add your vehicle"
- Body: "Make, model, plate. We'll review with the inspection report."
- Stacked form:
  - Make (with picker — Toyota, Honda, Hyundai...)
  - Model (text input)
  - Year (numeric picker, 2000-current)
  - Colour (picker: White, Silver, Black, Grey, Red, Blue, Other)
  - Plate (text, monospace styling)
  - Seats (numeric, default 4)
- Below form: 2 photo upload tiles (Vehicle exterior + Interior) — optional
- Primary CTA: "Save"

**Copy:**
- Eyebrow: `VEHICLE`
- Title: `Add your vehicle`
- Body: `Make, model, plate. We'll review with the inspection report.`
- Fields: `Make`, `Model`, `Year`, `Colour`, `Plate`, `Seats`
- Photo tiles: `Vehicle exterior (optional)`, `Vehicle interior (optional)`
- CTA: `Save`

**Mockup prompt block:**
```
SCREEN: Drivio Add Vehicle form
- Light ivory background.
- Top: small back button.
- Eyebrow "VEHICLE" in Albert Sans bold uppercase 11pt dim.
- Title "Add your vehicle" in Marcellus 28pt charcoal-teal.
- Body "Make, model, plate. We'll review with the inspection report." in Albert Sans 14pt dim.
- Stacked compact form fields:
  - "Make" with chevron-right (picker style): showing "Toyota"
  - "Model" text input: "Corolla"
  - "Year" with chevron-right: "2020"
  - "Colour" with chevron-right + a small filled coral circle to show the picked colour: "White"
  - "Plate" text input in mono font: "36566FG"
  - "Seats" numeric stepper showing "4"
- Below form: 2 tile placeholders side-by-side, each 1:1 aspect with a + icon and label
  - "Vehicle exterior (optional)"
  - "Vehicle interior (optional)"
- Bottom: primary "Save" button (coral, full-width, 52pt)
- iOS status bar at top.
```

---

#### SCR-014 — Vehicle Details (from profile)

**Purpose:** View current vehicle details + status + access doc list.

**Reached from:** Profile hub → Vehicle row
**Reaches:** Edit fields, change vehicle, document re-uploads

**Layout:**
- Ivory bg
- Top: back + title "Vehicle"
- Hero card: vehicle name (Marcellus 24pt), plate (mono), status pill (active/pending/suspended)
- 3-stat strip: Year · Colour · Seats
- Below: groups for Documents (list of all 6 doc rows with status), Photos, Actions (Change vehicle, Retire)

**Copy:**
- Title: `Vehicle`
- Status: `Active`, `Pending review`, `Suspended`, `Retired`
- Documents row: doc name + status pill ("Verified" coral / "Pending" amber / "Action needed" red)
- Action: `Change vehicle`, `Retire vehicle`

**Mockup prompt block:**
```
SCREEN: Drivio Vehicle Details
- Light ivory background.
- Top: back button + centered title "Vehicle" in Marcellus 18pt.
- Hero card (surface tone, rounded, 24pt margins):
  - "Toyota Corolla 2020" in Marcellus 24pt charcoal-teal
  - Plate "36566FG" in a small mono pill (coral background, ivory text, 4pt rounded, 14pt padding)
  - Status pill "Active" in coral-tinted background with coral text, top-right
- 3-stat strip below hero (centered): "2020 · White · 4 seats" in Albert Sans 14pt dim
- "Documents" section header in eyebrow style: "DOCUMENTS"
- List of 6 doc rows, each row with:
  - 24pt icon (Lucide, e.g., file-text, car, shield)
  - Doc name in Marcellus 14pt
  - Status pill on the right (coral/amber/red filled or text)
- "Actions" section header: "ACTIONS"
- Two rows: "Change vehicle" (chevron-right) and "Retire vehicle" (red text)
- iOS status bar at top.
```

---

#### SCR-015 — Vehicle Change (switcher)

**Purpose:** Switch between vehicles when driver has multiple.

**Reached from:** Vehicle Details → Change vehicle
**Reaches:** Vehicle Details (refreshed)

**Layout:**
- Ivory bg
- Top: back + title "Switch vehicle"
- Body: "Pick the vehicle you're driving today."
- Vertical list of vehicle cards:
  - Each card: vehicle name + plate + status pill, with a radio selector
  - Currently active vehicle marked
- Primary CTA: "Use this vehicle"

**Copy:**
- Title: `Switch vehicle`
- Body: `Pick the vehicle you're driving today.`
- CTA: `Use this vehicle`

**Mockup prompt block:**
```
SCREEN: Drivio Vehicle Switcher
- Light ivory background.
- Top: back button + centered title "Switch vehicle" in Marcellus 18pt.
- Body "Pick the vehicle you're driving today." in Albert Sans 14pt dim, 24pt margins.
- Vertical list of vehicle cards (3 cards visible):
  - Each card 96pt tall, surface tone, hairline border, rounded, 24pt margins
  - Inside: vehicle name in Marcellus 16pt, plate in mono pill, status pill
  - Right side: radio selector (coral filled when selected)
  - One card shows the active vehicle highlighted with a coral border
- Bottom: primary "Use this vehicle" button (coral, full-width, 52pt)
- iOS status bar at top.
```

---

### 3.4 Home / Drive Shell

#### SCR-016 — Home (offline)

**Purpose:** Driver is signed in but offline. Show the marketplace canvas + earnings + invite to go online.

**Reached from:** Splash hand-off or sign-out cancel
**Reaches:** Online state (after toggle) or any sub-route

**Layout:**
- Full-bleed map at top (~50% of screen) — stylized teal map background with a coral "you are here" pin in the center
- Top overlay (transparent):
  - Drivio wordmark left (Marcellus 18pt charcoal-teal + coral dot)
  - Notification bell icon top-right (with badge if unread)
  - Settings/gear icon
- Bottom sheet (rises from 50%):
  - Sheet handle (small gray pill)
  - Eyebrow: "OFFLINE"
  - Status pill (large): "You're offline." (charcoal-teal text)
  - 3-stat strip (TODAY · TRIPS · RATING): values + labels
  - Large "Go online" button (coral, full-width)
  - Below: bottom tab bar (4 tabs: Drive [active], Earnings, Pricing, Profile)

**Copy:**
- Wordmark: `Drivio`
- Eyebrow: `OFFLINE`
- Status: `You're offline.`
- Sub: `Tap "Go online" to start receiving requests.`
- Stats: `TODAY` `₦18,200`, `TRIPS` `12`, `RATING` `4.9 ★`
- CTA: `Go online`
- Tabs: `Drive`, `Earnings`, `Pricing`, `Profile`

**Mockup prompt block:**
```
SCREEN: Drivio Driver Home (Offline state)
- Full-bleed teal (#236767) stylized map at top, with a coral (#EE6F4A) pickup pin in the center (10pt circle with an ivory ring).
- Top overlay (transparent over the map):
  - Top-left: "Drivio" wordmark in Marcellus 18pt charcoal-teal with coral dot.
  - Top-right: a notification-bell icon (Lucide, in a small ivory glass-button background, with a coral dot indicator showing unread).
  - Just below the bell: a settings/gear icon (Lucide) in a similar glass button.
- Bottom sheet rising from the bottom 50%, rounded top corners (28pt radius), ivory background, soft shadow:
  - Small drag handle at top (gray 36×4pt pill).
  - Eyebrow Albert Sans bold uppercase 11pt: "OFFLINE", dim charcoal-teal.
  - Status text in Marcellus 24pt charcoal-teal: "You're offline."
  - Sub Albert Sans 13pt dim: "Tap 'Go online' to start receiving requests."
  - 3-column stat strip 50pt tall, equal width, each column shows:
    - Eyebrow "TODAY" in Albert Sans bold uppercase 9pt dim
    - Value "₦18,200" in Albert Sans bold 22pt charcoal-teal
  - Other columns: "TRIPS" / "12", "RATING" / "4.9 ★" (★ in butter color)
  - Large "Go online" button below stats (full-width, coral fill, ivory text, 52pt, Albert Sans bold)
  - Bottom: tab bar with 4 tabs (Drive active in coral, Earnings/Pricing/Profile in dim). Tab icons from Lucide.
- iOS status bar at top.
```

---

#### SCR-017 — Home (online, no requests)

**Purpose:** Driver is online and waiting for the next request.

**Reached from:** Tap "Go online" from SCR-016
**Reaches:** Request appears (SCR-019) or driver goes offline (SCR-016)

**Layout:**
- Same map shell as SCR-016 but with:
  - Live "you" pin (coral with pulsing ring)
  - "ONLINE" status pill at top (coral filled, ivory text)
- Bottom sheet:
  - Eyebrow: "LIVE"
  - Status: "Looking for requests..."
  - Quiet pulse animation (coral circle pulsing) instead of stat strip
  - 3-stat strip (today's earnings + trips + rating)
  - Below stats: coach tip card (if any active rule fires)
  - Bottom: "Go offline" ghost button
  - Tab bar

**Copy:**
- Top pill: `ONLINE`
- Eyebrow: `LIVE`
- Status: `Looking for requests...`
- Coach tip example: `Friday peak ahead. 17:00–20:00 usually busy.`
- Toggle: `Go offline`

**Mockup prompt block:**
```
SCREEN: Drivio Driver Home (Online, no requests)
- Same map shell as offline, but now:
  - "ONLINE" status pill top-center (coral filled, ivory text, 8pt-radius, small)
  - The pickup pin in the center has a pulsing coral ring around it (animation suggestion: 1.4s pulse)
- Bottom sheet:
  - Eyebrow "LIVE" in Albert Sans bold uppercase 11pt, coral
  - Status text "Looking for requests..." in Marcellus 22pt charcoal-teal
  - Small coral pulsing dot animation indicator
  - 3-stat strip (same as offline)
  - Below stats: a coach-tip card (surface tone, rounded, hairline border):
    - Eyebrow "TIP · FRIDAY" in coral
    - Body "Friday peak ahead. 17:00–20:00 usually busy." in Marcellus 14pt
    - Dismiss × top-right
  - Ghost-style "Go offline" button below (text only, charcoal-teal, centered)
  - Tab bar at bottom (Drive tab active)
- iOS status bar at top.
```

---

#### SCR-018 — Home (online, with request feed)

**Purpose:** Driver is online and there are nearby requests to consider.

**Reached from:** SCR-017 as soon as a request lands
**Reaches:** Bid composer (SCR-019)

**Layout:**
- Same map but now showing nearby request pins (small coral dots around the driver)
- Bottom sheet pulls higher to expose the request feed:
  - Eyebrow: "REQUESTS NEARBY · 3"
  - Stack of request cards (newest at top, slide-in animation):
    - Card 1: pickup address + dropoff address + distance + ETA + expiry countdown pill (e.g., "00:42")
  - Tap card → opens bid composer
  - "Go offline" still accessible at the bottom

**Copy:**
- Eyebrow: `REQUESTS NEARBY · 3`
- Card eyebrow: `00:42`
- Card body (pickup): `Pickup: 8 Marina Rd, Lagos Island`
- Card body (dropoff): `Drop-off: Lekki Phase 1`
- Card meta: `4.2 km · ~12 min`

**Mockup prompt block:**
```
SCREEN: Drivio Driver Home (Online, with 3 incoming requests)
- Top: same map but with 3 small coral dots visible at different positions (other pickup pins).
- "ONLINE" pill at top.
- Bottom sheet pulled up higher (now covering 65% of the screen):
  - Eyebrow "REQUESTS NEARBY · 3" in Albert Sans bold uppercase 11pt, coral
  - Stack of 3 request cards (each ~80pt tall, hairline border, rounded, ivory background):
    - Card 1 (newest, top): small coral pulsing dot top-right
      - Eyebrow "00:42" expiry counter in mono coral
      - Pickup row: small coral dot + "8 Marina Rd, Lagos Island" Albert Sans 13pt
      - Drop-off row: small teal square + "Lekki Phase 1" Albert Sans 13pt
      - Meta: "4.2 km · ~12 min" Albert Sans 11pt dim
    - Cards 2 and 3 similar, with longer expiries (00:58, 01:02)
  - Below stack: small "Go offline" ghost button
- iOS status bar at top.
```

---

### 3.5 Ride Request → Bid Composer

#### SCR-019 — Ride Request Detail / Bid Composer (Type variant)

**Purpose:** Driver inspects a ride request and sets a price (typed).

**Reached from:** Tapping a request card on home
**Reaches:** Bid submitted (SCR-022) or back to home (decline)

**Layout:**
- Top half: map showing pickup + dropoff + route polyline (coral)
- Top overlay: countdown "AUCTION CLOSES · 00:42" in mono coral on charcoal-teal pill
- Bottom sheet (50% of screen):
  - Pickup row (coral disc): "8 Marina Rd, Lagos Island"
  - Drop-off row (teal square): "Lekki Phase 1"
  - Meta chip row: "4.2 KM" + "~12 MIN" in mono chips
  - Eyebrow "YOUR PRICE"
  - Hero number (Albert Sans bold 56pt coral): "₦2,400" — keyboard-editable, tap to focus
  - "Suggested ₦2,200" sub line in dim
  - Quick adjusters row: `−500 −100 +100 +500` (4 chips)
  - You-keep line: "You keep" + "₦2,400" (always equals price; no commission math)
  - Two CTAs side-by-side: ghost "Decline" + primary "Submit bid" (coral)

**Copy:**
- Countdown: `AUCTION CLOSES · 00:42`
- Pickup: `8 Marina Rd, Lagos Island`
- Drop-off: `Lekki Phase 1`
- Meta: `4.2 KM` `~12 MIN`
- Eyebrow: `YOUR PRICE`
- Suggested: `Suggested ₦2,200`
- Quick adjusters: `−500`, `−100`, `+100`, `+500`
- You keep: `You keep ₦2,400`
- CTAs: `Decline`, `Submit bid`

**State variations:**
- Peak hours: amber pill "PEAK · 1.5×" next to suggested
- Night: blue pill "NIGHT · 1.2×"
- Bid below ₦100: red border on number, can't submit

**Mockup prompt block:**
```
SCREEN: Drivio Ride Request — Bid Composer (Type variant)
- Top 45% of the screen: map showing a route polyline (coral, 4pt stroke) from a pickup pin (coral disc) on the left to a drop-off pin (teal rotated square) on the right.
- Over the map, top-center: a small charcoal-teal pill containing "AUCTION CLOSES · 00:42" in mono ivory.
- Bottom sheet (rounded top corners, ivory background, soft shadow):
  - Pickup row: small coral disc + "8 Marina Rd, Lagos Island" Albert Sans 14pt
  - Vertical dotted connector
  - Drop-off row: small teal square + "Lekki Phase 1" Albert Sans 14pt
  - Two small chips with mono text: "4.2 KM" and "~12 MIN"
  - Eyebrow "YOUR PRICE" in Albert Sans bold uppercase 11pt coral
  - Hero price "₦2,400" in Albert Sans bold 56pt coral (tabular figures) — looks editable, with a thin cursor
  - Below price: "Suggested ₦2,200" in Albert Sans 13pt dim
  - Row of 4 quick-adjuster chips evenly spaced: "−500", "−100", "+100", "+500" (charcoal-teal text on surface-tone background, rounded pill)
  - Small "You keep ₦2,400" line in Albert Sans 12pt coral (same number as price)
  - Bottom: two buttons side by side
    - Left: ghost-style "Decline" (charcoal-teal text, no fill)
    - Right (wider): primary "Submit bid" (coral fill, ivory text, 52pt)
- iOS status bar at top.
```

---

#### SCR-020 — Ride Request Detail / Bid Composer (Slider variant)

**Purpose:** Same as SCR-019 but with a slider input.

**Layout:** Same shell. The hero price area is replaced with:
- Big number at top (current slider value)
- Horizontal slider track (coral fill on left, gray on right, with current % marker)
- Range labels at slider ends: "60%" and "160%"

**Copy:** Same; difference is the price input is via slider.

**Mockup prompt block:**
```
SCREEN: Drivio Ride Request — Bid Composer (Slider variant)
- Same layout as Type variant, BUT replace the price input area with:
  - Big "₦2,400" in Albert Sans bold 56pt coral at top
  - Below: horizontal slider track (8pt thick, coral fill on left up to current value, surface-tone gray on right, with a circular knob at the current position 64% of the way across)
  - Below track: "60%" and "160%" labels at each end in Albert Sans 11pt mono dim
  - Below slider: "Suggested ₦2,200" in 13pt dim
- Everything else unchanged.
- iOS status bar at top.
```

---

#### SCR-021 — Ride Request Detail / Bid Composer (Chips variant)

**Purpose:** Same but with 4 preset chips.

**Layout:** Same shell. The price input is replaced with:
- Big number at top (currently selected chip value)
- Row of 4 chips: −15% / Suggested / +15% / +30%
- Selected chip has coral fill + ivory text; others are surface-tone outlines

**Copy:** Same.

**Mockup prompt block:**
```
SCREEN: Drivio Ride Request — Bid Composer (Chips variant)
- Same layout as Type variant, BUT replace the price input area with:
  - Big "₦2,200" in Albert Sans bold 56pt coral at top
  - Below: row of 4 equal-width chips (each ~80pt wide, 44pt tall, rounded pill)
    - Chip 1: "−15%" + "₦1,870" stacked, surface-tone outline
    - Chip 2: "Suggested" + "₦2,200" stacked, coral filled (SELECTED) with ivory text
    - Chip 3: "+15%" + "₦2,530" stacked, surface-tone outline
    - Chip 4: "+30%" + "₦2,860" stacked, surface-tone outline
- Everything else unchanged.
- iOS status bar at top.
```

---

#### SCR-022 — Bid Submitted (waiting for outcome)

**Purpose:** Show driver that bid is in. Wait for accept/reject/expiry.

**Reached from:** Bid composer → Submit
**Reaches:** Active trip (SCR-023) if won, or back to home if lost/expired

**Layout:**
- Charcoal-teal background (dark moment of suspense)
- Center: coral pulsing ring + countdown "00:42" in mono ivory
- Above: title "Bid in." Marcellus 36pt ivory
- Below countdown: "₦2,400 · 4.2 km" mono ivory
- Status: "Waiting for the rider to choose." Albert Sans 14pt ivory dim
- Bottom: ghost "Withdraw bid" button

**Copy:**
- Title: `Bid in.`
- Countdown: `00:42`
- Sub: `₦2,400 · 4.2 km`
- Status: `Waiting for the rider to choose.`
- CTA: `Withdraw bid`

**Mockup prompt block:**
```
SCREEN: Drivio Bid Submitted (waiting)
- Full-bleed charcoal-teal background.
- Center: a coral circle (~140pt diameter) pulsing softly, with text inside:
  - Top of circle: "00:42" in Marcellus 36pt ivory (the countdown)
  - Below: "BID IN" in Albert Sans bold uppercase 10pt coral
- Above the circle: title "Bid in." in Marcellus 36pt ivory, centered
- Below circle: "₦2,400 · 4.2 km" in mono ivory
- Status text below: "Waiting for the rider to choose." in Albert Sans 14pt dim ivory, centered
- Bottom: ghost "Withdraw bid" text-button (ivory dim, centered)
- iOS status bar at top.
```

---

### 3.6 Active Trip

#### SCR-023 — Trip Assigned (just won)

**Purpose:** Driver just won a bid. Confirm details + go to pickup.

**Layout:**
- Map top (showing driver position + pickup pin + route)
- Top overlay: "GOT IT · KEMI" in coral pill
- Bottom sheet:
  - Eyebrow "ASSIGNED"
  - Headline (Marcellus 22pt): "Kemi · 8 Marina Rd"
  - Vehicle expected (text + "look out for the rider")
  - Locked fare (Albert Sans bold 32pt coral): "₦2,400"
  - Two CTAs side-by-side: ghost "Chat" + primary "Start drive" (coral)

**Copy:**
- Pill: `GOT IT · KEMI`
- Eyebrow: `ASSIGNED`
- Headline: `Kemi · 8 Marina Rd`
- Sub: `Look for Kemi in front of the building.`
- Fare: `₦2,400`
- CTAs: `Chat`, `Start drive`

**Mockup prompt block:**
```
SCREEN: Drivio Active Trip (Just Assigned)
- Top 50%: map showing the driver's current location pin + a coral pickup pin, with a coral route polyline connecting them.
- Over the map, top-center: a coral pill "GOT IT · KEMI" in Albert Sans bold uppercase ivory text.
- Bottom sheet (rounded top corners, ivory):
  - Eyebrow "ASSIGNED" in Albert Sans bold uppercase 11pt coral
  - Headline "Kemi · 8 Marina Rd" in Marcellus 22pt charcoal-teal
  - Body "Look for Kemi in front of the building." in Albert Sans 13pt dim
  - "LOCKED FARE" eyebrow + "₦2,400" in Albert Sans bold 32pt coral
  - Two buttons side-by-side at the bottom:
    - Ghost "Chat" (charcoal-teal text, no fill)
    - Primary "Start drive" (coral fill, ivory text, 52pt, wider)
- iOS status bar at top.
```

---

#### SCR-024 — Trip En Route

**Layout:**
- Map full-bleed (top 60%): driver's live location dot moving toward pickup pin
- Coral route polyline showing remaining path
- Top overlay: small "EN ROUTE TO KEMI" pill
- Bottom sheet:
  - ETA hero (Albert Sans bold 32pt charcoal-teal): "3 min"
  - "to pickup" small sub
  - Status: "Kemi at 8 Marina Rd"
  - Locked fare row (small)
  - Primary CTA: "I've arrived"

**Copy:**
- Pill: `EN ROUTE TO KEMI`
- ETA: `3 min`
- Status: `Kemi at 8 Marina Rd`
- Fare: `Locked: ₦2,400`
- CTA: `I've arrived`

**Mockup prompt block:**
```
SCREEN: Drivio Active Trip (En Route to Pickup)
- Top 60%: map showing the driver's car position moving along a coral route polyline toward a coral pickup pin. The map is teal toned.
- Over the map top-center: pill "EN ROUTE TO KEMI" coral fill.
- Bottom sheet:
  - Eyebrow "EN ROUTE" coral uppercase
  - ETA "3 min" in Albert Sans bold 36pt charcoal-teal, with "to pickup" smaller below
  - Below: "Kemi at 8 Marina Rd" in Marcellus 16pt
  - Locked-fare row: "Locked fare" small label + "₦2,400" mono coral
  - Primary "I've arrived" button (coral fill, full-width, 52pt)
- iOS status bar at top.
```

---

#### SCR-025 — Trip Arrived (waiting for passenger)

**Layout:**
- Map (driver + pickup pin colocated)
- Top overlay: "WAITING FOR KEMI" pill
- Bottom sheet:
  - Status (Marcellus 22pt): "Kemi knows you're here."
  - Sub: "Waiting up to 5 minutes."
  - Locked fare
  - Two CTAs: ghost "Chat" + primary "Start trip"

**Copy:**
- Pill: `WAITING FOR KEMI`
- Status: `Kemi knows you're here.`
- Sub: `Waiting up to 5 minutes.`
- CTAs: `Chat`, `Start trip`

**Mockup prompt block:**
```
SCREEN: Drivio Active Trip (Arrived — Waiting)
- Top 50%: map showing driver and pickup co-located.
- Pill top: "WAITING FOR KEMI"
- Bottom sheet:
  - Eyebrow "ARRIVED" coral
  - Status "Kemi knows you're here." in Marcellus 22pt
  - Sub "Waiting up to 5 minutes." in Albert Sans 13pt dim
  - Locked fare row
  - Two buttons: ghost "Chat" + primary "Start trip" (coral)
- iOS status bar at top.
```

---

#### SCR-026 — Trip In Progress

**Layout:**
- Map full-bleed (60%): live driver + dropoff pin + coral route
- Coral progress bar at top of sheet showing fraction
- Bottom sheet:
  - "IN PROGRESS" eyebrow
  - Status: "On your way · 8 min to Lekki Phase 1"
  - Locked fare
  - Primary: "End trip"
  - Ghost: "Safety"

**Copy:**
- Eyebrow: `IN PROGRESS`
- Status: `On your way · 8 min to Lekki Phase 1`
- CTAs: `Safety`, `End trip`

**Mockup prompt block:**
```
SCREEN: Drivio Active Trip (In Progress)
- Top 60%: map with driver position moving toward a teal dropoff pin via coral route polyline.
- Bottom sheet:
  - Coral progress bar at top (60% filled, mint progress)
  - Eyebrow "IN PROGRESS" coral
  - Status "On your way · 8 min to Lekki Phase 1" in Marcellus 18pt
  - Locked fare row
  - Two buttons: ghost "Safety" + primary "End trip" (coral fill)
- iOS status bar at top.
```

---

#### SCR-027 — Trip Completed (earnings summary)

**Layout:**
- Ivory background (no map)
- Top: small "Drivio" wordmark
- Center: large coral circle with check icon
- Title (Marcellus 36pt): "Trip complete."
- Hero earned: Albert Sans bold 56pt coral "+₦2,400"
- Trip recap card: pickup, drop-off, distance, duration
- "Rate Kemi" 5-star row
- Primary CTA: "Done"

**Copy:**
- Title: `Trip complete.`
- Earned: `+₦2,400`
- Card: pickup, dropoff, distance, duration
- Rate: `Rate Kemi`
- CTA: `Done`

**Mockup prompt block:**
```
SCREEN: Drivio Trip Completed
- Light ivory background.
- Top: small "Drivio" wordmark in Marcellus 18pt charcoal-teal with coral dot.
- Center: large coral filled circle (~96pt) with an ivory check icon (Lucide).
- Title "Trip complete." in Marcellus 36pt charcoal-teal, centered.
- Earned: "+₦2,400" in Albert Sans bold 56pt coral, centered (with tabular figures).
- Below: a "TRIP RECAP" card (surface tone, rounded, hairline):
  - "Pickup" + "8 Marina Rd"
  - "Drop-off" + "Lekki Phase 1"
  - "Distance" + "4.2 km"
  - "Duration" + "14 min"
- "Rate Kemi" row with 5 ★ icons (empty Lucide stars, tappable)
- Bottom: primary "Done" button (coral, full-width, 52pt)
- iOS status bar at top.
```

---

### 3.7 Communications & Safety

#### SCR-028 — Chat (with passenger)

**Layout:**
- Header with passenger name + back
- Quick-reply chip row at top
- Bubble list (driver bubbles right coral; passenger bubbles left ivory-light)
- Composer at bottom

**Copy:** Sample messages.

**Mockup prompt block:**
```
SCREEN: Drivio Trip Chat
- Light ivory background.
- Header bar (top): back button + "Kemi" in Marcellus 18pt + small status pill "1 min away"
- Quick-reply chip row (horizontally scrollable): "I'm here", "Coming up the road", "Where exactly?", "Could you come outside?", "Almost there"
- Bubble list area:
  - Right-aligned coral bubble (driver): "I'm here" + timestamp below
  - Left-aligned ivory-light bubble (passenger): "Coming down now"
  - Right-aligned coral bubble: "All good"
- Composer at bottom: text input + a paper-plane send icon in coral
- iOS status bar at top.
```

---

#### SCR-029 — Call (ringing → active)

**Layout:**
- Charcoal-teal full bleed
- Avatar circle large
- Name (Marcellus 28pt ivory)
- Status: "Calling..." → after connect: "00:23" timer
- Large coral end-call button at bottom
- (Active mode adds mute/speaker/keypad row)

**Copy:** `Calling Kemi...`, `00:23`, `End call`

**Mockup prompt block:**
```
SCREEN: Drivio Call (Ringing → Active)
- Full-bleed charcoal-teal background.
- Center: large avatar circle (~120pt) with initial "K" + soft outer pulse animation.
- Below avatar: name "Kemi" in Marcellus 28pt ivory.
- Below name: status "Calling..." in Albert Sans 14pt dim ivory.
- Bottom: large red round end-call button (warm red ~ #CC3D2F, 72pt diameter) with an ivory phone-hangup icon.
- (For active mode variant: also show a row of mute, speaker, keypad buttons above the end-call.)
- iOS status bar at top.
```

---

#### SCR-030 — Safety / SOS

**Layout:**
- Ivory bg with red accent stripe top
- Eyebrow: "SAFETY"
- Title: "If something's wrong"
- Huge SOS button (red filled, ~140pt, hold-to-activate ring around it)
- Quick-action rows below:
  - Call trusted contact
  - Share trip
  - Report unsafe rider
- Trusted contacts list (manage)

**Copy:**
- Title: `If something's wrong`
- SOS instruction: `Hold to alert Drivio`
- Actions: `Call trusted contact`, `Share trip`, `Report unsafe rider`

**Mockup prompt block:**
```
SCREEN: Drivio Safety / SOS
- Light ivory background with a 4pt warm-red horizontal stripe at top.
- Eyebrow "SAFETY" Albert Sans bold uppercase red.
- Title "If something's wrong" Marcellus 28pt charcoal-teal.
- Hero: large round warm-red button (~140pt diameter) labeled "HOLD" in ivory, with a faint outer ring suggesting hold-to-activate progress.
- Instruction "Hold to alert Drivio" in Albert Sans 14pt dim, below the button.
- Below: 3 quick-action rows (rounded surface-tone cards, hairline border):
  - "Call trusted contact" + chevron right
  - "Share trip" + chevron right
  - "Report unsafe rider" + chevron right
- "Trusted contacts" section header below with a "+ Add" affordance
- iOS status bar at top.
```

---

### 3.8 Earnings

#### SCR-031 — Earnings (Today)

**Layout:**
- Ivory bg
- Top: tab navigation + back (within tab bar context)
- Period segmenter: WEEK / MONTH / YEAR (active = TODAY at first)
- Hero earnings card (Albert Sans bold 56pt coral): "₦18,200" today
- Sub: "Today, across 12 trips"
- 4-metric grid: Avg fare, Trips, Accept rate, Cancel rate
- Coach tip cards stack
- Chart placeholder (bars)
- Tab bar at bottom (Earnings active)

**Copy:**
- Header: `Earnings`
- Period: `WEEK`, `MONTH`, `YEAR`
- Hero: `₦18,200`
- Sub: `Today, across 12 trips`
- Metrics: `Avg fare ₦1,517`, `Trips 12`, `Accept rate 78%`, `Cancel rate 4%`

**Mockup prompt block:**
```
SCREEN: Drivio Earnings (Today)
- Light ivory background.
- Top: title "Earnings" in Marcellus 28pt charcoal-teal.
- Below title: 3-segment selector "WEEK / MONTH / YEAR" with WEEK highlighted coral (and "TODAY" implicit since current).
- Hero earnings card (surface tone, rounded 24pt margins):
  - Eyebrow "TODAY"
  - Big "₦18,200" in Albert Sans bold 56pt coral
  - Sub "Today, across 12 trips" in 13pt dim
- Below: 2x2 grid of metric cards (each surface tone, hairline border):
  - "AVG FARE" "₦1,517"
  - "TRIPS" "12"
  - "ACCEPT RATE" "78%"
  - "CANCEL RATE" "4%"
- Below grid: 1-2 coach-tip cards (coral/amber tinted)
- Below: bar chart for the period (placeholder visual)
- Tab bar at bottom (Earnings active)
- iOS status bar at top.
```

---

#### SCR-032 — Earnings (Week / Month / Year switches)

(Same layout as SCR-031; period segmenter switches the chart + hero data. ChatGPT prompt is same with period swap.)

---

### 3.9 Pricing Strategy

#### SCR-033 — Pricing Strategy (main)

**Layout:**
- Ivory bg
- Tab in tab bar (Pricing active)
- Title (Marcellus 28pt): "Pricing strategy"
- Body: "Your defaults for the bid composer."
- Section: Base + per-km (each a stepper row)
- Section: Peak hours (toggle + slider)
- Section: Night shift (toggle + slider)
- Section: Trip preferences (Max pickup distance + Preferred trip length — chevron rows)
- Live preview at the bottom:
  - "Example: 8 km would suggest ₦2,200"

**Copy:**
- Title: `Pricing strategy`
- Body: `Your defaults for the bid composer.`
- Rows: `Base fare ₦600`, `Per km ₦200`, `Peak hours (off/on with 1.5× slider)`, `Night shift (off/on with 1.2× slider)`
- Preferences: `Max pickup distance`, `Preferred trip length`
- Preview: `Example: 8 km would suggest ₦2,200`

**Mockup prompt block:**
```
SCREEN: Drivio Pricing Strategy
- Light ivory background.
- Title "Pricing strategy" in Marcellus 28pt charcoal-teal.
- Body "Your defaults for the bid composer." in Albert Sans 14pt dim.
- Section "DEFAULTS":
  - Row: "Base fare" + stepper (− "₦600" +) on the right
  - Row: "Per km" + stepper (− "₦200" +)
- Section "SURCHARGES":
  - Row: "Peak hours" toggle ON, with multiplier "1.5×" + a small slider below
  - Row: "Night shift" toggle OFF, with multiplier "1.2×"
- Section "TRIP PREFERENCES":
  - Row: "Max pickup distance" + value "3 km" + chevron right
  - Row: "Preferred trip length" + value "Any" + chevron right
- Live preview card at bottom:
  - "Example: 8 km would suggest ₦2,200" in Marcellus 18pt
  - Sub: "₦600 + ₦200 × 8 km × 1.5× peak = ₦3,300" in mono dim
- Tab bar at bottom (Pricing active)
- iOS status bar at top.
```

---

#### SCR-034 — Max Pickup Distance Picker

**Layout:**
- Detail-scaffold with title
- Slider 0–10 km with snap stops
- Current value display
- Map preview showing the radius circle

**Mockup prompt block:**
```
SCREEN: Drivio Max Pickup Distance Picker
- Light ivory background.
- Back button + title "Max pickup distance" in Marcellus 18pt.
- Body "We won't show requests further than this."
- Hero: "3 km" in Albert Sans bold 56pt coral.
- Horizontal slider 0–10 km with snap stops every 1 km. Coral fill up to 3.
- Below slider: small map preview showing the driver's location with a coral circle representing the 3km radius.
- iOS status bar at top.
```

---

#### SCR-035 — Preferred Trip Length Picker

**Layout:**
- 4 chips: Short (<5km), Medium (5–15km), Long (>15km), Any
- Selected = coral fill

**Mockup prompt block:**
```
SCREEN: Drivio Preferred Trip Length
- Light ivory background.
- Back + title "Preferred trip length".
- Body "We'll prioritize requests of this length."
- 4 horizontal pill chips:
  - "Short" / "<5 km" — surface tone
  - "Medium" / "5–15 km" — surface tone
  - "Long" / ">15 km" — surface tone
  - "Any" — coral filled (SELECTED)
- Below: small dim text "You can still see all requests; this just prioritises."
- iOS status bar at top.
```

---

### 3.10 Profile

#### SCR-036 — Profile Hub

**Layout:**
- Ivory bg
- Hero header: avatar circle + name + ★ rating + "VERIFIED" pill
- 3-stat strip: Joined / Lifetime trips / Lifetime earnings
- Groups stacked:
  - Vehicle row (model + plate + chevron)
  - Documents (all 6 docs status)
  - Reviews (most recent + chevron)
  - Account (subscription, referral, payment methods)
  - Settings (help, sign out)

**Copy:**
- Stats: `Joined May 2026`, `12 trips`, `₦17,700`
- Pill: `VERIFIED`
- Rows: as listed

**Mockup prompt block:**
```
SCREEN: Drivio Profile Hub
- Light ivory background.
- Hero header (surface tone, rounded, generous padding):
  - Avatar circle (~64pt) with gradient + initial "E" in Marcellus, centered top
  - Name "Ebube Okocha" Marcellus 22pt below avatar
  - ★ Rating "4.9 ★" in butter color + "VERIFIED" pill (coral-tinted background, coral text, rounded pill, 6pt padding)
- 3-stat strip: "JOINED" "May 2026" / "TRIPS" "12" / "LIFETIME" "₦17,700"
- Group cards stacked:
  - "VEHICLE" row: Toyota Corolla · 36566FG (mono pill) · chevron
  - "DOCUMENTS" row: 6 status pills (or "All verified" condensed) · chevron
  - "REVIEWS" row: most recent review snippet · chevron
  - "ACCOUNT" group: rows for "Subscription · Drivio Pro Weekly · Renews Mon" (or "· Trial · 67 days left" during trial), "Referral code · DR8KH9", "Payment methods" · chevrons
  - "SETTINGS" group: rows for "Appearance", "Help", "Sign out"
- Tab bar at bottom (Profile active)
- iOS status bar at top.
```

---

#### SCR-037 — Reviews (passenger ratings)

**Layout:**
- Detail scaffold with title
- Hero: rating average "4.9 ★" Albert Sans bold 56pt with breakdown bars below (5/4/3/2/1 stars)
- Top tags chips ("On time", "Friendly", "Smooth driver")
- Recent reviews list

**Mockup prompt block:**
```
SCREEN: Drivio Reviews
- Light ivory background.
- Back + title "Reviews".
- Hero: average rating "4.9 ★" in Albert Sans bold 56pt butter color, centered.
- Below: 5 horizontal bars labeled 5★ to 1★ with bar-fill proportional to count.
- Top tags chips horizontally: "On time", "Friendly", "Smooth driver" (surface tone pills).
- Recent reviews list (each row): passenger name + ★ rating + review text + time-ago.
- iOS status bar at top.
```

---

#### SCR-038 — Payment Methods / Payout Account

**Layout:**
- Detail scaffold
- Title: "Manage payment"
- Wallet balance card: current balance + Withdraw button
- Payout account card: bank name + masked account number + "Edit" link
- Billing history: list of subscription debits

**Mockup prompt block:**
```
SCREEN: Drivio Manage Payment
- Light ivory background.
- Back + title "Manage payment".
- Wallet card (coral-tinted background, ivory text):
  - Eyebrow "WALLET BALANCE"
  - Big "₦24,800" in Albert Sans bold 56pt ivory
  - Primary "Withdraw" button (ivory fill, coral text, full-width within card)
- "PAYOUT ACCOUNT" section:
  - Card: bank name "GTBank · ****4567" + "Edit" link
  - "Account: Ebube Okocha"
- "BILLING HISTORY" section:
  - List of past subscription debits: "Drivio Pro Weekly · May 25, 2026 · −₦15,000" (varies by tier)
- iOS status bar at top.
```

---

#### SCR-039 — Referral

**Layout:**
- Detail scaffold
- Hero: referral code in mono large + "Share" button
- "How it works" 3-step illustration
- Stats: referred / active / pending counts
- Free-months-earned line

**Mockup prompt block:**
```
SCREEN: Drivio Referral
- Light ivory background.
- Back + title "Refer & earn".
- Hero: big referral code "DR8KH9" in mono 40pt charcoal-teal, centered in a coral-tinted card.
- "SHARE" button below code (coral fill, ivory text).
- "How it works" 3-step icons + text rows.
- Stats grid: "REFERRED" "5", "ACTIVE" "3", "PENDING" "2".
- Footer line: "You've earned 3 free months · ₦15,000 saved" in Marcellus 16pt.
- iOS status bar at top.
```

---

#### SCR-040 — Edit Profile

**Layout:**
- Form-style detail scaffold
- Avatar upload at top
- Form fields: Name, Email, DOB, Gender, (Phone is read-only)
- Save CTA

**Mockup prompt block:**
```
SCREEN: Drivio Edit Profile
- Light ivory background.
- Back + title "Edit profile".
- Avatar at top with "Change photo" link.
- Stacked form fields: "Full name", "Email", "Date of birth" (date picker), "Gender" (chevron picker).
- "Phone" field shown grayed out with "Verified · can't change" caption.
- Bottom: "Save" button (coral, full-width).
- iOS status bar at top.
```

---

#### SCR-041 — Help (Static)

**Layout:**
- Detail scaffold
- List of expandable topics
- "Contact us" footer with email + WhatsApp

**Mockup prompt block:**
```
SCREEN: Drivio Help
- Light ivory background.
- Back + title "Help".
- Topic accordions list (each collapsible):
  - "How does the bid composer work?"
  - "When do payouts arrive?"
  - "What happens when my subscription expires?"
  - "How do I update my vehicle?"
  - "How do I cancel a trip?"
  - Etc.
- Bottom "CONTACT US" section:
  - "Email support · support@drivio.app"
  - "WhatsApp us · +234 ..." rows
- iOS status bar at top.
```

---

#### SCR-042 — Sign Out + Danger Zone

**Layout:**
- Detail scaffold
- "Sign out" primary CTA
- Danger zone section (red accent)
- "Delete my account" with confirmation flow

**Mockup prompt block:**
```
SCREEN: Drivio Sign Out & Danger Zone
- Light ivory background.
- Back + title "Account".
- "Sign out" primary button (charcoal-teal fill, ivory text, full-width).
- Section separator + "DANGER ZONE" eyebrow in red.
- Card with red accent: "Delete my account" + body "This permanently removes your account after a 30-day grace period."
- Red "Delete my account" button (warm red fill, ivory text, full-width).
- iOS status bar at top.
```

---

### 3.11 Subscription Management

#### SCR-043 — Subscription Manage

**Purpose:** Show current tier, status, next renewal, billing history. Entry point to change tier, update payment method, cancel.

**Layout:**
- Detail scaffold (back + title "Subscription")
- Hero card (charcoal-teal background, ivory text):
  - Eyebrow: "DRIVIO PRO · <CURRENT_TIER>" (e.g., "DRIVIO PRO · WEEKLY")
  - Big price: "₦15,000 / week" Albert Sans bold 36pt coral
  - Status pill (Trial / Active / Past due / Expired) — coral / teal / amber / red
  - Renewal row: "Renews <date + time>" Albert Sans 14pt dim ivory
  - Progress bar (coral fill at % of period elapsed)
- Below hero card:
  - **Pending switch notice** (only if `pending_plan_id` not null): ivoryLight banner "Switch queued — you'll move to <new tier> at <renewal date>. **Cancel switch**"
- "PLAN" group (DetailGroup-style):
  - Row: "Change plan" → opens SCR-006b
  - Row: "Update payment method" → Paystack-managed
- "BILLING HISTORY" list (last 12 entries):
  - Each row: charge date + tier-aware label ("Drivio Pro Weekly · −₦15,000 · Paid")
  - Tap row → receipt detail
- Bottom danger zone:
  - "Cancel subscription" text link in red (with confirm sheet: "You'll keep access until your current period ends, then bidding stops. Continue?")

**Copy:**
- Title: `Subscription`
- Hero eyebrow: `DRIVIO PRO · WEEKLY` (or DAILY / MONTHLY)
- Hero price: `₦15,000 / week` (varies per tier)
- Status: `Active` (or Trial / Past due / Expired)
- Renews: `Renews Mon, Jun 8 at 23:00 WAT`
- Pending switch banner (if applicable): `Switch queued — you'll move to Monthly (₦50,000) at your next renewal. Cancel switch`
- Group: `PLAN` with rows `Change plan` · `Update payment method`
- Billing row format: `Drivio Pro <Tier> · −₦<amount> · Paid`

**States:**
- Trial (no charge yet) — Hero hides "Renews"; shows "Trial ends Aug 12" instead; "Change plan" CTA is "Pick a plan early"
- Active (current tier)
- Active with pending switch
- Past due (amber pill + "Update payment" CTA prominent)
- Expired (red pill + "Pick a plan" CTA prominent; routes to SCR-006b)

**Mockup prompt block:**
```
SCREEN: Drivio Subscription Manage (Active, Weekly tier)
- Light ivory (#F4ECE0) background.
- Back chevron-left top-left + title "Subscription" Marcellus 22pt centered.
- Hero card (full-width minus 20pt margin, charcoal-teal #0E2E2E background, ivory text, rounded 16pt):
  - Eyebrow uppercase Albert Sans bold 10pt letter-spaced 1.6, dim-ivory: "DRIVIO PRO · WEEKLY"
  - Massive "₦15,000 / week" Albert Sans bold 36pt coral
  - Pill below price: "Active" Albert Sans bold 11pt with green-success background ivory text
  - Row below "Renews Mon, Jun 8 at 23:00 WAT" Albert Sans 13pt dim-ivory with calendar icon (Lucide)
  - Thin coral progress bar at bottom of card (~50% fill)
- Group card "PLAN" ivoryLight (#FBF7EE) with hairline border:
  - Row 1: Lucide refresh-cw icon + "Change plan" + chevron-right
  - Row 2 (divided by hairline): Lucide credit-card icon + "Update payment method" + chevron-right
- Group card "BILLING HISTORY" ivoryLight hairline:
  - Row "Drivio Pro Weekly · −₦15,000 · Paid · Mon Jun 1" Albert Sans 14pt
  - Row "Drivio Pro Weekly · −₦15,000 · Paid · Mon May 25"
  - Row "Drivio Pro Weekly · −₦15,000 · Paid · Mon May 18"
  - More rows
- Bottom danger zone:
  - "Cancel subscription" text link in red Albert Sans medium 13pt centered
- iOS status bar at top.
```

**Variant — with pending tier switch:**

```
SCREEN: Drivio Subscription Manage (with pending Weekly → Monthly switch)
- Same as above, but BELOW the hero card and ABOVE the PLAN group:
  - Pending switch banner card: coral hairline border, ivoryLight background, generous padding
  - Lucide info icon coral + "Switch queued" Marcellus 14pt charcoal-teal
  - Body Albert Sans 13pt: "You'll move to Monthly (₦50,000) at your next renewal on Mon Jun 8."
  - Right-aligned text link "Cancel switch" in teal underline
```

---

#### SCR-043b — Confirm Tier Switch (Modal)

**Purpose:** Confirm the tier change is queued and explain when it takes effect.

**Reached from:** SCR-006b → after driver picks a new tier (when already on a different active tier)

**Layout:** Modal sheet, ivory base
- Title (Marcellus 22pt): "Switch to <new tier>?"
- Body: "Your <current tier> stays active until <current_period_end>. From then on, you'll pay ₦<new price> per <new cadence>. We won't charge anything today."
- Comparison row: "<Current tier> ₦<current> per <current cadence>" → "<New tier> ₦<new> per <new cadence>"
- Primary CTA: "Queue switch"
- Secondary text button: "Keep current plan"

**Copy:**
- Title: `Switch to Monthly?`
- Body: `Your Weekly plan stays active until Mon, Jun 8 at 23:00 WAT. From then on, you'll pay ₦50,000 every 30 days. We won't charge anything today.`
- CTA: `Queue switch`
- Cancel: `Keep current plan`

**States:**
- Default
- Submitting (CTA spinner)
- Success — modal dismisses; SCR-043 updates with pending switch banner

**Mockup prompt block:**
```
SCREEN: Drivio Confirm Tier Switch — modal
- Centered modal sheet 560pt wide on dimmed page backdrop (charcoal-teal scrim 50% opacity).
- Ivory (#F4ECE0) modal with rounded 20pt corners, generous padding.
- Title Marcellus 22pt charcoal-teal: "Switch to Monthly?"
- Body Albert Sans 14pt: "Your Weekly plan stays active until Mon, Jun 8 at 23:00 WAT. From then on, you'll pay ₦50,000 every 30 days. We won't charge anything today."
- Comparison row with two side-by-side mini cards (ivoryLight, hairline):
  - Left "WEEKLY · ₦15,000" with eyebrow color "CURRENT"
  - Right "MONTHLY · ₦50,000" with eyebrow color "NEW"
  - Coral arrow icon between them
- Footer right-aligned:
  - Ghost text button "Keep current plan"
  - Coral primary button "Queue switch" Albert Sans bold
- iOS status bar at top.
```

---

### 3.12 Notifications

#### SCR-044 — Notifications Inbox

**Layout:**
- Detail scaffold
- List of notifications (newest first), each = icon + title + body + time-ago + unread dot

**Mockup prompt block:**
```
SCREEN: Drivio Notifications Inbox
- Light ivory background.
- Back + title "Notifications".
- List of notification rows (each surface tone, hairline border):
  - Coral dot (unread) + icon (Lucide e.g., dollar-sign) + headline "Payout settled · ₦18,200" + sub time-ago.
  - Coral dot + icon (star) + "New review · 5 ★"
  - Gray dot (read) + icon (alert-triangle) + "Drivers' licence expires in 30 days"
  - More rows.
- iOS status bar at top.
```

---

### 3.13 Edge States

#### SCR-045 — No Requests

**Layout:**
- Centered IconDisc (coral) + h1 + bodySm + CTA "Go offline" or "Try a different zone"

**Mockup prompt block:**
```
SCREEN: Drivio Edge — No Requests
- Light ivory background.
- Centered coral IconDisc (60pt) with bell-off icon (Lucide).
- Title "Quiet right now." Marcellus 28pt charcoal-teal centered.
- Body "No requests in your zone in the last few minutes. Try moving toward Lekki or staying online — peak's coming." Albert Sans 14pt dim centered.
- CTA "Go offline" ghost-style centered.
- iOS status bar at top.
```

---

#### SCR-046 — Offline (no network)

**Layout:**
- Centered IconDisc (red) + h1 + body + CTA

**Mockup prompt block:**
```
SCREEN: Drivio Edge — Offline
- Light ivory background.
- Centered red IconDisc with wifi-off icon.
- Title "No connection." Marcellus 28pt.
- Body "We'll keep trying. Any actions are queued and will land when you're back."
- CTA "Retry" ghost centered.
- iOS status bar at top.
```

---

#### SCR-047 — Subscription Expired

**Purpose:** Tier-aware lockout. Driver picked a tier in the past but their subscription expired. The body copy includes their last tier so the renewal feels familiar.

**Layout:**
- Centered IconDisc (red, square, large bordered) with lock icon
- Title "Subscription paused."
- Body: tier-aware — "Your <last tier> ended on <date>. Pick a plan to get back on the marketplace."
- Primary "Pick a plan" CTA (coral, full-width) → routes to SCR-006b
- Below: "Sign out" text link

**Copy:**
- Title: `Subscription paused.`
- Body (one of, based on last subscription):
  - `Your Daily plan ended at 23:00 today. Pick a plan to get back on the marketplace.`
  - `Your Weekly plan ended on Mon, Jun 8. Pick a plan to get back on the marketplace.`
  - `Your Monthly plan ended on Jun 1. Pick a plan to get back on the marketplace.`
- CTA: `Pick a plan`
- Secondary: `Sign out`

**Mockup prompt block:**
```
SCREEN: Drivio Edge — Subscription Expired (tier-aware)
- Light ivory (#F4ECE0) background.
- Centered large red IconDisc (~72pt, square, bordered) with lock icon (Lucide).
- Title "Subscription paused." Marcellus 28pt charcoal-teal.
- Body Albert Sans 14pt dim charcoal-teal centered, max 360pt wide: "Your Weekly plan ended on Mon, Jun 8. Pick a plan to get back on the marketplace."
- Primary "Pick a plan" button (coral fill, ivory text, 52pt, full-width minus 20pt margins) Albert Sans bold.
- Below: "Sign out" text link in teal centered.
- iOS status bar at top.
```

---

#### SCR-048 — Rider Cancelled

**Layout:**
- IconDisc (amber)
- Title "Rider cancelled."
- Body about compensation if applicable
- Back-to-home CTA

**Mockup prompt block:**
```
SCREEN: Drivio Edge — Rider Cancelled
- Light ivory background.
- Centered amber IconDisc with x-circle icon.
- Title "Rider cancelled." Marcellus 28pt.
- Body "You were en route. We'll credit ₦400 to your wallet — Drivio covers driver compensation when riders cancel after acceptance."
- "Back to home" CTA (coral, full-width).
- iOS status bar at top.
```

---

### 3.14 Other Specialty Screens

#### SCR-049 — Document Re-upload

**Layout:** Identical to SCR-010 (document upload), with a top banner explaining the rejection reason.

#### SCR-050 — Trusted Contacts (add)

**Layout:**
- Bottom sheet modal
- Name field
- Phone field (E.164)
- Primary toggle
- Save CTA

**Mockup prompt block:**
```
SCREEN: Drivio Add Trusted Contact (bottom sheet)
- Modal sheet rising from the bottom, rounded top corners.
- Eyebrow "ADD TRUSTED CONTACT".
- Field: "Name"
- Field: "Phone" with 🇳🇬 +234 prefix
- Toggle: "Make primary"
- Save button (coral) + Cancel below.
- iOS status bar at top.
```

---

#### SCR-051 — Subscription Gate Sheet

**Layout:**
- Modal scrim over current screen
- Centered IconDisc (red square, 72pt bordered)
- Pill: "PAUSED"
- Title (h1): "Your subscription paused."
- Body: explaining + CTA "Renew now" coral + "Maybe later" ghost

**Mockup prompt block:**
```
SCREEN: Drivio Subscription Gate Sheet (modal)
- Dimmed scrim over the home page in background.
- Centered modal card (rounded, surface tone) ~70% width:
  - Red IconDisc 72pt with lock icon
  - Pill "PAUSED" red-tinted
  - Title "Your subscription paused." Marcellus 22pt
  - Body explaining the issue
  - Primary "Renew now" button (coral)
  - Ghost "Maybe later" button
- iOS status bar at top.
```

---

#### SCR-052 — KYC Gate Sheet

(Same shell as SCR-051 but with KYC copy and amber icon.)

#### SCR-053 — Location Gate Sheet

(Same shell with location-pin icon and copy.)

#### SCR-054 — Vehicle Gate Sheet

(Same shell with car icon.)

---

### 3.15 Splash + Permission variants

(Covered in SCR-001 with state variants.)

---

## 4. Flow Catalog

End-to-end sequences. Each flow lists screens in order.

---

### FLOW-01 — New Driver: Sign Up → First Bid

**Sequence:**
1. SCR-001 (Splash) → "Allow location" → wait for permission
2. SCR-002 (Welcome) → "Get started"
3. SCR-003 (Sign Up form) → fill form → "Continue"
4. SCR-005 (OTP) → enter 6 digits → "Verify & continue"
5. SCR-006 (Paywall) → "Start trial — KYC next"
6. SCR-007 (KYC Orchestrator)
7. SCR-008 (BVN/NIN) → "Verify"
8. SCR-009 (Selfie + Liveness) → capture
9. SCR-010 (Document upload × 6 in sequence)
10. SCR-011 (KYC Pending Review)
11. *[Admin approves overnight]*
12. SCR-013 (Add Vehicle) → fill form → "Save"
13. *[Admin approves vehicle]*
14. SCR-016 (Home offline) → "Go online"
15. SCR-017 (Home online, no requests)
16. SCR-018 (Home online with requests) → tap card
17. SCR-019 (Bid composer) → set price → "Submit bid"
18. SCR-022 (Bid submitted, waiting)
19. (Won) SCR-023 (Trip assigned)
20. SCR-024 (En route) → "I've arrived"
21. SCR-025 (Arrived) → "Start trip"
22. SCR-026 (In progress) → "End trip"
23. SCR-027 (Completed)
24. Back to SCR-018 (Home, looking for next)

---

### FLOW-02 — Returning Driver: Typical Day

1. SCR-001 (Splash, auto-routes signed-in)
2. SCR-016 (Home offline)
3. "Go online" → SCR-017 → SCR-018 (with requests)
4. Tap a request → SCR-019 → submit → SCR-022 → SCR-023…SCR-027
5. Repeat 6–12 times throughout the day
6. End of day: tap "Go offline" → back to SCR-016

---

### FLOW-03 — Withdraw Earnings to Bank

1. From SCR-036 (Profile) → "Payment methods" → SCR-038
2. (First time) → bottom sheet to add bank account → save
3. Wallet card → "Withdraw" → enter amount → confirm
4. Status moves to "Processing"
5. Push notification arrives: "Payout settled ₦X" → tap → SCR-044 (Notifications)

---

### FLOW-04 — Subscription Renewal Failure → Recovery (tier-aware)

1. At anniversary moment, Paystack charge fails for driver's current tier
2. Push: "Drivio Pro <Tier> · Payment failed. Update your card." (tier-aware copy)
3. Tap notification → SCR-043 (Subscription Manage) — status pill now `Past due` amber
4. "Update payment method" → enter new card → save → server triggers immediate retry
5. Retry success → status `Active` → banner clears, driver continues

If recovery fails past the tier's grace window (Daily: 1h / Weekly: 12h / Monthly: 3 days):
- Status → `Expired`
- Auto-flip-offline if driver was online and not in a trip
- Open app → SCR-047 (Subscription Expired) — body shows last tier and end date — `Pick a plan` CTA → SCR-006b → driver picks tier (typically same as before, but can switch) → Paystack checkout → success → `/home`

### FLOW-04b — Mid-cycle Tier Switch

1. Driver opens SCR-043 (Subscription Manage)
2. Tap "Change plan" → SCR-006b (Pick a Plan)
3. Recommendation banner reflects their actual platform usage (last 30 days post-trial)
4. Driver picks a different tier → SCR-043b (Confirm Tier Switch modal)
5. Confirm "Queue switch" → server writes `subscriptions.pending_plan_id`
6. SCR-043 reopens with the pending-switch banner visible above the PLAN group
7. At next anniversary: server runs the new tier's charge; `plan_id` updates; `pending_plan_id` clears
8. Push: "You're now on Drivio Pro <NewTier>. Next renewal <date>."

If driver cancels the switch before renewal:
- Open SCR-043 → "Cancel switch" link in pending-switch banner → confirm → `pending_plan_id` clears → renewal proceeds on current tier

---

### FLOW-05 — Safety Event (SOS)

1. From SCR-016 or SCR-024 (any state) → tap Safety FAB → SCR-030
2. Hold SOS button 3 seconds
3. Confirmation screen "Help requested. Stay on this screen."
4. Ops calls driver via masked call (SCR-029 inverse — incoming)

---

### FLOW-06 — Account Deletion

1. SCR-036 (Profile) → "Sign out" group → SCR-042
2. Scroll to Danger Zone → "Delete my account"
3. Confirmation modal: type DELETE → confirm
4. SCR-042 banner: "Deletion scheduled"
5. Driver signed out → SCR-002 (Welcome)

---

### FLOW-07 — KYC Re-upload After Rejection

1. Push notification: "Document rejected — drivers' licence"
2. Tap → SCR-012 (KYC Rejected)
3. → SCR-049 (Re-upload Document) → submit
4. Back to SCR-011 (Pending Review) for that document

---

### FLOW-08 — Switch Vehicle

1. SCR-036 (Profile) → Vehicle row → SCR-014 (Vehicle Details)
2. → "Change vehicle" → SCR-015 (Switcher)
3. Pick a vehicle → "Use this vehicle" → SCR-014 (refreshed)

---

### FLOW-09 — Change Pricing Strategy

1. SCR-016 (Home) → Pricing tab → SCR-033 (Pricing Strategy)
2. Adjust base + per-km → debounced save (no explicit Save button)
3. Toggle peak/night → debounced save
4. → "Max pickup distance" → SCR-034 → save
5. → "Preferred trip length" → SCR-035 → save
6. Back to SCR-033

---

### FLOW-10 — Refer & Earn

1. SCR-036 (Profile) → Referral row → SCR-039
2. Tap "Share" → system share sheet (defer v1.5 — placeholder no-op in v1)

---

### FLOW-11 — Trip Cancellation (Driver-initiated)

1. From SCR-024 (En Route) or SCR-025 (Arrived) → safety FAB or sheet menu → "Cancel trip"
2. Bottom sheet asks for reason (passenger no-show, vehicle issue, safety, other)
3. Confirm → trip status → cancelled
4. Back to SCR-016 (Home)

---

### FLOW-12 — Trip Cancellation (Passenger-initiated)

1. Passenger cancels server-side → trip status → cancelled
2. Driver sees: SCR-048 (Rider Cancelled) with compensation note
3. → "Back to home" → SCR-016

---

### FLOW-13 — Subscription Expiry Mid-Day

1. Driver online, mid-day → subscription expires → server gate flips
2. Driver finishes any active trip (sacred-trip rule)
3. On `onTripCompleted` → auto-flip-offline → SCR-047 (Subscription Expired) shown

---

### FLOW-14 — No Requests / Quiet Day

1. Online for >10 min with zero requests
2. SCR-017 stays; if driver pulls-to-refresh, may surface SCR-045 (No Requests edge state) with suggestions

---

### FLOW-15 — Network Drop Mid-Trip

1. Mid SCR-026 (In Progress), network drops
2. App detects via `ConnectivityController` → banner "Reconnecting..."
3. Local state preserves trip; mutation queue holds outgoing events
4. On reconnect, REST snapshot reconciles trip state; trip continues

---

## 5. Quick Reference for ChatGPT Prompting

### 5.1 Single-screen prompt template

```
[Brand prefix from §2]

[Screen prompt block from §3]

Render as a clean iPhone 14 mockup. The OS status bar at top shows 9:41. Render the screen in light theme (ivory background) unless I specifically say "dark mode" — in which case use charcoal-teal background.
```

### 5.2 Flow prompt template (for image-strip mockups)

```
[Brand prefix from §2]

I'm creating a sequence of mockups for the [FLOW NAME] flow. Render the following N screens side-by-side in order, each as an iPhone 14 mockup.

Screen 1: [prompt block from §3 for SCR-XXX]
Screen 2: [prompt block from §3 for SCR-YYY]
...
```

### 5.3 Variant prompt for component focus

For zoomed/detailed component close-ups (e.g., the bid composer hero number):
```
[Brand prefix from §2]

Show me a close-up of the bid composer hero number area — just the price input region, large and detailed, in light theme. Render the "₦2,400" number in Albert Sans bold 56pt coral, with the "−500 −100 +100 +500" quick-adjuster chip row below, and the "You keep ₦2,400" line below that. Surface-tone background, hairline borders on chips.
```

---

## 6. Coverage Checklist

61 unique screens documented. Verify against:

- [x] All onboarding/auth (SCR-001 to SCR-006)
- [x] All KYC (SCR-007 to SCR-012)
- [x] All vehicle (SCR-013 to SCR-015)
- [x] All home/drive shell variants (SCR-016 to SCR-018)
- [x] All bid composer variants (SCR-019 to SCR-022)
- [x] All active trip states (SCR-023 to SCR-027)
- [x] Comms (SCR-028, SCR-029)
- [x] Safety (SCR-030)
- [x] Earnings (SCR-031, SCR-032)
- [x] Pricing (SCR-033 to SCR-035)
- [x] Profile (SCR-036 to SCR-042)
- [x] Subscription manage (SCR-043)
- [x] Notifications (SCR-044)
- [x] Edge states (SCR-045 to SCR-048)
- [x] Specialty (SCR-049 to SCR-054)

15 end-to-end flows documented in §4.

---

## 7. Version History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-05-31 | [Product Owner] | Initial screen catalog and flow reference. 61 screens with mockup-ready prompts, 15 flows traversing screens. |

---

**END OF DOCUMENT**

When generating mockups, drop the brand prefix from §2 + the screen's prompt block into ChatGPT. Adjust copy and numbers per your specific use case. The brand visual world (palette, type, motion, photography mode) stays constant across every screen — what varies is layout, copy, and state.
