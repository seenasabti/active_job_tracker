class ActiveJobTrackerRecord < ApplicationRecord
  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }
  validates :job_id, presence: true, uniqueness: true
  belongs_to :active_job_trackable, polymorphic: true

  after_update :broadcast_changes, if: -> { ActiveJobTracker.configuration.auto_broadcast }

  # Class-level mutex for thread-safety
  @@mutex = Mutex.new

  def cache_threshold=(value)
    @cache_threshold = value || ActiveJobTracker.configuration.cache_threshold
  end

  def cache_threshold
    @cache_threshold ||= ActiveJobTracker.configuration.cache_threshold
  end

  def progress_cache
    Rails.cache.fetch(progress_cache_key, expires_in: 1.week) { 0 }.to_i
  end

  def progress_cache=(value)
    Rails.cache.write(progress_cache_key, value, expires_in: 1.week)
  end

  def progress_cache_key
    "active_job_tracker:#{self.id}:progress_cache"
  end

  def progress_percentage
    (progress_ratio * 100).to_i
  end

  def duration
    return nil unless started_at
    end_time = completed_at || failed_at || Time.current
    (end_time - started_at).to_f
  end

  def progress_ratio
    return 0.0 if target.to_i.zero?
    [ current.to_f / target.to_f, 1.0 ].min
  end

  def progress(use_cache = true)
    if use_cache
      key = progress_cache_key
      should_flush = false

      @@mutex.synchronize do
        current_value = Rails.cache.fetch(key, expires_in: 1.week) { 0 }.to_i
        new_value = current_value + 1
        Rails.cache.write(key, new_value, expires_in: 1.week)

        should_flush = new_value >= self.cache_threshold
      end

      # Flush outside the mutex to avoid deadlocks
      flush_progress_cache if should_flush
    else
      with_lock do
        self.current += 1
        save!
      end
    end
    self
  end

  def flush_progress_cache
    key = progress_cache_key

    cache_value = 0
    @@mutex.synchronize do
      cache_value = Rails.cache.read(key).to_i
      Rails.cache.delete(key)
    end

    if cache_value > 0
      with_lock do
        self.current += cache_value
        save!
      end
    end
  end

  private

  def broadcast_changes
    broadcast_replace_to(
     "active_job_trackers",
     target: "active_job_tracker_#{self.id}",
     partial: ActiveJobTracker.configuration.default_partial,
     locals: {
      active_job_tracker_record: self
     }
    )
  end
end
