class CreateDimCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :dim_campaigns do |t|
      t.string :company_id,    null: false
      t.string :brand_id,      null: false
      t.string :platform_name, null: false
      t.string :campaign_id,   null: false
      t.string :campaign_name, null: false
      t.timestamps
    end

    add_index :dim_campaigns, :brand_id
    add_index :dim_campaigns, :platform_name
    add_index :dim_campaigns, %i[brand_id platform_name]

    # Natural key: a (brand, platform, campaign) is unique in the warehouse.
    add_index :dim_campaigns, %i[brand_id platform_name campaign_id],
              unique: true, name: 'idx_dim_campaigns_natural_key'
    # Target for the composite FK on campaign_id_inclusions — including
    # company_id makes the inclusion's denormalized company provably consistent.
    add_index :dim_campaigns, %i[company_id brand_id platform_name campaign_id],
              unique: true, name: 'idx_dim_campaigns_company_natural_key'
  end
end
