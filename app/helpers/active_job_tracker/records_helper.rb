module ActiveJobTracker
  module RecordsHelper
    def active_job_tracker_wrapper(options = {}, &block)
      render partial: "active_job_tracker/active_job_tracker_wrapper",
       locals: {
        content: capture(&block),
        options: options
       }
    end
  end
end
