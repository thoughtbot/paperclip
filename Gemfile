source "https://rubygems.org"

gemspec

gem 'jruby-openssl', :platform => :jruby
gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby

gem 'pry', :platform => :ruby
gem 'pry-byebug', :platform => :ruby

# Hinting at development dependencies
# Prevents bundler from taking a long-time to resolve
group :development, :test do
  gem 'mime-types', '~> 1.16'
  gem 'builder', '~> 3.1.4'
end
