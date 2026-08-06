class InclusionSyncService
  def self.call
    new.call
  end

  # Reconciles rule-derived inclusions with the current inclusion_rules.
  # Two phases in one transaction so live readers never see a window where
  # rows have been deleted but not yet re-inserted.
  #
  # Only rows with inclusion_rule_id IS NOT NULL are the service's to manage.
  # Rows with a NULL rule id are manual/migrated (import_inclusions.py and the
  # v2 brands controller) and are never touched — otherwise the first cron run
  # after deploy would delete the entire migrated payload.
  def call
    ActiveRecord::Base.transaction do
      removed = ActiveRecord::Base.connection.execute(delete_sql).cmd_tuples
      added   = ActiveRecord::Base.connection.execute(insert_sql).ntuples
      { added: added, removed: removed }
    end
  end

  private

  def insert_sql
    <<~SQL
      INSERT INTO campaign_id_inclusions (company_id, brand_id, platform_name, campaign_id, inclusion_rule_id, created_at, updated_at)
      SELECT dc.company_id, ir.brand_id, dc.platform_name, dc.campaign_id, ir.id, NOW(), NOW()
      FROM inclusion_rules ir
      JOIN dim_campaigns dc
        ON dc.brand_id = ir.brand_id
       AND dc.campaign_name ILIKE ir.wildcard
      ON CONFLICT (brand_id, platform_name, campaign_id) DO NOTHING
      RETURNING id
    SQL
  end

  def delete_sql
    <<~SQL
      DELETE FROM campaign_id_inclusions ci
      WHERE ci.inclusion_rule_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM inclusion_rules ir
          JOIN dim_campaigns dc
            ON dc.brand_id = ir.brand_id
           AND dc.campaign_name ILIKE ir.wildcard
          WHERE ir.id = ci.inclusion_rule_id
            AND dc.brand_id      = ci.brand_id
            AND dc.platform_name = ci.platform_name
            AND dc.campaign_id   = ci.campaign_id
        )
    SQL
  end
end
