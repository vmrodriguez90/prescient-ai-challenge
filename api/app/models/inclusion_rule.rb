class InclusionRule < ApplicationRecord
  # :destroy, not :nullify — a rule-derived inclusion must die with its rule.
  # Nullifying would set inclusion_rule_id to NULL, which the sync service reads
  # as "manually added, never reconcile", making the row permanent.
  has_many :included_campaigns, class_name: 'IncludedCampaign', dependent: :destroy

  validates :brand_id, :wildcard, presence: true
  validates :brand_id, uniqueness: { message: 'already has an inclusion rule' }

  # Returns campaigns owned by this brand whose name matches the wildcard.
  # Brand-scoped so it mirrors the sync service's join exactly.
  # Examples: "%Search%", "PMAX%", "%Launch"
  def matching_campaigns
    Campaign.where(brand_id: brand_id).where('campaign_name ILIKE ?', wildcard)
  end
end
