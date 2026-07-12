# Gooi — Prompt Bank

**Generated:** 2026-07-12 · **Companion to:** `ASSESSMENT.md`, `FEATURES.md`

18 approved prompts (**P-01** … **P-18**), grouped by day. Execute in order. Each is independently shippable and depends on no other prompt's uncommitted work.

Day 1–3 front-load anything near billing, authorization, or data integrity. Day 6–7 is polish.

A separate **PENDING APPROVAL** section at the bottom holds three feature prompts (**F1**, **F2**, **F3**). **Do not execute those** until the founder has signed off. They are written and ready; they are not scheduled.

---

# STANDING HEADER

> **Prepend this to every prompt below. It applies without exception.**

You are working in **Alfred's Gooi**, a Rails application for a household organic-waste collection and composting service operating weekly across Cape Town, South Africa. It is solo-maintained by its founder and runs on Heroku. Real customers depend on it and real money moves through it.

**Environment**
- Ruby **3.3.5**, Rails **7.1.0**, PostgreSQL (a primary database and a separate queue database)
- Background jobs use **Solid Queue**, not Sidekiq
- Frontend: Hotwire (Turbo + Stimulus), Bootstrap 5.2, importmap-rails
- Working directory: the repository root. Current branch: `master`.

**Test command**
```bash
bin/rails test
```
Run a single file with `bin/rails test test/path/to/file_test.rb`.

**Baseline test state — read this carefully.** As of 2026-07-12 the suite is **red on `master`**: `204 runs, 456 assertions, 1 failures, 31 errors, 0 skips`. This is pre-existing and is not your fault. **Your bar is: no NEW failures or errors.** Prompts P-05 through P-08 exist specifically to bring this to green — as you complete them the counts will drop, and each of those prompts states its own expected count. Always compare against the count stated in the prompt you are executing, never against zero, unless the prompt says zero.

**Style conventions observed in this codebase — follow them**
- **No inline `style="..."` attributes in ERB views.** Styles live in SCSS partials under `app/assets/stylesheets/components/` using BEM naming. (Mailer templates are the sole exception — email requires inline styles, and existing mailer views use them.)
- **No inline `<script>` or `onclick` in ERB views.** Behaviour lives in Stimulus controllers under `app/javascript/controllers/`.
- **Never use `button_to` inside a `form_with` block.** `button_to` renders its own `<form>` tag; nested forms corrupt the outer form's `authenticity_token` and cause CSRF 422s. Use `link_to` with `data: { turbo_method: :post }` instead.
- **Never call `update(skip: true)` on a Collection.** Use `collection.mark_skipped!(by:, reason:)`, which sends the customer notification email. (`skip_silently!(reason:)` exists for jobs that must skip without emailing.)
- **Sanitise query params before assigning to enum attributes.** Rails enums raise `ArgumentError` at *assignment* time, not validation time, so `Model.new(plan: params[:plan])` will 500 on a bad value from a bot probe. Validate first: `Model.plans.key?(params[:plan]) ? params[:plan] : nil`.
- Do **not** run `rubocop` as a verification step. Use `bin/rails test`.
- Two-space indent. Existing files may have inconsistent style — match the file you are editing, not an ideal.

**Scope rule — this is absolute**
> **Do not modify files outside those listed in the prompt's `Files:` section. If you believe you must, stop and report why instead.**

**Commit**
- Commit when the task is complete and verification passes.
- Use the commit message given verbatim at the end of the prompt.
- Sign off with `this one is all claude` — **not** a `Co-Authored-By:` footer.

---
---

# DAY 1 — Public 500s and authorization holes

> These four are the highest-severity items in the assessment. Two are crashes on endpoints anyone can reach; two are IDOR holes that let a logged-in customer act on other customers' records. Do these first.

---

### [P-01] Fix 500 on the homepage when an unknown discount code is in the URL

**Type:** fix | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `app/controllers/pages_controller.rb`

**Context:**
`PagesController#home` renders the public homepage at `/`. It accepts an optional `?discount_code=XYZ` query parameter so that marketing links can pre-apply a discount. It looks the code up with `DiscountCode.find_by(code: ...)`, which returns `nil` when no such code exists — and then immediately calls a method on the result without checking for `nil`. The result is that **any request to `https://www.gooi.me/?discount_code=ANYTHING-INVALID` returns a 500 error.** This is reachable by bots probing query parameters, and by any customer who mistypes a code from a flyer.

**Task:**

1. Open `app/controllers/pages_controller.rb`.
2. Find the `home` action. It currently contains this block:

```ruby
    if @discount_code.present?
      found_code = DiscountCode.find_by(code: @discount_code.upcase)
      if found_code.discount_cents.present?
        @discount_amount = (found_code.discount_cents / 100.0)
      elsif found_code.discount_percent.present?
        @discount_percent = found_code.discount_percent.to_f / 100.0
      end
    end
```

3. Replace **exactly that block** with this:

```ruby
    if @discount_code.present?
      found_code = DiscountCode.find_by(code: @discount_code.upcase)
      if found_code.nil?
        @discount_code = nil
      elsif found_code.discount_cents.present?
        @discount_amount = (found_code.discount_cents / 100.0)
      elsif found_code.discount_percent.present?
        @discount_percent = found_code.discount_percent.to_f / 100.0
      end
    end
```

   Setting `@discount_code = nil` when the code is not found means the view will not display a discount banner for a code that does not exist. The two lines below the block (`@pct = ...` and `@amt = ...`) already default to `0.0` and need no change.

4. **Do not touch** any other action in this file. In particular, leave `def today`, `def fetch_snapscan_payments`, and `def handle_successful_payment` exactly as they are — those are dead code and are handled by P-02.

**Verification:**

1. Run the test suite:
   ```bash
   bin/rails test
   ```
   Expected: `1 failures, 31 errors` — unchanged from baseline. No new failures.

2. Manual check. Start the server:
   ```bash
   bin/rails server
   ```
   - Visit `http://localhost:3000/?discount_code=NOTAREALCODE` → the page must render normally with **no** discount banner and **no** error.
   - Visit `http://localhost:3000/` → must render normally, exactly as before.

**Stop condition:**
If the block in step 2 does not match the file exactly (for example, it has already been fixed, or the surrounding code differs), **stop, revert any changes, and report what you actually found.** Do not improvise a different fix.

**Commit message:**
```
Fix 500 on homepage when discount_code param is not a real code

DiscountCode.find_by returns nil for an unknown code, and the next line
called .discount_cents on it. Any request to /?discount_code=ANYTHING
returned a 500. Now an unrecognised code is treated as no code.

this one is all claude
```

---

### [P-02] Delete the dead, unauthenticated SnapScan payments route and its corpses

**Type:** fix | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `config/routes.rb`
- Read + modify: `app/controllers/payments_controller.rb`
- Read + modify: `app/controllers/pages_controller.rb`
- Read + modify: `app/controllers/customers_controller.rb`

**Context:**
The route `GET /snapscan/payments` points at `PaymentsController#fetch_snapscan_payments`. That action calls `SnapscanService.new(api_key)` — **a class that does not exist in this codebase.** The real class is `Snapscan::ApiClient`. So the action has never worked; every request to it raises `NameError` and returns a 500.

It is worse than merely dead: `PaymentsController` skips both `authenticate_user!` and `verify_authenticity_token` for this action, so it is a publicly-reachable, unauthenticated endpoint whose stated purpose is to dump SnapScan payment records as JSON. If someone had "helpfully" fixed the class name without noticing the missing auth guard, it would have become a payment-data leak.

The same dead lineage was copy-pasted as unused private methods into two other controllers. This task removes all of it.

**Task:**

1. In `config/routes.rb`, find and **delete this single line**:
   ```ruby
   get 'snapscan/payments', to: 'payments#fetch_snapscan_payments'
   ```
   Leave the `resources :payments, only: :index` line immediately below it, and the `post 'snapscan/webhook', ...` line above it, **untouched**. The webhook is live and load-bearing.

2. In `app/controllers/payments_controller.rb`:

   a. **Delete the entire `fetch_snapscan_payments` action** (the whole `def fetch_snapscan_payments ... end` block).

   b. Change the two `skip_before_action` lines at the top of the class from:
   ```ruby
     skip_before_action :verify_authenticity_token, only: [:snapscan_webhook, :fetch_snapscan_payments]
     skip_before_action :authenticate_user!, only: [:snapscan_webhook, :fetch_snapscan_payments]
   ```
   to:
   ```ruby
     skip_before_action :verify_authenticity_token, only: [:snapscan_webhook]
     skip_before_action :authenticate_user!, only: [:snapscan_webhook]
   ```

   c. **Do not touch** `snapscan_webhook`, `verify_signature`, `index`, or `show`. The webhook is live.

3. In `app/controllers/pages_controller.rb`, delete these three dead members. None of them is called from anywhere, and `handle_successful_payment` references an undefined `@subscription` instance variable:
   - the entire `def today ... end` action (no route points at it)
   - the entire private `def fetch_snapscan_payments ... end` method
   - the entire private `def handle_successful_payment ... end` method

   If removing these leaves the `private` keyword with nothing after it before `end`, delete the now-orphaned `private` keyword too.

   **Do not touch** `home`, `about`, `story`, `faq`, or `get_the_app`.

4. In `app/controllers/customers_controller.rb`, delete the byte-identical copies of the same two dead private methods:
   - the entire private `def fetch_snapscan_payments ... end` method
   - the entire private `def handle_successful_payment ... end` method

   If this leaves the `private` keyword orphaned, delete it too.

   **Do not touch** `subscriptions`, `manage`, `account`, `collections_history`, `my_stats`, `referrals`, `skipme`, or `submit_referral_code`.

**Verification:**

1. Confirm the route is gone and the webhook survives:
   ```bash
   bin/rails routes | grep -i snapscan
   ```
   Expected output: exactly one line, the webhook —
   `POST /snapscan/webhook  payments#snapscan_webhook`
   There must be **no** line for `payments#fetch_snapscan_payments`.

2. Confirm no references to the dead class remain:
   ```bash
   grep -rn "SnapscanService" app config
   ```
   Expected: **no output at all.**

3. Run the suite:
   ```bash
   bin/rails test
   ```
   Expected: `1 failures, 31 errors` — unchanged from baseline.

**Stop condition:**
If `grep -rn "fetch_snapscan_payments" app config` returns any hit after your changes, or if any of these methods turns out to be called from a view or another class, **stop, revert, and report.** Deleting a method that is actually in use is far worse than leaving dead code.

**Commit message:**
```
Remove dead unauthenticated SnapScan payments endpoint

GET /snapscan/payments called SnapscanService, a class that does not
exist (the real one is Snapscan::ApiClient), so it 500'd on every
request. It also skipped both authentication and CSRF, so a naive fix
to the class name would have turned it into a payment-data leak.

Also removes the identical dead fetch_snapscan_payments and
handle_successful_payment private methods copy-pasted into
PagesController and CustomersController, plus PagesController#today,
which has no route. The live SnapScan webhook is untouched.

this one is all claude
```

---

### [P-03] Close IDOR on subscription member actions

**Type:** fix | **Risk:** medium | **Scope:** medium

**Files:**
- Read + modify: `app/controllers/subscriptions_controller.rb`
- Read only (for context): `app/controllers/admin/base_controller.rb`

**Context:**
`SubscriptionsController` loads records with a bare `Subscription.find(params[:id])` and **never checks that the record belongs to the signed-in user.** Subscription IDs are sequential integers. Today, any logged-in customer can change `/subscriptions/1234/pause` to `/subscriptions/1235/pause` and skip a *stranger's* collection. `update` is worse still: its permitted parameters include `status`, `user_id`, and `street_address`, so a customer can rewrite another customer's subscription entirely.

This task adds `before_action` guards. It follows the pattern already used in `Admin::BaseController`, which does `redirect_to root_path, alert: "Not authorised." unless current_user&.admin?`.

Note that the driver (Alfred) and admins legitimately need to read and act on all subscriptions — the existing `index` action already grants access with `if current_user.admin? || current_user.driver?`. Preserve that.

**Task:**

1. Open `app/controllers/subscriptions_controller.rb`.

2. **Line 2** currently reads:
```ruby
  before_action :set_subscription, only: %i[show edit update destroy want_bags pause unpause holiday_dates clear_holiday complete reassign_collections welcome]
```
   Replace that single line with these three lines:
```ruby
  before_action :set_subscription, only: %i[show edit update destroy want_bags pause unpause holiday_dates clear_holiday complete reassign_collections welcome collections]
  before_action :authorize_subscription_owner_or_staff!, only: %i[edit update want_bags pause unpause holiday_dates clear_holiday welcome collections]
  before_action :require_admin!, only: %i[destroy complete reassign_collections]
```
   (`collections` has been added to `set_subscription`'s list — it previously did its own lookup.)

3. Several actions redundantly re-find the subscription in their own body, which would bypass nothing but is now dead weight. **Delete exactly these lines** — each is the first line inside its action, and `set_subscription` has already assigned `@subscription`:

   - in `def collections`, delete: `@subscription = Subscription.find(params[:id])`
   - in `def welcome`, delete: `@subscription = Subscription.find(params[:id])`
   - in `def pause`, delete: `@subscription = Subscription.find(params[:id])`
   - in `def unpause`, delete: `@subscription = Subscription.find_by(id: params[:id])` **and also delete the four lines immediately following it**, which are now unreachable because `set_subscription` uses `find` and raises on a missing record:
     ```ruby
     if @subscription.nil?
       redirect_to manage_path, alert: "Subscription not found"
       return
     end
     ```
   - in `def holiday_dates`, delete: `@subscription = Subscription.find(params[:id])`
   - in `def clear_holiday`, delete: `@subscription = Subscription.find(params[:id])`

   **Leave `def reassign_collections` alone.** It uses a local variable named `subscription` throughout its body, not `@subscription`. It is now protected by `require_admin!`, which is sufficient. Do not refactor it.

4. Find the `private` section. Immediately **after** the existing `set_subscription` method:
```ruby
  def set_subscription
    @subscription = Subscription.find(params[:id])
  end
```
   add these two new methods:
```ruby
  # Staff (admins and the driver) legitimately act on every subscription — this
  # mirrors the access rule already used in #index. Everyone else may only touch
  # their own. Subscription ids are sequential, so without this a customer can
  # pause, edit, or read a stranger's subscription by editing the URL.
  def authorize_subscription_owner_or_staff!
    return if current_user&.admin? || current_user&.driver?
    return if @subscription.user_id == current_user&.id

    redirect_to manage_path, alert: "Not authorised."
  end

  def require_admin!
    redirect_to root_path, alert: "Not authorised." unless current_user&.admin?
  end
```

5. **Do not touch** `index`, `new`, `create`, `show`, `today`, `today_notes`, `pending`, `all`, `paused`, `completed`, `legacy`, `recently_lapsed`, `export`, `import_csv`, `add_locations`, `create_locations`, `update_end_date`, `collect_courtesy`, or `subscription_params`. `show` is already safe — it redirects into the admin namespace, which has its own guard.

6. **Do not** add a `cancelled` status, change the status enum, or touch any billing or invoice code.

**Verification:**

1. Run the suite:
   ```bash
   bin/rails test
   ```
   Expected: `1 failures, 31 errors` — unchanged from baseline. If `test/controllers/subscriptions_controller_test.rb` produces a **new** failure, that is a real signal — see the stop condition.

2. Confirm the redundant lookups are gone:
   ```bash
   grep -n "Subscription.find(params\[:id\])" app/controllers/subscriptions_controller.rb
   ```
   Expected: exactly **two** hits — one inside `set_subscription`, one inside `reassign_collections`.

3. Manual check (requires two customer accounts in your local database, A and B, each with a subscription):
   - Sign in as customer A.
   - Note customer B's subscription id (from the Rails console: `User.find_by(email: "b@…").subscriptions.first.id`).
   - Visit `/subscriptions/<B's id>/edit`.
   - **Expected:** redirected to `/manage` with the flash "Not authorised."
   - Visit `/subscriptions/<A's own id>/edit`.
   - **Expected:** the edit page renders normally.

**Stop condition:**
If existing controller tests fail **after** your change in a way that suggests a legitimate flow is now blocked — for example a test signing in as a driver or admin gets redirected — **stop and report the exact test and its output.** Do not loosen the guard to make a test pass; the guard may be right and the test may be asserting the old broken behaviour, and that is a judgement call for a human.

**Commit message:**
```
Close IDOR on subscription member actions

set_subscription did a bare Subscription.find(params[:id]) with no
ownership check, and pause/unpause/holiday_dates/clear_holiday/edit/
update/want_bags/welcome/collections did no check of their own. Since
ids are sequential, any signed-in customer could skip a stranger's
collection, or — via update, which permits status, user_id and
street_address — rewrite their subscription outright.

Adds authorize_subscription_owner_or_staff! (admins and the driver keep
full access, matching #index) and require_admin! for the destructive
actions, and removes the now-redundant in-action lookups.

this one is all claude
```

---

### [P-04] Close IDOR on invoice show / edit / update / destroy

**Type:** fix | **Risk:** medium | **Scope:** small

**Files:**
- Read + modify: `app/controllers/invoices_controller.rb`

**Context:**
`InvoicesController` loads invoices with a bare `Invoice.find(params[:id])`. Five of its actions (`paid`, `send_email`, `apply_discount_code`, `remove_discount_code`, `pdf`) correctly guard themselves with an explicit `unless current_user.admin?` check. But **`show`, `edit`, `update`, and `destroy` have no check at all.** Any signed-in user can read, rewrite, or delete any other customer's invoice by editing the id in the URL.

`destroy` is the most serious. `Invoice` declares `has_many :revenue_recognitions, dependent: :destroy`, so deleting an invoice also destroys its recognised-revenue rows. That is a customer-triggerable hole in the company's books.

The fact that five sibling actions *do* have the guard is strong evidence this was an oversight rather than a decision.

**Task:**

1. Open `app/controllers/invoices_controller.rb`.

2. **Line 2** currently reads:
```ruby
  before_action :set_invoice, only: %i[show edit update destroy paid issued_bags send_email apply_discount_code pdf bags_whatsapp]
```
   Add a second `before_action` immediately after it, so the two lines read:
```ruby
  before_action :set_invoice, only: %i[show edit update destroy paid issued_bags send_email apply_discount_code pdf bags_whatsapp]
  before_action :authorize_invoice_owner_or_admin!, only: %i[show edit update destroy]
```

3. In the `private` section, immediately **after** the existing `set_invoice` method:
```ruby
  def set_invoice
    @invoice = Invoice.find(params[:id])
  end
```
   add this new method:
```ruby
  # Invoice ids are sequential. Without this, any signed-in customer could read,
  # rewrite, or delete a stranger's invoice by editing the URL — and because
  # Invoice has_many :revenue_recognitions, dependent: :destroy, deleting one
  # also destroys its recognised-revenue rows.
  def authorize_invoice_owner_or_admin!
    return if current_user&.admin?
    return if @invoice.subscription&.user_id == current_user&.id

    redirect_to invoices_path, alert: "Not authorised."
  end
```

   Note the safe navigation on `@invoice.subscription` — `Invoice belongs_to :subscription, optional: true`, because order-linked invoices have no subscription. An invoice with no subscription is therefore admin-only, which is correct.

4. **Do not touch** the existing `unless current_user.admin?` guards inside `paid`, `send_email`, `apply_discount_code`, `remove_discount_code`, or `pdf`. They are correct and this change does not make them redundant — those actions are not in the new `before_action`'s `only:` list.

5. **Do not touch** `index` (it already branches correctly on `current_user.admin?` vs `current_user.customer?`), `new`, `create`, `bags`, `issued_bags`, `bags_whatsapp`, `calculate_total`, or any invoice-item logic.

6. **Do not change any billing calculation, any invoice total, or anything in `app/services/`.** This task adds an authorization guard and nothing else.

**Verification:**

1. Run the suite:
   ```bash
   bin/rails test
   ```
   Expected: `1 failures, 31 errors` — unchanged from baseline.

2. Run the invoice controller tests specifically:
   ```bash
   bin/rails test test/controllers/invoices_controller_test.rb
   ```
   Expected: no new failures versus baseline.

3. Manual check (two customer accounts A and B, each with an invoice):
   - Sign in as customer A.
   - Visit `/invoices/<B's invoice id>`.
   - **Expected:** redirected to `/invoices` with the flash "Not authorised."
   - Visit `/invoices/<A's own invoice id>`.
   - **Expected:** renders normally.
   - Sign in as an admin, visit `/invoices/<B's invoice id>`.
   - **Expected:** renders normally.

**Stop condition:**
If a test fails showing that a **customer** is legitimately expected to reach `edit` or `update` on their own invoice and your guard blocks it, **stop and report** — the guard already permits the owner, so such a failure would mean the ownership chain (`invoice → subscription → user`) is not what I have assumed, and I want to know that before you work around it.

**Commit message:**
```
Close IDOR on invoice show/edit/update/destroy

set_invoice did a bare Invoice.find(params[:id]). Five sibling actions
guard themselves with an admin check; show, edit, update and destroy did
not, so any signed-in user could read, rewrite or delete a stranger's
invoice by editing the id in the URL.

destroy was the sharp edge: Invoice has_many :revenue_recognitions,
dependent: :destroy, so a customer could delete recognised revenue.

this one is all claude
```

---
---

# DAY 2 — Get the test suite to green

> The suite is currently red with 1 failure and 31 errors. Almost all of it is **stale test setup**, not broken product code — validations were added to models after the tests were written. A red baseline means the suite cannot tell anyone when they break something real, so this is the precondition for every other safety property in the codebase.
>
> Exactly one of these 32 is a genuine product bug, and it is in P-08.
>
> Do these in order. Each states the exact count you should see afterwards.

---

### [P-05] Repair PaymentTest — 7 errors from a missing required attribute

**Type:** test | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `test/models/payment_test.rb`
- Read only (for context): `app/models/payment.rb`, `db/schema.rb`

**Context:**
`app/models/payment.rb` validates `total_amount` for presence and numericality (`greater_than: 0`). `test/models/payment_test.rb` was written **before** that validation existed, and every one of its `Payment.create!` calls omits `total_amount`. All 7 tests in the file error with `ActiveRecord::RecordInvalid: Validation failed: Total amount can't be blank, Total amount is not a number`.

The tests are testing the right things (the `payment_type` enum and the `manual` boolean). They just need a valid record.

Important: `payments.total_amount` is an **integer column storing cents** — see `Snapscan::WebhookHandler`, which does `payment_amount = @payload["totalAmount"].to_f / 100.0` when reading it back. So `total_amount: 10_000` means R100.00. Use integer cents.

**Task:**

1. Open `test/models/payment_test.rb`.
2. Find **every** call to `Payment.create!` in the file (there are 7, one per test).
3. Add `total_amount: 10_000` to each one's attributes. For example, this:
   ```ruby
   p = Payment.create!(user: @user, payment_type: :eft, manual: true)
   ```
   becomes:
   ```ruby
   p = Payment.create!(user: @user, payment_type: :eft, manual: true, total_amount: 10_000)
   ```
   Apply the same addition to all 7. Do not change any existing attribute, and do not change any assertion.
4. **Do not modify `app/models/payment.rb`.** The validation is correct — the tests were stale.
5. Do not add new tests in this prompt.

**Verification:**
```bash
bin/rails test test/models/payment_test.rb
```
Expected: **7 runs, 0 failures, 0 errors.**

Then the full suite:
```bash
bin/rails test
```
Expected: **1 failures, 24 errors** (down from 31 — the 7 PaymentTest errors are gone).

**Stop condition:**
If adding `total_amount` makes a test fail on an *assertion* (rather than fixing an error), stop and report which assertion and what it expected — that would mean the test is asserting something about `total_amount` that I have not anticipated.

**Commit message:**
```
Fix PaymentTest: supply total_amount, which the model now requires

Payment validates total_amount for presence and numericality, but
payment_test.rb predates that validation and omitted it, erroring all 7
tests. total_amount is an integer column in cents (the SnapScan webhook
divides by 100 on read), so 10_000 = R100.00.

this one is all claude
```

---

### [P-06] Repair SubscriptionTest — errors from missing required address attributes

**Type:** test | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `test/models/subscription_test.rb`
- Read only (for context): `app/models/subscription.rb`

**Context:**
`Subscription` validates `street_address` for presence and `suburb` for both presence and inclusion in the `Subscription::SUBURBS` constant. `test/models/subscription_test.rb` was written before those validations and creates subscriptions without either, so its `setup` block raises and **every test in the file errors** with `Validation failed: Suburb is not included in the list, Street address can't be blank, Suburb can't be blank`.

The tests themselves are valuable — they cover `suggested_start_date`, which is the logic deciding when a renewing customer's new subscription begins. Getting them running again restores real coverage.

**Task:**

1. Open `test/models/subscription_test.rb`.
2. Find **every** call to `Subscription.create!` in the file — in the `setup` block and in any individual test.
3. Add these two attributes to each one:
   ```ruby
   street_address: "1 Test Road, Observatory, Cape Town",
   suburb: "Observatory",
   ```
   `"Observatory"` is a real member of `Subscription::SUBURBS`, so it passes the inclusion validation. Do not invent a suburb name — an unlisted suburb will fail validation.
4. Do not change any existing attribute (`plan`, `duration`, `start_date`, `end_date`, `status`, `user`), and do not change any assertion.
5. Be aware: setting `street_address` triggers the `geocoded_by :street_address` callback. If the tests now attempt real network calls to a geocoding API and fail or hang, **that is the stop condition below** — report it rather than working around it.
6. **Do not modify `app/models/subscription.rb`.** The validations are correct.

**Verification:**
```bash
bin/rails test test/models/subscription_test.rb
```
Expected: all tests run. Some may now **fail on assertions** rather than erroring in `setup` — that is progress, but report any that do rather than "fixing" them by changing the assertion.

Then the full suite:
```bash
bin/rails test
```
Expected: **error count drops by roughly 15**, to around `1 failures, 9 errors` if run after P-05.

**Stop condition:**
If the tests now attempt live geocoding network calls (symptoms: hanging, timeouts, or `Geocoder` errors in the output), **stop, revert, and report.** The correct fix is to stub the geocoder in `test/test_helper.rb`, which is outside the file list for this prompt and needs a deliberate decision about test configuration.

Likewise, if a test now **fails an assertion** about `suggested_start_date`, **stop and report the exact expected-vs-actual.** That would mean a real behavioural bug in date logic, which is date-sensitive billing-adjacent code and is not yours to change.

**Commit message:**
```
Fix SubscriptionTest: supply street_address and suburb

Subscription validates street_address presence and suburb inclusion in
SUBURBS, but subscription_test.rb predates both, so setup raised and
every test in the file errored. Uses Observatory, a real member of the
SUBURBS constant.

this one is all claude
```

---

### [P-07] Write the two mailer tests that were left as scaffold stubs

**Type:** test | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `test/mailers/user_mailer_test.rb`
- Read + modify: `test/mailers/drop_off_event_mailer_test.rb`
- Read only (for context): `app/mailers/user_mailer.rb`, `app/mailers/drop_off_event_mailer.rb`, `app/models/subscription.rb`

**Context:**
Both of these test files are **untouched Rails generator scaffolds** — they still contain the generator's placeholder assertions (`assert_equal "Welcome", mail.subject`, `["to@example.org"]`, `"from@example.com"`). They were never written. Each errors:

- `UserMailerTest#test_welcome` → `NoMethodError: undefined method 'user' for nil`, because it calls `UserMailer.welcome` without `.with(subscription:)`, so `params` is nil.
- `DropOffEventMailerTest#test_completion_notification` → `ArgumentError: wrong number of arguments (given 0, expected 1)`, because `completion_notification` takes a `drop_off_event` argument.

Replace both with real tests.

**Task:**

1. Replace the **entire contents** of `test/mailers/user_mailer_test.rb` with:

```ruby
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      first_name: "Thandi",
      last_name: "Mokoena",
      email: "thandi-#{SecureRandom.hex(4)}@example.com",
      phone_number: "+27821234567",
      password: "password"
    )

    @subscription = Subscription.create!(
      user: @user,
      plan: "Standard",
      duration: 3,
      street_address: "1 Test Road, Observatory, Cape Town",
      suburb: "Observatory"
    )
  end

  test "welcome is addressed to the subscription's user and mentions their name" do
    mail = UserMailer.with(subscription: @subscription).welcome

    assert_equal ["howzit@gooi.me"], mail.from
    assert_equal [@user.email], mail.to
    assert_equal "Welcome to Gooi!", mail.subject
    assert_match "Thandi", mail.body.encoded
  end

  test "welcome honours an explicit to_email override" do
    mail = UserMailer.with(subscription: @subscription, to_email: "someone-else@example.com").welcome

    assert_equal ["someone-else@example.com"], mail.to
  end

  test "sign_up_alert goes to the Gooi inbox and names the new customer" do
    mail = UserMailer.with(subscription: @subscription).sign_up_alert

    assert_equal ["howzit@gooi.me"], mail.to
    assert_equal "New Sign Up from Thandi!", mail.subject
  end
end
```

2. For `test/mailers/drop_off_event_mailer_test.rb`: **first read `app/mailers/drop_off_event_mailer.rb` and `app/models/drop_off_event.rb` in full** to learn what a valid `DropOffEvent` requires (it needs at minimum a `drop_off_site`, and the site needs a `user`, and the mailer reads `drop_off_event.date`).

   Then write a test that builds a valid `DropOffSite` (with a `user` whose role is `drop_off`), a valid `DropOffEvent` on that site with a `date`, and asserts:
   - `mail.to` equals `[the drop off site's user's email]`
   - `mail.from` equals `["howzit@gooi.me"]`
   - `mail.subject` is present (assert it is not blank — do **not** guess its exact text; read the mailer and assert what it actually sets)

   Keep it to that one test. Do not test the weekly-stats aggregation inside the mailer.

3. Do **not** modify either mailer class. Both work correctly; only the tests were never written.

**Verification:**
```bash
bin/rails test test/mailers/
```
Expected: **0 failures, 0 errors** across the mailers directory.

Then the full suite:
```bash
bin/rails test
```
Expected: **2 fewer errors** than before this prompt.

**Stop condition:**
If building a valid `DropOffEvent` in step 2 requires more than about five lines of setup, or requires creating records whose validations you cannot satisfy, **stop and report exactly which validation is blocking you.** Do not stub, mock, or monkey-patch the model to force the test through — a test that needs a fake model is not testing anything.

**Commit message:**
```
Write the UserMailer and DropOffEventMailer tests

Both files were untouched Rails generator scaffolds, still asserting the
placeholder "to@example.org" / "from@example.com" values, and both
errored: UserMailer.welcome was called without .with(subscription:), and
completion_notification without its required argument.

this one is all claude
```

---

### [P-08] Fix the real bug in InvoiceBuilder#apply_referrals, and repair its test

**Type:** fix | **Risk:** medium | **Scope:** small

**Files:**
- Read + modify: `app/services/invoice_builder.rb`
- Read + modify: `test/integration/referral_flow_test.rb`

**Context:**
**This is the one genuine product bug among the 32 red tests.** Everything else on Day 2 was stale test setup; this is real.

`InvoiceBuilder#apply_referrals` looks up discount products with `Product.find_by(title: ...)` and then calls `.price` on the result **without checking for `nil`**, in both of its branches:

```ruby
discount = Product.find_by(title: "Referred a friend discount (R50)")
invoice.invoice_items.create!(product: discount, quantity: @referred_friends, amount: discount.price)
#                                                                             ^^^^^^^^^^^^^^ NoMethodError if nil
```

When the product row is missing or has been renamed, this raises `NoMethodError: undefined method 'price' for nil` **in the middle of the signup flow** — after the user record has been created, leaving an orphaned account with no invoice. It is currently failing in `ReferralFlowTest#test_referrer_gets_discount_after_referee_payment`.

Every **other** product lookup in this same file already handles the missing case with `raise "Product not found: #{title}"`. This one was simply missed. Your job is to make it consistent with its siblings.

⚠️ **This file is billing code and is treated as fragile. You are adding nil-guards and nothing else. Do not change any amount, any quantity, any calculation, or any control flow beyond raising on a missing product. Do not touch any other method in this file.**

**Task:**

1. Open `app/services/invoice_builder.rb` and find the `apply_referrals` private method. It currently reads:

```ruby
  def apply_referrals(invoice)
    if @referred_friends&.positive?
      discount = Product.find_by(title: "Referred a friend discount (R50)")
      invoice.invoice_items.create!(product: discount, quantity: @referred_friends, amount: discount.price)
      mark_referrals_used
    elsif @referee && @referee != @subscription.user
      plan_name = @subscription.plan == "XL" ? "XL" : @subscription.plan.downcase
      title     = "Referral discount #{plan_name} #{@subscription.duration} month"
      discount  = Product.find_by(title: title)
      invoice.invoice_items.create!(product: discount, quantity: 1, amount: discount.price)

      unless @subscription.user.referrals_as_referee.exists?
        Referral.create!(
          subscription: @subscription,
          referee:      @subscription.user,
          referrer:     @referee,
          status:       :pending
        )
      end
    end
  end
```

2. Replace **exactly that method** with this version. The only changes are two added `raise` lines, matching the `raise "Product not found: #{title}"` convention already used by `add_starter_kit`, `add_subscription_product`, and `add_commercial_subscription` in this same file:

```ruby
  def apply_referrals(invoice)
    if @referred_friends&.positive?
      title    = "Referred a friend discount (R50)"
      discount = Product.find_by(title: title)
      raise "Product not found: #{title}" unless discount

      invoice.invoice_items.create!(product: discount, quantity: @referred_friends, amount: discount.price)
      mark_referrals_used
    elsif @referee && @referee != @subscription.user
      plan_name = @subscription.plan == "XL" ? "XL" : @subscription.plan.downcase
      title     = "Referral discount #{plan_name} #{@subscription.duration} month"
      discount  = Product.find_by(title: title)
      raise "Product not found: #{title}" unless discount

      invoice.invoice_items.create!(product: discount, quantity: 1, amount: discount.price)

      unless @subscription.user.referrals_as_referee.exists?
        Referral.create!(
          subscription: @subscription,
          referee:      @subscription.user,
          referrer:     @referee,
          status:       :pending
        )
      end
    end
  end
```

3. Now open `test/integration/referral_flow_test.rb`. The test fails because the required `Product` rows do not exist in the test database. In the test's `setup`, create the products the referral path needs. You will need to **read the test first** to see which plan and duration it uses, then create the matching product. If the test uses a `Standard` plan with a 3-month duration, the required product title is exactly:
   ```
   Referral discount standard 3 month
   ```
   (note the lowercase plan name — `apply_referrals` downcases everything except `XL`).

   Read `app/models/product.rb` to see what attributes `Product` requires, then create the row in `setup` with a sensible negative `price` (a discount reduces the invoice; check how other discount products in `db/seeds.rb` are priced and match that sign convention).

4. **Do not modify any other method in `app/services/invoice_builder.rb`.** In particular do not touch `apply_discount_code`, `add_starter_kit`, `add_subscription_product`, `add_commercial_subscription`, `add_commercial_from_quote_monthly`, `add_commercial_from_quote_upfront`, `add_monthly_subscription`, `add_monthly_starter_kit_installment`, or `call`.

5. **Do not touch anything under `app/services/revenue_recognitions/`.**

**Verification:**
```bash
bin/rails test test/integration/referral_flow_test.rb
```
Expected: **0 failures, 0 errors.**

Then the full suite:
```bash
bin/rails test
```
Expected, if P-05, P-06 and P-07 are all done: **0 failures, 0 errors — a green suite.** If any failures remain, report them individually; do not attempt to fix anything not named in this prompt.

**Stop condition:**
If making the test pass appears to require changing an **amount, a quantity, or a sign** anywhere in `invoice_builder.rb`, **stop immediately, revert, and report.** That would mean the discount arithmetic itself is wrong, which is a founder decision about money, not a bug fix. Your change here must be limited to the two `raise` lines.

**Commit message:**
```
Guard against a missing referral discount Product in InvoiceBuilder

apply_referrals called .price on the result of Product.find_by without a
nil check, in both branches. A missing or renamed product row therefore
raised NoMethodError mid-signup, after the user had been created but
before the invoice existed — leaving an orphaned account.

Now raises "Product not found: <title>", matching the convention already
used by every other product lookup in this file. No amount, quantity or
calculation is changed. Also seeds the products the referral flow test
needs, which is what it was erroring on.

this one is all claude
```

---
---

# DAY 3 — Data safety

---

### [P-09] Make /skipme a POST — a GET must never mutate data

**Type:** fix | **Risk:** medium | **Scope:** medium

**Files:**
- Read + modify: `config/routes.rb`
- Read + modify: `app/controllers/customers_controller.rb`
- Read + modify: `app/views/customers/skipme.html.erb`
- Read + modify: `app/views/customers/manage.html.erb`
- Read only (for context): `app/models/collection.rb`

**Context:**
`GET /skipme` currently **mutates data**: `CustomersController#skipme` calls `collection.mark_skipped!`, which marks the customer's next collection as skipped and sends them an email.

`GET` requests are assumed safe by the entire web. Browser link-prefetchers, the "restore tabs on startup" behaviour, email-security scanners that pre-click links, and — critically for Gooi, which sends links over WhatsApp — **WhatsApp's own link-preview crawler** will all fire a GET without any human intending it. A customer with this page open in a tab can silently lose a collection they wanted.

This codebase already knows this pattern and already solved it once, correctly. From `config/routes.rb`:

```ruby
# Promotional soil bag giveaway — signed per-collection link, no login required.
# GET is a landing page (WhatsApp prefetches link previews); POST does the write.
get  "soil-bag/:token", to: "soil_bags#show",  as: :soil_bag
post "soil-bag/:token", to: "soil_bags#claim", as: :claim_soil_bag
```

**Apply exactly that pattern here:** GET shows a confirmation page, POST performs the skip. Read `app/controllers/soil_bags_controller.rb` and `app/views/soil_bags/show.html.erb` first and mirror their structure.

**Task:**

1. In `config/routes.rb`, replace this line:
```ruby
  get "skipme", to: "customers#skipme"
```
   with:
```ruby
  # GET is a confirmation page; POST does the write. A GET must never skip a
  # collection — link prefetchers and WhatsApp's preview crawler fire GETs.
  get  "skipme", to: "customers#skipme",         as: :skipme
  post "skipme", to: "customers#confirm_skipme", as: :confirm_skipme
```

2. In `app/controllers/customers_controller.rb`, replace the entire existing `skipme` action with these two actions. `skipme` now only *reads* and prepares the confirmation page; `confirm_skipme` does the write:

```ruby
  # Confirmation page. Reads only — never skips. See routes.rb.
  def skipme
    @subscription = current_user.subscriptions.where(status: 'active').order(:created_at).last
    @collection   = @subscription&.collections&.where('date >= ?', Date.current)&.order(:date)&.first

    return redirect_to manage_path, notice: "No upcoming collection found." unless @subscription && @collection

    @date_text = skip_date_text(@collection)
  end

  # The actual write, reached only by POST from the confirmation page.
  def confirm_skipme
    @subscription = current_user.subscriptions.where(status: 'active').order(:created_at).last
    @collection   = @subscription&.collections&.where('date >= ?', Date.current)&.order(:date)&.first

    return redirect_to manage_path, notice: "No upcoming collection found." unless @subscription && @collection

    if @collection.mark_skipped!(by: current_user, reason: "skipme")
      redirect_to manage_path, notice: "Done — we'll skip you #{skip_date_text(@collection)}."
    else
      redirect_to manage_path, alert: "Something went wrong. Please WhatsApp Alfred and he'll sort it out."
    end
  end
```

3. In the `private` section of the same controller, add this helper:

```ruby
  def skip_date_text(collection)
    case (collection.date - Date.current).to_i
    when 0 then "today"
    when 1 then "tomorrow"
    else "on #{collection.date.strftime('%A, %b %d')}"
    end
  end
```

4. Rewrite `app/views/customers/skipme.html.erb` as a confirmation page. It must:
   - state which collection is about to be skipped, using `@date_text` and `@collection.date`
   - present a confirm control that **POSTs** to `confirm_skipme_path`
   - offer a cancel link back to `manage_path`

   Use `link_to` with `data: { turbo_method: :post }` for the confirm control — **not** `button_to`, and **not** a `button_to` nested inside any form (see the standing header).

   ```erb
   <%= link_to "Yes, skip this collection", confirm_skipme_path,
               data: { turbo_method: :post },
               class: "action-btn" %>
   ```

   Follow the existing markup conventions in `app/views/customers/manage.html.erb` for card and button classes. **No inline `style="..."` attributes** — if you need a new style, add it to a SCSS partial under `app/assets/stylesheets/components/` and import it in `_index.scss`.

   The old view relied on an `@note` instance variable that no longer exists. Remove that dependency.

5. In `app/views/customers/manage.html.erb`, find the link that points to the skipme page. If it is a plain `link_to skipme_path`, **it is still correct** — it now leads to the confirmation page rather than performing the skip, which is the whole point. Only change it if it currently sends a non-GET method or carries a `data-turbo-method`; in that case make it a plain GET `link_to`.

6. **Do not change `Collection#mark_skipped!`.** It is correct.

**Verification:**

1. Routes:
   ```bash
   bin/rails routes | grep -i skipme
   ```
   Expected: exactly two lines — a `GET /skipme` → `customers#skipme` and a `POST /skipme` → `customers#confirm_skipme`.

2. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors** (assuming Day 2 is complete).

3. Manual check — this is the important one. As a signed-in customer with an active subscription and an upcoming collection:
   - Visit `/skipme` in the browser.
   - **Expected:** a confirmation page naming the collection date. **In the Rails console, confirm the collection's `skip` is still `false`.** Merely *loading* the page must not have skipped anything. This is the entire point of the task — verify it explicitly.
   - Click "Yes, skip this collection".
   - **Expected:** redirected to `/manage` with a success flash, and the collection now has `skip: true`.

**Stop condition:**
If any other view, mailer, or WhatsApp message template links to `skipme_path` expecting it to perform the skip immediately, **stop and report every such call site.** Changing the semantics of that path without updating its callers would break a live customer flow. Search before you finish:
```bash
grep -rn "skipme" app/
```

**Commit message:**
```
Make /skipme a POST — a GET must never skip a collection

GET /skipme called mark_skipped!, which skips the collection and emails
the customer. Link prefetchers, tab-restore, email scanners and — since
Gooi sends links over WhatsApp — WhatsApp's own preview crawler all fire
GETs with no human intent, so a customer could silently lose a
collection they wanted.

GET now renders a confirmation page and POST does the write, exactly the
pattern the soil-bag claim links already use for the same reason.

this one is all claude
```

---

### [P-10] Add the four missing database indexes

**Type:** fix | **Risk:** low | **Scope:** small

**Files:**
- Create: `db/migrate/<timestamp>_add_missing_performance_indexes.rb`
- Modify (automatically, by running the migration): `db/schema.rb`

**Context:**
Four columns that are queried on hot paths have no index.

The pointed one is **`payments.snapscan_id`**. `Snapscan::WebhookHandler` does `Payment.find_by(snapscan_id: @payload["id"])` as its **duplicate-payment guard** — so it runs on the critical path of every single incoming payment, as a sequential scan, getting slower as the payments table grows.

The other three are ordinary performance debt, cheap to fix now while the tables are small:
- `invoices.issued_date` — scanned by `MonthlyInvoiceService#find_or_create_invoice` on every monthly run, and by `NudgePendingSubscriptionsJob`
- `subscriptions.next_invoice_date` — `MonthlyInvoiceService.process_all` scans the whole subscriptions table on every `CreateCollectionsJob` run
- `collections.(subscription_id, date)` — a composite; only `subscription_id` alone is indexed today, but `suggested_start_date`, `adopt_future_collections!` and the customer collection history all filter on both

**Task:**

1. Generate the migration:
   ```bash
   bin/rails generate migration AddMissingPerformanceIndexes
   ```

2. Replace the generated file's contents with exactly this (keeping whatever class name the generator produced in the `class ... < ActiveRecord::Migration[7.1]` line):

```ruby
class AddMissingPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Duplicate-payment guard in Snapscan::WebhookHandler — runs on the critical
    # path of every incoming payment.
    add_index :payments, :snapscan_id

    # MonthlyInvoiceService#find_or_create_invoice and NudgePendingSubscriptionsJob.
    add_index :invoices, :issued_date

    # MonthlyInvoiceService.process_all scans this on every CreateCollectionsJob run.
    add_index :subscriptions, :next_invoice_date

    # suggested_start_date, adopt_future_collections! and customer collection
    # history all filter on both columns; only subscription_id alone is indexed.
    add_index :collections, [:subscription_id, :date]
  end
end
```

3. Run the migration:
   ```bash
   bin/rails db:migrate
   ```

4. Confirm `db/schema.rb` was updated by the migration and **commit it along with the migration file.** Do not hand-edit `db/schema.rb`.

5. **Do not add a unique index on `payments.snapscan_id`.** It is tempting — it would enforce webhook idempotency at the database level — but production may already contain rows with duplicate or `NULL` `snapscan_id` values (manual EFT and cash payments have no SnapScan id at all), and a unique index would fail to build on deploy. A plain index is the correct, safe change. If the founder later wants the uniqueness constraint, that needs a data audit first.

6. Do not add any other index, and do not modify any model, controller, or service.

**Verification:**

1. Migration ran cleanly:
   ```bash
   bin/rails db:migrate:status | tail -5
   ```
   Expected: the new migration shows as `up`.

2. Indexes are present in the schema:
   ```bash
   grep -n "snapscan_id\|issued_date\|next_invoice_date\|subscription_id_and_date" db/schema.rb
   ```
   Expected: an `t.index` line for each of the four.

3. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

**Stop condition:**
If `bin/rails db:migrate` fails for any reason, **stop, run `bin/rails db:rollback`, and report the exact error.** Do not modify the schema by hand to work around a failing migration.

**Commit message:**
```
Add indexes on payments.snapscan_id, invoices.issued_date,
subscriptions.next_invoice_date and collections(subscription_id, date)

payments.snapscan_id is the duplicate-payment guard in the SnapScan
webhook, so it was a sequential scan on the critical path of every
incoming payment. The other three are scanned by MonthlyInvoiceService,
NudgePendingSubscriptionsJob and the customer collection history.

Deliberately NOT unique on snapscan_id: manual EFT and cash payments
have none, so a unique index would fail to build against production data.

this one is all claude
```

---
---

# DAY 4 — Additive test coverage around billing

> **Read this before starting either prompt below.**
>
> The revenue-recognition system was recently repaired and is treated as fragile. These two prompts add tests **only**. You must not change a single line of application code in `app/services/revenue_recognitions/`, `app/services/invoice_builder.rb`, `app/services/monthly_invoice_service.rb`, or `app/models/invoice.rb`.
>
> These are **characterization tests**: their job is to pin down what the code *currently does*, so that the next person to touch it can tell whether they changed it. If a test you write fails, your default assumption must be **"I have misunderstood the code"**, not "the code is wrong". Read it again. If after re-reading you still believe the behaviour is wrong, **stop and report it — do not fix it.** A test that documents a bug is useful; a smaller model silently "fixing" accounting logic is not.

---

### [P-11] Characterization tests for RevenueRecognitions::Recognize

**Type:** test | **Risk:** low (additive only) | **Scope:** medium

**Files:**
- Create: `test/services/revenue_recognitions/recognize_test.rb` (the directory `test/services/revenue_recognitions/` already exists — check what is already in it and do not duplicate existing coverage)
- Read only, do **not** modify: `app/services/revenue_recognitions/recognize.rb`, `app/models/invoice.rb`, `app/models/revenue_recognition.rb`, `app/models/subscription.rb`, `app/models/product.rb`

**Context:**
`RevenueRecognitions::Recognize` turns an invoice into `revenue_recognitions` rows using **accrual accounting on `issued_date`** — rows are created whether or not the invoice is paid. It is the heart of Gooi's books. Its rules, from the comment at the top of the class:

- **order-linked invoices** → full amount in the month of the linked collection's date (falling back to the issue month), type `one_off`
- **`once_off` plan subscriptions** → full amount in the month of the first collection (falling back to the issue month), type `one_off`
- **`monthly_invoicing` subscriptions** → full amount in the issue month, type `service`
- **term subscriptions** (1/3/6/12 months) → one-off items (starter kits, compost bags, soil — matched by the `ONE_OFF_TITLES` regex) recognised fully in the issue month; the remaining service portion spread evenly across `duration` months, **with the rounding remainder on the final month**
- invoices with no resolvable subscription or order → returned as `:exception`, never written

Two properties are load-bearing and must be pinned:
- `split_cents` splits in **integer cents** so that rows **always sum exactly to the invoice total**
- `verify_sum!` raises if they ever don't

**Task:**

1. First, read `app/services/revenue_recognitions/recognize.rb` in full, and list what is already covered in `test/services/revenue_recognitions/`. Do not duplicate an existing test.

2. Write tests covering, at minimum:

   a. **A 3-month term subscription spreads service revenue across 3 months.** Assert there are 3 rows, that their `recognized_amount` values **sum exactly to the invoice total**, and that their `period_month` values are three consecutive months starting from the service start.

   b. **The rounding remainder lands on the final month.** Use a total that does not divide evenly by 3 — for example **R100.00 over 3 months**. Assert the rows are `[33.33, 33.33, 33.34]` (verify this against the actual `split_cents` implementation before asserting — read it, don't assume) and that they sum to exactly `100.00`.

   c. **One-off items are recognised fully in the issue month, not spread.** Build an invoice with a starter-kit item (its title must match the `ONE_OFF_TITLES` regex — read the constant) plus a service item, on a term subscription. Assert the starter-kit amount appears as a single `one_off` row in the issue month, and only the remainder is spread.

   d. **A `monthly_invoicing` subscription produces exactly one row in the issue month**, type `service`.

   e. **A `once_off` plan subscription produces exactly one `one_off` row**, dated to the month of its first collection.

   f. **An invoice with no subscription and no order returns `:exception`** and **writes no rows**. Assert `RevenueRecognition.count` is unchanged.

   g. **`call` is idempotent.** Calling it twice without `force: true` must not duplicate rows — the second call returns status `:skipped_existing`. Assert the row count is the same after both calls.

   h. **`call(force: true)` replaces rows rather than appending.** Assert the count after a forced re-run equals the count after the first run.

3. Follow the existing test conventions in this codebase: no fixtures (the `test/fixtures/` directory is effectively empty — every test builds its own records), and unique emails via `SecureRandom.hex(4)` to avoid uniqueness collisions between tests. Subscriptions need `street_address` and a `suburb` from the `Subscription::SUBURBS` constant (use `"Observatory"`).

4. **Change no application code.** If a test fails, re-read the implementation — you have misunderstood it. If you still believe it is wrong after re-reading, **stop and report.**

**Verification:**
```bash
bin/rails test test/services/revenue_recognitions/
```
Expected: **all tests pass, 0 failures, 0 errors.**

```bash
bin/rails test
```
Expected: **0 failures, 0 errors.**

Confirm you changed no application code:
```bash
git status --short app/
```
Expected: **no output.** If anything under `app/` is modified, you have violated the scope of this task — revert it.

**Stop condition:**
**If any test you write fails, stop and report it. Do not change application code to make it pass.** This is accounting logic; a failing characterization test is a finding for a human to evaluate, not a bug for you to fix. Report the exact expected-vs-actual and what you believe it means.

**Commit message:**
```
Add characterization tests for RevenueRecognitions::Recognize

Pins current behaviour of the accrual recognition rules: even spread
across term months with the rounding remainder on the final month, exact
integer-cent summation to the invoice total, one-off items recognised in
the issue month rather than spread, monthly_invoicing and once_off
single-row cases, the no-subscription exception path, and the
idempotency / force-replace semantics of #call.

Tests only. No application code changed.

this one is all claude
```

---

### [P-12] Characterization tests for InvoiceBuilder discount handling

**Type:** test | **Risk:** low (additive only) | **Scope:** medium

**Files:**
- Create: `test/services/invoice_builder_test.rb`
- Read only, do **not** modify: `app/services/invoice_builder.rb`, `app/models/discount_code.rb`, `app/models/invoice_discount_code.rb`, `app/models/invoice.rb`

**Context:**
`InvoiceBuilder#apply_discount_code` is the code path that decides whether a customer actually receives the discount they were promised. It has several guards worth pinning:

- it no-ops unless the code `available?`
- it no-ops if the code has already been `used_by?` this user
- percentage codes clamp the percentage to `0..100`
- fixed-amount codes divide `discount_cents` by 100
- **the discount is capped at the subtotal, so an invoice can never go negative**
- on success it creates an `invoice_discount_codes` row, sets `used_discount_code = true`, and increments the code's `used_count`

The assessment flagged a related risk (`ASSESSMENT.md`, billing risk 4): a discount whose Product title does not resolve **silently produces no discount rather than an error**, meaning a customer promised 15% off could be billed full price with nobody finding out. **These tests do not fix that — they document current behaviour so the founder can see it clearly.**

**Task:**

1. Read `app/services/invoice_builder.rb` (`apply_discount_code` and `call`) and `app/models/discount_code.rb` in full. Learn exactly what `available?`, `used_by?`, `percentage_based?` and `fixed_amount?` do before writing a line.

2. Write tests covering, at minimum:

   a. **A valid percentage code reduces the invoice total by that percentage.** Assert the resulting `invoice.total_amount`, that an `invoice_discount_codes` row exists, and that `invoice.used_discount_code` is `true`.

   b. **A valid fixed-amount code reduces the total by `discount_cents / 100.0`.**

   c. **A discount larger than the subtotal is capped at the subtotal** — assert `invoice.total_amount` is exactly `0` and **never negative**. (`Invoice#calculate_total` also floors at zero; assert the outcome, which is what matters.)

   d. **An unavailable code applies no discount.** Total is unchanged, no `invoice_discount_codes` row, `used_discount_code` is not `true`.

   e. **A code already used by this same user applies no discount** (the `used_by?` guard).

   f. **A successful application increments the code's `used_count` by exactly 1.**

3. Follow existing test conventions: build your own records, unique emails via `SecureRandom.hex(4)`, subscriptions need `street_address` and `suburb: "Observatory"`. You will need to create the `Product` rows that `InvoiceBuilder` looks up by title for whichever plan/duration your test subscription uses — read `add_subscription_product` and `add_starter_kit` to see exactly which titles it will demand, and create those products in `setup`. If a product is missing, the builder raises `"Product not found: <title>"`, which tells you precisely what to create.

4. **Change no application code.** In particular, do not "fix" the silent no-op described in the context above — document it if you encounter it, and note it in your final report.

**Verification:**
```bash
bin/rails test test/services/invoice_builder_test.rb
```
Expected: **all tests pass, 0 failures, 0 errors.**

```bash
bin/rails test
```
Expected: **0 failures, 0 errors.**

```bash
git status --short app/
```
Expected: **no output.**

**Stop condition:**
Same as P-11: **if a test fails, stop and report — do not change application code.** Additionally, if you find that the discount arithmetic produces a result you believe is wrong (rather than merely surprising), **report it prominently.** That is a finding about money and it goes to the founder, not into a fix.

**Commit message:**
```
Add characterization tests for InvoiceBuilder discount handling

Pins the behaviour of apply_discount_code: percentage and fixed-amount
paths, the cap that prevents a negative invoice total, the availability
and already-used-by-this-user guards, and used_count incrementing.

Tests only. No application code changed.

this one is all claude
```

---
---

# DAY 5 — Trust surface

---

### [P-13] Add privacy policy and terms of service pages (structure only)

**Type:** polish | **Risk:** low | **Scope:** medium

**Files:**
- Read + modify: `config/routes.rb`
- Read + modify: `app/controllers/pages_controller.rb`
- Create: `app/views/pages/privacy.html.erb`
- Create: `app/views/pages/terms.html.erb`
- Read + modify: `app/views/shared/_footer.html.erb`
- Read only (for conventions): `app/views/pages/faq.html.erb`, `app/views/pages/about.html.erb`

**Context:**
Gooi has **no privacy policy and no terms of service**, and no link to either in the footer. It collects, from every customer: full name, email address, phone number, **physical home address**, and geolocation coordinates. It shares data with Postmark, Twilio, Mailchimp, SnapScan, Google Analytics and Ahoy.

Gooi is a South African business processing South African residents' personal information, which brings it under **POPIA** (the Protection of Personal Information Act). It also pitches to body corporates and offices (there are `estate-deck` and `office-deck` routes in this app), and any office manager doing vendor due diligence will ask for a privacy policy.

**Your job is the scaffolding — routes, controller actions, views, footer links, and page structure with correct headings. Your job is NOT to write the legal content.** Every place where a specific factual or legal commitment is required, you must leave a clearly-marked placeholder for the founder. **Do not invent a retention period. Do not invent an Information Officer. Do not invent a legal undertaking.** Inventing legal commitments for a real company is worse than leaving the page unwritten.

**Task:**

1. In `config/routes.rb`, next to the other static page routes (`about`, `story`, `faq`), add:
```ruby
  get "privacy", to: "pages#privacy"
  get "terms",   to: "pages#terms"
```

2. In `app/controllers/pages_controller.rb`:
   - add two empty actions, `def privacy; end` and `def terms; end`
   - add `:privacy` and `:terms` to the existing `skip_before_action :authenticate_user!, only: [...]` list at the top of the class, so both pages are publicly reachable

3. Create `app/views/pages/privacy.html.erb`. Match the markup conventions of `app/views/pages/faq.html.erb` (read it first — reuse its container and section classes). **No inline `style="..."` attributes.** Set the page meta at the top, following the pattern the layout expects:
```erb
<% content_for :meta_title, "Privacy Policy | Gooi" %>
<% content_for :meta_description, "How Gooi collects, uses and protects your personal information." %>
```
   Structure it with these headings, and under each, a `TODO(founder)` placeholder paragraph in an HTML comment stating exactly what must be supplied:
   - Who we are
   - What personal information we collect *(you may pre-fill this factually from the schema — name, email, phone number, street address, suburb, geolocation coordinates — since that is observable from the code and not a legal commitment)*
   - Why we collect it
   - Who we share it with *(you may pre-fill the processor list factually: Postmark for email, Twilio for WhatsApp, Mailchimp for mailing lists, SnapScan for payments, Google Analytics and Ahoy for site analytics)*
   - How long we keep it — **`TODO(founder)`: retention period. Do not invent one.**
   - Your rights under POPIA (access, correction, deletion, objection)
   - Our Information Officer — **`TODO(founder)`: name and contact email. POPIA requires a named Information Officer. Do not invent one.**
   - How to contact us

4. Create `app/views/pages/terms.html.erb` the same way, with `content_for :meta_title` / `:meta_description` set, and these headings, each with a `TODO(founder)` placeholder:
   - The service we provide
   - Subscriptions, plans and durations
   - Payment terms — **`TODO(founder)`**
   - Skipping and pausing collections
   - Cancellation and refunds — **`TODO(founder)`**
   - What we will and won't collect (acceptable waste) — **`TODO(founder)`**
   - Liability
   - Changes to these terms

5. In `app/views/shared/_footer.html.erb`, add two links alongside the existing Home / About / FAQ / Blog links, matching their exact existing markup and CSS classes:
```erb
<%= link_to 'Privacy', privacy_path %>
<%= link_to 'Terms', terms_path %>
```

6. **Do not** add a cookie-consent banner, do not touch the Google Analytics or Ahoy configuration, and do not modify any other page.

**Verification:**

1. Routes exist:
   ```bash
   bin/rails routes | grep -E "privacy|terms"
   ```
   Expected: a `GET /privacy` and a `GET /terms`.

2. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

3. Manual check, **signed out** (both pages must be publicly reachable — that is the entire point):
   - Visit `/privacy` → renders, all headings present, `TODO(founder)` placeholders visible in the page source as HTML comments.
   - Visit `/terms` → same.
   - Confirm both links appear in the footer on the homepage and are clickable.
   - Check on a narrow viewport (375px) that the footer does not overflow horizontally.

4. Confirm you invented nothing:
   ```bash
   grep -c "TODO(founder)" app/views/pages/privacy.html.erb app/views/pages/terms.html.erb
   ```
   Expected: several in each.

**Stop condition:**
**If you find yourself about to write a specific retention period, a named Information Officer, a refund policy, or any other concrete legal commitment — stop and leave a `TODO(founder)` instead.** That content is the founder's to supply and should be reviewed by someone who knows POPIA. A page full of honest placeholders is useful; a page full of invented legal commitments is a liability.

**Commit message:**
```
Add privacy policy and terms of service page scaffolding

Gooi collects names, phone numbers, physical home addresses and
geolocation from South African residents and shares them with six
third-party processors, with no privacy policy and no terms anywhere in
the app — a POPIA exposure as well as a blocker for the estate and
office pitches.

Adds routes, public actions, structured pages with correct headings, and
footer links. All legal content is left as explicit TODO(founder)
placeholders: retention period, Information Officer, payment terms,
cancellation and refunds are for the founder to supply, not for a model
to invent.

this one is all claude
```

---

### [P-14] Tell the truth in recurring.yml about the missing worker dyno

**Type:** polish | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `config/recurring.yml`
- Create: `docs/BACKGROUND_JOBS.md`
- Read only (for context): `Procfile`, `app/models/invoice.rb`, `app/controllers/drivers_days_controller.rb`

**Context:**
`config/recurring.yml` schedules `CreateCollectionsJob` for Tuesday, Wednesday and Thursday at 15:00 UTC. `Procfile` declares `worker: bin/jobs`. **Neither is true in production: there is no worker dyno running.**

The codebase already knows this and works around it, with comments saying so — for example `app/models/invoice.rb`:

> *"perform_now: there is no worker dyno in production, so perform_later would enqueue into the queue DB and never run."*

Scheduled work therefore **piggybacks on Alfred's route-day taps**: collection creation runs from `DriversDaysController#end` via `perform_now`, and the Monday revenue-recognition catch-up runs from `DriversDaysController#start`.

The danger is the gap between the config and reality. Anyone reading `recurring.yml` will reasonably conclude collections are created on a schedule. They are not. And several `perform_later` calls are silently no-ops in production — most sharply, an admin clicking "trigger reminders" on the WhatsApp page gets a success flash and **zero messages are sent.**

**This task changes no behaviour. It documents reality so that the next person to read this config is not misled.** The decision about whether to actually run a worker dyno is the founder's and is out of scope.

**Task:**

1. At the top of `config/recurring.yml`, above the `production:` key, add this comment block verbatim:

```yaml
# ⚠️ THESE SCHEDULES DO NOT RUN IN PRODUCTION.
#
# Solid Queue only executes recurring tasks when a worker process is running
# (`bin/jobs`, declared in the Procfile). There is currently no worker dyno on
# Heroku, so nothing in this file fires.
#
# Scheduled work instead piggybacks on the driver's route-day taps, using
# perform_now from the controller:
#
#   - CreateCollectionsJob            → DriversDaysController#end   ("End" tap)
#   - CreateNextWeekDropOffEventsJob  → DriversDaysController#end
#   - CheckSubscriptionsForCompletionJob → DriversDaysController#end
#   - RevenueRecognitionCatchUpJob    → DriversDaysController#start (Mondays only)
#   - SyncRevenueRecognitionsJob      → Invoice after_commit (perform_now)
#
# Jobs still invoked with perform_later are therefore DEAD in production:
#   - MailchimpSyncJob            (Subscription#sync_to_mailchimp)
#   - CalculateFinancialMetricsJob (Admin::ExpensesController, 5 call sites)
#   - NudgePendingSubscriptionsJob (Admin::DashboardController)
#   - WhatsappReminderJob          (Admin::WhatsappMessagesController#trigger_reminders)
#
# The last one is the sharp edge: an admin clicking "trigger reminders" gets a
# success flash and no WhatsApp messages are sent.
#
# See docs/BACKGROUND_JOBS.md. If a worker dyno is ever enabled, this file
# becomes live — review it before doing so.
```

2. **Leave the actual YAML schedule entries below it completely unchanged.** Do not delete them. If a worker dyno is enabled later, they should start working.

3. Create `docs/BACKGROUND_JOBS.md` explaining, in prose:
   - that there is no worker dyno in production and what that means
   - the piggyback pattern, with the exact controller actions and the jobs each triggers (list above)
   - which `perform_later` calls are consequently dead, and the specific user-visible consequence of each
   - the consequence of Alfred not tapping "End" on a route day (next week's collections are not created)
   - that enabling a worker dyno would make `config/recurring.yml` live, and that it must be reviewed first
   - that `bin/jobs` is the worker command, for whoever enables it

   Keep it under one page. Be factual. Do not recommend a course of action — the dyno decision is the founder's.

4. **Change no Ruby code.** Do not convert any `perform_later` to `perform_now`. That is a real behavioural change with real consequences (a synchronous WhatsApp broadcast from a web request could time out the dyno) and it is not this task.

**Verification:**

1. YAML still parses:
   ```bash
   ruby -ryaml -e "puts YAML.load_file('config/recurring.yml').inspect"
   ```
   Expected: prints the parsed hash with the `production` key and its three job entries **still intact**. If it prints `nil` or raises, your comment block has broken the file.

2. App still boots:
   ```bash
   bin/rails runner "puts 'ok'"
   ```
   Expected: `ok`

3. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

4. No Ruby changed:
   ```bash
   git status --short app/
   ```
   Expected: **no output.**

**Stop condition:**
If you conclude a worker dyno *is* in fact running in production (for example, you find evidence in `app.json`, a Heroku config file, or a `Procfile` variant that contradicts this), **stop and report.** The entire premise of this task would be wrong and the comment you are about to write would itself become the misleading thing.

**Commit message:**
```
Document that recurring.yml does not run in production

recurring.yml schedules CreateCollectionsJob for Tue/Wed/Thu and the
Procfile declares a worker, but no worker dyno runs on Heroku, so none
of it fires. Scheduled work actually piggybacks on Alfred's route-day
taps via perform_now, and four perform_later call sites are dead —
including the WhatsApp reminder trigger, which flashes success and sends
nothing.

Comments the config truthfully and adds docs/BACKGROUND_JOBS.md. No
behaviour change; the schedule entries are left intact so they work if a
worker is ever enabled.

this one is all claude
```

---
---

# DAY 6 — Performance and observability

---

### [P-15] Fix the N+1 on the subscriptions index

**Type:** fix | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `app/controllers/subscriptions_controller.rb`
- Read only (for context): `app/views/subscriptions/index.html.erb`, `app/models/subscription.rb`

**Context:**
`SubscriptionsController#index` is the admin's most-used list. It eager-loads `:user` and `:invoices`, but the view then calls `subscription.total_collections` and `subscription.remaining_collections` on **every row** — and each of those methods runs a fresh `COUNT(*)` against the `collections` table. Two extra queries per row.

The fix is unusually clean, because **the correct SQL already exists in this very file.** Lines 4–5 define:

```ruby
  TOTAL_COLLECTIONS_SQL = "(SELECT COUNT(*) FROM collections WHERE collections.subscription_id = subscriptions.id AND collections.skip = false)".freeze
  REMAINING_COLLECTIONS_SQL = "(CEIL(subscriptions.duration * 4.2) - #{TOTAL_COLLECTIONS_SQL})".freeze
```

These were written so the index could **sort** by those columns. We can also `select` them as attributes, which makes the values available on each record with no extra query.

**Task:**

1. Open `app/controllers/subscriptions_controller.rb` and find the `index` action. Its admin/driver branch currently reads:

```ruby
      @subscriptions = Subscription.active
                                    .includes(:user, :invoices)
                                    .joins(:user)
                                    .order(Arel.sql("#{order_col} #{@dir}"))
```

2. Replace **exactly those four lines** with:

```ruby
      # total_collections / remaining_collections are methods that each run a
      # COUNT per row. Select them as attributes using the same SQL the sort
      # already uses, so the view reads them for free. Aliased to *_count so
      # they shadow nothing on the model.
      @subscriptions = Subscription.active
                                    .includes(:user, :invoices)
                                    .joins(:user)
                                    .select(
                                      "subscriptions.*",
                                      "#{TOTAL_COLLECTIONS_SQL} AS total_collections_count",
                                      "#{REMAINING_COLLECTIONS_SQL} AS remaining_collections_count"
                                    )
                                    .order(Arel.sql("#{order_col} #{@dir}"))
```

3. Open `app/views/subscriptions/index.html.erb`. In the **table body only**, replace the per-row method calls with the selected attributes:
   - `subscription.total_collections` → `subscription.total_collections_count`
   - `subscription.remaining_collections` → `subscription.remaining_collections_count`

   Apply this to **every** occurrence in the row loop, including inside the `overdue` conditional near line 36. Be careful with `remaining_collections&.to_i` — the selected attribute may be `nil` when `duration` is `nil`, so **keep the safe navigation**: `subscription.remaining_collections_count&.to_i`.

4. **Do not change** the `<th>` sort-header links at the top of the table. They pass the string keys `"total_collections"` / `"remaining_collections"` to `SORTABLE_SUB_COLS`, which is a separate mechanism and still correct.

5. **Do not** modify `Subscription#total_collections` or `Subscription#remaining_collections` in the model. They are used elsewhere (mailers, `admin/users/show`, `customers#manage`) and must keep working.

6. **Do not** touch the non-admin branch of `index` (`@subscriptions = Subscription.where(user_id: current_user.id)`) — the customer's own list is one or two rows and needs nothing.

**Verification:**

1. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

2. Manual check — this is the point of the task, so actually do it:
   - Sign in as an admin and load `/subscriptions`.
   - In `log/development.log`, count the `SELECT COUNT(*) FROM "collections"` lines generated by that request.
   - **Expected: zero.** Before this change there were two per row.
   - The **displayed numbers must be identical** to before. Verify at least three rows against the old behaviour — the point is to make it faster, not different. If any number changed, that is the stop condition.
   - Click the "Total Collections" and "Remaining" column headers. Sorting must still work in both directions.

**Stop condition:**
If the numbers rendered in the table **change** after this refactor, **stop, revert, and report.** The selected SQL and the Ruby methods should produce identical values; if they don't, one of them is wrong, and finding out which is a job for a human — `remaining_collections` has a `once_off` special case (`return 1 - total_collections if once_off?`) that the SQL does **not** replicate, so pay particular attention to rows for `once_off` subscriptions.

**Commit message:**
```
Fix N+1 on the subscriptions index

The view called total_collections and remaining_collections per row, each
of which runs a COUNT against collections — two extra queries per row on
the admin's most-used list. Selects them as attributes instead, reusing
the SQL the sort already defines. The model methods are untouched;
they're used elsewhere.

this one is all claude
```

---

### [P-16] Generate and commit the sitemap that robots.txt already advertises

**Type:** polish | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `config/sitemap.rb`
- Create: `public/sitemap.xml` (and any companion files the generator emits)
- Read + modify: `.gitignore` (only if it currently ignores `public/sitemap*`)
- Read only: `public/robots.txt`, `config/routes.rb`

**Context:**
`public/robots.txt` ends with:
```
Sitemap: https://www.gooi.me/sitemap.xml
```
The `sitemap_generator` gem is in the `Gemfile` and `config/sitemap.rb` exists and is configured — **but no sitemap has ever been generated or committed, so that URL returns a 404.** Every crawler that reads `robots.txt` follows that line and hits a dead end. For a local service business competing on organic search for "compost collection Cape Town", that is free SEO left on the floor, and the infrastructure to fix it is already installed.

The existing `config/sitemap.rb` covers `/`, `/about`, `/story`, `/faq`, `/blog`, and all published posts. It is missing several public pages that exist in `routes.rb`.

**Task:**

1. Read `config/routes.rb` and confirm which routes are **public and indexable**. Then read `config/sitemap.rb`.

2. Add to `config/sitemap.rb` the public pages currently missing. Add the farms index and each farm's show page (`resources :farms, only: [:index, :show], param: :slug` — these are public-facing drop-off site pages and are exactly the kind of local-SEO content that should be indexed):

```ruby
  add farms_path, changefreq: "monthly", priority: 0.7

  DropOffSite.find_each do |site|
    add farm_path(site), lastmod: site.updated_at, changefreq: "monthly", priority: 0.6
  end
```

   **If and only if P-13 has already been committed**, also add:
```ruby
  add "/privacy", changefreq: "yearly", priority: 0.3
  add "/terms",   changefreq: "yearly", priority: 0.3
```
   If P-13 is not yet done, omit these two lines — do not add routes that don't exist.

3. **Do not add** to the sitemap: anything under `/admin`, `/subscriptions`, `/invoices`, `/drivers_days`, `/orders`, `/users`, the `estate-deck` or `office-deck` sales decks, the `journey/:token` or `soil-bag/:token` links, or any block/survey page. `robots.txt` already disallows most of these, and the token links are private per-customer URLs — **putting them in a public sitemap would leak them.**

4. Generate the sitemap:
   ```bash
   bin/rails sitemap:refresh:no_ping
   ```
   (`:no_ping` so this does not notify search engines from a local machine.)

5. Check `.gitignore`. If it ignores `public/sitemap*` or similar, **remove that ignore rule** — the sitemap must be committed so it is present on Heroku, which has an ephemeral filesystem and no scheduled job to regenerate it.

6. Commit the generated `public/sitemap.xml` (and any index/companion files produced) along with the `config/sitemap.rb` change.

**Verification:**

1. The file exists and is valid XML:
   ```bash
   ls -la public/sitemap*
   ruby -rrexml/document -e "REXML::Document.new(File.read('public/sitemap.xml')); puts 'valid xml'"
   ```
   Expected: the file exists, and `valid xml`.

2. It contains the expected URLs and **none of the forbidden ones**:
   ```bash
   grep -c "<loc>" public/sitemap.xml
   grep -E "admin|invoice|drivers_day|soil-bag|journey|estate-deck|office-deck" public/sitemap.xml
   ```
   Expected: a positive count of `<loc>` entries, and the second grep returns **no output at all**. If it returns anything, you have leaked a private URL into a public file — remove it before committing.

3. It is not gitignored:
   ```bash
   git check-ignore public/sitemap.xml
   ```
   Expected: **no output** (meaning the file is not ignored and will be committed).

4. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

**Stop condition:**
If `bin/rails sitemap:refresh:no_ping` fails, **report the exact error rather than hand-writing an XML file.** A hand-maintained sitemap will silently rot the moment a blog post is published, which is worse than not having one.

**Commit message:**
```
Generate and commit the sitemap robots.txt already points at

robots.txt has advertised https://www.gooi.me/sitemap.xml all along, but
no sitemap was ever generated, so every crawler that read robots.txt
followed that line into a 404. The sitemap_generator gem and
config/sitemap.rb were already set up and simply never run.

Also adds the public farm pages, which are exactly the local-SEO surface
worth indexing. Private token links and all admin//customer paths are
deliberately excluded.

this one is all claude
```

---

### [P-17] Add error tracking

**Type:** polish | **Risk:** low | **Scope:** small

**Files:**
- Read + modify: `Gemfile`
- Create: `config/initializers/sentry.rb`
- Read + modify: `.env.example` (create it if it does not exist)
- Read + modify: `README.md` (only to document the new env var, if a setup section exists)

**Context:**
Gooi has **no error tracking of any kind.** Verified absent from the `Gemfile`: Sentry, Honeybadger, Rollbar, Bugsnag, AppSignal.

Every production 500 is currently invisible. The homepage crash fixed in P-01 (`/?discount_code=ANYTHING` → 500) could have been firing for months and nobody would know. The founder finds out about errors when a customer complains, or never.

This is the cheapest permanent capability upgrade available: one gem, one initializer, one environment variable. **You cannot fix what you cannot see.**

**Task:**

1. Add to the `Gemfile`, in the main group (not inside `:development` or `:test`):
```ruby
gem "sentry-ruby"
gem "sentry-rails"
```

2. Install:
   ```bash
   bundle install
   ```

3. Create `config/initializers/sentry.rb` with exactly this:

```ruby
# Error tracking. No-ops entirely when SENTRY_DSN is unset, so development and
# test are unaffected and a missing env var can never break a boot.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Sample everything — Gooi's traffic is far below any volume where sampling
  # would save money, and a missed error is worse than a duplicate one.
  config.traces_sample_rate = 0.0 # performance tracing off; error reporting only

  # Never ship customer personal information to a third party. Gooi handles
  # names, phone numbers and physical home addresses.
  config.send_default_pii = false

  config.before_send = lambda do |event, _hint|
    # Belt and braces: strip anything that looks like a credential or an address.
    event.request&.data = nil if event.request
    event
  end
end
```

4. Document the new environment variable. If `.env.example` exists, add `SENTRY_DSN=` to it; if it does not, create it containing just that line plus a brief comment. If `README.md` has a setup or environment section, add one line noting that `SENTRY_DSN` is optional and that error tracking is disabled without it.

5. **Do not** add performance monitoring, session replay, or profiling. Error reporting only.

6. **Do not** add a `SENTRY_DSN` value. The founder must create the Sentry project and set the variable on Heroku. Without it, the initializer is a no-op — which is correct and safe.

7. **Do not** modify any controller, model, service, or job. Sentry's Rails integration hooks in automatically.

**Verification:**

1. The app boots with **no** `SENTRY_DSN` set (this is the critical case — a missing env var must never break the app):
   ```bash
   bin/rails runner "puts 'boots without SENTRY_DSN: ok'"
   ```
   Expected: `boots without SENTRY_DSN: ok`

2. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.**

3. Confirm no application code changed:
   ```bash
   git status --short app/
   ```
   Expected: **no output.**

4. Confirm the initializer is inert outside production:
   ```bash
   bin/rails runner "puts Sentry.initialized? ? 'initialized' : 'inert (correct for development)'"
   ```
   Expected: `inert (correct for development)` — `enabled_environments` is production-only.

**Stop condition:**
If `bundle install` fails or produces a dependency conflict, **stop, revert the `Gemfile` and `Gemfile.lock`, and report the exact conflict.** Do not resolve it by upgrading or downgrading unrelated gems — a dependency change in a production Rails app is not a side effect to absorb inside an error-tracking task.

**Commit message:**
```
Add Sentry error tracking (no-op until SENTRY_DSN is set)

The app had no error tracking of any kind, so every production 500 was
invisible — the homepage crash on an unknown ?discount_code= could have
been firing for months unnoticed.

Production-only, error reporting only (no tracing, no profiling), and
send_default_pii is off with request data stripped in before_send, since
Gooi handles names, phone numbers and physical home addresses. Inert
until the founder sets SENTRY_DSN on Heroku.

this one is all claude
```

---
---

# DAY 7 — Polish

---

### [P-18] Give transactional emails a shared branded layout

**Type:** polish | **Risk:** low | **Scope:** medium

**Files:**
- Read + modify: `app/views/layouts/mailer.html.erb`
- Read + modify: `app/views/layouts/mailer.text.erb`
- Create: `app/views/shared/_mailer_header.html.erb`
- Create: `app/views/shared/_mailer_footer.html.erb`
- Read only (for the brand colours and existing conventions): `app/views/user_mailer/welcome.html.erb`, `app/views/subscription_mailer/payment_received.html.erb`

**Context:**
`app/views/layouts/mailer.html.erb` is still the **stock Rails scaffold** — an empty `<style>` block and a bare `<%= yield %>`. Consequently every one of the ~20 mailer templates re-implements the brand inline: `font-family: Arial, sans-serif`, `color: #1f4632` (Gooi green), `#FBB718` (Gooi yellow) buttons — copy-pasted, with no logo, no consistent header, and no footer.

The website has a strong visual identity. The emails do not carry it. Every email is a brand impression, and consolidating the chrome into the layout means the next brand tweak is one file instead of twenty.

**This is the one place inline styles are correct** — email clients require them, and the existing templates already use them. Do not try to apply the project's no-inline-styles rule here; it does not apply to mailer views.

**The hard constraint: every existing email must still render correctly afterwards.** You are adding chrome around the existing body content, not rewriting the bodies.

**Task:**

1. Read `app/views/user_mailer/welcome.html.erb` and `app/views/subscription_mailer/payment_received.html.erb` to extract the established brand values. They are:
   - green: `#1f4632`
   - yellow (buttons): `#FBB718`
   - font stack: `Arial, sans-serif`

2. Create `app/views/shared/_mailer_header.html.erb`: a simple centred header with the Gooi wordmark as **text** (`gooi`) in the brand green at a large size, on a white background, with a bottom border in the brand green.

   ⚠️ **Do not attempt to construct a logo as inline SVG.** There is a standing rule in this project: the real Gooi logo lives in the nav bar and in Affinity Designer files, and hand-built `<text>gooi*</text>` SVG substitutes are explicitly not allowed. Plain styled HTML text is correct here. If a real logo image is wanted later, the founder will supply an asset.

3. Create `app/views/shared/_mailer_footer.html.erb` containing:
   - the Gooi name and a one-line description
   - a link to the website (`root_url`)
   - the WhatsApp contact link already used across the existing templates: `https://wa.me/27785325513`
   - a plain-text line: `You're receiving this because you have a Gooi account.`
   - **an unsubscribe / preferences link.** Point it at `manage_url`. Add an HTML comment above it: `<!-- TODO(founder): a real unsubscribe endpoint. POPIA requires an opt-out on direct marketing; manage_url is a placeholder for transactional mail. -->`

   Keep it small, grey, centred — standard email-footer treatment.

4. Rewrite `app/views/layouts/mailer.html.erb` so it wraps the yielded body in a table-based email shell (tables, not flexbox — email clients require them). It must:
   - set a max width of 600px, centred
   - render `shared/_mailer_header` above `<%= yield %>`
   - render `shared/_mailer_footer` below it
   - set the base font family and colour on the body wrapper
   - include `<meta name="viewport" content="width=device-width, initial-scale=1">`

   **Preserve `<%= yield %>` exactly.** Every existing template's content flows through it and must be unaffected.

5. Update `app/views/layouts/mailer.text.erb` similarly: keep `<%= yield %>`, and add a plain-text footer beneath it (the Gooi name, the website URL, the WhatsApp number).

6. **Do not modify any individual mailer template.** Not one. They keep their inline styles and keep working — you are adding chrome around them. If a template's own styling now looks slightly doubled up against the layout, **leave it**; deduplicating 20 templates is a separate task and is not worth the regression risk here.

**Verification:**

1. Suite:
   ```bash
   bin/rails test
   ```
   Expected: **0 failures, 0 errors.** The mailer tests written in P-07 will exercise the new layout.

2. Manual check — **render several real emails and actually look at them.** In `bin/rails console`:
   ```ruby
   sub = Subscription.last
   puts UserMailer.with(subscription: sub).welcome.body.encoded
   ```
   Confirm the header and footer appear, and that the original body content is **fully intact** in between.

3. Repeat for at least three more mailers with different shapes — for example:
   ```ruby
   puts SubscriptionMailer.with(subscription: sub).payment_received.body.encoded
   puts InvoiceMailer.with(invoice: Invoice.last).invoice_created.body.encoded
   puts CollectionMailer.skipped(collection_id: Collection.last.id, actor_id: nil, reason: "test", occurred_at: Time.zone.now).body.encoded
   ```
   Every one must still contain its original content, now wrapped in the new chrome.

4. If `letter_opener` is available in development, open one in a browser and check it renders on a narrow (mobile) width without horizontal overflow.

**Stop condition:**
If wrapping a template in the layout **breaks its rendering** — content disappears, the layout swallows it, or a mailer raises — **stop, revert, and report which mailer and how.** Some mailers may set `layout: false` or specify their own layout; if you find one that does, leave it alone and report it. Breaking a live customer email is a bad trade for nicer chrome.

**Commit message:**
```
Give transactional emails a shared branded layout

layouts/mailer.html.erb was still the stock Rails scaffold — an empty
<style> block and a bare yield — so all ~20 mailer templates re-declared
the brand inline, with no logo, no consistent header and no footer.

Adds a 600px table-based email shell with a shared header and footer
(website link, WhatsApp contact, and a placeholder unsubscribe link
marked TODO(founder), which POPIA will want for direct marketing). No
individual mailer template is touched; the chrome wraps them.

this one is all claude
```

---
---
---

# ⛔ PENDING APPROVAL — DO NOT EXECUTE

> **Everything below this line is a FEATURE, not a fix. It is written and ready, and it is NOT scheduled.**
>
> **The smaller model must not execute F1, F2, or F3.** They require the founder's explicit sign-off first, for the reasons given in `FEATURES.md`.
>
> If you are a model working through this prompt bank: **your work ends at P-18.** Stop there. Do not proceed past this line. If you have completed P-18 and have time remaining, re-run the full test suite and report the state of the tree — do not start a feature.

---

### [F1-PROMPT] `PENDING APPROVAL` — Payment receipt email

**Type:** feature | **Risk:** low | **Scope:** small
**Approval required from:** founder. See `FEATURES.md` → F1 (recommended: **greenlight**).

**Files:**
- Read + modify: `app/mailers/payment_mailer.rb`
- Create: `app/views/payment_mailer/receipt.html.erb`
- Create: `app/views/payment_mailer/receipt.text.erb`
- Read + modify: `app/controllers/invoices_controller.rb`
- Create: `test/mailers/payment_mailer_test.rb`

**Context:**
When the founder marks an invoice paid — `InvoicesController#paid`, the action she clicks for every EFT and cash payment — the customer is sent **nothing**. A `payment_received` email exists, but it fires only from `Subscription#activate_subscription`, i.e. only on a *first* payment against a *pending* subscription. So a renewal payment, a monthly-billing payment, or a compost-bags order payment produces total silence. The customer transfers money into a bank account and hears nothing back.

"Hi, did you get my payment?" is the highest-volume avoidable support message in any subscription business, and every one of them currently lands in the founder's personal WhatsApp.

**Task:**

1. Add a `receipt` method to `app/mailers/payment_mailer.rb` (the class already exists with `short_payment_alert`; follow its exact style, including `track_opens` and `message_stream`):

```ruby
  def receipt(payment:, invoice:, user:)
    @payment        = payment
    @invoice        = invoice
    @user           = user
    @payment_amount = payment.total_amount.to_f / 100.0

    mail(
      to: @user.email,
      subject: "Payment received — thanks, #{@user.first_name}! 🌱",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
```

   Note `payment.total_amount` is an **integer column in cents** — hence the `/ 100.0`. This matches `short_payment_alert` directly above it.

2. Create `app/views/payment_mailer/receipt.html.erb`. Match the inline-style conventions of the existing mailer templates (brand green `#1f4632`, yellow `#FBB718` buttons, `Arial, sans-serif`). Use this copy **verbatim** — it is written in the brand's established voice and must not be re-composed:

```erb
<div style="font-family: Arial, sans-serif; color: #1f4632; padding: 2rem;">
  <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 0.5rem;">Payment received 🌱</h1>

  <p style="font-size: 1.1rem; margin-top: 1rem;">Hi <%= @user.first_name %>,</p>

  <p style="font-size: 1.1rem;">
    Thanks — we've received your payment of
    <strong>R<%= number_with_precision(@payment_amount, precision: 2) %></strong>.
    Consider this your receipt.
  </p>

  <table style="width: 100%; border-collapse: collapse; margin: 1.5rem 0; font-size: 1rem;">
    <tr>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0;">Invoice</td>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0; text-align: right;">
        #<%= @invoice.number || @invoice.id %>
      </td>
    </tr>
    <tr>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0;">Amount paid</td>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0; text-align: right;">
        R<%= number_with_precision(@payment_amount, precision: 2) %>
      </td>
    </tr>
    <tr>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0;">Date</td>
      <td style="padding: 0.5rem 0; border-bottom: 1px solid #e0e0e0; text-align: right;">
        <%= @payment.date&.strftime("%-d %B %Y") %>
      </td>
    </tr>
  </table>

  <p style="margin: 2rem 0;">
    <a href="<%= invoice_url(@invoice) %>"
       style="background-color: #FBB718; color: white; padding: 10px 20px; border-radius: 40px; text-decoration: none; font-weight: bold;">
      View Invoice
    </a>
  </p>

  <p style="font-size: 1.1rem;">
    Thanks for gooiing with us — every bucket you fill is one that doesn't go to landfill.
  </p>

  <p style="font-size: 1.1rem;">
    Anything look wrong?
    <a href="https://wa.me/27785325513" style="color: #1f4632; font-weight: bold; text-decoration: underline;">WhatsApp Alfred</a>
    and he'll sort it out.
  </p>
</div>
```

3. Create `app/views/payment_mailer/receipt.text.erb` — the same content as plain text. Follow the structure of an existing `.text.erb` mailer view in this codebase.

4. In `app/controllers/invoices_controller.rb`, in the `paid` action: **after** the `ActiveRecord::Base.transaction do ... end` block closes and **before** the `flash[:notice]` line, send the receipt. It must be **outside** the transaction — an email failure must never roll back a recorded payment — and it must be individually rescued so that a mailer problem cannot break the founder's workflow:

```ruby
    begin
      PaymentMailer.receipt(payment: payment, invoice: @invoice, user: user).deliver_now
    rescue StandardError => e
      Rails.logger.error("[InvoicesController#paid] receipt email failed: #{e.class} — #{e.message}")
    end
```

   ⚠️ **You must hoist the `payment` variable out of the transaction block** so it is in scope afterwards. Declare `payment = nil` before the `ActiveRecord::Base.transaction do` line and change `Payment.create!(...)` to `payment = Payment.create!(...)`. Read the action carefully before editing — do not change any other line in it, and **do not alter the invoice, the payment amounts, or the subscription-activation logic.**

5. Create `test/mailers/payment_mailer_test.rb` asserting that `receipt`:
   - is addressed to the customer's email
   - is from `howzit@gooi.me`
   - contains the correctly formatted rand amount (i.e. that the cents-to-rand division happened — assert the body contains `R100.00` for a payment with `total_amount: 10_000`)

6. **Do not** send a receipt from the SnapScan webhook path. That path already sends `payment_received` via `activate_subscription`, and duplicating it would email the customer twice. This task covers **only** the manual `#paid` action.

**Verification:**
```bash
bin/rails test test/mailers/payment_mailer_test.rb
bin/rails test
```
Expected: **0 failures, 0 errors.**

Manual: in the admin UI, mark a test invoice paid. Confirm exactly **one** receipt email is generated (check `letter_opener` or the logs), that the amount shown is in **rands, not cents** (a R100 payment must read `R100.00`, never `R10000.00`), and that the payment was still recorded correctly.

**Stop condition:**
If hoisting the `payment` variable out of the transaction requires restructuring the `paid` action beyond that one change, **stop and report.** That action records money; it is not a place to improvise. Likewise, if you find the customer would receive **two** emails for a single payment, stop and report rather than adding a suppression flag.

**Commit message:**
```
Send the customer a receipt when an invoice is marked paid

InvoicesController#paid — the action the founder clicks for every EFT and
cash payment — recorded the payment and told the customer nothing. The
existing payment_received email only fires for a first payment on a
pending subscription, so renewals, monthly billing and bag orders were
silent. "Did you get my payment?" was landing in the founder's WhatsApp.

The mail is sent outside the transaction and individually rescued, so a
mailer failure can never roll back or block a recorded payment.

this one is all claude
```

---

### [F2-PROMPT] `PENDING APPROVAL` — Suburb waitlist launch announcement

**Type:** feature | **Risk:** low | **Scope:** medium
**Approval required from:** founder. See `FEATURES.md` → F2 (recommended: **greenlight**).

**Files:**
- Create: `db/migrate/<timestamp>_add_announced_at_to_interests.rb`
- Read + modify: `app/models/interest.rb`
- Read + modify: `app/mailers/interest_mailer.rb`
- Create: `app/views/interest_mailer/suburb_launched.html.erb`
- Create: `app/views/interest_mailer/suburb_launched.text.erb`
- Read + modify: `app/controllers/admin/interests_controller.rb`
- Read + modify: `app/views/admin/interests/index.html.erb`
- Read + modify: `config/routes.rb`
- Create: `test/models/interest_test.rb` additions (the file exists — **add** to it, do not replace it)

**Context:**
The `Interest` model captures name + email + suburb from people in **52 Cape Town suburbs Gooi does not yet serve**. `InterestMailer` already notifies the founder and confirms to the customer. There is an admin index at `/admin/interests`. **And then nothing ever happens with the list.**

`Subscription::FUTURE_SUBURBS` shows expansion is actively planned (Noordhoek, Milnerton, Tableview, Glencairn). When Gooi launches a new route, the first marketing action should be one click against a warm list of people who explicitly asked to be customers — not a manual mail-merge, and certainly not forgetting the list exists.

Grouping the index by suburb is also, on its own, a **demand map** telling the founder where to expand next. That view does not exist today.

**Task:**

1. Migration — add a nullable timestamp so nobody is announced to twice:
```ruby
class AddAnnouncedAtToInterests < ActiveRecord::Migration[7.1]
  def change
    add_column :interests, :announced_at, :datetime
    add_index  :interests, :suburb
  end
end
```
   Run `bin/rails db:migrate` and commit the resulting `db/schema.rb`.

2. In `app/models/interest.rb`, add:
```ruby
  scope :unannounced, -> { where(announced_at: nil) }
  scope :in_suburb,   ->(suburb) { where(suburb: suburb) }

  def announced?
    announced_at.present?
  end
```
   **Do not touch** the existing validations or the `after_create_commit :notify!` callback.

3. Add `suburb_launched` to `app/mailers/interest_mailer.rb`, matching the existing methods' style:
```ruby
  def suburb_launched
    @interest = params[:interest]

    mail(
      to: @interest.email,
      subject: "Good news — Gooi is now collecting in #{@interest.suburb}! 🌱",
      track_opens: 'true',
      message_stream: 'outbound'
    )
  end
```

4. Create the HTML and text templates. Use this copy **verbatim** (brand voice; do not re-compose). Match the inline-style conventions of the existing mailer templates:

```erb
<div style="font-family: Arial, sans-serif; color: #1f4632; padding: 2rem;">
  <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 0.5rem;">We're in <%= @interest.suburb %>! 🌱</h1>

  <p style="font-size: 1.1rem; margin-top: 1rem;">Hi <%= @interest.name %>,</p>

  <p style="font-size: 1.1rem;">
    A while back you told us you wanted Gooi in <strong><%= @interest.suburb %></strong>.
    We've been working on it — and we're finally collecting there.
  </p>

  <p style="font-size: 1.1rem;">
    Here's how it works: we drop off a bin, you fill it with your kitchen scraps,
    and every week Alfred collects it and takes it to a local farm to be composted.
    No landfill, no fuss.
  </p>

  <p style="margin: 2rem 0;">
    <a href="<%= root_url %>"
       style="background-color: #FBB718; color: white; padding: 10px 20px; border-radius: 40px; text-decoration: none; font-weight: bold;">
      Start gooiing
    </a>
  </p>

  <p style="font-size: 1.1rem;">
    Thanks for putting your hand up early — it genuinely helped us decide where to go next.
  </p>

  <p style="font-size: 0.85rem; color: #888; margin-top: 2.5rem;">
    You're receiving this because you registered interest in Gooi collecting in your suburb.
    <a href="mailto:howzit@gooi.me?subject=Unsubscribe" style="color: #888;">Unsubscribe</a>
  </p>
</div>
```

   ⚠️ **The unsubscribe line is not optional.** This is a bulk mail to people who opted in months or years ago; POPIA expects an opt-out on direct marketing. Keep it.

5. In `app/controllers/admin/interests_controller.rb`:
   - in `index`, build `@interests_by_suburb = Interest.unannounced.group(:suburb).count.sort_by { |_suburb, count| -count }.to_h` — this is the demand map, ordered by demand
   - add an `announce_suburb` action. It must:
     - read `params[:suburb]`
     - **validate that the suburb is a member of `Interest::SUBURBS`** before doing anything (never interpolate a raw param into a query — and see the standing header's note on enum/param sanitisation)
     - find `Interest.unannounced.in_suburb(suburb)`
     - send `InterestMailer.with(interest: interest).suburb_launched.deliver_now` to each — **`deliver_now`, not `deliver_later`**: there is no worker dyno in production (see `docs/BACKGROUND_JOBS.md`), so `deliver_later` would silently send nothing
     - set `announced_at: Time.current` on each **only after its mail is successfully sent**, so a mid-run failure does not mark unsent people as announced
     - rescue per-recipient, log failures, and continue — one bad email address must not abort the run
     - redirect back to the index with a notice stating exactly how many were sent and how many failed

6. Route it, inside the existing `namespace :admin` block, on the `interests` resource:
```ruby
    resources :interests, only: [:index, :show, :edit, :update, :destroy] do
      collection do
        post :announce_suburb
      end
    end
```

7. In `app/views/admin/interests/index.html.erb`, add a section listing each suburb with its unannounced count, and next to each a control that POSTs to `announce_suburb_admin_interests_path(suburb: suburb)`.

   ⚠️ **This sends real email to real people and cannot be undone.** It must require an explicit confirmation. Use `link_to` with `data: { turbo_method: :post, turbo_confirm: "Send the launch announcement to all N people who registered interest in <suburb>? This cannot be undone." }` — **not** `button_to`, and never a `button_to` nested inside a form (see the standing header). Interpolate the real count and suburb into the confirm text.

   Follow the existing markup conventions of the file. **No inline `style="..."` attributes** — put any new styles in a SCSS partial under `app/assets/stylesheets/components/` and import it in `_index.scss`.

8. Add tests to the existing `test/models/interest_test.rb` (**append**, do not replace) covering the `unannounced` and `in_suburb` scopes and the `announced?` predicate.

**Verification:**
```bash
bin/rails db:migrate
bin/rails test
```
Expected: **0 failures, 0 errors.**

Manual, in development with `letter_opener`:
- Create two `Interest` records in the same suburb and one in a different suburb.
- Load `/admin/interests`. Confirm the suburb counts are correct and ordered by demand.
- Click announce on the first suburb; confirm the dialog appears with the right count.
- Confirm **exactly two** emails are generated, both for the right suburb.
- Confirm all three records: the two announced now have `announced_at` set; the third is still `nil`.
- Click announce on the same suburb **again**. Confirm **zero** emails are sent — the `unannounced` scope must now exclude them. **This idempotency check is the important one.**

**Stop condition:**
If the announce action would send to an interest **whose `announced_at` is already set**, stop and fix the scope before going further — double-emailing a warm list is a real reputational cost and is exactly what the column exists to prevent.

If you cannot make the send loop mark `announced_at` **only after a successful send**, stop and report rather than marking them all upfront. Marking someone announced who never received the mail permanently drops them from the list.

**Commit message:**
```
Add suburb launch announcements for the interest waitlist

The Interest model has been collecting name/email/suburb across 52
unserved suburbs, with an admin index — and no way to ever act on it. The
list was being collected and buried, while FUTURE_SUBURBS shows expansion
is actively planned.

Adds a demand map (unannounced interests grouped by suburb, ordered by
count) and a one-click announcement per suburb. announced_at makes it
idempotent so nobody is emailed twice; sends are deliver_now (no worker
dyno in production) and mark announced_at only on success, so a failed
send doesn't silently drop someone from the list. Carries an unsubscribe
link.

this one is all claude
```

---

### [F3-PROMPT] `PENDING APPROVAL` — Customer cancellation request (option b)

**Type:** feature | **Risk:** medium | **Scope:** medium
**Approval required from:** founder. **This one needs a product decision *before* the prompt is valid.** See `FEATURES.md` → F3.

> ⚠️ **This prompt implements option (b): request-to-cancel.** The customer submits a cancellation request with a reason; it alerts the founder, who closes the loop personally. It **does not** cancel anything automatically, does not touch the subscription status enum, and does not touch any billing code.
>
> **If the founder chooses option (a) — full self-service, immediate cancellation — this prompt is WRONG and must not be executed.** That option needs a status-enum migration and interacts with billing, and should be written in a session with a human.
>
> Do not execute this until the founder has explicitly chosen option (b).

**Files:**
- Create: `db/migrate/<timestamp>_create_cancellation_requests.rb`
- Create: `app/models/cancellation_request.rb`
- Read + modify: `app/models/subscription.rb` (add **one** `has_many` association — nothing else)
- Read + modify: `app/controllers/subscriptions_controller.rb`
- Read + modify: `app/mailers/subscription_mailer.rb`
- Create: `app/views/subscription_mailer/cancellation_requested.html.erb`
- Create: `app/views/subscription_mailer/cancellation_requested_alert.html.erb`
- Read + modify: `app/views/customers/manage.html.erb`
- Read + modify: `config/routes.rb`
- Create: `app/assets/stylesheets/components/_cancellation.scss`
- Read + modify: `app/assets/stylesheets/components/_index.scss`
- Create: `test/models/cancellation_request_test.rb`

**Context:**
There is **no cancellation flow anywhere in Gooi.** The `Subscription` status enum is `pending / active / pause / completed / legacy` — there is no `cancelled`. A customer who wants to leave either WhatsApps the founder, or simply stops paying and silently becomes a lapsed `completed` subscription.

That second path is what most people actually take, which means **Gooi never learns why anyone leaves.** There is a `ChurnCalculator` service that computes the churn *rate*, but nothing in the system captures a churn *reason*. That is the most valuable single data point a subscription business collects, and Gooi is collecting none of it.

This feature captures the reason and routes it to the founder, **without** mutating any subscription state. It touches no billing code and no status enum by design.

**Task:**

1. Migration:
```ruby
class CreateCancellationRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :cancellation_requests do |t|
      t.references :subscription, null: false, foreign_key: true
      t.integer  :reason,       null: false
      t.text     :note
      t.datetime :requested_at, null: false
      t.datetime :resolved_at
      t.string   :outcome

      t.timestamps
    end

    add_index :cancellation_requests, :resolved_at
  end
end
```

2. `app/models/cancellation_request.rb`:
```ruby
class CancellationRequest < ApplicationRecord
  belongs_to :subscription
  has_one :user, through: :subscription

  # Why customers leave. This is the whole point of the feature — ChurnCalculator
  # can already tell us the rate, but nothing captured the reason.
  enum :reason, %i[too_expensive moving_away not_enough_waste
                   service_issue composting_myself other]

  validates :requested_at, presence: true

  scope :open,     -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }

  def open?
    resolved_at.nil?
  end
end
```

3. In `app/models/subscription.rb`, add **only** this line among the other associations, and change nothing else in the file:
```ruby
  has_many :cancellation_requests, dependent: :destroy
```

4. Route it, as a member action on `subscriptions`:
```ruby
      post :request_cancellation
```

5. In `SubscriptionsController`, add a `request_cancellation` action. **It must be covered by the `authorize_subscription_owner_or_staff!` before_action added in P-03** — add `:request_cancellation` to that filter's `only:` list. The action must:
   - **sanitise the reason param before assigning it to the enum** — a raw param would raise `ArgumentError` at assignment (see the standing header):
     ```ruby
     reason = CancellationRequest.reasons.key?(params[:reason]) ? params[:reason] : "other"
     ```
   - create the `CancellationRequest` with `requested_at: Time.current`
   - send `cancellation_requested` to the customer and `cancellation_requested_alert` to `howzit@gooi.me`, both `deliver_now` (no worker dyno)
   - redirect to `manage_path` with a notice
   - **NOT change the subscription's status, `is_paused`, `end_date`, or anything else on the subscription.** Not one field. The founder closes the loop by hand — that is the entire design of option (b).

6. Add both mailer methods to `SubscriptionMailer`, following the existing `*_alert` pattern in that file (customer mail to `@subscription.user.email`; alert to `howzit@gooi.me`). Write the customer template to acknowledge the request warmly and say Alfred will be in touch — **do not** promise a refund, a specific timeline, or a specific outcome.

7. On `/manage` (`app/views/customers/manage.html.erb`), add a modest "Cancel my subscription" affordance — it should not be a primary button competing with the main actions. It opens a form with a reason `<select>` (populated from `CancellationRequest.reasons.keys`) and an optional note `<textarea>`, POSTing to the new route.

   **No inline styles** — put them in the new `_cancellation.scss` partial with BEM naming and import it in `_index.scss`. **No inline JS** — if the form needs to show/hide, use a Stimulus controller.

8. Write `test/models/cancellation_request_test.rb` covering the enum, the `open` / `resolved` scopes, and the `requested_at` presence validation.

**Verification:**
```bash
bin/rails db:migrate
bin/rails test
```
Expected: **0 failures, 0 errors.**

Manual: as a customer, submit a cancellation request from `/manage`. Then, **critically**, confirm in the Rails console that the subscription's `status`, `is_paused`, and `end_date` are **all completely unchanged**. Confirm a `CancellationRequest` row was created with the right reason, and that both emails were generated.

**Stop condition:**
**If you find yourself modifying the `Subscription` status enum, adding a `cancelled` status, or changing any subscription field in `request_cancellation` — stop immediately and revert.** That is option (a), a different feature, which the founder has not approved and which interacts with billing. This prompt creates a *record of a request* and nothing more.

**Commit message:**
```
Capture cancellation requests with a reason

Gooi had no cancellation flow: a customer who wanted to leave either
WhatsApp'd the founder or silently stopped paying. Most take the second
path, so Gooi never learned why anyone leaves — ChurnCalculator computes
the rate, but nothing captured the reason.

Adds a cancellation_requests table, a reason enum, a form on /manage, and
alerts to both the customer and the founder. Deliberately changes no
subscription state: the founder closes the loop personally, keeping the
save conversation while capturing the churn reason.

this one is all claude
```
