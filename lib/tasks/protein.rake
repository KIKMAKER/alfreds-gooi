# Seeds the protein / plate-waste stream: the Langa AgriHub drop-off site and the
# three protein commercial products.
#
# Dry-run by default — prints exactly what it would create and changes nothing:
#
#   bin/rails protein:seed
#
# To actually write:
#
#   bin/rails protein:seed CONFIRM=1
#
# ⚠️  The R0.50/kg Langa rate is provisional. Confirm the final rate with Kiki
#     before running with CONFIRM=1, or override it:
#
#   bin/rails protein:seed CONFIRM=1 FEE_PER_KG=0.65
#
# Idempotent: existing records are found by name/title and reported as "exists",
# never duplicated or overwritten.
namespace :protein do
  desc "Seed the Langa AgriHub drop-off site and the three protein products (dry-run unless CONFIRM=1)"
  task seed: :environment do
    confirmed  = ENV["CONFIRM"] == "1"
    fee_per_kg = BigDecimal(ENV.fetch("FEE_PER_KG", "0.50"))

    site_attrs = {
      name:            "Langa AgriHub",
      street_address:  ENV.fetch("LANGA_ADDRESS", "Washington Street, Langa"),
      suburb:          "Langa",
      contact_name:    "Mahlubi",
      collection_day:  ENV.fetch("LANGA_COLLECTION_DAY", "Wednesday"),
      accepts_protein: true,
      fee_per_kg:      fee_per_kg,
      notes:           "In-vessel BioBin composting — takes animal protein and plate scrapings."
    }

    products = [
      {
        title:        "Protein Volume Processing per 25L (6-month rate)",
        description:  "Processing of animal protein and plate-waste per 25L sealed bucket, in-vessel BioBin composting.",
        price:        1300.0,
        billing_type: "standard"
      },
      {
        title:        "Protein collection visit (6-month rate @ R240pm)",
        description:  "Scheduled protein collection visit. Billed at R240 per month over a 6-month term.",
        price:        1440.0,
        billing_type: "standard"
      },
      {
        # Title deliberately contains "Starter Bucket" so RevenueRecognitions::Recognize
        # matches it against ONE_OFF_TITLES and recognises it fully in the issue month.
        title:        "Protein Starter Bucket (25L sealed, swap pair)",
        description:  "Pair of 25L sealed swap buckets for protein and plate waste. One-off purchase.",
        price:        320.0,
        billing_type: "standard"
      }
    ]

    puts "\n#{'=' * 72}"
    puts confirmed ? "PROTEIN SEED — WRITING to #{Rails.env}" : "PROTEIN SEED — DRY RUN (#{Rails.env}). Nothing will be written."
    puts "#{'=' * 72}\n\n"

    puts "Drop-off site:"
    existing_site = DropOffSite.find_by(name: site_attrs[:name])
    if existing_site
      puts "  [exists] ##{existing_site.id} #{existing_site.name} — " \
           "accepts_protein=#{existing_site.accepts_protein?} fee_per_kg=R#{existing_site.fee_per_kg}"
      puts "           (left untouched — edit it in /admin/drop_off_sites instead)"
    else
      site_attrs.each { |k, v| puts "  [create] #{k}: #{v}" }
      puts "  ⚠️  fee_per_kg R#{fee_per_kg}/kg is PROVISIONAL — confirm with Kiki." unless ENV["FEE_PER_KG"]
    end

    puts "\nProducts:"
    products.each do |attrs|
      existing = Product.find_by(title: attrs[:title])
      if existing
        puts "  [exists] ##{existing.id} #{existing.title} — R#{existing.price} (#{existing.billing_type})"
      else
        puts "  [create] #{attrs[:title]} — R#{attrs[:price]} (#{attrs[:billing_type]}, quote-eligible)"
      end
    end

    unless confirmed
      puts "\nDry run complete. Re-run with CONFIRM=1 to write these records.\n\n"
      next
    end

    puts "\nWriting…"
    ActiveRecord::Base.transaction do
      site = DropOffSite.find_or_create_by!(name: site_attrs[:name]) do |s|
        s.assign_attributes(site_attrs.except(:name))
      end
      puts "  ✓ Drop-off site ##{site.id} #{site.name}"

      products.each do |attrs|
        product = Product.find_or_create_by!(title: attrs[:title]) do |p|
          p.assign_attributes(attrs.except(:title))
          p.is_active = false # not a shop item; quotes/invoices only
        end
        puts "  ✓ Product ##{product.id} #{product.title} — R#{product.price}"
      end
    end

    puts "\nDone.\n\n"
  end
end
