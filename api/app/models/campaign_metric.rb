class CampaignMetric < ApplicationRecord
  self.table_name = 'campaign_metrics'

  belongs_to :campaign,
    primary_key: :campaign_id,
    foreign_key: :campaign_id,
    class_name:  'Campaign'

  scope :for_brand,    ->(id)       { where(brand_id: id) }
  scope :for_platform, ->(platform) { where(platform_name: platform) }
  scope :for_period,   ->(from, to) { where(date: from..to) }

  # Returns metrics joined with dim_campaigns, excluding campaigns in the
  # exclusion config for each brand when apply_config: true.
  def self.with_campaign_info(exclusion_map: {}, apply_config: false)
    query = joins(
      "INNER JOIN dim_campaigns dc
         ON dc.campaign_id   = campaign_metrics.campaign_id
        AND dc.brand_id      = campaign_metrics.brand_id
        AND dc.platform_name = campaign_metrics.platform_name"
    )

    if apply_config && exclusion_map.any?
      exclusion_map.each do |brand_id, excluded_ids|
        next if excluded_ids.empty?
        query = query.where(
          "NOT (campaign_metrics.brand_id = ? AND campaign_metrics.campaign_id IN (?))",
          brand_id, excluded_ids
        )
      end
    end

    query
  end
end
