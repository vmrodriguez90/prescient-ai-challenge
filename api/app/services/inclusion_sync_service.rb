class InclusionSyncService
  def self.call
    new.call
  end

  def call
    result = ActiveRecord::Base.connection.execute(insert_sql)
    { added: result.cmd_tuples }
  end

  private

  def insert_sql
    <<~SQL
      INSERT INTO campaign_id_inclusions (brand_id, platform_name, campaign_id, inclusion_rule_id, created_at, updated_at)
      SELECT DISTINCT ON (ir.brand_id, dc.platform_name, dc.campaign_id)
        ir.brand_id,
        dc.platform_name,
        dc.campaign_id,
        ir.id,
        NOW(),
        NOW()
      FROM inclusion_rules ir
      JOIN dim_campaigns dc ON dc.campaign_name ILIKE ir.wildcard
      ORDER BY ir.brand_id, dc.platform_name, dc.campaign_id, ir.id
      ON CONFLICT (brand_id, platform_name, campaign_id) DO NOTHING
    SQL
  end
end
