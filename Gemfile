source "https://rubygems.org"

# Specify your gem's dependencies in active_job_tracker.gemspec.
gemspec
group :test do
  gem "mocha"
end

gem "rails"
gem "turbo-rails"

group :development do
  gem "puma"
  gem "sqlite3"
  gem "propshaft"
  gem "redis"

  gem "rubocop-rails-omakase", require: false

  # Start debugger with binding.b [https://github.com/ruby/debug]
  gem "debug", ">= 1.0.0"
end
