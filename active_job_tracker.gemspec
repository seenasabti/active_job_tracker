require_relative "lib/active_job_tracker/version"

Gem::Specification.new do |spec|
  spec.name = "active_job_tracker"
  spec.version = ActiveJobTracker::VERSION
  spec.authors = [ "Seena Sabti" ]
  spec.homepage = "https://github.com/seenasabti/active_job_tracker"
  spec.summary = "ActiveJobTracker provides a way to track the progress of ActiveJob jobs."
  spec.description = "ActiveJobTracker provides a way to track the progress of ActiveJob jobs."
  spec.license = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.1"

  spec.add_development_dependency "mocha"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "propshaft"
  spec.add_development_dependency "rubocop-rails-omakase"
  spec.add_development_dependency "debug", ">= 1.0.0"
end
