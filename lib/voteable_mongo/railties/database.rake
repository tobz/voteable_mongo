namespace :mongo do
  namespace :voteable do
    desc 'Update up_votes_count, down_votes_count, votes_count and votes_point'
    task :remake_stats => :environment do
      Mongo::Voteable::Tasks.remake_stats(:log)
    end
    
    desc 'Set counters and points to 0 for klass. Usage: rake mongo:voteable:reset_stats[klass]'
    task :reset_stats, :klass => :environment do |t, args|
      klass = args[:klass]
      klass = klass.classify.constantize
      raise "This klass should be Voteable" unless klass.ancestors.include? Mongo::Voteable
      Mongo::Voteable::Tasks.reset_stats(klass, :log)
    end

    desc 'Set counters and point to 0 for uninitizized voteable objects'
    task :init_stats => :environment do
      Mongo::Voteable::Tasks.init_stats(:log)
    end

    desc 'Migrate vote data created by version < 0.7.0 to new vote data storage'
    task :migrate_old_votes => :environment do
      Mongo::Voteable::Tasks.migrate_old_votes(:log)
    end
  end
end
