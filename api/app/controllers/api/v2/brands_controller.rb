module Api
  module V2
    class BrandsController < ApplicationController
      class NotOwned < StandardError
        attr_reader :ids
        def initialize(ids)
          @ids = ids
          super("Campaigns not owned by this brand: #{ids.join(', ')}")
        end
      end

      before_action :set_brand_id, only: [:show, :update, :destroy]

      rescue_from NotOwned do |e|
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v2/brands
      def index
        brand_ids = IncludedCampaign.distinct.pluck(:brand_id)
        brands = brand_ids.map { |bid| brand_json(bid) }
        render json: brands
      end

      # GET /api/v2/brands/:brand_id
      def show
        render json: brand_json(@brand_id)
      end

      # POST /api/v2/brands/:brand_id
      def create
        brand_id = params[:brand_id]

        if brand_exists?(brand_id)
          render json: { error: "Brand '#{brand_id}' already exists" }, status: :unprocessable_entity
          return
        end

        unless Campaign.exists?(brand_id: brand_id)
          render json: { error: "Brand '#{brand_id}' does not exist in dim_campaigns" }, status: :unprocessable_entity
          return
        end

        ActiveRecord::Base.transaction do
          set_wildcard(brand_id, brand_params[:wildcard]) if brand_params[:wildcard].present?
          add_campaigns(brand_id, brand_params[:campaigns]) if brand_params[:campaigns].present?
        end

        render json: brand_json(brand_id), status: :created
      end

      # PATCH /api/v2/brands/:brand_id
      def update
        ActiveRecord::Base.transaction do
          set_wildcard(@brand_id, brand_params[:wildcard]) if brand_params[:wildcard].present?
          add_campaigns(@brand_id, brand_params[:campaigns]) if brand_params[:campaigns].present?
        end

        render json: brand_json(@brand_id)
      end

      # DELETE /api/v2/brands/:brand_id
      def destroy
        InclusionRule.where(brand_id: @brand_id).destroy_all
        IncludedCampaign.where(brand_id: @brand_id).delete_all

        head :no_content
      end

      private

      def brand_params
        params.permit(:brand_id, :wildcard, campaigns: [])
      end

      def set_brand_id
        @brand_id = params[:brand_id]

        unless brand_exists?(@brand_id)
          render json: { error: "Brand '#{@brand_id}' not found" }, status: :not_found
        end
      end

      def brand_exists?(brand_id)
        IncludedCampaign.exists?(brand_id: brand_id) || InclusionRule.exists?(brand_id: brand_id)
      end

      def brand_json(brand_id)
        rule = InclusionRule.find_by(brand_id: brand_id)

        campaigns = IncludedCampaign.where(brand_id: brand_id).map do |ic|
          { id: ic.id, company_id: ic.company_id, campaign_id: ic.campaign_id, platform_name: ic.platform_name, inclusion_rule_id: ic.inclusion_rule_id }
        end

        { brand_id: brand_id, inclusion_rule_id: rule&.id, campaigns: campaigns }
      end

      def set_wildcard(brand_id, pattern)
        rule = InclusionRule.find_by(brand_id: brand_id)
        if rule
          rule.update!(wildcard: pattern)
        else
          InclusionRule.create!(brand_id: brand_id, wildcard: pattern)
        end
      end

      def add_campaigns(brand_id, campaign_ids)
        rule = InclusionRule.find_by(brand_id: brand_id)
        ids = Array(campaign_ids).map(&:to_s).uniq

        # A single query is both the ownership check and the platform_name
        # resolution, since (brand_id, campaign_id) is unique in dim_campaigns.
        owned = Campaign.where(brand_id: brand_id, campaign_id: ids).to_a
        unowned = ids - owned.map(&:campaign_id)
        raise NotOwned, unowned if unowned.any?

        owned.each do |campaign|
          IncludedCampaign.find_or_create_by!(
            brand_id: brand_id,
            platform_name: campaign.platform_name,
            campaign_id: campaign.campaign_id
          ) do |ic|
            ic.company_id = campaign.company_id
            ic.inclusion_rule = rule
          end
        end
      end
    end
  end
end
