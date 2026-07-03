class IncludedCampaign < ApplicationRecord
  self.table_name = 'campaign_id_inclusions'

  belongs_to :inclusion_rule, optional: true
  belongs_to :campaign, primary_key: :campaign_id, foreign_key: :campaign_id
end
