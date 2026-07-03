namespace :inclusions do
  desc "Sync campaign_id_inclusions from inclusion_rules wildcards (additive only)"
  task sync: :environment do
    puts "Syncing campaign inclusions from rules..."
    result = InclusionSyncService.call
    puts "Done. Added #{result[:added]} new campaign inclusions."
  end
end
