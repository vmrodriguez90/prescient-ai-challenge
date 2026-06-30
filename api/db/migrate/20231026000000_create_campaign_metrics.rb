class CreateCampaignMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_metrics do |t|
      t.string  :company_id,    null: false
      t.string  :brand_id,      null: false
      t.string  :platform_name, null: false
      t.string  :campaign_id,   null: false
      t.date    :date,          null: false
      t.integer :impressions,   null: false, default: 0
      t.integer :clicks,        null: false, default: 0
      t.decimal :spend,         null: false, default: 0, precision: 10, scale: 2
      t.integer :conversions,   null: false, default: 0
      t.timestamps
    end

    add_index :campaign_metrics, %i[brand_id platform_name campaign_id]
    add_index :campaign_metrics, :date
    add_index :campaign_metrics, %i[brand_id date]
  end
end
