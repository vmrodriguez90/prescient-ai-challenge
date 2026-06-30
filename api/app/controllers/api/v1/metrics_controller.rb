module Api
  module V1
    class MetricsController < ApplicationController
      include ExclusionConfigurable

      # GET /api/v1/metrics
      # Params:
      #   brand_id       - filter by brand
      #   platform_name  - filter by platform
      #   apply_config   - "true" to exclude campaigns in the exclusion config
      #   date_from      - start date (YYYY-MM-DD), defaults to 30 days ago
      #   date_to        - end date   (YYYY-MM-DD), defaults to today
      def index
        full_exclusion_map = load_exclusion_config
        apply_config       = params[:apply_config] == 'true'
        exclusion_brand    = params[:exclusion_brand]

        exclusion_map = if exclusion_brand.present?
          full_exclusion_map.slice(exclusion_brand)
        else
          full_exclusion_map
        end

        date_range = CampaignMetric.select('MIN(date) AS min_date, MAX(date) AS max_date').take
        date_from = parse_date(params[:date_from]) || date_range&.min_date || 30.days.ago.to_date
        date_to   = parse_date(params[:date_to])   || date_range&.max_date || Date.today

        metrics = CampaignMetric
          .with_campaign_info(exclusion_map: exclusion_map, apply_config: apply_config)
          .for_period(date_from, date_to)

        metrics = metrics.for_brand(params[:brand_id])       if params[:brand_id].present?
        metrics = metrics.for_platform(params[:platform_name]) if params[:platform_name].present?

        # Aggregate by campaign
        aggregated = metrics
          .group('campaign_metrics.company_id', 'campaign_metrics.brand_id', 'campaign_metrics.platform_name', 'campaign_metrics.campaign_id', 'dc.campaign_name')
          .select(
            'campaign_metrics.company_id', 'campaign_metrics.brand_id', 'campaign_metrics.platform_name', 'campaign_metrics.campaign_id', 'dc.campaign_name',
            'SUM(impressions) AS total_impressions',
            'SUM(clicks)      AS total_clicks',
            'SUM(spend)       AS total_spend',
            'SUM(conversions) AS total_conversions',
            'ROUND(SUM(clicks)::numeric / NULLIF(SUM(impressions), 0) * 100, 2) AS ctr',
            'ROUND(SUM(spend)::numeric  / NULLIF(SUM(clicks), 0), 2)            AS cpc',
            'ROUND(SUM(conversions)::numeric / NULLIF(SUM(clicks), 0) * 100, 2) AS cvr'
          )
          .order(:brand_id, :platform_name, :campaign_id)
          .map(&:attributes)

        render json: {
          metrics: aggregated,
          meta: {
            total_campaigns: aggregated.size,
            date_from:       date_from,
            date_to:         date_to,
            config_applied:  apply_config,
            totals: {
              impressions: aggregated.sum { |r| r['total_impressions'].to_i },
              clicks:      aggregated.sum { |r| r['total_clicks'].to_i },
              spend:       aggregated.sum { |r| r['total_spend'].to_f }.round(2),
              conversions: aggregated.sum { |r| r['total_conversions'].to_i }
            }
          }
        }
      end

      private

      def parse_date(str)
        return nil if str.blank?
        Date.parse(str)
      rescue ArgumentError
        nil
      end
    end
  end
end
