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

ActiveRecord::Schema[7.2].define(version: 2025_10_10_104409) do
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

  create_table "buckets", force: :cascade do |t|
    t.bigint "drivers_day_id", null: false
    t.float "weight_kg", default: 0.0
    t.boolean "half", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "drop_off_event_id"
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
    t.integer "order", default: 0
    t.boolean "wants_veggies"
    t.string "customer_note"
    t.integer "position"
    t.index ["drivers_day_id"], name: "index_collections_on_drivers_day_id"
    t.index ["subscription_id"], name: "index_collections_on_subscription_id"
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
    t.index ["user_id"], name: "index_drop_off_sites_on_user_id"
  end

  create_table "interests", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "suburb"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
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
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "buckets", "drivers_days"
  add_foreign_key "buckets", "drop_off_events"
  add_foreign_key "business_profiles", "subscriptions"
  add_foreign_key "collections", "drivers_days"
  add_foreign_key "collections", "subscriptions"
  add_foreign_key "drivers_days", "users"
  add_foreign_key "drop_off_events", "drivers_days"
  add_foreign_key "drop_off_events", "drop_off_sites"
  add_foreign_key "drop_off_sites", "users"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "invoices", "subscriptions"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "collections"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "users"
  add_foreign_key "referrals", "subscriptions"
  add_foreign_key "referrals", "users", column: "referee_id"
  add_foreign_key "referrals", "users", column: "referrer_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscriptions", "users"
end
