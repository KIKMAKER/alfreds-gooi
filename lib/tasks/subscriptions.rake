namespace :subscriptions do
  desc "Backfill product_ids for existing subscriptions"
  task backfill_product_ids: :environment do
    puts "Starting backfill of product_ids for subscriptions..."

    total_count = 0
    commercial_count = 0
    standard_count = 0
    skipped_count = 0
    error_count = 0

    Subscription.find_each do |subscription|
      total_count += 1

      begin
        if subscription.Commercial?
          backfill_commercial_subscription(subscription)
          commercial_count += 1
        else
          backfill_standard_subscription(subscription)
          standard_count += 1
        end
      rescue => e
        puts "  ❌ Error processing subscription ##{subscription.id}: #{e.message}"
        error_count += 1
      end

      # Progress indicator every 50 subscriptions
      if total_count % 50 == 0
        puts "  Processed #{total_count} subscriptions..."
      end
    end

    puts "\n✅ Backfill complete!"
    puts "  Total subscriptions processed: #{total_count}"
    puts "  Commercial subscriptions: #{commercial_count}"
    puts "  Standard/XL subscriptions: #{standard_count}"
    puts "  Errors: #{error_count}"
  end

  def backfill_commercial_subscription(subscription)
    # Skip if already has product_ids
    if subscription.monthly_collection_product_id && subscription.volume_processing_product_id
      return
    end

    bucket_size = subscription.bucket_size || 45

    # Find monthly collection product
    monthly_title = case subscription.duration
                    when 12
                      "Commercial weekly collection per month (12-month rate)"
                    when 6
                      "Commercial weekly collection per month (6-month rate)"
                    when 3
                      "Commercial weekly collection per month (3-month rate)"
                    else
                      puts "  ⚠️  Subscription ##{subscription.id}: Unsupported duration #{subscription.duration}"
                      return
                    end

    monthly_product = Product.find_by(title: monthly_title)
    unless monthly_product
      puts "  ⚠️  Subscription ##{subscription.id}: Product not found: #{monthly_title}"
      return
    end

    # Find volume processing product
    volume_title = case subscription.duration.to_i
                   when 12
                     "Volume Processing per #{bucket_size}L (12-month rate)"
                   when 6
                     # Check if this is Loading Bay (special case with non-premium rate)
                     if subscription.user&.first_name == "Loading" && subscription.user&.last_name == " Bay"
                       "Volume Processing per #{bucket_size}L (6-month rate)"
                     else
                       "Volume Processing per #{bucket_size}L (Premium 6-month rate)"
                     end
                   when 3
                     "Volume Processing per #{bucket_size}L (3-month rate)"
                   else
                     puts "  ⚠️  Subscription ##{subscription.id}: Unsupported duration #{subscription.duration}"
                     return
                   end

    volume_product = Product.find_by(title: volume_title)
    unless volume_product
      puts "  ⚠️  Subscription ##{subscription.id}: Product not found: #{volume_title}"
      return
    end

    # Update the subscription
    subscription.update_columns(
      monthly_collection_product_id: monthly_product.id,
      volume_processing_product_id: volume_product.id
    )

    puts "  ✓ Subscription ##{subscription.id} (Commercial): stored product_ids"
  end

  def backfill_standard_subscription(subscription)
    # Skip if already has product_id
    return if subscription.subscription_product_id

    # Determine if this is an OG subscription
    og = subscription.user&.og? || false

    title = if og
              "#{subscription.plan} #{subscription.duration} month OG subscription"
            else
              "#{subscription.plan} #{subscription.duration} month subscription"
            end

    product = Product.find_by(title: title)
    unless product
      puts "  ⚠️  Subscription ##{subscription.id}: Product not found: #{title}"
      return
    end

    # Update the subscription
    subscription.update_column(:subscription_product_id, product.id)

    puts "  ✓ Subscription ##{subscription.id} (#{subscription.plan}): stored product_id"
  end
end
