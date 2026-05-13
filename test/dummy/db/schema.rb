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

ActiveRecord::Schema[8.1].define(version: 2026_05_12_000001) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "upright_probe_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "duration"
    t.string "probe_name"
    t.string "probe_service"
    t.string "probe_target"
    t.string "probe_type"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_upright_probe_results_on_created_at"
    t.index ["probe_name"], name: "index_upright_probe_results_on_probe_name"
    t.index ["probe_type"], name: "index_upright_probe_results_on_probe_type"
    t.index ["status"], name: "index_upright_probe_results_on_status"
  end

  create_table "upright_rollups_probe_rollups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "period_start", null: false
    t.string "probe_name", null: false
    t.string "probe_service"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.float "uptime_fraction", null: false
    t.index ["probe_name", "period_start"], name: "idx_on_probe_name_period_start_3a6029f64e", unique: true
    t.index ["probe_service", "period_start"], name: "idx_on_probe_service_period_start_c65e2bccc5"
  end

  create_table "upright_rollups_service_rollups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "period_start", null: false
    t.string "service_code", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.float "uptime_fraction", null: false
    t.index ["service_code", "period_start"], name: "idx_on_service_code_period_start_610d020d62", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
