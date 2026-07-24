# Growth Features — Handover Notes

Context for another AI picking up work on Alfred's Gooi's B2B/growth surface: apartment
blocks & estates, the customer journey page, quotes/surveys, and the blocks landing page.
This is a snapshot of what's **already built** as of 2026-07-15 — read the actual files
before changing anything, this doc will drift.

## 1. Blocks (apartment buildings / estates)

`Block` (`app/models/block.rb`, table `blocks`) is the model for a multi-unit residential
building or estate that groups several `Subscription`s together. "Estate" is marketing
copy/UI language for the same concept — there is no separate `Estate` model.

- Columns: `name`, `slug` (unique, auto-generated from `name` on create, collision-safe),
  `description`, `resident_count`, `latitude`/`longitude`, `photos` (Active Storage,
  `has_many_attached`). `address` exists in the schema but is unused — address is derived
  from linked subscriptions.
- Associations: `has_many :subscriptions, dependent: :nullify`,
  `has_many :block_survey_responses, dependent: :destroy`,
  `has_many :quotations, dependent: :nullify`.
- `subscriptions.block_id` is a nullable FK — admin assigns/unassigns subs to a block manually
  (`Admin::BlocksController#assign_subscription` / `#remove_subscription`).
- Impact math lives on the model: `expected_weekly_volume_l`, `actual_volume_l` (and
  `_this_week_l`/`_last_week_l`/`_this_month_l`), `lifetime_volume_l`, `weight_kg`, `co2e_kg`,
  using constants `LITRES_PER_HOUSEHOLD = 5`, `DENSITY_KG_PER_L = 0.6`, `CO2E_PER_KG = 1.9`.
  `estimated_contributing_households` back-calculates participation from actual volume rather
  than contracted capacity.
- Class methods `Block.annual_kg_per_household` / `Block.annual_co2e_per_household` power
  "what one household contributes" messaging on the survey page.

**Admin CRUD**: `Admin::BlocksController` (`/admin/blocks`) — standard CRUD plus
`assign_subscription`, `remove_subscription`, `send_pitch` (emails a chosen quotation, the
estate sales deck link, and the block's survey link via `BlockSurveyMailer.pitch`).

## 2. Block resident survey

`BlockSurveyResponse` (table `block_survey_responses`) — a per-resident survey scoped to one
block, **not** a general prospect-intake survey.

- Columns: `block_id` (FK, required), `has_compost_bin`, `wants_to_buy_bin`,
  `wants_phase_one` (all booleans, must be explicitly true/false), `respondent_name`,
  `unit_number`.
- `Block` exposes aggregate counters: `survey_response_count`, `survey_wants_phase_one_count`,
  `survey_wants_bin_count`, `survey_has_bin_count`.
- Public controller: `BlockSurveysController` — `show` (form), `create`, `thanks`.
- Routes: `resources :blocks, only: [:show], param: :slug` nests
  `resource :survey, only: [:show, :create]` plus `GET survey/thanks`.

**Important gap**: survey answers do not feed any pricing/quote logic. A `Block` has both
`block_survey_responses` and `quotations`, but they're only linked manually — an admin reads
survey results, then builds a `Quotation` by hand and picks it in `send_pitch`. If asked to
"auto-generate a quote from survey answers," that's new work, not wiring up something existing.

## 3. Quotation (the "quote" model — there is no `Quote` or `Survey`-for-pricing model)

`Quotation` (`app/models/quotation.rb`, table `quotations`) covers both prospect quotes and
one-off event quotes.

- Columns: `user_id` (optional — nil for prospects), `subscription_id` (optional, per code
  comment this reverse link is unused), `block_id` (optional), `prospect_name/email/phone/company`,
  `notes`, `number` (from Postgres sequence `quotation_number_seq`), `created_date`,
  `expires_at`, `status` enum (`draft/sent/accepted/rejected/expired`), `total_amount`,
  `duration_months` (default 6), `quote_type` enum (`subscription`/`event`, default
  `subscription`), `event_date/name/venue`, `collections_per_week` (default 1),
  `buckets_per_collection`.
- `has_many :quotation_items, dependent: :destroy`, `has_many :products, through: :quotation_items`,
  `accepts_nested_attributes_for :quotation_items`.
- Validation `has_customer_or_prospect_details` requires `user_id` OR `prospect_name` — a quote
  always has *someone* to send to, customer or prospect.
- `calculate_total` sums `quotation_items.amount * quantity` (line items are denormalized from
  `product.price` at creation, so later price changes don't retroactively alter old quotes).
- Pricing derivation helpers: `weekly_rate`/`monthly_rate`, `ongoing_weekly_rate`/
  `ongoing_monthly_rate` (strip one-time costs — line items whose product title matches
  "Starter" or "bulk purchase"), `effective_collections_per_week` (infers from a "Weekly
  collection" line item if the field is still default), `inferred_waste_stream`/`protein?`
  and `inferred_bucket_size` (infer from product titles containing "protein" / "25L"/"45L").
  **These are all string-matching against product titles** — fragile if product names change.
- `created_subscription` = `Subscription.find_by(quotation_id: id)` — this is the actual link
  from an accepted quote to the resulting subscription (`subscriptions.quotation_id` FK).
- `billable_items` feeds `InvoiceBuilder` when converting an accepted quote into billing.

**Public controller** `QuotationsController` — `show` (no auth), `accept` (customer accepts →
status `accepted`, `QuotationMailer.accepted`), `pdf` (via `QuotationPdfGenerator`).
**Admin controller** `Admin::QuotationsController` — CRUD plus `send_email` (draft→sent,
`QuotationMailer.quotation_created`) and `extend_expiry` (+30 days, blocked once
accepted/rejected).

## 4. Customer journey page — not a funnel tracker

`JourneyController#show` (route `GET journey/:token`) is a **public, token-authenticated
impact/stats page for an existing paying customer**, not a signup→survey→quote→subscription
lifecycle tracker despite the name. Don't build stage-tracking logic on top of it assuming
that's what it already does.

- `User.journey_token` (unique, auto-generated on create) is the auth mechanism — no login
  required, just knowledge of the token (linked from `Admin::UsersController#show` as
  "🌱 Journey page").
- Computed stats: lifetime litres/kg/CO2e, total collections, `journey_consistency_rate`
  (a more accurate variant of `User#consistency_rate` that correctly handles multi-collection-
  per-week commercial accounts), CO2e-to-car-km equivalent, months active since first
  subscription, total paid (via `Invoice`), cost-per-collection.
- View: `app/views/journey/show.html.erb`, custom layout `layouts/journey.html.erb`.

## 5. Blocks/estates marketing surface (two separate public pages)

- **Per-block landing page**: `BlocksController#show`, route `GET /blocks/:slug`. A specific
  building's public page (intended for a QR code on a poster in the building) — hero with block
  photos, name, description, collection days, this/last-week volume vs. expected volume, links
  into the resident survey.
- **Generic estate sales deck**: `EstateDecksController#show`, route `GET estate-deck` (named
  `estate_deck`). Not block-specific — an inline-SVG slideshow (Stimulus controller
  `estate-deck`) pitching kitchen-scrap collection to apartment blocks/estates as prospective
  B2B customers (problem framing, 2025 diversion stats, etc.). This is the deck URL
  (`estate_deck_url`) embedded in `BlockSurveyMailer.pitch`.

**Outbound sales flow, end to end**: admin creates/edits a `Block` → residents fill in the
survey (or admin manually links a `Quotation`) → admin opens the block in `/admin/blocks`,
picks a quotation, hits `send_pitch` → email goes out containing the generic estate deck link,
the quotation (view/PDF), and the block's own survey link → prospect can `accept` the quotation
publicly → `Subscription.quotation_id` links the resulting subscription back to the quote.

There is no blocks/estates content on the main marketing homepage
(`app/views/pages/home.html.erb`) — this whole growth surface lives outside it, in
`estate_decks` and per-block `blocks/show`.

## Known gaps / things that look built but aren't

- No service converts `BlockSurveyResponse` answers into a `Quotation` — quotes are built by
  hand via `quotation_items_attributes` in the admin form.
- `Quotation#subscription_id` is present in schema but explicitly noted as an unused reverse
  link — the real link back to a subscription is `Subscription.quotation_id`, not this field.
- Waste-stream/bucket-size/collections-per-week inference on `Quotation` is done by scanning
  product **titles** for substrings ("protein", "25L", "Starter", etc.) — renaming a `Product`
  will silently break these inferences.
