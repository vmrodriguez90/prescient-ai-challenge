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
        campaigns = Campaign.included
        campaigns = campaigns.by_brand(params[:brand_id])       if params[:brand_id].present?
        campaigns = campaigns.by_platform(params[:platform_name]) if params[:platform_name].present?
        campaigns = campaigns.by_company(params[:company_id])    if params[:company_id].present?
        campaigns = campaigns.search(params[:search])           if params[:search].present?

        records = campaigns.order(:brand_id, :platform_name, :campaign_name).to_a

        render json: {
          campaigns: records.as_json,
          meta: {
            total: records.size
          }
        }
      end

    end
  end
end
