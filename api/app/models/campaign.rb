class Campaign < ApplicationRecord
  self.table_name = 'dim_campaigns'

  validates :company_id, :brand_id, :platform_name, :campaign_id, :campaign_name, presence: true

  scope :by_brand,    ->(id)       { where(brand_id: id) }
  scope :by_platform, ->(platform) { where(platform_name: platform) }
  scope :search,      ->(term)     { where('campaign_name ILIKE ?', "%#{term}%") }
end
