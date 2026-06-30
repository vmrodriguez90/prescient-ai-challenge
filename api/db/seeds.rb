require 'csv'

# ── dim_campaigns ────────────────────────────────────────────────────────────

csv_path = Rails.root.join('data', 'dim_campaign.csv')

unless File.exist?(csv_path)
  puts "  Skipping seeds: #{csv_path} not found."
  return
end

if Campaign.any?
  puts "  dim_campaigns already seeded (#{Campaign.count} rows). Skipping."
else
  count = 0
  CSV.foreach(csv_path, headers: true) do |row|
    Campaign.create!(
      company_id:    row['company_id'],
      brand_id:      row['brand_id'],
      platform_name: row['platform_name'],
      campaign_id:   row['campaign_id'],
      campaign_name: row['campaign_name'],
      created_at:    row['created_at'],
      updated_at:    row['updated_at']
    )
    count += 1
  end
  puts "  Seeded #{count} campaigns."
end

# ── campaign_metrics ─────────────────────────────────────────────────────────

if CampaignMetric.any?
  puts "  campaign_metrics already seeded (#{CampaignMetric.count} rows). Skipping."
else
  # Daily metric ranges per platform — loosely based on real-world ad benchmarks
  PLATFORM_RANGES = {
    'facebook_ads'  => { impressions: 5_000..40_000, ctr: 0.01..0.03,  cpc: 0.80..2.50,  cvr: 0.02..0.06 },
    'google_ads'    => { impressions: 2_000..15_000, ctr: 0.04..0.09,  cpc: 1.50..5.00,  cvr: 0.04..0.10 },
    'pinterest_ads' => { impressions: 8_000..60_000, ctr: 0.003..0.01, cpc: 0.30..1.20,  cvr: 0.01..0.03 },
  }.freeze

  DEFAULT_RANGE = { impressions: 3_000..20_000, ctr: 0.02..0.05, cpc: 1.00..3.00, cvr: 0.02..0.05 }.freeze

  def self.rand_in(range) = rand * (range.max - range.min) + range.min

  campaigns = Campaign.all
  days       = 30
  start_date = Date.new(2024, 1, 1)

  rows = []
  campaigns.each do |c|
    ranges = PLATFORM_RANGES.fetch(c.platform_name, DEFAULT_RANGE)

    days.times do |i|
      impressions = rand(ranges[:impressions])
      clicks      = (impressions * rand_in(ranges[:ctr])).round
      spend       = (clicks * rand_in(ranges[:cpc])).round(2)
      conversions = (clicks * rand_in(ranges[:cvr])).round

      rows << {
        company_id:    c.company_id,
        brand_id:      c.brand_id,
        platform_name: c.platform_name,
        campaign_id:   c.campaign_id,
        date:          start_date + i,
        impressions:   impressions,
        clicks:        clicks,
        spend:         spend,
        conversions:   conversions,
        created_at:    Time.now,
        updated_at:    Time.now
      }
    end
  end

  # Bulk insert for speed
  rows.each_slice(500) { |batch| CampaignMetric.insert_all(batch) }

  puts "  Seeded #{rows.size} campaign metric rows (#{campaigns.count} campaigns × #{days} days)."
end
