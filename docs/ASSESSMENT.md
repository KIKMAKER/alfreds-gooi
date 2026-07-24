# Gooi — Strategic Code Assessment

**Date:** 2026-07-12
**Reviewed at:** commit `424721e5` (branch `master`, with uncommitted weekly-snapshot work in tree)
**Stack:** Rails 7.1.0 / Ruby 3.3.5 / PostgreSQL (primary + queue DBs) / Solid Queue / Hotwire / Bootstrap 5.2 / Devise / Postmark / Heroku

---

## How to read this document

Each finding has a **severity** (`CRITICAL` / `HIGH` / `MEDIUM` / `LOW`) and a one-line **why it matters**. Severity is judged against Gooi's actual stage: a solo-founder service business with real paying customers, real money moving through invoices, and one collector (Alfred) depending on the app to do his route.

Findings scheduled for execution are tagged with their prompt ID (e.g. `→ P-01`), which maps to `PROMPT_BANK.md`. Findings that need the founder are tagged `→ BUCKET 3`. Feature gaps are tagged `→ FEATURES.md`.

---

## Executive summary

The app is **substantially more mature than a typical solo-founder Rails app**. Revenue recognition is real accrual accounting with an integrity check. The driver workflow has genuine domain intelligence (the `end_time_flag` sanity checks on `DriversDay` are excellent — they catch the "forgot to tap Start" failure mode that would silently corrupt every downstream stat). There is a financial dashboard, expense import with bank-statement parsing, quotations with PDF generation, a referral system, WhatsApp integration, and a public impact-snapshot surface. This is a real business system.

The problems are **not architectural**. They are three specific classes of gap:

1. **Two public endpoints will 500 on trivially-reachable input** — one of them is the homepage.
2. **Authorization is enforced per-action by hand, and several actions were missed** — a logged-in customer can currently read any invoice and pause/edit any other customer's subscription by guessing an integer ID.
3. **The test suite is red (1 failure, 31 errors), and almost all of it is stale test setup, not broken product code** — which means the suite currently cannot tell you when you break something real.

Everything else is polish, and there is a lot of runway on the polish. The single biggest *non-bug* gap is the trust surface: there is no privacy policy and no terms of service, which for a South African business collecting names, physical addresses, and phone numbers is a POPIA compliance exposure, not merely an aesthetic one.

---

# LENS A — Code health

## A1. `CRITICAL` — The public homepage 500s on an unknown discount code

**File:** `app/controllers/pages_controller.rb:9-16`

```ruby
@discount_code = params[:discount_code]
if @discount_code.present?
  found_code = DiscountCode.find_by(code: @discount_code.upcase)
  if found_code.discount_cents.present?   # ← found_code is nil when the code doesn't exist
```

`find_by` returns `nil` for an unrecognised code, and the very next line calls `.discount_cents` on it. Any request to `https://www.gooi.me/?discount_code=ANYTHING` returns a 500.

**Why it matters:** This is the root path. It is reachable by anyone, it is reachable by bots probing query params, and it is reachable by a customer who mistypes a code from a flyer or who has a stale code in a bookmarked link. A 500 on the homepage is the worst possible first impression and it is a two-line fix.

→ **P-01**

## A2. `CRITICAL` — Unauthenticated route calls a class that does not exist

**Files:** `config/routes.rb:139`, `app/controllers/payments_controller.rb:40-50`

```ruby
# routes.rb
get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'

# payments_controller.rb — skips BOTH authenticate_user! and verify_authenticity_token
def fetch_snapscan_payments
  service = SnapscanService.new(api_key)   # ← NameError: uninitialized constant SnapscanService
```

The real class is `Snapscan::ApiClient`. This action is on a route that explicitly skips authentication *and* CSRF verification (`payments_controller.rb:3-4`). Every request to it raises `NameError` and returns a 500.

**Why it matters:** Two distinct problems stacked. The action is dead (it cannot ever have worked), *and* it is a publicly-reachable unauthenticated endpoint whose stated purpose is "dump all SnapScan payment records as JSON". If someone had fixed the constant name without noticing the missing auth guard, it would have become a payment-data leak. The correct action is to delete the route and the action; the same helper already exists, correctly namespaced, as a private method elsewhere.

→ **P-02**

## A3. `HIGH` — IDOR: any logged-in customer can act on any other customer's subscription

**File:** `app/controllers/subscriptions_controller.rb`

`set_subscription` (line 620) is a bare `Subscription.find(params[:id])` with no ownership scoping, and the following member actions perform **no** owner check before acting:

| Action | Line | What an attacker can do |
|---|---|---|
| `pause` | 383 | Skip a stranger's next collection |
| `unpause` | 395 | Un-skip a stranger's collection |
| `holiday_dates` | 424 | Mark a stranger's collections skipped over a date range |
| `clear_holiday` | 438 | Clear a stranger's holiday |
| `edit` / `update` | 283 / 288 | Change a stranger's address, plan, duration, status |
| `want_bags` | 275 | Read a stranger's invoice |
| `welcome` | 360 | Read a stranger's invoice + discount details |
| `collections` | 315 | Read a stranger's full collection history |
| `complete` | 320 | Mark a stranger's subscription complete |
| `reassign_collections` | 338 | Move a stranger's collections between subscriptions |

`show` is safe only by accident — it redirects to the admin namespace, which *is* guarded.

**Why it matters:** Subscription IDs are sequential integers. A curious (or malicious) logged-in customer changing `/subscriptions/1234/pause` to `/subscriptions/1235/pause` will succeed. `update` is the worst of these: it accepts `status`, `user_id`, and `street_address` through `subscription_params`, so it is not just a nuisance — it is account takeover of a subscription record. Nothing here requires a sophisticated attacker; it requires someone editing a URL.

→ **P-03**

## A4. `HIGH` — IDOR: any logged-in user can read, edit, and delete any invoice

**File:** `app/controllers/invoices_controller.rb`

`set_invoice` (line ~277) is a bare `Invoice.find(params[:id])`. The controller guards `paid`, `send_email`, `apply_discount_code`, `remove_discount_code`, and `pdf` with explicit `unless current_user.admin?` checks — but **`show`, `edit`, `update`, and `destroy` have no check at all**.

**Why it matters:** `show` exposes another customer's name, amounts, and line items. `edit`/`update` allow rewriting another customer's invoice line items and total. `destroy` allows deleting it outright — and because `Invoice has_many :revenue_recognitions, dependent: :destroy`, deleting an invoice silently destroys its recognised-revenue rows. That is a customer-triggerable hole in the books. The fact that five *other* actions in this same controller got the guard is strong evidence this was an oversight, not a decision.

→ **P-04**

## A5. `HIGH` — `GET /skipme` mutates data

**Files:** `config/routes.rb:335`, `app/controllers/customers_controller.rb:100-122`

```ruby
get "skipme", to: "customers#skipme"
# ...
if collection.mark_skipped!(by: current_user, reason: "skipme")
```

A `GET` request marks the customer's next collection as skipped and sends an email.

**Why it matters:** `GET` requests are assumed safe by the entire web. Browser link prefetchers, WhatsApp/iMessage link-preview crawlers, email-security scanners that pre-click links, and the user's own browser "restore tabs on startup" can all fire this without human intent. A customer who has this page open in a tab, closes their laptop, and reopens it can silently lose a collection they wanted. Note this is *not* purely theoretical for Gooi specifically — the app sends links over WhatsApp, and WhatsApp actively prefetches URLs it is sent.

→ **P-09**

## A6. `MEDIUM` — `config/recurring.yml` schedules jobs that cannot run

**Files:** `config/recurring.yml`, `Procfile`

`recurring.yml` declares `CreateCollectionsJob` for Tuesday/Wednesday/Thursday at 15:00 UTC. `Procfile` declares `worker: bin/jobs`. But **there is no worker dyno running in production** — this is confirmed by the deliberate `perform_now` workarounds throughout the codebase, each with a comment explaining why:

- `app/models/invoice.rb:55` — *"perform_now: there is no worker dyno in production, so perform_later would enqueue into the queue DB and never run"*
- `app/controllers/drivers_days_controller.rb:87` — Monday's `RevenueRecognitionCatchUpJob` piggybacks on Alfred tapping "Start"
- `app/controllers/drivers_days_controller.rb:171-173` — collection creation piggybacks on Alfred tapping "End"

**Why it matters:** The system currently *works*, but it works because Alfred taps buttons. The danger is the gap between what the config says and what is true. Anyone reading `recurring.yml` (including a future contractor, or a future you at 11pm) will reasonably conclude collections are created on a schedule. They are not. Worse, several `perform_later` calls remain live and are silently no-ops in production: `MailchimpSyncJob` (`subscription.rb:590`), `CalculateFinancialMetricsJob` (5 call sites in `admin/expenses_controller.rb`), `NudgePendingSubscriptionsJob` (`admin/dashboard_controller.rb:5`), and `WhatsappReminderJob` (`admin/whatsapp_messages_controller.rb:24`). **The WhatsApp reminder one is the sharp edge: an admin clicking "trigger reminders" gets a success flash and no messages are sent.**

→ **P-14** (comment the config truthfully + document the piggyback pattern). The decision of whether to *pay for a worker dyno* is → **BUCKET 3**.

## A7. `MEDIUM` — `InvoiceBuilder#apply_referrals` crashes signup if a Product row is missing

**File:** `app/services/invoice_builder.rb:301-320`

```ruby
discount = Product.find_by(title: "Referred a friend discount (R50)")
invoice.invoice_items.create!(product: discount, quantity: @referred_friends, amount: discount.price)
#                                                                              ^^^^^^^^^^^^^^ NoMethodError if nil
```

Both branches of `apply_referrals` call `.price` on an unguarded `find_by` result. This is *already failing in the test suite* (`ReferralFlowTest#test_referrer_gets_discount_after_referee_payment` → `NoMethodError: undefined method 'price' for nil`).

**Why it matters:** Every other product lookup in this file uses `raise "Product not found: #{title}"` — this one was missed. The failure mode is a 500 in the middle of the signup flow, after the user record has been created, leaving an orphaned account with no invoice. Renaming a product in the admin UI is enough to trigger it. Note the sibling risk: `apply_discount_code` builds a title string from `subscription.plan` and `duration`, so a plan/duration combination with no matching discount Product silently produces no discount rather than an error — a customer who was promised 15% off gets billed full price and nobody finds out.

→ **P-08** (nil-guard, matching the existing `raise` convention). **This is the one change I am scheduling that touches `InvoiceBuilder`** — it is strictly a guard, it changes no amount, and it converts a 500 into a clear error.

## A8. `MEDIUM` — N+1 on the subscriptions index

**Files:** `app/controllers/subscriptions_controller.rb:24-28`, `app/views/subscriptions/index.html.erb:44-50`

The index eager-loads `:user` and `:invoices`, then the view calls `subscription.total_collections` and `subscription.remaining_collections` per row — each of which is a fresh `COUNT(*)` against `collections`.

**Why it matters:** Two extra queries per row on the admin's most-used list. The fix is unusually clean here because **the correct SQL already exists in the file** — `TOTAL_COLLECTIONS_SQL` and `REMAINING_COLLECTIONS_SQL` (lines 4-5) were written for sorting and can simply be `select`ed as attributes.

→ **P-15**

## A9. `MEDIUM` — Missing database indexes on hot lookup columns

**File:** `db/schema.rb`

| Table.column | Queried by | Currently |
|---|---|---|
| `invoices.issued_date` | `MonthlyInvoiceService#find_or_create_invoice` (every monthly run), `NudgePendingSubscriptionsJob`, statements ordering | unindexed |
| `subscriptions.next_invoice_date` | `MonthlyInvoiceService.process_all` — full scan on every `CreateCollectionsJob` run | unindexed |
| `collections.(subscription_id, date)` | `suggested_start_date`, `adopt_future_collections!`, customer history, impact stats | only `subscription_id` alone |
| `payments.snapscan_id` | webhook idempotency check on **every** SnapScan payment | unindexed |

**Why it matters:** `payments.snapscan_id` is the pointed one — it is the duplicate-payment guard in `Snapscan::WebhookHandler#create_payment_and_process_subscription`, so it runs on the critical path of every incoming payment and gets slower as the payments table grows. The others are ordinary performance debt, cheap to fix now while the tables are small.

→ **P-10**

## A10. `MEDIUM` — Test suite baseline is red: 1 failure, 31 errors

**Verified:** `bin/rails test` → `204 runs, 456 assertions, 1 failures, 31 errors, 0 skips`

The errors are **overwhelmingly stale test setup, not broken product code**:

| Test file | Errors | Cause |
|---|---|---|
| `test/models/payment_test.rb` | 7 | Builds `Payment.create!` with no `total_amount`; a `presence` + `numericality` validation was added to the model afterwards |
| `test/models/subscription_test.rb` | ~15 | `setup` builds a Subscription with no `street_address`/`suburb`; validations added afterwards |
| `test/mailers/user_mailer_test.rb` | 1 | Calls the mailer without `.with(subscription:)`, so `params` is nil |
| `test/mailers/drop_off_event_mailer_test.rb` | 1 | Calls `completion_notification` with no argument |
| `test/integration/referral_flow_test.rb` | 1 | The real `InvoiceBuilder` nil-bug from **A7** |

**Why it matters:** This is the highest-leverage item in the whole assessment and it is *not* a code-quality nicety. A red baseline means the suite has stopped being a signal. Right now, if a change breaks billing, the output is "1 failure, 32 errors" and nobody can tell it apart from "1 failure, 31 errors". Getting to green is the precondition for every other safety property in this document. Only one of the 32 (the referral one) is a genuine product bug.

→ **P-05, P-06, P-07, P-08**

## A11. `LOW` — Dead code and copy-paste debris

| Location | Issue |
|---|---|
| `app/controllers/pages_controller.rb:24-35` | `def today` — no route points at it |
| `app/controllers/pages_controller.rb:53-71` | `fetch_snapscan_payments` / `handle_successful_payment` — private, never called, and `handle_successful_payment` references an undefined `@subscription` |
| `app/controllers/customers_controller.rb:160-175` | Byte-identical copy of the same two dead private methods |
| `app/jobs/create_today_collections_job.rb:18` | Passes `today.wday` (an Integer) as `day_name`, then queries `where(collection_day: day_name)`. Works *only* because the enum is integer-backed — the sibling `CreateCollectionsJob` passes a String for the same query. Two call sites, two incompatible conventions, both "correct". |
| `app/views/admin/discount_codes/new.html.erb:9` | `warning: key :as is duplicated and overwritten on line 10` (emitted on every test run) |

**Why it matters:** Individually trivial. Collectively they are the reason a future reader cannot trust what they are looking at — the `handle_successful_payment` corpses in particular look like live payment code and are duplicated across two controllers.

→ **P-02** (the payment corpses, bundled with A2 since they are the same dead lineage)

## A12. `LOW` — `Collection#sync_drivers_day_with_date` does a `User.find_by(role: :driver)` per save

**File:** `app/models/collection.rb:143-154`

Runs inside a `before_save` callback. Fine at current volume; will bite during any bulk date-shift operation.

**Why it matters:** Noted for completeness, not scheduled. Not worth touching until it hurts.

---

## The billing / revenue-recognition system — treated as fragile, per instruction

I read `RevenueRecognitions::Recognize`, `RevenueRecognitions::Backfill`, `InvoiceBuilder`, `MonthlyInvoiceService`, and `Invoice`. **I am scheduling no behavioural changes here.** Observations, recorded for the founder's awareness only:

**What is genuinely good:** The accrual model is correct and clearly reasoned. `split_cents` does an exact integer-cent split with the remainder on the final month, so rows always sum to the invoice total. `verify_sum!` then *asserts* that inside the lock and raises if it drifts — this is a real integrity check, and it is rare to find one in an app this size. `Subscription has_many :revenue_recognitions, dependent: :nullify` with a comment explaining that recognition rows are invoice-anchored financial history that must survive subscription deletion: correct, and deliberately so.

**Risks noted, not scheduled:**

1. `Invoice has_many :revenue_recognitions, dependent: :destroy` — combined with the unguarded `InvoicesController#destroy` (**A4**), a customer can delete recognised revenue. **The fix for this is the authorization guard in P-04, not a change to the recognition system.** This is the one place where an unfixed Lens-A bug reaches into the books, and it is why P-04 is scheduled on Day 1.
2. `MonthlyInvoiceService#find_or_create_invoice` groups by "unpaid invoice for this user issued today". If a monthly run partially fails and is retried the next day, the retry creates a *second* invoice rather than completing the first.
3. `MonthlyInvoiceService#generate_monthly_invoice` advances `next_invoice_date` **before** `notify_or_send_preview`. If the mailer raises, the date has already moved and that month's invoice is silently never previewed to the admin.
4. `InvoiceBuilder#apply_discount_code` silently no-ops when the discount Product title doesn't resolve (see **A7**) — a promised discount can vanish without an error.

→ All four to **BUCKET 3**. Item 1 is mitigated by P-04. Items 2–4 want a session with a human who can reason about the money.

**What I *am* scheduling here is additive test coverage only** — characterization tests that pin current behaviour so that the next person who touches this can tell whether they changed it. → **P-11, P-12**

---

# LENS B — Professionalism gaps

## B1. `HIGH` — No privacy policy, no terms of service, no POPIA notice

**Verified absent:** no route, no view, no footer link (`app/views/shared/_footer.html.erb` links Home / About / FAQ / Blog only).

Gooi collects, from every customer: full name, email, phone number, **physical home address**, and geolocation coordinates (`subscriptions.latitude` / `longitude`, populated by the Geocoder gem). It shares data with third-party processors (Postmark, Twilio, Mailchimp, SnapScan, Google Analytics, Ahoy). It has an Instagram-facing public impact snapshot.

**Why it matters:** Under South Africa's **POPIA**, a responsible party processing personal information must, at minimum, notify data subjects of what is collected and why, identify an Information Officer, and state retention and sharing practices. Gooi is a South African business processing South African residents' home addresses. This is a legal exposure, not a design nicety — and it is *also* a commercial one: the app has an `estate-deck` and an `office-deck` for pitching to body corporates and offices. Any office manager doing basic vendor due diligence will ask for a privacy policy, and there isn't one.

→ **P-13** builds the pages, routes, footer links, and structure with clearly-marked `TODO(founder)` placeholders. **The legal content itself — Information Officer name, retention periods, the actual undertakings — is → BUCKET 3 and should not be invented by a model.**

## B2. `MEDIUM` — `robots.txt` advertises a sitemap that does not exist

**Files:** `public/robots.txt:9`, `config/sitemap.rb` (present), `public/sitemap.xml` (**absent**)

`robots.txt` ends with `Sitemap: https://www.gooi.me/sitemap.xml`. The `sitemap_generator` gem is in the Gemfile and `config/sitemap.rb` exists, but no sitemap has been generated or committed, so that URL 404s.

**Why it matters:** Every crawler that reads `robots.txt` follows that line and gets a 404. For a local service business competing on organic search for "compost collection Cape Town", this is free SEO left on the floor — and the infrastructure to fix it is already installed.

→ **P-16**

## B3. `MEDIUM` — Transactional email coverage has one real hole: **no payment receipt**

The email estate is otherwise strong — 13 mailers, most with both HTML and text parts, and a genuinely good 3-stage dunning ladder in `NudgePendingSubscriptionsJob` (day 3 / day 7 / day 14).

| Event | Customer email? | Notes |
|---|---|---|
| Signup | ✅ `UserMailer#welcome` | |
| Payment activates a **pending** subscription | ✅ `payment_received` (via `activate_subscription`) | |
| **Payment on any other invoice** | ❌ **nothing** | See below |
| Invoice created | ✅ `invoice_created` | |
| Payment overdue | ✅ 3-stage nudge | |
| Short payment | ⚠️ admin only | Customer is never told they underpaid |
| Collection skipped | ✅ `CollectionMailer#skipped` | |
| Subscription ending soon | ✅ | |
| Subscription complete | ✅ (two variants: with/without renewal) | |
| Plan changed | ✅ | |
| Referral completed | ✅ | |
| **Cancellation** | ❌ | No cancellation flow exists at all — see C1 |

**The receipt hole, precisely:** `InvoicesController#paid` (line 102) is what the founder clicks for every EFT and cash payment. It marks the invoice paid, creates the `Payment` record, and activates the subscription **if it was pending** — but it sends the customer *nothing*. A renewal payment, a monthly-billing payment, or a compost-bags order payment therefore produces **zero confirmation to the customer**. The customer pays money into a bank account and hears silence.

**Why it matters:** "I paid — did you get it?" is the single most common support message any subscription business receives, and it is entirely preventable. Every one of those messages currently lands in the founder's WhatsApp.

→ **FEATURES.md F1**, pre-written in the PENDING APPROVAL section of the prompt bank.

## B4. `MEDIUM` — No error tracking, no uptime monitoring, no slow-query visibility

**Verified absent from `Gemfile`:** Sentry, Honeybadger, Rollbar, Bugsnag, AppSignal, Scout, Skylight, New Relic, Lograge, Rack::Attack.

**Why it matters:** Every 500 in this document — the homepage discount-code crash (**A1**), the dead SnapScan route (**A2**), the `InvoiceBuilder` nil (**A7**) — is invisible today. The founder finds out when a customer complains, or never. The homepage one in particular could have been firing for months. **You cannot fix what you cannot see, and right now Gooi cannot see anything.** This is the cheapest permanent capability upgrade available: one gem, one initializer, one env var.

→ **P-17**

## B5. `LOW` — Emails have no shared branded layout

**File:** `app/views/layouts/mailer.html.erb` — it is the stock Rails scaffold, an empty `<style>` block and a bare `<%= yield %>`.

Every mailer template therefore re-implements the brand inline: `font-family: Arial`, `color: #1f4632` (Gooi green), `#FBB718` (Gooi yellow) buttons, copy-pasted across ~20 templates. There is no logo, no consistent header, no footer, and **no unsubscribe/preferences link**.

**Why it matters:** The emails read as competent transactional mail from a company without a designer, when the actual website has a strong visual identity. Every email is a brand impression. Consolidating the chrome into the layout also means the next brand tweak is one file, not twenty. (Note: the *absence of an unsubscribe link* on marketing-adjacent mail is also a POPIA direct-marketing consideration — related to **B1**.)

→ **P-18** (build the layout + shared partials; leave existing templates working). Deciding the email design → BUCKET 3 if the founder wants it to look like anything specific.

## B6. Things that are already good — do not "fix" these

Recording these explicitly so that a future pass doesn't burn a session re-litigating them:

- **Custom error pages exist and are good.** `errors_controller.rb` + `config.exceptions_app = self.routes` in production, with branded 404/422/500 views that offer a context-appropriate CTA ("Go to dashboard" if signed in, "Go home" if not).
- **SEO meta is genuinely well done.** `layouts/application.html.erb` has per-page overridable `meta_title` / `meta_description` / `og_image`, full Open Graph tags (with `og:image:width`/`height` set, which most apps forget), Twitter card tags, and a favicon. Only the sitemap (**B2**) is missing.
- **Bot-noise handling is thoughtful.** `routes.rb` short-circuits WordPress-scanner paths and the Chrome DevTools probe before they reach the controller stack.
- **The PWA session-restore hack is smart.** `ApplicationController#restore_session_from_cookie` works around iOS Safari clearing session cookies when a standalone PWA closes — with a comment explaining exactly why.
- **Webhook signature verification is correct.** Both SnapScan (HMAC-SHA256 via `Rack::Utils.secure_compare` — constant-time, correctly done) and Twilio (`Twilio::Security::RequestValidator`) verify signatures.
- **Admin tooling is deep.** Blazer is mounted for analytics, there is expense import with bank-statement CSV parsing, financial dashboards, quotation PDFs, bulk messaging, and a payment-transfer/claim-orphaned-payments tool. The founder is not living in the Rails console.

---

# LENS C — Missing features

Ranked in `FEATURES.md`. Summarised here with severity as *business* cost:

| # | Gap | Severity | Why it matters |
|---|---|---|---|
| **C1** | **No customer-facing cancellation** | `HIGH` | A customer who wants to leave has no way to do it. They WhatsApp the founder, or they simply stop paying and become a silent lapse. Gooi loses the churn *reason* — the single most valuable data a subscription business collects — and the founder does the admin by hand. |
| **C2** | **No payment receipt email** (= B3) | `HIGH` | Customer pays, hears nothing, messages the founder to ask. Highest-volume avoidable support load. |
| **C3** | **Suburb waitlist collects demand but never acts on it** | `MEDIUM` | The `Interest` model captures name/email/suburb for 52 unserviced suburbs, with an admin index. But there is no way to email a suburb's waitlist when Gooi launches there. The demand data is being *collected and buried* — this is a warm list of pre-qualified leads with zero acquisition cost. |
| **C4** | **No card-on-file / recurring billing** | `MEDIUM` | Every payment is a manual SnapScan/EFT push by the customer, chased by a 3-stage dunning ladder. This is the structural reason dunning exists at all. Real fix, real scope — needs a payment-provider decision (Stripe / Paystack / Yoco / SnapScan recurring). |
| **C5** | **Collection reminder by email** | `LOW` | WhatsApp reminders exist (`WhatsappReminderJob`) but silently no-op without a worker dyno (**A6**). An email reminder would be a cheap, reliable belt-and-braces. |
| **C6** | **Impact stats are computed but not shareable** | `LOW` | `User#lifetime_co2e_kg`, `#current_streak`, `#consistency_rate` all exist and render on `my_stats`. There is no share affordance. For a values-driven brand this is organic-growth surface being left idle. |

---

# What I am NOT scheduling, and why

| Item | Reason |
|---|---|
| Any behavioural change to `RevenueRecognitions::*` | Explicitly out of scope; recently repaired; treated as fragile. Additive tests only (P-11). |
| `MonthlyInvoiceService` retry/ordering issues (billing risks 2–4 above) | Needs a human who can reason about money. → BUCKET 3 |
| Extracting a policy layer (Pundit) for authorization | Right long-term answer, wrong week. P-03/P-04 fix the actual holes with `before_action` guards matching the existing house style. Revisit once the suite is green. |
| Fat-controller refactors (`subscriptions_controller.rb` is 753 lines) | No user-visible benefit; high regression risk against a red suite; not a good use of a smaller model's session. |
| Worker dyno decision | Costs money. → BUCKET 3 |
| `Collection#sync_drivers_day_with_date` per-save driver lookup (**A12**) | Not hurting yet. |

---

# Bucket 3 — needs the founder

Ordered by how much they should jump the queue.

1. **Should a worker dyno be running?** (`~$7/mo` on Heroku.) Today, WhatsApp reminders, Mailchimp sync, and financial-metric recalculation are dead code in production, and collection creation depends on Alfred tapping a button. Everything else in this list is downstream of this decision. **This should jump the queue.**
2. **Privacy policy + terms content.** P-13 builds the scaffolding; the Information Officer, retention periods, and actual undertakings must come from you (ideally reviewed by someone who knows POPIA). Do not let a model invent these.
3. **The four billing risks** listed under the revenue-recognition section — particularly the silent discount-code no-op (a customer promised 15% off may have been charged full price, and no error was raised).
4. **Should customers be able to cancel themselves?** (C1) This is a product decision with a real trade-off: self-service cancellation reduces friction *to leave* as well as friction *to stay*. Many founders deliberately keep a human in the loop here to save the relationship. Your call, and a defensible one either way.
5. **Payment provider for recurring billing** (C4) — the largest structural improvement available, and the one that would let you delete the dunning ladder.
6. **Email design direction** (B5) — if the branded mailer layout should look like anything specific, say so; otherwise P-18 will match the site's existing green/yellow palette.
