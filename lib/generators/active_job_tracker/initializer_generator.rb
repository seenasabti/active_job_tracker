# frozen_string_literal: true

module ActiveJobTracker
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      desc "Creates an initializer file for configuring ActiveJobTracker"

      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "config/initializers/active_job_tracker.rb", "config/initializers/active_job_tracker.rb"
      end
    end
  end
end
