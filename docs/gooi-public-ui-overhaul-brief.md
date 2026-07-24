# Gooi Public UI Overhaul — Brief for Claude Code

*Companion to `gooi-marketing-plan.md` and `BRAND.md`. Point Claude Code at all three.*

**Repo:** `~/code/KIKMAKER/alfreds-gooi` · **Live:** gooi.me
**Reference designs:** current gooi.me homepage (screenshot A) and the Netlify redesign by Kiki's sister (screenshot B, gooi-cape-town.netlify.app)

---

## 0. Mission statement

Rebuild Gooi's public, lead-facing pages to be dramatically better at converting visitors into sign-ups and waitlist leads, while looking like a company that deserves the trust it has earned. The logged-in UI is already good and is **out of scope**. This is a blend job, not a rewrite-from-scratch job:

- **From the Netlify redesign (B):** the narrative arc, the split hero with a benefit-led headline, the 3-step "How gooi works", the Yes/Nope "What you can gooi" cheat sheet, plan-first pricing, the B2B band, the FAQ accordion, the alternating cream/green sections.
- **From the current site (A):** the Mapbox coverage map with day toggles, the "Think we should gooi in your 'hood?" waitlist form, live specific impact numbers, testimonials, the honest microcopy ("Consistent-ish timing · Traffic & Alfred's chats can nudge times a bit"), the pattern background and wave dividers.
- **From BRAND.md:** every token, colour, font, radius, shadow, and voice rule. BRAND.md §8 (`_tokens.scss` proposal) is the authoritative starting point for the design system.

**Non-negotiable brand rules (from BRAND.md §5):** ground every claim in specific numbers, never vague ones ("54,497 kg", not "thousands of kilos"). Use "neighbours", not customers/users. Alfred by first name. "Gooi" as a verb. No guilt framing, no em dashes, no contrast framing, no engagement bait. Warm, practical, Capetonian.

---

## 1. Phased plan

Work in this order. Each phase is a separate Claude Code session with its own PR.

### Phase 0 — Design tokens (small, do first)
1. Create `app/assets/stylesheets/config/_tokens.scss` exactly as specified in BRAND.md §8: `$fs-*` type scale, `$space-*` spacing scale, `$radius-*` radii, `$shadow-*` shadows, semantic colour aliases (`$color-primary`, `$color-accent`, etc.).
2. Import after `config/colors` and `config/fonts` in `application.scss`.
3. Fix the invalid `font-size: bigger` in `_card.scss`.
4. Migrate the hardcoded hex values listed in BRAND.md §2 ("Hardcoded values in current codebase") to variables. Priority files: `_home.scss`, `_button.scss`, `_card.scss`, `_navbar.scss`.
5. Do NOT visually change anything in this phase. Screenshot-diff before/after to confirm.

### Phase 1 — Snapshot views (the stats images)
Rails views rendered at exact social dimensions, screenshotted to PNG. The daily stats HTML approach already exists — extend the pattern.

1. **`GET /snapshots/weekly`** — 1080×1350 weekly stats post. Content: "This week with Gooi" eyebrow, hero kg number (Libre Baskerville, huge, cream on `$dark-green` pattern background), neighbours count, collections completed, running total since 2023, one equivalence line, logo + gooi.me footer. Redesign freely so it works in pure HTML/CSS: flat layout, brand pattern as CSS/SVG background, no Canva-dependent effects.
2. **`GET /snapshots/daily`** — 1080×1920 daily impact story (align with the existing daily stats view; refactor onto shared partials).
3. **`GET /snapshots/road-to-100`** — 1080×1350 campaign tracker: horizontal progress bar 0→100,000 kg, current total huge, "the first 50 tonnes took three years. Help us gooi the next 50 in one." Editable via query param or DB so the same view serves posts and the homepage strip.
4. **Shared infrastructure:** a `snapshots` layout (no nav/footer, fixed viewport, tokens-based), shared partials (`_stat_hero`, `_progress_bar`, `_snapshot_footer`), and an equivalence helper (`kg → wheelbarrows / bakkie-loads / rugby players / CO₂e`) usable in snapshots, homepage, and WhatsApp copy.
5. **PNG capture:** admin-only button or rake task using grover/ferrum to save each snapshot as PNG at 2x. Keep fonts self-hosted or preloaded so headless rendering is deterministic.

### Phase 2 — Homepage overhaul (the big one)
Rebuild `pages#home` (or equivalent) as a sequence of partials, each with its own SCSS partial and, where interactive, a Stimulus controller. Target section order:

1. **Nav** — adopt B's simpler public nav: How it works · What you can gooi · Pricing · Business, plus the yellow "Sign up" pill. Preserve current logged-in awareness (Dashboard / Log out).
2. **Hero (split, from B)** — Headline: "Your kitchen scraps deserve a second life." with `$dark-yellow` highlight on "second life". One short subline (max 2 lines): weekly doorstep collection, scraps become compost at local farms. Primary CTA "Start gooi-ing". Beneath it, the live proof line: "**54,497 kg** diverted since 2023, and counting" pulled from the DB, gently counting up on load (Stimulus + IntersectionObserver, respects `prefers-reduced-motion`). Right side: strong real photo (the papaya-in-bucket shot works; final choice is Kiki's). Keep the dark green pattern background and wave divider from A. The Soil for Life video moves further down the page or to the About page — it should not occupy the hero.
3. **Live impact strip (new, replaces B's vague "Thousands of kilos" band)** — three live stats from the stats endpoint: total kg since 2023 · kg this week · neighbours gooi-ing weekly. Optionally render the Road-to-100 progress bar here (reuse the Phase 1 partial). This is the site's heartbeat and a press magnet.
4. **How gooi works (from B)** — three numbered steps (Get your bucket → Fill it all week → We collect & compost) beside the bakkie photo. Tight copy, Alfred named in step 3.
5. **What you can gooi (from B)** — the Yes/Nope two-column cheat sheet, dark-green Yes card, white Nope card. Link to a full list page. This block is also an SEO asset; mark it up as content, not images.
6. **Pricing (blend)** — plan-first like B: **Standard · XL · Once-off** as the three cards. Inside Standard and XL, a commitment selector (1 / 3 / 6 months) that updates the monthly price (Stimulus), defaulting to 6 months with a "most popular" badge. Show "from R180/mo" pattern. Kiki to confirm whether B's strikethrough anchor pricing (R180 ~~R260~~) stays. Once-off card: R145, "Just trying it out? Book a single collection."
7. **Where we collect (KEEP from A — do not drop)** — Mapbox map with day toggles, plus the four honest info cards verbatim ("The gooi bakkie loops Cape Town once a week", "Consistent-ish timing", "Your day = your 'hood", "Always current"). Performance: lazy-load Mapbox only when the section approaches the viewport (IntersectionObserver) — this is likely the single biggest page-weight win.
8. **Waitlist form (KEEP from A, relocate here)** — "Think we should gooi in your 'hood?" sits directly after the map, catching everyone whose suburb isn't covered. Keep name/email/suburb/note and the "Plant the seed" button. Ensure submissions persist to a waitlist table with suburb, so per-suburb demand counts can feed the NOW strategy and Suburb Spotlight posts. Post-submit state: "You're seed #N in {suburb}" if the data supports it.
9. **Testimonials (KEEP from A)** — three cards, first names, at least one Alfred mention. `$surface-mint` background per existing pattern.
10. **Straight from the gooi feed (from B)** — grid of recent Instagram posts. Simplest robust option: a manually curated set of 4–6 images in the repo/admin, refreshed monthly; upgrade to the Instagram API post-Meta-verification. Do not block the overhaul on this.
11. **B2B band (from B)** — "Restaurant owner or building manager?" full-width dark band, "Get in touch" CTA to the commercial flow. Volume-based pricing and flexible contracts mentioned in one line.
12. **FAQ / Good to know (from B)** — accordion (native `<details>` or Stimulus): where do you collect, what do I do with the bucket, does it really become compost (name Soil for Life and Streetscapes), can I cancel anytime, what about the 2027 Western Cape organics mandate.
13. **Footer** — current links + WhatsApp (078 532 5513), howzit@gooi.me, Instagram, and the "One Small Change, Huge Impact" strapline.

**Conversion logic across the page:** there are exactly two funnels — in-area visitors → Sign up; out-of-area visitors → waitlist. Every section should feed one of them. A stretch goal worth attempting: a suburb quick-check in or near the hero ("Check your street's collection day") that either deep-links to sign-up or scrolls to the waitlist form pre-filled.

### Phase 3 — Supporting public pages
1. **/hello** — owned link-in-bio page (suburb check, sign up, Gooi Soil, latest stats snapshot, once-off booking). Replaces any third-party link tool.
2. **What you can gooi** — full page expanding the cheat sheet; the SEO workhorse.
3. **About / mission** — the fireside narrative: how Gooi began (an idea met a person), the four-step loop, the decentralised Cape Town vision. Home for the Soil for Life video.
4. **Business** — commercial page for cafés/restaurants/buildings, reusing the Church Square pitch material.
5. **Later (flag, don't build yet):** per-suburb landing pages (/pinelands, /muizenberg …) with local stats and waitlist counts — the NOW strategy's SEO layer.

---

## 2. Technical standards for all phases

- **Mobile-first.** Most Instagram-referred traffic is on a phone. Design every section at 380px first.
- **Stimulus for all interactivity** (pricing selector, FAQ, counter, map lazy-load, day toggles). No new JS frameworks.
- **Partials discipline:** one section = one partial = one SCSS partial, all consuming `_tokens.scss`. No new hardcoded hex values or px font sizes anywhere.
- **Performance:** optimise and lazy-load images (WebP, width-appropriate `srcset`), defer Mapbox, preload the two Google Fonts, aim for LCP under 2.5s on mid-range mobile.
- **Accessibility:** yellow buttons carry `$dark-green` text (verify contrast), visible focus states, alt text on every image, accordion and toggles keyboard-operable, `prefers-reduced-motion` respected.
- **Analytics:** keep GA4/Ahoy events on the key actions — sign-up start, plan selected, waitlist submit, B2B contact, suburb check. These four numbers define whether the overhaul worked.
- **SEO:** proper title/meta/OG per page, LocalBusiness structured data, semantic headings.
- **Screenshots at every step.** Render and eyeball each section against screenshots A and B before moving on.

---

## 3. Kickoff prompt (paste into Claude Code)

> Read `gooi-public-ui-overhaul-brief.md`, `BRAND.md`, and `gooi-marketing-plan.md` in full before writing any code. We are executing the brief in phases; today is Phase {0|1|2.x}. Explore the relevant existing code first (`app/views/pages/`, `app/assets/stylesheets/`, the existing daily stats snapshot view) and summarise the current structure back to me before proposing changes. Then implement the phase as specified, one section at a time, showing me a screenshot after each section. Never introduce hardcoded colours, px font sizes, or new fonts; everything comes from `_tokens.scss` and BRAND.md. Match the voice rules in BRAND.md §5 for any copy you write, and flag any copy decisions for me rather than inventing claims or numbers. Commit per section with clear messages.

---

## 4. Decisions Kiki makes before Phase 2

1. **Anchor pricing:** keep sister's strikethrough style (R180 ~~R260~~/mo) or show "from R180/mo" only?
2. **Hero image:** papaya bucket, an Alfred/bakkie shot, or a short muted clip? (Photo recommended for LCP.)
3. **Video placement:** How-it-works section or About page?
4. **IG feed source:** manual curated set now, API later — confirm.
5. **Counter animation:** count-up on load, or static number?
6. **Copy keeps:** confirm "No bin juice, no guilt, no landfill" (it flirts with the no-contrast-framing rule — it's charming, your call).
7. **Waitlist "seed #N" feature:** worth the small backend addition?

## 5. What to hand over alongside this brief

- **Sister's Netlify source** if she'll share it (zip or repo) — lets Claude Code port her step-cards, cheat sheet, and accordion styles instead of re-deriving them from a screenshot. Screenshots suffice if not.
- **Photo shortlist:** 8–10 best photos (hero candidates, bakkie, Alfred, farm, bucket) dropped into a folder Claude Code can reference.
- **The real FAQ answers** in Kiki's words (bucket logistics, cancellation, the 2027 mandate line).
- **GA4/Ahoy notes** if any: current drop-off points, top landing pages, mobile share.
- **Confirmation of the waitlist model/table name** so the form wiring targets the right place.
