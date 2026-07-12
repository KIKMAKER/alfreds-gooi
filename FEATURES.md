# Gooi — Feature Proposals

**Date:** 2026-07-12
**Companion to:** `ASSESSMENT.md` (Lens C) and `PROMPT_BANK.md`

These are gaps inferred from what the code implies about the business — not a wishlist. Each is something a professional service business of Gooi's type and stage would be expected to have.

Ranked by **value ÷ effort**. "Value" is weighted toward *reducing the founder's manual load* and *stopping revenue leaking*, because Gooi is solo-maintained and every hour of admin is an hour not spent growing.

---

## Ranking

| # | Feature | Value | Effort | Delegable? | Verdict |
|---|---|---|---|---|---|
| **F1** | Payment receipt email | **High** | **Low** | ✅ Yes — prompt pre-written | **GREENLIGHT** |
| **F2** | Suburb waitlist launch announcement | **High** | **Low** | ✅ Yes — prompt pre-written | **GREENLIGHT** |
| **F3** | Customer self-service cancellation | **High** | Medium | ⚠️ Prompt pre-written, but **needs a founder product decision first** | **DECIDE, then execute** |
| **F4** | Shareable impact card | Medium | Low | ✅ Yes (needs design taste for the card itself) | Defer to week 2 |
| **F5** | Email collection reminder | Medium | Low | ✅ Yes | Defer — blocked on the worker-dyno decision |
| **F6** | Card-on-file recurring billing | **Very High** | **High** | ❌ No — needs a session with a human | Biggest prize, not this week |
| **F7** | Collector route sheet (printable/offline) | Low | Low | ✅ Yes | Skip — mostly already exists |

---

## F1 — Payment receipt email `GREENLIGHT`

**Value: High · Effort: Low · Delegable: yes**

### What it is
When the founder marks an invoice paid (`InvoicesController#paid` — the EFT/cash path she clicks every week), send the customer a receipt: amount, date, what it covers, and a link to the invoice.

### Why it matters at Gooi's stage
Right now, `#paid` marks the invoice, creates the `Payment`, activates the subscription if it was pending — **and tells the customer nothing.** A `payment_received` email exists but only fires from `Subscription#activate_subscription`, i.e. only for a *first* payment on a *pending* subscription. So:

- Renewal payment → silence
- Monthly-billing payment → silence
- Compost-bags / soil order payment → silence
- Any EFT the founder reconciles by hand → silence

The customer transfers money into a bank account and gets no acknowledgement. "Hi, did you get my payment?" is the highest-volume avoidable support message in any subscription business, and every one of them currently lands in the founder's personal WhatsApp. This is the best value-to-effort ratio on the entire list: one mailer method, one template, one call site.

### Rough scope
- `PaymentMailer#receipt` (the mailer class already exists — it currently only has `short_payment_alert`)
- One HTML template + one text template
- One call in `InvoicesController#paid`, inside the existing transaction's success path
- Guard: don't send for order-linked invoices where the order flow already confirms

### Delegable?
**Yes.** Full prompt pre-written — see `PROMPT_BANK.md` → **F1-PROMPT**. All copy is provided verbatim so the model is transcribing, not composing.

---

## F2 — Suburb waitlist launch announcement `GREENLIGHT`

**Value: High · Effort: Low · Delegable: yes**

### What it is
An admin action on the interests page: pick a suburb, see everyone who registered interest from it, and send them all a "we've launched in your suburb" email with a signup link.

### Why it matters at Gooi's stage
The `Interest` model already captures name + email + suburb across **52 unserviced Cape Town suburbs**. `InterestMailer` already sends the founder a notification and the customer a confirmation. There's an admin index at `/admin/interests`. **And then nothing happens.** The data is collected, stored, listed — and buried.

This is a warm list of people who *raised their hand and asked to be customers*, with zero acquisition cost. When Gooi expands a route (and `Subscription::FUTURE_SUBURBS` shows expansion is actively planned — Noordhoek, Milnerton, Tableview, Glencairn), the first marketing action should be one click, not a manual mail-merge. Right now expanding into a suburb means the founder exports a list by hand or forgets the list exists.

It also directly informs **where to expand**: a count of interests per suburb is a demand map. That view doesn't exist today.

### Rough scope
- Group the existing `/admin/interests` index by suburb with counts (the demand map — valuable on its own)
- `InterestMailer#suburb_launched(interest)`
- Admin action: `POST /admin/interests/announce_suburb` → sends to every interest in that suburb, `perform_now` (no worker dyno), with a confirmation step showing the recipient count
- Mark announced interests so nobody gets it twice — needs one boolean column, `announced_at`

### Delegable?
**Yes.** Full prompt pre-written — see `PROMPT_BANK.md` → **F2-PROMPT**. Includes the migration.

⚠️ **One founder note:** this sends bulk email to people who opted in months or years ago. That's legitimate under POPIA (they consented, and it's the thing they asked for) but the email **must** carry an unsubscribe link. The prompt includes one.

---

## F3 — Customer self-service cancellation `DECIDE FIRST`

**Value: High · Effort: Medium · Delegable: yes, once decided**

### What it is
Let a customer cancel their subscription from `/manage`: a cancel button, a reason dropdown, a confirmation, a cancellation email, and a `cancelled` status.

### Why it matters at Gooi's stage
**There is no cancellation flow anywhere in the app.** The `Subscription` status enum is `pending / active / pause / completed / legacy` — there is no `cancelled`. A customer who wants to leave has exactly two options today:

1. WhatsApp the founder and ask her to do it by hand
2. Stop paying, and silently become a `completed` subscription that never renews

Option 2 is what most people actually do, and it means **Gooi never learns why anyone leaves.** Churn reason is the most valuable single data point a subscription business collects, and Gooi is currently collecting none of it. There's a `ChurnCalculator` service in `app/services/` computing churn *rate* — it can tell the founder that people are leaving, but nothing in the system can tell her *why*.

It's also a trust signal. "Easy to cancel" is something confident subscription businesses advertise, and the absence of it reads to a certain kind of customer as a dark pattern even when it isn't one.

### The decision the founder must make first

**This is a genuine product trade-off and I am not going to pretend otherwise.** Self-service cancellation removes friction to *leave* as well as friction to *stay*. Many small service businesses deliberately keep a human in the loop, because a WhatsApp conversation saves relationships that a "Confirm cancellation" button does not — and at Gooi's size, the founder probably *can* have that conversation with every leaver.

Three defensible options:

- **(a) Full self-service.** Cancel button → immediate. Best trust signal, highest churn-reason capture, most leaks.
- **(b) Request-to-cancel.** Customer submits reason + confirmation; it creates a task for the founder and sends *her* an alert; she closes the loop personally. **Captures the reason data, keeps the save conversation.** ← *my recommendation*
- **(c) Do nothing.** Status quo.

**I recommend (b).** It gets you the churn data — the actual prize — without giving up the relationship-save, and it converts a WhatsApp thread into a structured record. It's also strictly less risky to build: it never mutates subscription status, so it cannot interact with billing at all.

### Rough scope (option b)
- `cancellation_requests` table: `subscription_id`, `reason` (enum), `note` (text), `requested_at`, `resolved_at`, `outcome`
- Form on `/manage`, `POST /subscriptions/:id/request_cancellation`
- `SubscriptionMailer#cancellation_requested` (to customer: "we got it, Alfred will be in touch") + alert to founder
- Admin list of open requests
- **Touches no billing code, no status enum, no revenue recognition.**

### Delegable?
**Yes, once the founder picks an option.** A prompt for **option (b)** is pre-written — see `PROMPT_BANK.md` → **F3-PROMPT**, marked `PENDING APPROVAL`. If the founder picks (a) instead, that needs a different prompt and a status-enum migration, which I'd want to write with her.

---

## F4 — Shareable impact card `Defer`

**Value: Medium · Effort: Low · Delegable: yes (with design input)**

`User#lifetime_co2e_kg`, `#lifetime_compost_kg`, `#current_streak`, `#consistency_rate` are all computed and rendered on `/my_stats`. The app *already* renders Instagram-format impact snapshots for the founder (`drivers_days#snapshot`, `layouts/snapshot.html.erb`, and the in-flight `weekly_snapshot` work in the working tree). The customer-facing equivalent — "I've diverted 340kg from landfill with @gooi_capetown" with a share button — does not exist.

For a values-driven brand whose customers *chose* it for environmental reasons, this is organic growth surface sitting idle. The referral system already exists to catch the traffic.

**Why deferred:** the code is easy; the *card design* is the whole feature, and that needs the founder's eye. Worth a session together rather than a prompt. The snapshot layout machinery already in the repo is most of the technical work.

---

## F5 — Email collection reminder `Defer — blocked`

**Value: Medium · Effort: Low**

`WhatsappReminderJob` + `SendWhatsappReminderJob` + `TwilioWhatsappService` exist and are well-built. **They also silently do nothing in production**, because they're invoked with `perform_later` and there is no worker dyno (see `ASSESSMENT.md` **A6**). An admin clicking "trigger reminders" gets a success flash and zero messages sent.

An email reminder would be a reliable belt-and-braces — email doesn't need Twilio credits or template approval.

**Why deferred:** it is blocked on the worker-dyno decision (Bucket 3, item 1). If a worker dyno gets turned on, the *existing WhatsApp reminders start working* and this may be unnecessary. **Do not build this until that decision is made** — you might be building a redundant system to work around a problem that $7/month solves.

---

## F6 — Card-on-file recurring billing `The big one — not this week`

**Value: Very High · Effort: High · Delegable: NO**

Every payment in Gooi today is a **manual push by the customer** — a SnapScan QR scan or an EFT into a bank account, reconciled by hand. That single fact explains a startling amount of this codebase:

- The 3-stage dunning ladder (`NudgePendingSubscriptionsJob`) exists because payments don't happen automatically
- `payment_reminder_sent_at` exists on `subscriptions` to track the chase
- `claim_orphaned_payments` and `transfer_payments` admin tools exist to reconcile payments to the wrong account
- `Snapscan::SyncService` exists to poll for payments that the webhook missed
- `PaymentMailer#short_payment_alert` exists because customers underpay
- `MonthlyInvoiceService` + admin approval + preview emails exist to get invoices out the door every month

**All of that is scaffolding around the absence of a card on file.** Recurring billing wouldn't just add a feature — it would let the founder delete a meaningful fraction of the system she currently maintains, and it would convert "chase the customer" into "the money arrives".

**Why not this week:** it needs a payment-provider decision (Stripe, Paystack, Yoco, or SnapScan's own recurring product — all four are viable in South Africa, with different fee structures and different local support), a migration plan for ~existing customers, and careful thought about the interaction with `revenue_recognitions`. This is the highest-value item on the list and it is the one thing here that **should not be handed to a smaller model.** It's a session with a human.

---

## F7 — Collector route sheet `Skip`

Assessed and rejected. `drivers_days#route` already builds an ordered route combining collections and drop-off events, `route_export_text` already generates a shareable text manifest, `OsrmRouteOptimiser` solves the TSP, and there's a `missing_customers` flow for missed collections. The gap I expected to find isn't there — this is already handled. Recording it so nobody re-derives the same conclusion later.

---

# Recommendation

**Greenlight F1 and F2 this week.** Both are low-effort, high-value, touch nothing dangerous, and have complete prompts written. F1 stops the "did you get my payment?" WhatsApps. F2 turns a buried list into a growth channel.

**Decide F3 before anything gets built.** My recommendation is option (b), request-to-cancel — it captures churn reasons without giving up the save conversation, and it's strictly safer to build.

**Book a session for F6.** It's the biggest prize and the least suitable for delegation.
