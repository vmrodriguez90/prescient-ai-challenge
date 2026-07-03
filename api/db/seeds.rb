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