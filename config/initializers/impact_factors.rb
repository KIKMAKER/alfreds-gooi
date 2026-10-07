# CO₂e factors (rough starting points — tune over time)
IMPACT = {
  # kg CO₂e avoided per kg of organic waste diverted from landfill.
  # SINGLE SOURCE for every customer-, driver- and email-facing CO₂e figure
  # (User, Block, DriversDay, weekly stats email, homepage strip). Was split
  # across 0.6 / 1.9 / 1.96 until Oct 2026. Needs a citable source — change it
  # here and everything follows.
  co2e_per_kg_diverted: 1.96,

  # Vehicle: Nissan NP200 diesel (adjust as you measure)
  diesel_co2e_per_litre: 2.68,   # kg CO₂ per litre of diesel
  l_per_100km:          7.0,     # average route consumption

  # Trees: kg CO₂ absorbed per tree per year (rule of thumb)
  tree_co2e_per_year:   21.8
}.freeze
