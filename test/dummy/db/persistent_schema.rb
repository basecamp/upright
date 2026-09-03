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

ActiveRecord::Schema[8.1].define(version: 2026_09_01_000001) do
  create_table "upright_incident_affected_services", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "service_code", null: false
    t.index ["incident_id", "service_code"], name: "idx_on_incident_id_service_code_188b04aae6", unique: true
    t.index ["incident_id"], name: "index_upright_incident_affected_services_on_incident_id"
    t.index ["service_code"], name: "index_upright_incident_affected_services_on_service_code"
  end

  create_table "upright_incident_automatic_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "incident_id", null: false
    t.string "service_code", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_upright_incident_automatic_reports_on_incident_id", unique: true
    t.index ["service_code"], name: "index_upright_incident_automatic_reports_on_service_code", unique: true
  end

  create_table "upright_incident_updates", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.integer "incident_id", null: false
    t.string "status", null: false
    t.index ["incident_id"], name: "index_upright_incident_updates_on_incident_id"
  end

  create_table "upright_incidents", force: :cascade do |t|
    t.boolean "auto_created", default: false, null: false
    t.datetime "created_at", null: false
    t.string "created_by"
    t.datetime "ends_at"
    t.string "impact", null: false
    t.datetime "last_seen_down_at"
    t.datetime "recovery_started_at"
    t.datetime "resolved_at"
    t.datetime "starts_at", null: false
    t.string "status", null: false
    t.string "title", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.string "updated_by"
    t.index ["resolved_at", "starts_at"], name: "index_upright_incidents_on_resolved_at_and_starts_at"
    t.index ["type", "starts_at"], name: "index_upright_incidents_on_type_and_starts_at"
  end

  create_table "upright_rollups_probe_rollups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "period_start", null: false
    t.string "probe_name", null: false
    t.string "probe_service"
    t.string "probe_target"
    t.string "probe_type"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.float "uptime_fraction", null: false
    t.index ["probe_name", "probe_type", "probe_target", "period_start"], name: "idx_probe_rollups_identity_period", unique: true
    t.index ["probe_service", "period_start"], name: "idx_on_probe_service_period_start_c65e2bccc5"
  end

  add_foreign_key "upright_incident_affected_services", "upright_incidents", column: "incident_id"
  add_foreign_key "upright_incident_automatic_reports", "upright_incidents", column: "incident_id"
  add_foreign_key "upright_incident_updates", "upright_incidents", column: "incident_id"
end
