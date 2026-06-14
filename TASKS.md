# Gooi Task List
_Last assessed: 2026-06-14_

## Database & Model Health

### 🔴 High Priority
<!-- Issues causing performance problems or data integrity risks right now -->

**[TASK-001] Add index on `collections.date`**
- What: Add a DB index on `collections.date`.
- Why: `date` is used in WHERE/ORDER clauses on nearly every driver-facing page (`where(date: Date.today)`, `where("date >= ?", ...)`, `order(date: :desc)`) — every page load fires a seq-scan on a table that grows by ~100 rows/week.
- Where: New migration; `db/schema.rb:218`
- Effort: XS
- Status: done

---

**[TASK-002] Add index on `drivers_days.date`**
- What: Add a DB index on `drivers_days.date`.
- Why: `DriversDay.find_or_create_by(date: today)` and date-range queries are called on every collection day start, route load, and snapshot view with no index to support them.
- Where: New migration; `db/schema.rb:300`
- Effort: XS
- Status: done

---

**[TASK-003] Add index on `subscriptions.status`**
- What: Add a DB index on `subscriptions.status`.
- Why: `.where(status: :active)`, `.where(status: :pending)`, etc. appear in almost every admin and driver view; without an index every query scans the full subscriptions table.
- Where: New migration; `db/schema.rb:781`
- Effort: XS
- Status: done

---

**[TASK-004] Add index on `subscriptions.collection_day`**
- What: Add a DB index on `subscriptions.collection_day`.
- Why: Route-planning queries filter by `collection_day` every single weekday (`where(collection_day: @today, status: 'active')`); both columns are used together and a composite index on `[status, collection_day]` would be most efficient.
- Where: New migration; `db/schema.rb:768`, also used at `subscriptions_controller.rb:481` and `drivers_days_controller.rb:98`
- Effort: XS
- Status: done

---

**[TASK-005] Add index on `users.referral_code`**
- What: Add a DB index on `users.referral_code` (uniqueness already validated; just needs the index).
- Why: `User.find_by(referral_code: ...)` is called in the hot payment path (`activate_subscription`, `create_referral_from_code`) with no index — this does a full-table scan on users.
- Where: New migration; `db/schema.rb:835`, `subscription.rb:472,500`
- Effort: XS
- Status: done

---

**[TASK-006] Add uniqueness constraint and index on `discount_codes.code`**
- What: Add a unique DB index on `discount_codes.code` and a `validates :code, uniqueness: true` in the model.
- Why: `DiscountCode.find_by(code: ...)` has no index, and duplicate codes are allowed at the DB level — a duplicate could silently apply the wrong discount.
- Where: New migration; `discount_code.rb:1`, `db/schema.rb:280`
- Effort: XS
- Status: done

---

**[TASK-007] Fix `Subscription.paused` scope — enum value mismatch**
- What: Change `scope :paused, -> { where(status: :paused) }` to `where(status: :pause)` to match the declared enum value.
- Why: The enum at `subscription.rb:63` declares `:pause` (not `:paused`); Rails raises `ArgumentError` when an unknown enum value is passed to `where`, so every caller of `Subscription.paused` will 500 in production.
- Where: `app/models/subscription.rb:56`
- Effort: XS
- Status: done

---

**[TASK-008] Fix model/DB mismatch: `DropOffEvent` optional drivers_day**
- What: Remove `optional: true` from `belongs_to :drivers_day` in `DropOffEvent`.
- Why: `drop_off_events.drivers_day_id` is `null: false` in the DB schema, but the model marks it optional — Rails validations will pass on a nil drivers_day and then the DB will raise a NOT NULL violation, giving an unintelligible 500 instead of a validation error.
- Where: `app/models/drop_off_event.rb:3`, `db/schema.rb:318`
- Effort: XS
- Status: done

---

**[TASK-009] Fix model/DB mismatch: `WhatsappMessage` optional user**
- What: Remove `optional: true` from `belongs_to :user` in `WhatsappMessage` (or add `null: true` to the DB column if optional is genuinely needed).
- Why: `whatsapp_messages.user_id` is `null: false` in the schema but the model marks it optional — same class of mismatch as TASK-008.
- Where: `app/models/whatsapp_message.rb:2`, `db/schema.rb:851`
- Effort: XS
- Status: done

---

**[TASK-010] Fix N+1 in `Admin::LogisticsController#index`**
- What: Replace the per-DriversDay `d.collections.where(skip: false).sum { ... }` Ruby block with a single SQL aggregate query before the map loop.
- Why: For every DriversDay (could be hundreds of rows), a separate SELECT is fired to compute litres — this is a textbook N+1 that will degrade linearly as the history grows.
- Where: `app/controllers/admin/logistics_controller.rb:22-29`
- Effort: S
- Status: done

---

**[TASK-011] Eliminate duplicated `customer_map_data` between LogisticsController and CollectionsController**
- What: Extract the shared `customer_map_data` action and `calculate_marker_size` helper into a concern or the `Subscription` model, and remove the duplicate in `Admin::CollectionsController`.
- Why: Both controllers contain identical 50-line methods with inner N+1 loops (`sub.collections.where(...)` inside `.map`) — the duplication means bugs will be fixed in only one place, and the N+1 fires once per active subscription.
- Where: `app/controllers/admin/logistics_controller.rb:76-130`, `app/controllers/admin/collections_controller.rb:53-135`
- Effort: M
- Status: done

---

**[TASK-012] Restore `Invoice` presence validations**
- What: Uncomment and re-enable `validates :issued_date, :due_date, :total_amount, presence: true` in `Invoice`.
- Why: The validations are entirely commented out (line 14), meaning invoices can be saved with `nil` dates and no total — this causes nil errors downstream in PDF generation and payment flow.
- Where: `app/models/invoice.rb:14`
- Effort: S (need to audit whether any existing code creates invoices without these fields first)
- Status: proposed

---

**[TASK-013] Replace Ruby-sort customer_id generation with a SQL query**
- What: In `User#set_customer_id`, replace `customers.sort_by { |c| c.customer_id[4..].to_i }.last` with `User.where.not(customer_id: nil).maximum("CAST(SUBSTRING(customer_id FROM 5) AS INTEGER)")`.
- Why: The current code loads every user with a customer_id into Ruby and sorts them — O(n) on a table that grows every signup, and vulnerable to race conditions.
- Where: `app/models/user.rb:274-278`
- Effort: XS
- Status: proposed

---

### 🟡 Medium Priority
<!-- Refactoring and improvements that will matter as the app scales -->

**[TASK-014] Add index on `invoices.paid`**
- What: Add a DB index on `invoices.paid`.
- Why: `where(invoices: { paid: false })` appears in the pending users view, nudge logic, and revenue calculations — no index means a seq-scan on an ever-growing table.
- Where: New migration; `db/schema.rb:492`
- Effort: XS
- Status: proposed

---

**[TASK-015] Add index on `collections.skip`**
- What: Add a DB index on `collections.skip`.
- Why: `where(skip: false)` is the most common collection filter in the app (route views, stats, impact calculations) and currently has no index.
- Where: New migration; `db/schema.rb:205`
- Effort: XS
- Status: proposed

---

**[TASK-016] Add uniqueness DB constraint on `referrals [referee_id, referrer_id]`**
- What: Add a unique composite index on `[referee_id, referrer_id]` in the referrals table and a corresponding model validation.
- Why: Without it, multiple referral records can be created for the same pair (e.g., on renewal), and a referee could accumulate multiple discounts.
- Where: New migration; `db/schema.rb:612`, `app/models/referral.rb`
- Effort: S
- Status: proposed

---

**[TASK-017] Guard `Invoice#set_number` and `Quotation#set_number` against race conditions**
- What: Replace the `ORDER BY created_at DESC LIMIT 1` + 1 pattern with a DB sequence (`CREATE SEQUENCE invoice_number_seq`) or an advisory lock.
- Why: Two simultaneous invoice creates will both read the same "last number" and assign duplicates — likely to happen during busy payment periods.
- Where: `app/models/invoice.rb:24-32`, `app/models/quotation.rb:39-47`
- Effort: M
- Status: proposed

---

**[TASK-018] Move `calculate_marker_size` to `Subscription` model**
- What: Add a `marker_size(avg_bags:, avg_buckets:)` instance method to `Subscription` and remove the private helper from both controllers.
- Why: This is pure domain logic (plan-based size thresholds) living in two controller files — it belongs with the model that owns the `plan` attribute.
- Where: `app/controllers/admin/logistics_controller.rb:140-159`, `app/controllers/admin/collections_controller.rb:115-134`
- Effort: S
- Status: proposed

---

**[TASK-019] Extract `new_customer_count_for` to a service or model scope**
- What: Move `new_customer_count_for(collections)` from `DriversDaysController` private methods to `DriversDay` or a dedicated query object.
- Why: It's business logic (counts users with exactly 1 lifetime collection), currently only accessible from within this one controller, and duplicated across `show`, `complete`, and `snapshot` actions.
- Where: `app/controllers/drivers_days_controller.rb:391-400`
- Effort: S
- Status: proposed

---

**[TASK-020] Fix `Collection belongs_to :subscription` mismatch with DB constraint**
- What: Remove `optional: true` from `belongs_to :subscription` in `Collection`, or add a DB migration to make `subscription_id` nullable if truly optional.
- Why: The DB has `subscription_id null: false` but the model says `optional: true` — Rails skips the presence validation, so only the DB raises an error (as a cryptic constraint violation rather than a model validation failure).
- Where: `app/models/collection.rb:2`, `db/schema.rb:200`
- Effort: XS
- Status: proposed

---

**[TASK-021] Add `Collection` scopes for common filters**
- What: Add `scope :active, -> { where(skip: false) }`, `scope :for_date, ->(date) { where(date: date) }`, and `scope :completed, -> { where(is_done: true) }` to `Collection`.
- Why: `where(skip: false)` and `where(date: ...)` appear 20+ times across controllers and models as raw SQL strings — named scopes make intent clear and allow chaining.
- Where: `app/models/collection.rb:7`
- Effort: XS
- Status: proposed

---

**[TASK-022] Add `Invoice` scopes for `paid` and `unpaid`**
- What: Add `scope :paid, -> { where(paid: true) }` and `scope :unpaid, -> { where(paid: false) }` to `Invoice`.
- Why: `where(invoices: { paid: false })` appears in at least 5 different controller/query contexts with no named abstraction.
- Where: `app/models/invoice.rb`
- Effort: XS
- Status: proposed

---

**[TASK-023] Replace `Block#collection_days` Ruby map with a pluck query**
- What: Change `active_subscriptions.map(&:collection_day).uniq.compact` to `active_subscriptions.distinct.pluck(:collection_day).compact`.
- Why: The current code loads all subscription ActiveRecord objects into Ruby to extract one column — `pluck` keeps the query in SQL.
- Where: `app/models/block.rb:53`
- Effort: XS
- Status: proposed

---

**[TASK-024] Rewrite `User#current_streak` to avoid loading all collections**
- What: Refactor `current_streak` to use a SQL window function or a bounded query (e.g., fetch only the most recent 52 non-skipped collections) rather than loading every past collection.
- Why: The current implementation calls `collections.where('date <= ?', Date.today).order(date: :desc)` with no limit, loading the full history into Ruby — slow for long-time customers.
- Where: `app/models/user.rb:121-153`
- Effort: S
- Status: proposed

---

**[TASK-025] Remove dead `notify_skip_marked` method from `Collection`**
- What: Delete the `notify_skip_marked(user)` private method (lines 88-95).
- Why: There is no callback, caller, or reference to this method anywhere in the codebase — it was replaced by `mark_skipped!` but never deleted.
- Where: `app/models/collection.rb:88-95`
- Effort: XS
- Status: proposed

---

**[TASK-026] Add index on `collections.position` for per-drivers_day ordering**
- What: Add a DB index on `[drivers_day_id, position]` (composite).
- Why: `order(position: :asc)` within a drivers_day scope is used on every route view; the existing index on `drivers_day_id` alone doesn't cover the sort.
- Where: New migration; `db/schema.rb:218`
- Effort: XS
- Status: proposed

---

**[TASK-027] Add model associations for `subscription_product_id`, `monthly_collection_product_id`, `volume_processing_product_id`**
- What: Either add `belongs_to :subscription_product, class_name: 'Product', optional: true` (and siblings) to `Subscription`, or remove these columns if the feature was abandoned.
- Why: Three integer columns on `subscriptions` reference `products` with no FK constraint, no association, and no usage in the codebase — they're either orphaned feature stubs or should be properly wired up.
- Where: `db/schema.rb:793-795`, `app/models/subscription.rb`
- Effort: S
- Status: proposed

---

### 🟢 Low Priority / Nice to Have
<!-- Hygiene, best practices, future-proofing -->

**[TASK-028] Add `Payment` model validations**
- What: Add `validates :total_amount, presence: true, numericality: { greater_than: 0 }` and `validates :user, presence: true` to `Payment`.
- Why: `Payment` has zero validations — any amount (including negative or nil) can be persisted, and the `user` association is required by the DB but not validated at the Rails layer.
- Where: `app/models/payment.rb`
- Effort: XS
- Status: proposed

---

**[TASK-029] Replace `puts` calls in models with `Rails.logger`**
- What: Replace all `puts` calls in `Subscription` (lines 86, 254, 562, 572, etc.) and `User` (lines 303, 306) with `Rails.logger.debug` or `Rails.logger.warn`.
- Why: `puts` outputs to stdout (visible in dev logs but silent on Heroku unless log drains are configured), is stripped in production, and signals unfinished debugging rather than intentional observability.
- Where: `app/models/subscription.rb:86,254,562,572,578,584,589`, `app/models/user.rb:303,306`
- Effort: XS
- Status: proposed

---

**[TASK-030] Triage and document `collections.wants_veggies` and `collections.soil_bag`**
- What: Determine if `wants_veggies` and `soil_bag` are active features; if not, add a migration to drop them (or document what feature they belong to).
- Why: Both columns exist only in CSV import code and are never set or read through any UI — they look like stubs that were never built out, and they add noise to the schema.
- Where: `db/schema.rb:211-212`, `app/controllers/collections_controller.rb:319`
- Effort: XS
- Status: proposed

---

**[TASK-031] Remove dead code in `Subscription` model**
- What: Delete `set_suburb`, `determine_starter_kit_title`, and `determine_subscription_title` private methods.
- Why: `set_suburb` is commented out of the callback list; the other two have no callers anywhere in the codebase — they're legacy from before `InvoiceBuilder` was introduced.
- Where: `app/models/subscription.rb:554-611`
- Effort: XS
- Status: proposed

---

**[TASK-032] Rename `subscriptions.ending_soon_emailed_at` to be type-accurate**
- What: Either rename the column to `ending_soon_emailed_on` (it's a `date`, not a `datetime`) or migrate it to `datetime` to match the `_at` suffix convention Rails and the rest of the codebase uses.
- Why: The `_at` suffix conventionally means a timestamp column throughout Rails (and the rest of this schema); a `date` column with that suffix will confuse readers and tooling.
- Where: `db/schema.rb:790`
- Effort: XS
- Status: proposed

---

**[TASK-033] Add `DiscountCode` code uniqueness validation**
- What: Add `validates :code, presence: true, uniqueness: { case_sensitive: false }` to `DiscountCode`.
- Why: There is no model-level uniqueness guard — the DB index (TASK-006) will protect data integrity, but a model validation gives a friendly error rather than a DB exception.
- Where: `app/models/discount_code.rb`
- Effort: XS
- Status: proposed

---

**[TASK-034] Add `scope :active` and `scope :completed` to `DriversDay`**
- What: Add `scope :with_end_time, -> { where.not(end_time: nil) }` and `scope :this_year, ->(year) { where("EXTRACT(year FROM date) = ?", year) }` to `DriversDay`.
- Why: Several controllers use raw WHERE fragments against `drivers_days` (yearly_snapshot, financials); named scopes would centralise the logic.
- Where: `app/models/drivers_day.rb`, `app/controllers/drivers_days_controller.rb:277`
- Effort: XS
- Status: proposed

---
