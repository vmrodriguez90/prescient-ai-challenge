class CreateInclusionRules < ActiveRecord::Migration[7.1]
  def change
    create_table :inclusion_rules do |t|
      t.string :brand_id, null: false
      t.string :wildcard, null: false
      t.timestamps
    end

    add_index :inclusion_rules, :brand_id
    add_index :inclusion_rules, %i[brand_id wildcard], unique: true
  end
end
