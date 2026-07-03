module Api
  module V2
    class CampaignsController < ApplicationController

      # GET /api/v2/campaigns
      # Params:
      #   brand_id       - filter by brand
      #   platform_name  - filter by platform
      #   company_id     - filter by company
      #   search         - filter by campaign name (case-insensitive)
      def index
        campaigns = Campaign.where(campaign_id: IncludedCampaign.select(:campaign_id))
        campaigns = campaigns.where(brand_id: params[:brand_id])             if params[:brand_id].present?
        campaigns = campaigns.where(platform_name: params[:platform_name])   if params[:platform_name].present?
        campaigns = campaigns.where(company_id: params[:company_id])         if params[:company_id].present?
        campaigns = campaigns.where('campaign_name ILIKE ?', "%#{params[:search]}%") if params[:search].present?

        result = campaigns.order(:brand_id, :platform_name, :campaign_name)

        render json: {
          campaigns: result.as_json,
          meta: {
            total: result.size
          }
        }
      end

    end
  end
end
