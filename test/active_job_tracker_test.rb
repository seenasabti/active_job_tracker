require "test_helper"

class ActiveJobTrackerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJobTrackerRecord.any_instance.stubs(:broadcast_replace_to).returns(true)
  end

  test "it has a version number" do
    assert ActiveJobTracker::VERSION
  end

  test "configuration defaults are set correctly" do
    config = ActiveJobTracker.configuration

    assert_equal 100, config.default_target
    assert_equal 10, config.cache_threshold
    assert_equal true, config.auto_broadcast
    assert_equal "active_job_tracker/active_job_tracker", config.default_partial
    assert_equal true, config.include_style
  end

  test "configuration can be modified" do
    original_config = ActiveJobTracker.configuration.dup

    ActiveJobTracker.configure do |config|
      config.default_target = 200
      config.cache_threshold = 5
      config.auto_broadcast = false
      config.default_partial = "custom/partial"
      config.include_style = false
    end

    config = ActiveJobTracker.configuration
    assert_equal 200, config.default_target
    assert_equal 5, config.cache_threshold
    assert_equal false, config.auto_broadcast
    assert_equal "custom/partial", config.default_partial
    assert_equal false, config.include_style

    ActiveJobTracker.configure do |config|
      config.default_target = original_config.default_target
      config.cache_threshold = original_config.cache_threshold
      config.auto_broadcast = original_config.auto_broadcast
      config.default_partial = original_config.default_partial
      config.include_style = original_config.include_style
    end
  end

  test "trackable method raises error when arguments are empty" do
    job = Job.new()
    assert_raises(ArgumentError) do
      job.trackable
    end
  end

  test "trackable method returns first argument" do
    tracked_object = HasTracker.create(name: "tracked_object")
    job = Job.new(tracked_object, "other_arg")
    assert_equal HasTracker, job.trackable.class
  end

  test "job lifecycle methods update tracker status correctly" do
    tracked_object = HasTracker.create(name: "tracked_object")
    job = Job.new(tracked_object)

    job.initialize_tracker
    assert_not_nil tracked_object.job

    assert_equal "pending", tracked_object.job.status

    job.mark_as_running
    assert_equal "running", tracked_object.reload.job.status

    job.active_job_tracker.current = job.active_job_tracker.target
    job.mark_as_completed
    assert_equal "completed", tracked_object.reload.job.status
  end

  test "active_job_tracker_target updates target" do
    tracked_object = HasTracker.create(name: "tracked_object")

    perform_enqueued_jobs do
      Job.perform_later(tracked_object, 12)
    end

    assert_equal 12, tracked_object.job.target
  end

  test "active_job_tracker_progress updates current wihout cache" do
    tracked_object = HasTracker.create(name: "tracked_object")

    perform_enqueued_jobs do
      Job.perform_later(tracked_object, 100, 12, false)
    end

    assert_equal 12, tracked_object.job.current
  end

  test "active_job_tracker_progress updates current with cache" do
    tracked_object = HasTracker.create(name: "tracked_object")

    perform_enqueued_jobs do
      Job.perform_later(tracked_object, 100, 12, true)
    end

    assert_equal 12, tracked_object.job.current
  end

  test "active_job_tracker_log_error updates tracker with error info" do
    tracked_object = HasTracker.create(name: "tracked_object")

    perform_enqueued_jobs do
      assert_raises(StandardError) do
        Job.perform_later(tracked_object, 100, 12, true, true)
      end
    end

    assert_equal "Error Message", tracked_object.job.error
    assert_not_nil tracked_object.job.backtrace
  end
end

class Job < ApplicationJob
  include ActiveJobTracker

  queue_as :default

  def perform(csv_upload, target = 100, progress = 100, use_cache = true, throw_error = false)
    active_job_tracker_target(target)
    (1..progress).each do |_|
      active_job_tracker_progress(cache: use_cache)
      raise StandardError.new("Error Message") if throw_error
    end
  end
end
