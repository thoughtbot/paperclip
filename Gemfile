source "https://rubygems.org"

gemspec

gem 'sqlite3', '~> 1.3.8', :platforms => :ruby
gem 'pry'

# Hinting at development dependencies
# Prevents bundler from taking a long-time to resolve
group :development, :test do
  gem 'activerecord-import'
  gem 'mime-types', '~> 1.16'
  gem 'builder'
  gem 'rubocop', require: false
end
