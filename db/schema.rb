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

ActiveRecord::Schema[7.0].define(version: 2024_05_23_105211) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "collections", force: :cascade do |t|
    t.datetime "time"
    t.string "kiki_note"
    t.string "alfred_message", default: "N/A"
    t.integer "bags"
    t.bigint "subscription_id", null: false
    t.boolean "is_done", default: false, null: false
    t.boolean "skip", default: false, null: false
    t.integer "needs_bags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "drivers_day_id"
    t.datetime "date"
    t.boolean "new_customer", default: false
    t.float "buckets"
    t.integer "dropped_off_buckets"
    t.integer "soil_bag", default: 0
    t.index ["drivers_day_id"], name: "index_collections_on_drivers_day_id"
    t.index ["subscription_id"], name: "index_collections_on_subscription_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.string "name"
    t.string "phone_number"
    t.string "email"
    t.boolean "is_available", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subscription_id"], name: "index_contacts_on_subscription_id"
  end

  create_table "drivers_days", force: :cascade do |t|
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "note"
    t.bigint "user_id", null: false
    t.integer "total_buckets"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "date"
    t.datetime "sfl_time"
    t.integer "start_kms"
    t.integer "end_kms"
    t.string "message_from_alfred"
    t.index ["user_id"], name: "index_drivers_days_on_user_id"
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
    t.datetime "holiday_start"
    t.datetime "holiday_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "collection_order"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "testimonials", force: :cascade do |t|
    t.string "content"
    t.integer "raking"
    t.bigint "user_id"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "collections", "drivers_days"
  add_foreign_key "collections", "subscriptions"
  add_foreign_key "contacts", "subscriptions"
  add_foreign_key "drivers_days", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "testimonials", "users"
end
