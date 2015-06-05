source "https://rubygems.org"

gemspec

gem 'sqlite3', '~> 1.3.8', :platforms => :ruby

gem 'jruby-openssl', :platforms => :jruby
gem 'activerecord-jdbcsqlite3-adapter', :platforms => :jruby

gem 'rubysl', :platforms => :rbx
gem 'racc', :platforms => :rbx

gem 'pry'

# Hinting at development dependencies
# Prevents bundler from taking a long-time to resolve
group :development, :test do
  gem 'mime-types', '~> 1.16'
  gem 'builder'
end
