# frozen_string_literal: true

module ActiveJobTracker
  # Configuration options for ActiveJobTracker
  class Configuration
    # Default target value for jobs
    # @return [Integer]
    attr_accessor :default_target

    # Default cache threshold for progress updates
    # @return [Integer]
    attr_accessor :cache_threshold

    # Whether to automatically broadcast changes
    # @return [Boolean]
    attr_accessor :auto_broadcast

    # Default partial path for rendering job trackers
    # @return [String]
    attr_accessor :default_partial

    # Whether to raise an error when progress increments the current value beyond the target value
    # @return [Boolean]
    attr_accessor :raise_error_when_target_exceeded

    # Whether to include the style in the job tracker
    # @return [Boolean]
    attr_accessor :include_style

    # The turbo stream channel to use for broadcasting job tracker updates
    # @return [String]
    attr_accessor :turbo_stream_channel

    # Initialize with default values
    def initialize
      @default_target = 100
      @cache_threshold = 10
      @auto_broadcast = true
      @raise_error_when_target_exceeded = false
      @default_partial = "active_job_tracker/active_job_tracker"
      @include_style = true
      @turbo_stream_channel = "Turbo::StreamsChannel"
    end
  end
end
