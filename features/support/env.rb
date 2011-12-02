require 'aruba/cucumber'
require 'capybara/cucumber'
require 'test/unit/assertions'
require 'pry'

$CUCUMBER=1

World(Test::Unit::Assertions)

Before do
  @aruba_timeout_seconds = 120
end
