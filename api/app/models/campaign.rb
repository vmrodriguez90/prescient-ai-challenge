class Campaign < ApplicationRecord
  self.table_name = 'dim_campaigns'

  validates :company_id, :brand_id, :platform_name, :campaign_id, :campaign_name, presence: true

  scope :by_brand,    ->(id)       { where(brand_id: id) }
  scope :by_company,  ->(id)       { where(company_id: id) }
  scope :by_platform, ->(platform) { where(platform_name: platform) }
  scope :search,      ->(term)     { where('campaign_name ILIKE ?', "%#{term}%") }

  # Campaigns that appear in campaign_id_inclusions, matched on the full
  # ownership key. EXISTS (not a join) so it can never widen the result set.
  scope :included, -> {
    where(
      IncludedCampaign
        .where('campaign_id_inclusions.brand_id      = dim_campaigns.brand_id')
        .where('campaign_id_inclusions.platform_name = dim_campaigns.platform_name')
        .where('campaign_id_inclusions.campaign_id   = dim_campaigns.campaign_id')
        .arel.exists
    )
  }
end
