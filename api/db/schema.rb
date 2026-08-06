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

ActiveRecord::Schema[7.1].define(version: 2023_10_28_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "campaign_id_inclusions", force: :cascade do |t|
    t.string "company_id", null: false
    t.string "brand_id", null: false
    t.string "platform_name", null: false
    t.string "campaign_id", null: false
    t.bigint "inclusion_rule_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "platform_name", "campaign_id"], name: "idx_inclusions_brand_platform_campaign", unique: true
    t.index ["brand_id", "platform_name"], name: "idx_inclusions_brand_platform"
    t.index ["inclusion_rule_id"], name: "index_campaign_id_inclusions_on_inclusion_rule_id"
  end

  create_table "dim_campaigns", force: :cascade do |t|
    t.string "company_id", null: false
    t.string "brand_id", null: false
    t.string "platform_name", null: false
    t.string "campaign_id", null: false
    t.string "campaign_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "platform_name", "campaign_id"], name: "idx_dim_campaigns_natural_key", unique: true
    t.index ["brand_id", "platform_name"], name: "index_dim_campaigns_on_brand_id_and_platform_name"
    t.index ["brand_id"], name: "index_dim_campaigns_on_brand_id"
    t.index ["company_id", "brand_id", "platform_name", "campaign_id"], name: "idx_dim_campaigns_company_natural_key", unique: true
    t.index ["platform_name"], name: "index_dim_campaigns_on_platform_name"
  end

  create_table "inclusion_rules", force: :cascade do |t|
    t.string "brand_id", null: false
    t.string "wildcard", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "idx_inclusion_rules_brand_id_unique", unique: true
  end

  add_foreign_key "campaign_id_inclusions", "dim_campaigns", column: ["company_id", "brand_id", "platform_name", "campaign_id"], primary_key: ["company_id", "brand_id", "platform_name", "campaign_id"], name: "fk_inclusions_dim_campaigns", on_delete: :cascade
  add_foreign_key "campaign_id_inclusions", "inclusion_rules"
end
