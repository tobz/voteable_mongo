module Rails #:nodoc:
  module VoteableMongoid #:nodoc:
    class Railtie < Rails::Railtie #:nodoc:

      initializer "preload all application models" do |app|
        config.to_prepare do
          ::Rails::Mongoid.load_models(app)
        end
      end

      rake_tasks do
        load 'voteable_mongoid/railties/database.rake'
      end

    end
  end
end
