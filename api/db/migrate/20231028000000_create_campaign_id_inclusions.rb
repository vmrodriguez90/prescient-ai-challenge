class CreateCampaignIdInclusions < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_id_inclusions do |t|
      t.string     :brand_id,      null: false
      t.string     :platform_name, null: false
      t.string     :campaign_id,   null: false
      t.references :inclusion_rule, foreign_key: true, null: true
      t.timestamps
    end

    add_index :campaign_id_inclusions,
              [:brand_id, :platform_name, :campaign_id],
              unique: true,
              name: 'idx_inclusions_brand_platform_campaign'
    add_index :campaign_id_inclusions,
              [:brand_id, :platform_name],
              name: 'idx_inclusions_brand_platform'
  end
end
