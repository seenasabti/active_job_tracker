class ActiveJobTrackerRecord < ApplicationRecord
  attr_accessor :progress_cache

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }
  validates :job_id, presence: true, uniqueness: true
  belongs_to :active_job_trackable, polymorphic: true

  after_update :broadcast_changes, if: -> { ActiveJobTracker.configuration.auto_broadcast }

  def cache_threshold=(value)
    @cache_threshold = value || ActiveJobTracker.configuration.cache_threshold
  end

  def cache_threshold
    @cache_threshold ||= ActiveJobTracker.configuration.cache_threshold
  end

  def progress_cache
    @progress_cache ||= 0
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
      self.progress_cache = self.progress_cache + 1
      flush_progress_cache if self.progress_cache >= self.cache_threshold
    else
      with_lock do
        self.current = self.current + 1
        save
      end
    end
    self
  end

  def flush_progress_cache
    return if self.progress_cache.zero?
    with_lock do
      self.current = self.current + self.progress_cache
      save
    end
    @progress_cache = 0
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
