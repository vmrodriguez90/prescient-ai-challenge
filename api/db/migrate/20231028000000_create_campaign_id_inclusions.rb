class CreateCampaignIdInclusions < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_id_inclusions do |t|
      t.string     :company_id,    null: false
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

    # A brand can only include a campaign it actually owns. The composite FK
    # (with company_id) makes cross-brand/cross-company leakage impossible at
    # the DB level. ON DELETE CASCADE: an inclusion is meaningless once its
    # source campaign leaves the dimension.
    add_foreign_key :campaign_id_inclusions, :dim_campaigns,
                    column:      %i[company_id brand_id platform_name campaign_id],
                    primary_key: %i[company_id brand_id platform_name campaign_id],
                    name: 'fk_inclusions_dim_campaigns', on_delete: :cascade
  end
end
