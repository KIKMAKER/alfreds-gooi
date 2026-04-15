require 'csv'

puts "\n--- Seeding users and subscriptions ---"

CSV_PATH = Rails.root.join('db', 'LOGS for CSV - export_csv.csv')

# ── Staff ─────────────────────────────────────────────────────────────────────

User.find_or_create_by!(email: "driver@gooi.com") do |u|
  u.first_name   = "Alfred"
  u.last_name    = "Mbonjwa"
  u.password     = "password"
  u.role         = "driver"
  u.phone_number = "+27785325513"
end
puts "  ✓ Alfred Mbonjwa (driver)"

User.find_or_create_by!(email: "gooi@gooi.com") do |u|
  u.first_name   = "Kiki"
  u.last_name    = "Kenn"
  u.password     = "password"
  u.role         = "admin"
  u.phone_number = "+27836353126"
end
puts "  ✓ Kiki Kenn (admin)"

# ── CSV import ────────────────────────────────────────────────────────────────

unless File.exist?(CSV_PATH)
  puts "  ✗ CSV not found at #{CSV_PATH} — skipping customer import"
  return
end

# Status distribution for the current (latest) subscription.
# Weighted toward active to reflect a healthy customer base.
CURRENT_STATUSES = ([:active] * 13) + ([:pause] * 3) + ([:pending] * 2) + ([:completed] * 2)

# Plan can change on renewal — use this to vary renewals slightly
RENEWAL_PLANS = {
  "Standard" => [:Standard, :Standard, :Standard, :XL],  # 75% stay Standard, 25% upgrade
  "XL"       => [:XL, :XL, :XL],
  "Commercial" => [:Commercial]
}

imported = 0
failed   = 0

CSV.foreach(CSV_PATH, headers: :first_row) do |row|
  first_name   = row['first_name'].to_s.strip
  last_name    = row['last_name'].to_s.strip
  email        = row['email'].to_s.strip.downcase
  phone        = row['phone_number'].to_s.strip
  street       = row['street_address'].to_s.strip
  plan         = row['plan'].to_s.strip
  duration     = row['duration'].to_i
  suburb       = row['suburb'].to_s.strip
  customer_id  = row['customer_id'].to_s.strip

  next if email.blank?

  begin
    user = User.create!(
      first_name:  first_name,
      last_name:   last_name,
      email:       email,
      phone_number: phone,
      password:    "password",
      role:        "customer",
      customer_id: customer_id.presence
    )
  rescue ActiveRecord::RecordInvalid => e
    failed += 1
    next
  end

  total_subs   = rand(1..4)
  base_plan    = plan.in?(%w[Standard XL Commercial once_off]) ? plan : "Standard"
  csv_start    = row['start_date'].present? ? (Date.parse(row['start_date']) rescue Date.today - rand(6..24).months) : (Date.today - rand(6..24).months)
  sub_duration = duration.positive? ? duration : [3, 6].sample

  current_start = csv_start

  total_subs.times do |i|
    is_last = (i == total_subs - 1)

    # Pick plan: CSV plan for first sub, allow upgrades on renewal
    sub_plan = if i == 0
                 base_plan.to_sym
               else
                 (RENEWAL_PLANS[base_plan] || [:Standard]).sample
               end

    if is_last
      status         = CURRENT_STATUSES.sample
      end_date_val   = status == :completed ? current_start + sub_duration.months : nil
      holiday_start  = nil
      holiday_end    = nil

      # Paused users have an active holiday window
      if status == :pause
        holiday_start = Date.today - rand(0..14).days
        holiday_end   = Date.today + rand(7..28).days
      # ~12% of active users happen to be on holiday right now
      elsif status == :active && rand < 0.12
        holiday_start = Date.today - rand(0..5).days
        holiday_end   = Date.today + rand(3..18).days
      end
    else
      status        = :completed
      end_date_val  = current_start + sub_duration.months
      holiday_start = nil
      holiday_end   = nil
    end

    sub = Subscription.new(
      user:           user,
      street_address: street,
      suburb:         suburb,
      plan:           sub_plan,
      duration:       sub_duration,
      status:         status,
      start_date:     current_start,
      end_date:       end_date_val
    )
    sub.holiday_start = holiday_start if holiday_start
    sub.holiday_end   = holiday_end   if holiday_end
    # Use save (not save!) — some legacy CSV suburbs/addresses may not pass strict validation
    sub.save

    unless is_last
      next_start   = end_date_val + rand(5..30).days
      # Don't build a chain of future subs
      break if next_start > Date.today
      current_start = next_start
      sub_duration  = [3, 6].sample
    end
  end

  imported += 1
rescue => e
  puts "  ✗ Error on #{email}: #{e.message}"
  failed += 1
end

puts "\n  ✓ #{imported} users imported (#{failed} skipped)"
puts "  #{Subscription.where(status: :active).count} active subscriptions"
puts "  #{Subscription.where(status: :pause).count} paused (on holiday)"
puts "  #{Subscription.where(status: :pending).count} pending"
puts "  #{Subscription.where(status: :completed).count} completed"
puts "  #{Subscription.count} total subscriptions across #{User.where(role: :customer).count} customers"
