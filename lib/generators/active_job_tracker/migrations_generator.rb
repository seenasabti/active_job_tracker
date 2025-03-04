# frozen_string_literal: true

module ActiveJobTracker
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      desc "Creates migration files for ActiveJobTracker"

      source_root File.expand_path("templates", __dir__)

      def copy_migrations
        migration_files = Dir.glob(File.join(self.class.source_root, "migrations", "*.rb"))
        migration_files.each do |file|
          migration_filename = File.basename(file)
          new_filename = "#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_#{migration_filename}"
          copy_file "migrations/#{migration_filename}", "db/migrate/#{new_filename}"
          sleep(1) if migration_files.count > 1
        end
      end
    end
  end
end
