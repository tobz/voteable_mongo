module Rails #:nodoc:
  module VoteableMongoid #:nodoc:
    class Railtie < Rails::Railtie #:nodoc:

      rake_tasks do
        load "voteable_mongoid/railties/database.rake"
      end

    end
  end
end
