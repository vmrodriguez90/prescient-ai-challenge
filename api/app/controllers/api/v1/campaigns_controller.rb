module Api
  module V1
    class CampaignsController < ApplicationController
      include ExclusionConfigurable

      # GET /api/v1/campaigns
      # Params:
      #   brand_id       - filter by brand
      #   platform_name  - filter by platform
      #   company_id     - filter by company
      #   search         - filter by campaign name (case-insensitive)
      #   apply_config   - "true" to hide excluded campaigns
      def index
        campaigns = Campaign.all
        campaigns = campaigns.where(brand_id: params[:brand_id])       if params[:brand_id].present?
        campaigns = campaigns.where(platform_name: params[:platform_name]) if params[:platform_name].present?
        campaigns = campaigns.where(company_id: params[:company_id])   if params[:company_id].present?
        campaigns = campaigns.where('campaign_name ILIKE ?', "%#{params[:search]}%") if params[:search].present?

        exclusion_map = load_exclusion_config
        apply_config    = params[:apply_config] == 'true'
        exclusion_brand = params[:exclusion_brand]

        active_exclusions = if exclusion_brand.present?
          exclusion_map.slice(exclusion_brand)
        else
          exclusion_map
        end

        result = campaigns.order(:brand_id, :platform_name, :campaign_name).map do |c|
          excluded = active_exclusions.fetch(c.brand_id, []).include?(c.campaign_id)
          c.as_json.merge('excluded' => excluded)
        end

        result = result.reject { |c| c['excluded'] } if apply_config

        render json: {
          campaigns: result,
          meta: {
            total: result.size,
            config_applied: apply_config
          }
        }
      end

      # GET /api/v1/campaigns/brands
      def brands
        brands = Campaign.distinct.order(:brand_id).pluck(:brand_id)
        render json: { brands: brands }
      end

      # GET /api/v1/campaigns/exclusion_brands
      def exclusion_brands
        config = load_exclusion_config
        render json: { brands: config.keys.sort }
      end

      # GET /api/v1/campaigns/platforms
      def platforms
        platforms = Campaign.distinct.order(:platform_name).pluck(:platform_name)
        render json: { platforms: platforms }
      end

    end
  end
end
