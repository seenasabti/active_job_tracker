require "test_helper"

class ActiveJobTrackerRecordTest < ActiveSupport::TestCase
  setup do
    @trackable = HasTracker.create(name: "Test User")
    @record = ActiveJobTrackerRecord.create(
     job_id: "test_job_id",
     active_job_trackable: @trackable,
     status: :pending,
     current: 0,
     target: 100
    )
    ActiveJobTrackerRecord.any_instance.stubs(:broadcast_replace_to).returns(true)

    # Clear the cache for this record
    Rails.cache.clear
  end

  teardown do
    # Clean up cache after each test
    Rails.cache.clear
  end

  test "validations" do
    # Job ID is required
    invalid_record = ActiveJobTrackerRecord.new(
     active_job_trackable: @trackable,
     status: :pending
    )
    assert_not invalid_record.valid?
    assert_includes invalid_record.errors[:job_id], "can't be blank"

    # Job ID must be unique
    duplicate_record = ActiveJobTrackerRecord.new(
     job_id: "test_job_id",
     active_job_trackable: @trackable,
     status: :pending
    )
    assert_not duplicate_record.valid?
    assert_includes duplicate_record.errors[:job_id], "has already been taken"
  end

  test "status enum works correctly" do
    @record.status = :pending
    assert @record.pending?
    assert_not @record.running?

    @record.status = :running
    assert @record.running?
    assert_not @record.pending?

    @record.status = :completed
    assert @record.completed?
    assert_not @record.running?

    @record.status = :failed
    assert @record.failed?
    assert_not @record.completed?
  end

  test "cache_threshold defaults to configuration value" do
    assert_equal ActiveJobTracker.configuration.cache_threshold, @record.cache_threshold
  end

  test "cache_threshold can be overridden" do
    @record.cache_threshold = 20
    assert_equal 20, @record.cache_threshold

    # Setting to nil should revert to default
    @record.cache_threshold = nil
    assert_equal ActiveJobTracker.configuration.cache_threshold, @record.cache_threshold
  end

  test "progress_cache defaults to zero" do
    assert_equal 0, @record.progress_cache
  end

  test "progress_cache can be set and retrieved" do
    @record.progress_cache = 5
    assert_equal 5, @record.progress_cache
  end

  test "progress_cache_key is unique per record" do
    assert_equal "active_job_tracker:#{@record.id}:progress_cache", @record.progress_cache_key
  end

  test "progress_percentage calculates correctly" do
    @record.current = 0
    @record.target = 100
    assert_equal 0, @record.progress_percentage

    @record.current = 25
    assert_equal 25, @record.progress_percentage

    @record.current = 50
    assert_equal 50, @record.progress_percentage

    @record.current = 100
    assert_equal 100, @record.progress_percentage

    # Should cap at 100%
    @record.current = 150
    assert_equal 100, @record.progress_percentage
  end

  test "duration calculates correctly" do
    # No started_at should return nil
    @record.started_at = nil
    assert_nil @record.duration

    # With started_at but no completed_at, should use current time
    now = Time.current
    @record.started_at = now - 10.seconds
    @record.completed_at = nil

    # Use a range to account for slight timing differences
    assert_in_delta 10.0, @record.duration, 1.0

    # With completed_at, should use that time
    @record.started_at = now - 20.seconds
    @record.completed_at = now - 10.seconds
    assert_equal 10.0, @record.duration
  end

  test "progress_ratio calculates correctly" do
    @record.current = 0
    @record.target = 100
    assert_equal 0.0, @record.progress_ratio

    @record.current = 25
    assert_equal 0.25, @record.progress_ratio

    @record.current = 50
    assert_equal 0.5, @record.progress_ratio

    @record.current = 100
    assert_equal 1.0, @record.progress_ratio

    # Should cap at 1.0
    @record.current = 150
    assert_equal 1.0, @record.progress_ratio

    # Should handle zero target
    @record.target = 0
    assert_equal 0.0, @record.progress_ratio
  end

  test "progress with cache increments progress_cache" do
    assert_equal 0, @record.progress_cache

    @record.progress
    assert_equal 1, @record.progress_cache

    @record.progress
    assert_equal 2, @record.progress_cache
  end

  test "progress flushes cache when threshold is reached" do
    @record.cache_threshold = 3
    @record.current = 0
    @record.progress_cache = 0

    @record.progress
    assert_equal 1, @record.progress_cache
    assert_equal 0, @record.current

    @record.progress
    assert_equal 2, @record.progress_cache
    assert_equal 0, @record.current

    # This should trigger a flush
    @record.progress
    assert_equal 0, @record.progress_cache
    assert_equal 3, @record.current
  end

  test "progress without cache updates current directly" do
    @record.current = 0

    @record.progress(false)
    assert_equal 0, @record.progress_cache
    assert_equal 1, @record.current

    @record.progress(false)
    assert_equal 0, @record.progress_cache
    assert_equal 2, @record.current
  end

  test "flush_progress_cache updates current and resets cache" do
    @record.current = 5
    @record.progress_cache = 3
    @record.save

    @record.flush_progress_cache
    assert_equal 0, @record.progress_cache
    assert_equal 8, @record.current

    # Should do nothing if progress_cache is zero
    @record.current = 10
    @record.progress_cache = 0
    @record.save

    @record.flush_progress_cache
    assert_equal 0, @record.progress_cache
    assert_equal 10, @record.current
  end

  test "broadcast_changes is called after update when auto_broadcast is true" do
    original_auto_broadcast = ActiveJobTracker.configuration.auto_broadcast
    ActiveJobTracker.configuration.auto_broadcast = true

    @record.expects(:broadcast_changes)
    @record.update(status: :running)

    # Reset configuration
    ActiveJobTracker.configuration.auto_broadcast = original_auto_broadcast
  end

  test "progress is thread-safe with Rails.cache" do
    # Set up a record with a clean cache
    @record.current = 0
    @record.progress_cache = 0
    @record.cache_threshold = 100 # Set threshold to 100

    # Create multiple threads that increment the progress
    threads = []
    thread_count = 10
    increments_per_thread = 20

    thread_count.times do |i|
      threads << Thread.new do
        increments_per_thread.times do |j|
          @record.progress(true)
          puts "Thread #{i} increment #{j}: cache=#{@record.progress_cache}, current=#{@record.current}" if ENV["DEBUG"]
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    # Debug output
    puts "After all threads: cache=#{@record.reload.progress_cache}, current=#{@record.current}" if ENV["DEBUG"]

    # Verify that all increments were counted
    total_expected = thread_count * increments_per_thread
    actual_progress = @record.reload.progress_cache + @record.current
    assert_equal total_expected, actual_progress, "Expected total progress (cache + current) to be #{total_expected}, but got #{actual_progress} (cache: #{@record.progress_cache}, current: #{@record.current})"

    # Flush the cache and verify the current value
    @record.flush_progress_cache

    # Debug output
    # puts "After flush: cache=#{@record.progress_cache}, current=#{@record.current}" if ENV["DEBUG"]

    assert_equal total_expected, @record.current
    # Verify that the cache is completely deleted, not just set to 0
    assert_nil Rails.cache.read(@record.progress_cache_key)
  end
end
