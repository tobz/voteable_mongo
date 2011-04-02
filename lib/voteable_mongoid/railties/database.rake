namespace :db do
  namespace :mongoid do
    namespace :voteable do
      desc 'Update up_votes_count, down_votes_count, votes_count and votes_point'
      task :remake_stats => :environment do
        Mongoid::Voteable::Stats.remake(:log)
      end
      
      desc 'Set counters and point to 0 for uninitizized voteable objects'
      task :init_stats => :environment do
        Mongoid::Voteable::Stats.init(:log)
      end
      
      desc 'Migrate vote data created by version < 0.7.0 to new vote data storage'
      task :migrate_old_votes => :environment do
        Mongoid::Voteable.migrate_old_votes(:log)
      end
    end
  end
end
