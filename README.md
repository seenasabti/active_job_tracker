# ActiveJobTracker

ActiveJobTracker provides persisted, real-time tracking and monitoring of ActiveJob jobs in Ruby on Rails applications. It allows you to track job status, progress, and errors with a simple API and real-time UI updates via ActionCable.

<img width="796" alt="Screenshot 2025-03-04 at 1 09 38 PM" src="https://github.com/user-attachments/assets/d34e6fb8-bb3c-4d71-a737-2f7597a23c43" />

## Features

- Track job status (pending, running, completed, failed)
- Monitor job progress with percentage completion
- Real-time UI updates via ActionCable
- Error tracking and reporting
- Efficient progress caching to minimize database updates
- Configurable options

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_job_tracker'
```

And then execute:

```bash
bundle install
```

After installation, run the generators to set up the gem:

```bash
# Create the necessary database migrations
rails generate active_job_tracker:migrations

# Run the migrations
rails db:migrate

# Generate the configuration initializer (optional)
rails generate active_job_tracker:initializer
```

## Configuration

You can configure ActiveJobTracker with the following options:

```ruby
# config/initializers/active_job_tracker.rb
ActiveJobTracker.configure do |config|
  # Default target value for jobs (default: 100)
  # This represents the total number of items to process in a job
  config.default_target = 100

  # Default cache threshold for progress updates (default: 10)
  # Progress updates are batched until this threshold is reached to reduce database writes
  config.cache_threshold = 10

  # Whether to automatically broadcast changes (default: true)
  # When true, job updates are automatically broadcast via ActionCable
  config.auto_broadcast = true

  # Default partial path for rendering job trackers
  # (default: 'active_job_tracker/active_job_tracker')
  config.default_partial = 'active_job_tracker/active_job_tracker'

  # Whether to include the style in the job tracker (default: true)
  # When true, the gem's CSS styles are automatically included
  config.include_style = true
end
```

## Usage

### Basic Setup

Set up the model that creates jobs:

```ruby
class CsvUpload < ApplicationRecord
  # Sets up polymorphic association to tie this record to the ActiveJobTracker
  has_one :job, as: :active_job_trackable, class_name: 'ActiveJobTrackerRecord'

  after_create :create_jobs

  def create_jobs
    # The tracked record must be passed into the job as the first argument
    ProcessImportJob.perform_later(self)
  end
end

```

Include the `ActiveJobTracker` module in your job classes:

```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJobTracker

  def perform(*args)
    # Your job logic here
  end
end
```

This automatically tracks the job's status (pending, running, completed, failed) throughout its lifecycle.

### Tracking Progress

To track progress within your job:

```ruby
class ProcessImportJob < ApplicationJob
  include ActiveJobTracker

  def perform(file_path)
    records = CSV.read(file_path)

    # Set the target (here, total number of items to process)
    # Defaults to 100 if unspecified
    active_job_tracker_target(records.size)

    records.each do |record|
      # Process item

      # Update progress (increments by 1)
      active_job_tracker_progress
    end
  end
end
```

For more efficient progress tracking with many updates, use progress caching:

```ruby
# In your job
def perform
  # You can override the cache threshold for when to flush progress updates to the database
  active_job_tracker_cache_threshold(20)
  active_job_tracker_target(records.size)
  1000.times do |i|
    # Process item

    # This will only update the database every 20th increment
    active_job_tracker_progress(cache: true)
  end
end
```

### Displaying Progress in Views

#### Basic Usage

To display job progress in your views:

```erb
<%= active_job_tracker_wrapper do %>
  <% @csv_uploads.each do |csv_upload| %>
    <% if (job = csv_upload.job) %>
      <%= render partial: 'active_job_tracker/active_job_tracker', locals: { active_job_tracker_record: job } %>
    <% end %>
  <% end %>
<% end %>
```

This will render a default tracker UI with progress bar, status badge, and job information.

#### Custom Rendering

You can customize the tracker UI by creating your own partials and using the ActiveJobTrackerRecord model attributes:
- Make sure to set the `config.default_partial` to the new partial path
- Each job block needs to be wrapped with `id="active_job_tracker_<%= tracker.id %>"` for turbo to update your frontend

```erb
<%= active_job_tracker_wrapper(html_options: { class: 'custom-container' }) do %>
  <% ActiveJobTrackerRecord.find_each do |tracker| %>
    <div class="custom-tracker" id="active_job_tracker_<%= tracker.id %>">
      <h3>Job #<%= tracker.id %></h3>

      <div class="status">
        Status: <span class="badge"><%= tracker.status %></span>
      </div>

      <div class="progress-bar">
        <progress value="<%= tracker.current %>" max="<%= tracker.target %>"></progress>
        <span><%= tracker.progress_percentage %>%</span>
      </div>

      <% if tracker.started_at.present? %>
        <div class="timing">
          Started: <%= tracker.started_at %>
          <% if tracker.completed_at.present? %>
            <br>Completed: <%= tracker.completed_at %>
            <br>Duration: <%= tracker.duration %> seconds
          <% end %>
        </div>
      <% end %>

      <% if tracker.failed? && tracker.error.present? %>
        <div class="error">
          <h4>Error:</h4>
          <p><%= tracker.error %></p>
          <% if tracker.backtrace.present? %>
            <pre><%= tracker.backtrace %></pre>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>
<% end %>
```

### Helper Methods

The gem provides the following helper method for displaying job trackers:

- `active_job_tracker_wrapper(options = {}, &block)` - Renders a wrapper for job trackers with Turbo Stream support

### Available Model Methods

The `ActiveJobTrackerRecord` model provides these useful methods:

```ruby
# Progress calculation
tracker.progress_ratio       # => 0.75 (ratio between 0 and 1)
tracker.progress_percentage  # => 75 (percentage between 0 and 100)

# Time tracking
tracker.duration  # => 123.45 (seconds since started_at)

# Status methods (from enum)
tracker.pending?    # => true/false
tracker.running?    # => true/false
tracker.completed?  # => true/false
tracker.failed?     # => true/false
```

### Error Handling

Errors are automatically tracked when a job fails. The gem adds a rescue_from handler that logs the error details before re-raising the exception:

```ruby
# This happens automatically when you include ActiveJobTracker
rescue_from(Exception) do |exception|
  active_job_tracker_log_error(exception)
  raise exception
end
```

You can also manually log errors:

```ruby
def perform
  begin
    # Risky operation
  rescue => e
    active_job_tracker_log_error(e)
    # Handle the error
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seenasabti/active_job_tracker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
