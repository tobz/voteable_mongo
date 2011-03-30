namespace :db do
  namespace :mongoid do
    namespace :voteable do
      desc 'Update up_votes_count, down_votes_count, votes_count and votes_point'
      task :remake_stats => :environment do
        Mongoid::Voteable::Stats.remake(:log)
      end
    end
  end
end
