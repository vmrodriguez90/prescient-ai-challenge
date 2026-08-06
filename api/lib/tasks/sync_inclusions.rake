namespace :inclusions do
  desc "Sync campaign_id_inclusions from inclusion_rules wildcards (adds + removes stale rows)"
  task sync: :environment do
    puts "Syncing campaign inclusions from rules..."
    result = InclusionSyncService.call
    puts "Done. Added #{result[:added]}, removed #{result[:removed]} campaign inclusions."
  end
end
