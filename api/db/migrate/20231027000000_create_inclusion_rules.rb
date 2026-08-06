class CreateInclusionRules < ActiveRecord::Migration[7.1]
  def change
    create_table :inclusion_rules do |t|
      t.string :brand_id, null: false
      t.string :wildcard, null: false
      t.timestamps
    end

    # One inclusion rule per brand, so brand_id itself is unique.
    add_index :inclusion_rules, :brand_id, unique: true, name: 'idx_inclusion_rules_brand_id_unique'
  end
end
