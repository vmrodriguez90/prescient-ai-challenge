class InclusionRule < ApplicationRecord
  has_many :included_campaigns, class_name: 'IncludedCampaign', dependent: :nullify

  validates :brand_id, :wildcard, presence: true
  validates :brand_id, uniqueness: { message: 'already has an inclusion rule' }

  # Returns campaigns whose name matches this rule's wildcard (SQL ILIKE pattern)
  # Examples: "%Search%", "PMAX%", "%Launch"
  def matching_campaigns
    Campaign.where('campaign_name ILIKE ?', wildcard)
  end
end
