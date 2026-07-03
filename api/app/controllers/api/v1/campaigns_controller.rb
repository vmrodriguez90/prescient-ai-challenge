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
      def index
        campaigns = Campaign.all
        campaigns = campaigns.where(brand_id: params[:brand_id])       if params[:brand_id].present?
        campaigns = campaigns.where(platform_name: params[:platform_name]) if params[:platform_name].present?
        campaigns = campaigns.where(company_id: params[:company_id])   if params[:company_id].present?
        campaigns = campaigns.where('campaign_name ILIKE ?', "%#{params[:search]}%") if params[:search].present?

        exclusion_map = load_exclusion_config
        excluded_ids = if params[:brand_id].present?
          exclusion_map.fetch(params[:brand_id], [])
        else
          exclusion_map.values.flatten
        end
        campaigns = campaigns.where.not(campaign_id: excluded_ids) if excluded_ids.any?

        result = campaigns.order(:brand_id, :platform_name, :campaign_name)

        render json: {
          campaigns: result.as_json,
          meta: {
            total: result.size
          }
        }
      end

      # GET /api/v1/campaigns/brands
      def brands
        brand_ids = Campaign.distinct.order(:brand_id).pluck(:brand_id)
        rules_by_brand = InclusionRule.order(:wildcard).group_by(&:brand_id)

        brands = brand_ids.map do |brand_id|
          rules = rules_by_brand.fetch(brand_id, [])
          {
            brand_id: brand_id,
            inclusion_rules: rules.map { |r| { id: r.id, wildcard: r.wildcard } }
          }
        end

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
