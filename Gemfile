# frozen_string_literal: true

source 'https://rubygems.org'

gem 'aws-sdk-s3'
gem 'faraday'
gem 'mail'
gem 'rollbar'
gem 'rubyzip'
# Switch to custom branch that incorporates some necessary bug fixes
gem 'roo', git: 'https://github.com/Energy-Sparks/roo.git', branch: 'bug-fix-branch'
gem 'roo-xls'

group :test do
  gem 'bundler-audit'
  gem 'rspec'
end

group :development do
  gem 'fasterer'
  gem 'guard-rspec', require: false
  gem 'overcommit'
  gem 'rubocop-rspec'
end
