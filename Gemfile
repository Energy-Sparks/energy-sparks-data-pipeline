source 'https://rubygems.org'

gem 'aws-sdk-s3'
gem 'mail'
gem 'rubyzip'
gem 'faraday'
gem 'rollbar'
# Switch to custom branch that incorporates some necessary bug fixes
gem 'roo', git: 'https://github.com/Energy-Sparks/roo.git', branch: 'bug-fix-branch'
gem 'roo-xls'

group :test do
  gem 'rspec'
  gem 'bundler-audit'
end

group :development do
  gem 'fasterer'
  gem 'guard-rspec', require: false
end
