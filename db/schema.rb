# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_03_23_134734) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "buckets", force: :cascade do |t|
    t.bigint "drivers_day_id", null: false
    t.float "weight_kg", default: 0.0
    t.boolean "half", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "drop_off_event_id"
    t.integer "bucket_size", default: 25
    t.index ["drivers_day_id"], name: "index_buckets_on_drivers_day_id"
    t.index ["drop_off_event_id"], name: "index_buckets_on_drop_off_event_id"
  end

  create_table "business_profiles", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.string "business_name"
    t.string "vat_number"
    t.string "contact_person"
    t.string "street_address"
    t.string "suburb"
    t.string "postal_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "registration_number"
    t.index ["subscription_id"], name: "index_business_profiles_on_subscription_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "time"
    t.string "kiki_note"
    t.string "alfred_message", default: "N/A"
    t.integer "bags", default: 0
    t.bigint "subscription_id", null: false
    t.boolean "is_done", default: false, null: false
    t.boolean "skip", default: false, null: false
    t.integer "needs_bags", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "drivers_day_id"
    t.date "date"
    t.boolean "new_customer", default: false
    t.float "buckets", default: 0.0
    t.integer "dropped_off_buckets", default: 0
    t.integer "soil_bag", default: 0
    t.boolean "wants_veggies"
    t.string "customer_note"
    t.integer "position"
    t.integer "buckets_45l", default: 0
    t.integer "buckets_25l", default: 0
    t.index ["drivers_day_id"], name: "index_collections_on_drivers_day_id"
    t.index ["subscription_id"], name: "index_collections_on_subscription_id"
  end

  create_table "commercial_inquiries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "business_name"
    t.text "business_address"
    t.integer "estimated_buckets"
    t.integer "preferred_duration"
    t.string "collection_frequency"
    t.text "additional_notes"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_commercial_inquiries_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.string "phone_number", null: false
    t.string "relationship"
    t.boolean "whatsapp_opt_out", default: false, null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number"], name: "index_contacts_on_phone_number"
    t.index ["subscription_id", "is_primary"], name: "index_contacts_on_subscription_id_and_is_primary"
    t.index ["subscription_id", "phone_number"], name: "index_contacts_on_subscription_id_and_phone_number", unique: true
    t.index ["subscription_id"], name: "index_contacts_on_subscription_id"
  end

  create_table "day_statistics", force: :cascade do |t|
    t.bigint "drivers_day_id", null: false
    t.decimal "net_kg"
    t.integer "bucket_count"
    t.integer "full_count"
    t.integer "half_count"
    t.decimal "full_equiv"
    t.decimal "avg_kg_bucket"
    t.decimal "avg_kg_full"
    t.integer "households"
    t.integer "bags_sum"
    t.decimal "route_hours"
    t.decimal "stops_per_hr"
    t.decimal "kg_per_hr"
    t.integer "kms"
    t.decimal "kg_per_km"
    t.decimal "avoided_co2e_kg"
    t.decimal "driving_co2e_kg"
    t.decimal "net_co2e_kg"
    t.decimal "trees_gross"
    t.decimal "trees_to_offset_drive"
    t.decimal "trees_net"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["drivers_day_id"], name: "index_day_statistics_on_drivers_day_id"
  end

  create_table "discount_codes", force: :cascade do |t|
    t.string "code"
    t.integer "discount_cents"
    t.datetime "expires_at"
    t.integer "usage_limit"
    t.integer "used_count"
    t.boolean "default", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "discount_percent"
  end

  create_table "drivers_days", force: :cascade do |t|
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "note"
    t.bigint "user_id", null: false
    t.integer "total_buckets"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.datetime "sfl_time"
    t.integer "start_kms"
    t.integer "end_kms"
    t.string "message_from_alfred"
    t.float "total_net_kg"
    t.bigint "current_drop_off_event_id"
    t.index ["current_drop_off_event_id"], name: "index_drivers_days_on_current_drop_off_event_id"
    t.index ["user_id"], name: "index_drivers_days_on_user_id"
  end

  create_table "drop_off_events", force: :cascade do |t|
    t.bigint "drop_off_site_id", null: false
    t.bigint "drivers_day_id", null: false
    t.date "date"
    t.datetime "time"
    t.boolean "is_done", default: false, null: false
    t.integer "buckets_dropped", default: 0
    t.float "weight_kg", default: 0.0
    t.string "driver_note"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "arrival_time"
    t.datetime "departure_time"
    t.integer "duration_minutes"
    t.boolean "is_final_destination", default: false, null: false
    t.index ["arrival_time"], name: "index_drop_off_events_on_arrival_time"
    t.index ["drivers_day_id"], name: "index_drop_off_events_on_drivers_day_id"
    t.index ["drop_off_site_id"], name: "index_drop_off_events_on_drop_off_site_id"
  end

  create_table "drop_off_sites", force: :cascade do |t|
    t.string "name"
    t.string "street_address"
    t.string "suburb"
    t.string "contact_name"
    t.string "phone_number"
    t.text "notes"
    t.float "latitude"
    t.float "longitude"
    t.float "total_weight_kg", default: 0.0
    t.integer "total_dropoffs_count", default: 0
    t.integer "collection_day"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "slug"
    t.text "story"
    t.string "website"
    t.string "instagram_handle"
    t.string "facebook_url"
    t.float "average_duration_minutes"
    t.integer "total_duration_minutes", default: 0
    t.integer "completed_dropoffs_count", default: 0
    t.index ["slug"], name: "index_drop_off_sites_on_slug", unique: true
    t.index ["user_id"], name: "index_drop_off_sites_on_user_id"
  end

  create_table "expense_imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "filename", null: false
    t.string "bank_name"
    t.date "statement_start_date"
    t.date "statement_end_date"
    t.integer "total_rows"
    t.integer "imported_rows"
    t.integer "skipped_rows"
    t.text "import_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_expense_imports_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.date "transaction_date", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category", null: false
    t.string "description"
    t.string "vendor"
    t.string "payment_method"
    t.string "reference_number"
    t.text "notes"
    t.integer "accounting_month", null: false
    t.integer "accounting_year", null: false
    t.bigint "expense_import_id"
    t.boolean "verified", default: false
    t.bigint "verified_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accounting_year", "accounting_month"], name: "index_expenses_on_accounting_year_and_accounting_month"
    t.index ["category"], name: "index_expenses_on_category"
    t.index ["expense_import_id"], name: "index_expenses_on_expense_import_id"
    t.index ["transaction_date"], name: "index_expenses_on_transaction_date"
    t.index ["verified"], name: "index_expenses_on_verified"
    t.index ["verified_by_id"], name: "index_expenses_on_verified_by_id"
  end

  create_table "financial_metrics", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "month", null: false
    t.decimal "cash_revenue", precision: 10, scale: 2, default: "0.0"
    t.decimal "recognized_revenue", precision: 10, scale: 2, default: "0.0"
    t.decimal "cogs_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "operational_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "fixed_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "marketing_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "admin_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "other_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_expenses", precision: 10, scale: 2, default: "0.0"
    t.decimal "gross_profit", precision: 10, scale: 2, default: "0.0"
    t.decimal "net_profit", precision: 10, scale: 2, default: "0.0"
    t.integer "active_subscriptions"
    t.integer "new_subscriptions"
    t.integer "churned_subscriptions"
    t.decimal "mrr", precision: 10, scale: 2, default: "0.0"
    t.datetime "calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "month"], name: "index_financial_metrics_on_year_and_month", unique: true
  end

  create_table "interests", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "suburb"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoice_discount_codes", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "discount_code_id", null: false
    t.decimal "discount_amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discount_code_id"], name: "index_invoice_discount_codes_on_discount_code_id"
    t.index ["invoice_id"], name: "index_invoice_discount_codes_on_invoice_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "product_id", null: false
    t.float "quantity", default: 1.0, null: false
    t.float "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["product_id"], name: "index_invoice_items_on_product_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.date "issued_date"
    t.date "due_date"
    t.integer "number"
    t.float "total_amount"
    t.boolean "paid", default: false
    t.bigint "subscription_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "legacy_subscription_id"
    t.boolean "used_discount_code"
    t.bigint "order_id"
    t.index ["order_id"], name: "index_invoices_on_order_id"
    t.index ["subscription_id"], name: "index_invoices_on_subscription_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1
    t.decimal "price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "collection_id"
    t.string "status", default: "pending"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_orders_on_collection_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "snapscan_id"
    t.string "status"
    t.integer "total_amount"
    t.integer "tip_amount"
    t.integer "fee_amount"
    t.integer "settle_amount"
    t.datetime "date"
    t.string "user_reference"
    t.string "merchant_reference"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "invoice_id"
    t.string "payment_type"
    t.boolean "manual", default: false, null: false
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "body", null: false
    t.text "excerpt"
    t.string "cover_image_url"
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.float "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: false, null: false
    t.integer "stock", default: 0
  end

  create_table "quotation_items", force: :cascade do |t|
    t.bigint "quotation_id", null: false
    t.bigint "product_id", null: false
    t.float "quantity", default: 1.0
    t.float "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_quotation_items_on_product_id"
    t.index ["quotation_id"], name: "index_quotation_items_on_quotation_id"
  end

  create_table "quotations", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "subscription_id"
    t.string "prospect_name"
    t.string "prospect_email"
    t.string "prospect_phone"
    t.string "prospect_company"
    t.text "notes"
    t.integer "number"
    t.date "created_date"
    t.date "expires_at"
    t.integer "status", default: 0
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duration_months", default: 6, null: false
    t.string "quote_type", default: "subscription", null: false
    t.date "event_date"
    t.string "event_name"
    t.string "event_venue"
    t.index ["subscription_id"], name: "index_quotations_on_subscription_id"
    t.index ["user_id"], name: "index_quotations_on_user_id"
  end

  create_table "referrals", force: :cascade do |t|
    t.bigint "referrer_id", null: false
    t.bigint "referee_id", null: false
    t.bigint "subscription_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.index ["referee_id"], name: "index_referrals_on_referee_id"
    t.index ["referrer_id"], name: "index_referrals_on_referrer_id"
    t.index ["subscription_id"], name: "index_referrals_on_subscription_id"
  end

  create_table "revenue_recognitions", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "subscription_id", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.integer "period_month", null: false
    t.integer "period_year", null: false
    t.decimal "recognized_amount", precision: 10, scale: 2, null: false
    t.string "recognition_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_revenue_recognitions_on_invoice_id"
    t.index ["period_year", "period_month"], name: "index_revenue_recognitions_on_period_year_and_period_month"
    t.index ["subscription_id"], name: "index_revenue_recognitions_on_subscription_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "customer_id"
    t.string "access_code"
    t.string "street_address"
    t.string "suburb"
    t.integer "duration"
    t.datetime "start_date"
    t.integer "collection_day"
    t.integer "plan"
    t.boolean "is_paused", default: false, null: false
    t.bigint "user_id", null: false
    t.date "holiday_start", default: "2000-01-01"
    t.date "holiday_end", default: "2000-01-01"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "collection_order"
    t.boolean "is_new_customer", default: true
    t.float "latitude"
    t.float "longitude"
    t.string "apartment_unit_number"
    t.integer "status", default: 0
    t.datetime "end_date"
    t.string "referral_code"
    t.string "discount_code"
    t.integer "buckets_per_collection"
    t.integer "bucket_size", default: 45
    t.boolean "monthly_invoicing", default: false, null: false
    t.decimal "contract_total", precision: 10, scale: 2
    t.date "next_invoice_date"
    t.date "ending_soon_emailed_at"
    t.integer "collections_per_week", default: 1, null: false
    t.decimal "starter_kit_installment", precision: 10, scale: 2
    t.integer "subscription_product_id"
    t.integer "monthly_collection_product_id"
    t.integer "volume_processing_product_id"
    t.string "title"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "testimonials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.boolean "public", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_testimonials_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.integer "role", default: 0
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "customer_id"
    t.string "referral_code"
    t.boolean "og", default: false
    t.boolean "whatsapp_opt_out", default: false
    t.string "provider"
    t.string "uid"
    t.string "referred_by_code"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "whatsapp_messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "subscription_id"
    t.string "message_type", null: false
    t.text "message_body", null: false
    t.string "twilio_sid"
    t.string "status"
    t.text "error_message"
    t.date "collection_date"
    t.boolean "used_template", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "contact_id"
    t.index ["collection_date"], name: "index_whatsapp_messages_on_collection_date"
    t.index ["contact_id"], name: "index_whatsapp_messages_on_contact_id"
    t.index ["message_type"], name: "index_whatsapp_messages_on_message_type"
    t.index ["status"], name: "index_whatsapp_messages_on_status"
    t.index ["subscription_id"], name: "index_whatsapp_messages_on_subscription_id"
    t.index ["user_id"], name: "index_whatsapp_messages_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "buckets", "drivers_days"
  add_foreign_key "buckets", "drop_off_events"
  add_foreign_key "business_profiles", "subscriptions"
  add_foreign_key "collections", "drivers_days"
  add_foreign_key "collections", "subscriptions"
  add_foreign_key "commercial_inquiries", "users"
  add_foreign_key "contacts", "subscriptions"
  add_foreign_key "day_statistics", "drivers_days"
  add_foreign_key "drivers_days", "drop_off_events", column: "current_drop_off_event_id"
  add_foreign_key "drivers_days", "users"
  add_foreign_key "drop_off_events", "drivers_days"
  add_foreign_key "drop_off_events", "drop_off_sites"
  add_foreign_key "drop_off_sites", "users"
  add_foreign_key "expense_imports", "users"
  add_foreign_key "expenses", "expense_imports"
  add_foreign_key "expenses", "users", column: "verified_by_id"
  add_foreign_key "invoice_discount_codes", "discount_codes"
  add_foreign_key "invoice_discount_codes", "invoices"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "invoices", "orders"
  add_foreign_key "invoices", "subscriptions"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "collections"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "users"
  add_foreign_key "quotation_items", "products"
  add_foreign_key "quotation_items", "quotations"
  add_foreign_key "quotations", "subscriptions"
  add_foreign_key "quotations", "users"
  add_foreign_key "referrals", "subscriptions"
  add_foreign_key "referrals", "users", column: "referee_id"
  add_foreign_key "referrals", "users", column: "referrer_id"
  add_foreign_key "revenue_recognitions", "invoices"
  add_foreign_key "revenue_recognitions", "subscriptions"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscriptions", "users"
  add_foreign_key "testimonials", "users"
  add_foreign_key "whatsapp_messages", "contacts"
  add_foreign_key "whatsapp_messages", "subscriptions"
  add_foreign_key "whatsapp_messages", "users"
end
