module Rails #:nodoc:
  module VoteableMongo #:nodoc:
    class Railtie < Rails::Railtie #:nodoc:

      initializer "preload all application models" do |app|
        config.to_prepare do
          if defined?(Mongoid)
            ::Rails::Mongoid.load_models(app)
          end
        end
      end

      rake_tasks do
        load 'voteable_mongo/railties/database.rake'
      end

    end
  end
end
