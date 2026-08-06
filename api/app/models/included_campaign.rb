class IncludedCampaign < ApplicationRecord
  self.table_name = 'campaign_id_inclusions'

  belongs_to :inclusion_rule, optional: true

  validates :company_id, :brand_id, :platform_name, :campaign_id, presence: true
  validates :campaign_id, uniqueness: { scope: %i[brand_id platform_name] }
  validate :campaign_must_be_owned_by_brand

  # dim_campaigns.campaign_id is not unique on its own (B1/B2/B3 each own a
  # "campaign_1"), so look the source campaign up on the full composite key
  # rather than a `belongs_to` that would resolve to an arbitrary row.
  def campaign
    Campaign.find_by(
      company_id: company_id,
      brand_id: brand_id,
      platform_name: platform_name,
      campaign_id: campaign_id
    )
  end

  private

  def campaign_must_be_owned_by_brand
    return if [company_id, brand_id, platform_name, campaign_id].any?(&:blank?)
    return if Campaign.exists?(
      company_id: company_id,
      brand_id: brand_id,
      platform_name: platform_name,
      campaign_id: campaign_id
    )

    errors.add(:campaign_id, "is not owned by brand #{brand_id}")
  end
end
