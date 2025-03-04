module ActiveJobTracker
  class Engine < ::Rails::Engine
    isolate_namespace ActiveJobTracker

    generators do
      require "generators/active_job_tracker/initializer_generator"
      require "generators/active_job_tracker/migrations_generator"
    end

    initializer "active_job_tracker.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper ActiveJobTracker::RecordsHelper
      end
    end
  end
end
