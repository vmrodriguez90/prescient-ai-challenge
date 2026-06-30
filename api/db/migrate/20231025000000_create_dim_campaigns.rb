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
  end
end
