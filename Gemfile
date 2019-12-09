source "https://rubygems.org"

gemspec

gem "pry"
gem "sqlite3", "~> 1.3.8", platforms: :ruby

# Hinting at development dependencies
# Prevents bundler from taking a long-time to resolve
group :development, :test do
  gem "activerecord-import"
  gem "builder"
  gem "mime-types"
  gem "rspec"
  gem "rubocop", require: false
  gem "sprockets", "3.7.2"
end
