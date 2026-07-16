# Design tokens — status

Source proposal: `BRAND.md` Section 8 (`~/Claude/Gooi/BRAND.md`), which suggested a
`config/_tokens.scss` partial for font sizes, spacing, radii, colour aliases, and shadows.

## Done

- `config/_tokens.scss` created and imported in `application.scss` (after `config/colors`,
  before `config/bootstrap_variables`).
- **Colours**: every hardcoded hex duplicate flagged in BRAND.md Section 2 is now a named
  token. `#138a64` was merged into `$medium-green` (confirmed dead CSS, no visual risk).
- **Radii**: every exact-match `border-radius` in `application.scss`, `_button.scss`,
  `_card.scss`, `_navbar.scss` tokenised.
- **Font sizes**: every exact-match `font-size` in the same priority files plus
  `_home.scss` tokenised. `1.0625rem` on the four homepage body-copy paragraphs
  (hero/mission/compost/partner-farms) was deliberately merged into `$fs-md`
  (visual sign-off given — see git log).
- **Shadows**: the four exact-match `box-shadow` values tokenised (`_navbar.scss`,
  `_admin_dashboard.scss`, `_home.scss` x2).

Commit trail: search `git log --oneline --grep="Phase"` for the full sequence.

## Parked — pick up here

1. **Mint surface shades** — three near-duplicate tokens still separate:
   `$color-surface-mint` (#f5faf9), `$color-surface-mint-alt` (#e8f4f3),
   `$color-surface-mint-hover` (#f0f6f4). Visible at: homepage testimonials section
   (`/`), FAQ page (`/faq`), logged-in navbar dropdown hover, admin interests
   suburb pills (`/admin/interests`). Needs the same visual-approval pass as the
   `1.0625rem` merge before collapsing them.

2. **`$color-text-forest` (#1f4632)** — own token, never proposed for merging into
   an existing colour by BRAND.md. No action needed unless a future review flags it.

3. **Phase 4: spacing (`$space-*`)** — intentionally *not* a batch sweep. Highest
   blast radius, least existing consistency to protect. Tokenise a file's spacing
   opportunistically when touching it for other work, not as a dedicated pass.

4. Remaining `1.0625rem` instances outside the homepage (`_interests.scss:104`,
   `_faq.scss:55`) were out of scope for the homepage-only approval above — same
   question applies if/when revisited.

## Verification method used

No visual regression tooling exists in this repo. Every token substitution here
was checked by compiling the real asset pipeline and confirming byte-identical
(or deliberately-approved) output:

```ruby
Rails.application.assets.find_asset('application.css')
```

via `bin/rails runner`, rather than a standalone `sassc` call (which can't resolve
`@import "bootstrap"` outside Sprockets' load paths).
