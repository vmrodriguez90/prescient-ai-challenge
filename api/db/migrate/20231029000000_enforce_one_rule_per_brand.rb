class EnforceOneRulePerBrand < ActiveRecord::Migration[7.1]
  def up
    # Keep only the first rule per brand, remove duplicates
    execute <<~SQL
      DELETE FROM inclusion_rules
      WHERE id NOT IN (
        SELECT MIN(id) FROM inclusion_rules GROUP BY brand_id
      )
    SQL

    remove_index :inclusion_rules, :brand_id
    remove_index :inclusion_rules, %i[brand_id wildcard]
    add_index :inclusion_rules, :brand_id, unique: true, name: 'idx_inclusion_rules_brand_id_unique'
  end

  def down
    remove_index :inclusion_rules, name: 'idx_inclusion_rules_brand_id_unique'
    add_index :inclusion_rules, :brand_id
    add_index :inclusion_rules, %i[brand_id wildcard], unique: true
  end
end
