# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
require "rails/test_help"
require "mocha/minitest"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

ActiveRecord::Base.connection.create_table :active_job_tracker_records, force: true do |t|
  t.belongs_to :active_job_trackable, polymorphic: true, index: { name: "index_active_job_tracker_records_on_active_job_trackable" }

  t.string :job_id, null: false, index: true
  t.integer :status, default: 0, null: false
  t.integer :current, default: 0, null: false
  t.integer :target, default: 100, null: false

  t.text :error
  t.text :backtrace

  t.datetime :started_at
  t.datetime :failed_at
  t.datetime :completed_at

  t.timestamps
end

ActiveRecord::Base.connection.create_table :has_trackers, force: true do |t|
  t.string :name
  t.timestamps
end
