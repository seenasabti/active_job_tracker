require "active_job_tracker/version"
require "active_job_tracker/engine"
require "active_job_tracker/configuration"

module ActiveJobTracker
  extend ActiveSupport::Concern

  class Error < StandardError
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  included do
    before_enqueue :initialize_tracker
    before_perform :mark_as_running
    after_perform :mark_as_completed

    rescue_from(Exception) do |exception|
      active_job_tracker_log_error(exception)
      raise exception
    end
  end

  def active_job_tracker_cache_threshold(value)
    active_job_tracker.cache_threshold = value
  end

  def active_job_tracker_target(target)
    active_job_tracker.update(target: target)
  end

  def active_job_tracker_progress(cache: false)
    active_job_tracker.progress(cache)
  end

  def active_job_tracker_log_error(exception)
    active_job_tracker.update(
     status: "failed",
     failed_at: Time.current,
     error: exception.message,
     backtrace: exception.backtrace&.join("\n").to_s.truncate(1000)
    )
  end

  def active_job_tracker
    @active_job_tracker ||= ::ActiveJobTrackerRecord.find_or_create_by(job_id: job_id, active_job_trackable: trackable)
  end

  def trackable
    raise ArgumentError, "Trackable object is required as the first argument." if arguments.empty?
    arguments.first
  end

  def initialize_tracker
    active_job_tracker.update(
     status: "pending",
     started_at: nil,
     completed_at: nil,
     target: ActiveJobTracker.configuration.default_target,
     current: 0
    )
  end

  def mark_as_running
    active_job_tracker.update(status: "running", started_at: Time.current)
  end

  def mark_as_completed
    active_job_tracker.flush_progress_cache
    if active_job_tracker.current == active_job_tracker.target
      active_job_tracker.update(status: "completed", completed_at: Time.current)
    end
  end
end
