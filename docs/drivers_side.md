# Driver's Side — Handoff Notes

Scope: the driver-facing workflow (route building, the day-of-collection run,
drop-offs, bucket weighing, and end-of-day stats). Written for a future AI
picking this up cold — read this before touching `DriversDay`, `Collection`,
`DropOffEvent`, or `Bucket`.

## The daily arc, model by model

`DriversDay` is the spine of a route day: one per (driver, date), created
lazily via `find_or_create_by!` from several entry points (`CreateCollectionsJob`,
the `start`/`route` controller actions). It owns:

- `has_many :collections` — pickups for that day
- `has_many :drop_off_events` — waste drop-offs at sites that day
- `has_many :buckets` — weighed bucket records for the day
- `has_one :day_statistic` — computed end-of-day stats (see below)

The driver's day has a linear real-world flow, and the controller actions
mirror it:

1. **`route`** (`DriversDaysController#route`) — builds `@route_items`, the
   collections and drop-off events merged and sorted by `position`. This is
   the planning/ordering view, editable via drag-drop → `reorder` (updates
   `position` on both collection and drop-off-event rows in one pass, then
   pushes the new order back onto `subscription.collection_order` so future
   auto-created collections inherit it).
2. **`start`** — the morning briefing. Sets `start_time` on first PATCH.
   Surfaces skips, bag requests, new customers, soil bag claims, and
   recently-lapsed customers who might still need a courtesy collection.
   Also piggybacks `RevenueRecognitionCatchUpJob` on Mondays — see the "no
   prod workers" note below, this is not a coincidence.
3. **`vamos`** — a second, similar briefing screen (legacy overlap with
   `start`; the two haven't been consolidated — don't assume one is dead
   without checking usage).
4. Driving the route: collections get marked done, bags/buckets recorded,
   customer notes taken. Drop-offs get `record_arrival` / `record_departure`
   (JSON endpoints used from the mobile UI to time-stamp each site visit) and
   `complete`.
5. **`end`** — sets `end_time` (defaults to "now", overridable if the tap was
   missed earlier). Runs `DriversDay#end_time_sensible` validation first (see
   sanity-checking below) before doing anything else. On success:
   `calculate_and_save_statistics!`, sends `DailySnapshotMailer`, and
   piggybacks three jobs (`CreateCollectionsJob`, `CreateNextWeekDropOffEventsJob`,
   `CheckSubscriptionsForCompletionJob`) each wrapped in its own rescue so one
   job failure can't 500 the end-of-day flow for the driver.
6. **`complete`** / **`show`** / **`snapshot`** — the stats dashboard, reading
   back `day_statistic`. `snapshot` is the public, no-auth version rendered in
   its own `snapshot` layout (for sharing a link, e.g. via the daily email).
7. **`weekly_snapshot`** / **`yearly_snapshot`** — roll-ups via `WeeklyStats`
   service and manual aggregation respectively. `yearly_snapshot` currently
   defaults to year 2025 if no `year` param is given — worth revisiting as
   time passes.

## Sanity-checking start/end times

`DriversDay#end_time_flag` (app/models/drivers_day.rb) exists because Alfred
(the driver) sometimes forgets to tap Start or End at the right moment. It
classifies a suspicious pairing into `:inverted`, `:too_short`, `:too_long`,
or `:different_day`, and `end_time_flag_field` tells the `end` view which
field to let him correct. The `end` action's `override_end_time_warning` flag
lets him force through a day that's genuinely unusual (e.g. a long one).
This logic is deliberately conservative — don't "fix" it by loosening the
thresholds (`MIN_ROUTE_MINUTES` / `MAX_ROUTE_HOURS`) without understanding
why they were chosen; they exist to catch a specific real failure mode, not
to enforce arbitrary business rules.

## Collections

`Collection` belongs to `Subscription` and optionally `DriversDay`. Key
things to know:

- **Always use `mark_skipped!`**, never `update(skip: true)` — it sends the
  skip-notification email and guards against double-sending (see CLAUDE.md
  critical note #1). `skip_silently!` is the deliberate exception, used by
  jobs pre-creating collections during a known pause/holiday.
- **Position sync**: `sync_drivers_day_with_date` runs automatically on date
  changes to *existing* collections, finding/creating the right `DriversDay`
  for the new date and appending the collection to the end of that day's
  route. New collections created by jobs assign `drivers_day` explicitly and
  skip this callback (see `needs_drivers_day_sync?`).
- **Action tokens** (`soil_bag_token`, `skip_token`): short random codes
  minted per-collection so a customer can act on a single collection from a
  WhatsApp link with no login. Each has its own column so a skip link and a
  soil-bag-claim link are independent and separately revocable. They expire
  naturally when the collection's date passes — no separate TTL column.
- **`volume_litres`** differs by plan: `Standard`/`once_off` estimate from
  `bags`; `XL`/Commercial use actual weighed bucket sizes
  (`buckets_25l`/`buckets_45l`) when present, falling back to a flat 25L ×
  `buckets` estimate otherwise.
- `new_customer` is a boolean flag on `Collection`, but per CLAUDE.md note
  #8, **never use it for reporting** — it gets cleared to `false` on every
  update. Use `DriversDay.new_customer_count_for(collections)` instead, which
  derives "new" from the customer having exactly one lifetime collection.

## Buckets and weighing

`Bucket` belongs to `DriversDay` (route-level, filled while driving) or a
`DropOffEvent` (site-level, filled during drop-off — see the nested
`drivers_days/:id/drop_off_events/:id/buckets` route using
`DropOffEvents::BucketsController`). The driver enters a **gross** scale
reading (`gross_kg`, a virtual attribute); `apply_tare` subtracts a
fixed tare weight per bucket size (25L: 0.90kg, 45L: 1.50kg) before save, so
`weight_kg` is always net. Both `DriversDay#recalc_totals!`/`Bucket#recalc_day_cache`
and `DropOffSite#recalc_totals!`/`DropOffEvent#recalc_site_totals` keep
cached total columns (`total_net_kg`, `total_buckets`) in sync via
`after_commit`/`after_update` callbacks — if you add a new way to
create/destroy a bucket, make sure one of these fires, or the cached totals
will silently drift from the real bucket rows.

`full_equivalent_count` / `avg_net_kg_per_full_equiv` normalize everything to
25L-equivalent buckets (a 45L bucket = 1.8 "full equivalents") — this is the
unit used for weekly/yearly stats reporting, not raw bucket count.

## Drop-offs

`DropOffEvent` belongs to a `DriversDay` and a `DropOffSite`, ordered via
`acts_as_list scope: :drivers_day` (shares the same position space as
collections on that day — the `route` view interleaves both by `position`).
Tracks `arrival_time`/`departure_time` for dwell-time analytics
(`DropOffSite#recalculate_average_duration`). `waste_stream` (`general` /
`protein`) is validated against the site's `accepts_protein?` — protein can
only go to a protein-capable site (currently just Langa's AgriHub BioBin).
`DropOffSite::DROP_OFF_ONLY_SUBURBS` (Langa, Philippi, Epping) extends the
collection-service `Subscription::SUBURBS` list — these are valid drop-off
locations even though Gooi doesn't run a collection round there.

## Route ordering and optimisation

Two competing optimiser services exist in `app/services/`:

- **`GeographicRouteOptimiser`** — nearest-neighbor sort using each
  subscription's lat/lng, starting from the business location (27 Hare
  Street, Mowbray). **This is the one actually wired up** —
  `CollectionsController#optimise_route` calls it directly.
- **`OsrmRouteOptimiser`** — calls the public OSRM Trip API to solve routing
  properly (splits the route into segments around fixed drop-off positions,
  optimises each collection segment, keeps drop-offs pinned). CLAUDE.md's
  "Important Services" section documents *this* one, but it does not appear
  to be called from the controller anymore.

**This is a live discrepancy worth flagging to Kristen** — either
`OsrmRouteOptimiser` is legacy code that should be removed (and CLAUDE.md
updated), or `optimise_route` should be calling it and got quietly swapped to
the geographic fallback (e.g. if the OSRM public server was flaky/rate
limited). Don't assume either is "correct" — ask before deleting or rewiring.

Manual reordering (drag-drop in the `route` view) hits `reorder`, which also
writes back to `subscription.collection_order` via `update` (not
`update_column`) specifically so the `sync_collection_positions` callback
fires and next week's auto-created collection inherits the same route
position. `CollectionsController#reset_order` reverses this — pulls
positions back from `subscription.collection_order` — used to restore a
day's order after some disruption.

## Background jobs touching the driver's day

All in `app/jobs/`, run via Solid Queue — but production has no queue worker
dyno, so time-sensitive jobs are triggered by `perform_now` piggybacked on
real controller actions (Monday's revenue recognition on `start`; collection
creation, next week's drop-off events, and subscription completion checks
all on `end`). If you add a new job that needs to run on a schedule, it
needs a piggyback point, not just `perform_later`.

- `CreateCollectionsJob` — anchors 7 days ahead of the given/today date,
  finds/creates that day's `DriversDay`, and creates one `Collection` per
  active subscription on the matching `collection_day`, deduplicating when a
  user has multiple active subscriptions at the same address (keeps the
  oldest). Also triggers `MonthlyInvoiceService.process_all`.
- `CreateTodayCollectionsJob` / `CreateTomorrowCollectionsJob` /
  `CreateNextWeekCollectionsJob` — manual/admin-triggered variants, see
  `CollectionsController#perform_create_*`.
- `CreateFirstCollectionJob` — bootstraps the very first collection for a
  brand-new subscription.
- `CreateNextWeekDropOffEventsJob` — the drop-off equivalent, run at
  end-of-day.
- `CheckSubscriptionsForCompletionJob` — marks subscriptions `completed` once
  their duration is reached.

## Stats and reporting

- `DriversDay#calculate_and_save_statistics!` computes and persists a
  `DayStatistic` row (bucket weight/count, households served, route
  hours/kms, stops-per-hour, kg-per-hour, CO2/tree equivalents) once a day
  ends.
- `WeeklyStats.call` is the shared service behind `weekly_snapshot` (and
  presumably `WeeklyStatsMailer`, sent by `DriversDay` "on Thursday
  completion" per CLAUDE.md — worth checking that mailer trigger still lines
  up with `send_weekly_stats_if_thursday_finished` if you touch it).
  `mode: :route_week` anchors Mon–Thu around a given date rather than a
  rolling 7 days.
- `yearly_snapshot` hardcodes a default year (2025) when no `year` param is
  given — will need bumping (or a smarter default) as real years pass.

## Things a future AI should double check before relying on them

1. **`OsrmRouteOptimiser` vs `GeographicRouteOptimiser`** — confirmed live
   discrepancy above; verify which is current before writing code that
   assumes one is authoritative.
2. **`start` vs `vamos`** — both render a very similar morning-briefing view;
   check `config/routes.rb` and any nav links to see which is actually
   reachable in the current UI before assuming either is unused.
3. Per CLAUDE.md's critical notes: always use `mark_skipped!`, never trust
   `new_customer` for reporting, and never use `button_to` inside a
   `form_with` (CSRF risk) anywhere you're touching these views.
